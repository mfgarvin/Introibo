import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/parish.dart';
import '../utils/layout_scale.dart';
import '../utils/map_clustering.dart';
import '../services/location_service.dart';
import '../services/parish_service.dart';
import '../main.dart'
    show
        kPrimaryColor,
        kSecondaryColor,
        kBackgroundColor,
        kBackgroundColorDark,
        kCardColor,
        kCardColorDark,
        kTextDark,
        kAccentGoldDeep,
        primaryAccentFor,
        cardBorderFor,
        warningAccentFor,
        themeNotifier;
import '../widgets/stained_glass_header.dart';
import '../widgets/zip_location_dialog.dart';
import 'parish_detail_page.dart';

class FindParishNearMePage extends StatefulWidget {
  /// When the map is shown as a root tab (inside RootShell), there's nothing
  /// to pop back to — so we hide the floating back button.
  final bool inTab;

  const FindParishNearMePage({super.key, this.inTab = false});

  @override
  State<FindParishNearMePage> createState() => _FindParishNearMePageState();
}

class _FindParishNearMePageState extends State<FindParishNearMePage>
    with WidgetsBindingObserver {
  LatLng? userLocation;
  LocationFix? _fix;
  LocationFailure? _locationFailure;
  List<Parish> _parishes = [];
  List<Parish> _nearbyParishes = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  final MapController _mapController = MapController();
  PageController _pageController = PageController(viewportFraction: 0.85);

  /// Bumped whenever the carousel is rebuilt around a re-sorted list, as the
  /// PageView's key — see [_resetCarousel].
  int _carouselGeneration = 0;

  /// True once the map has been built, so [MapController] is safe to drive.
  bool _mapReady = false;

  /// Set when the user pans or zooms by hand. Their framing then wins over a
  /// background refresh — we only auto-recenter until they take the wheel.
  bool _userMovedCamera = false;

  /// Where the parish list is sorted from, when that isn't the user. Set to
  /// the camera centre each time a pan or zoom settles, so the carousel
  /// follows the view, and so a later background refresh doesn't quietly drag
  /// the list back to the user's own position. Non-null means the list is
  /// "what's in view" — which it is from the moment the map is ready; only
  /// before that is it the nearest 40, so the carousel has something to show.
  LatLng? _areaOrigin;

  /// Following mode found nothing inside the view, so the carousel is showing
  /// the nearest few instead — the pill has to say so.
  bool _noneInView = false;

  /// Restarted by every gesture frame; fires once the map has been still for
  /// [_followDelay], so the carousel doesn't churn under a moving finger.
  Timer? _followTimer;
  static const _followDelay = Duration(milliseconds: 300);

  /// Zoom in half-steps, as last drawn. Clusters only depend on the zoom, so
  /// the markers rebuild when this changes, not on every frame of a pan.
  int? _clusterZoomBucket;

  /// Screen distance under which marks merge. The largest mark (the selected
  /// pin, a full bubble) is 52px across, so at this spacing none can overlap.
  static const double _clusterRadius = 56;

  // Parchment/sepia tone — a soft warm wash that desaturates the map without
  // going full Stamen-Watercolor. Built from a standard sepia matrix scaled
  // back toward identity.
  static const _parchmentFilter = ColorFilter.matrix(<double>[
    0.55, 0.30, 0.10, 0, 18, // R
    0.20, 0.62, 0.10, 0, 14, // G
    0.12, 0.20, 0.50, 0, 5,  // B
    0,    0,    0,    1, 0,  // A
  ]);

  // Night wash for dark mode. The daytime tiles are light-on-light, so simply
  // dimming them would take the labels down with the land and leave nothing
  // readable. This is instead the composition of three matrices — invert,
  // hue-rotate 180° (so inverted water comes back blue rather than orange),
  // then the same warm desaturation the parchment filter uses, dimmed. Dark
  // text becomes candlelight cream, land settles just above the dark card
  // colour, and water still reads as water. The one concession is polarity:
  // white road fill inverts to near-black, so roads read as dark ribbons with
  // light casings rather than light lines. No linear matrix can invert the
  // labels without also inverting the roads.
  static const _nightFilter = ColorFilter.matrix(<double>[
     0.326, -1.288, -0.130, 0, 286.5, // R
    -0.366, -0.551, -0.123, 0, 270.1, // G
    -0.340, -1.140,  0.513, 0, 248.3, // B
     0,      0,      0,     1, 0,     // A
  ]);

  bool get _isDark => themeNotifier.isDarkMode;
  Color get _bgColor => _isDark ? kBackgroundColorDark : kBackgroundColor;
  Color get _cardColor => _isDark ? kCardColorDark : kCardColor;
  Color get _textColor => _isDark ? kTextDark : Colors.black87;
  Color get _subtextColor =>
      _isDark ? kTextDark.withValues(alpha: 0.7) : Colors.black54;
  Color get _accent => primaryAccentFor(isDark: _isDark);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // RootShell holds the tabs in a `static const` list, so a theme flip
    // rebuilds RootShell but hands this page the identical widget instance and
    // Flutter skips the subtree. Every tab subscribes for itself; without this
    // the map keeps its old wash until some other change happens to repaint it.
    themeNotifier.addListener(_onThemeChanged);
    locationService.addListener(_onSharedLocation);
    _loadParishData();
    _getUserLocation();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  /// Adopt a fix the Home tab obtained — both tabs stay alive side by side.
  void _onSharedLocation() {
    final fix = locationService.lastFix;
    if (fix == null || !mounted) return;
    if (userLocation == fix.position && _fix?.source == fix.source) return;
    _applyFix(fix);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeNotifier.removeListener(_onThemeChanged);
    locationService.removeListener(_onSharedLocation);
    _followTimer?.cancel();
    _mapController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh location on foreground (catches movement + a permission grant
    // made while backgrounded). Updates the marker/nearby list without moving
    // the camera, so a user's manual pan/zoom is preserved.
    if (state == AppLifecycleState.resumed) {
      _getUserLocation();
    }
  }

  /// Every parish the map can place, in the service's order. The order is
  /// what keeps clusters stable as the map pans — see
  /// [clusterByScreenDistance].
  List<Parish> get _mappable => _parishes
      .where((p) => p.latitude != null && p.longitude != null)
      .toList();

  void _rebuildNearby() {
    final origin = _areaOrigin ?? userLocation;
    if (origin == null) return;
    if (_areaOrigin != null && _mapReady) {
      final view = _parishesInView();
      _nearbyParishes = view.parishes;
      _noneInView = view.noneInView;
      return;
    }
    // Before the map is ready there is no view to list; the nearest 40 stand
    // in for the frame or two until [_followView] takes over.
    _noneInView = false;
    _nearbyParishes = (_mappable
          ..sort((a, b) =>
              _distance(origin, a).compareTo(_distance(origin, b))))
        .take(40)
        .toList();
  }

  /// Following the view: the carousel is exactly what's on screen — however
  /// many that is, since the PageView is lazy.
  ///
  /// Ordered from [around] when it is in view (the selected parish, so it
  /// leads and its neighbours sit beside it, and a pan that brings nothing
  /// new into view changes nothing), otherwise from the camera centre.
  ({List<Parish> parishes, bool noneInView}) _parishesInView(
      {Parish? around}) {
    final camera = _mapController.camera;
    final bounds = camera.visibleBounds;
    final inView = _mappable
        .where((p) => bounds.contains(LatLng(p.latitude!, p.longitude!)))
        .toList();
    final from = around != null && inView.contains(around)
        ? LatLng(around.latitude!, around.longitude!)
        : camera.center;
    int byDistance(Parish a, Parish b) =>
        _distance(from, a).compareTo(_distance(from, b));
    if (inView.isEmpty) {
      // Panned out over the lake: an empty carousel is a dead end, so offer
      // the nearest few and let the pill say they're not in view.
      return (
        parishes: (_mappable..sort(byDistance)).take(5).toList(),
        noneInView: true
      );
    }
    inView.sort(byDistance);
    // A second worship site at the same address ties at zero; the selected
    // one still goes first.
    if (from != camera.center && inView.first != around) {
      inView
        ..remove(around)
        ..insert(0, around!);
    }
    return (parishes: inView, noneInView: false);
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    final bucket = (camera.zoom * 2).round();
    if (hasGesture) {
      // A hand-driven pan/zoom pins the view; refreshes stop stealing it
      // until the user asks to recenter.
      _userMovedCamera = true;
      _followTimer?.cancel();
      _followTimer = Timer(_followDelay, _followView);
    }
    // One rebuild per half-step of zoom, not one per frame.
    if (bucket != _clusterZoomBucket) {
      setState(() => _clusterZoomBucket = bucket);
    }
  }

  /// Re-list the carousel around what the map is now showing. Every parish is
  /// already in memory, so this is a local filter and sort, not a fetch.
  ///
  /// The card the user was on stays on if it's still in view, so a small pan
  /// doesn't throw away their place; [select] puts a specific parish there
  /// instead (a tapped pin that wasn't in the list).
  ///
  /// [fresh] drops the current card too — for a start or a recentre, where
  /// the list should begin at whatever is nearest the centre.
  void _followView({Parish? select, bool fresh = false}) {
    _followTimer?.cancel();
    if (!mounted || !_mapReady) return;
    final keep = select ??
        (!fresh && _selectedIndex < _nearbyParishes.length
            ? _nearbyParishes[_selectedIndex]
            : null);
    final wasFollowing = _areaOrigin != null;
    _areaOrigin = _mapController.camera.center;
    final view = _parishesInView(around: keep);

    // Nothing entered or left the view: leave the carousel exactly as it is,
    // on whatever card the user swiped to. Re-sorting here is what made the
    // neighbouring cards shuffle on every small pan.
    if (wasFollowing &&
        select == null &&
        !fresh &&
        view.noneInView == _noneInView &&
        view.parishes.length == _nearbyParishes.length &&
        view.parishes.toSet().containsAll(_nearbyParishes)) {
      return;
    }

    var list = view.parishes;
    var index = keep == null ? -1 : list.indexOf(keep);
    if (index < 0 && select != null) {
      list = [select, ...list];
      index = 0;
    }
    setState(() {
      _nearbyParishes = list;
      _noneInView = view.noneInView;
      _selectedIndex = math.max(index, 0);
      _resetCarousel(_selectedIndex);
    });
  }

  /// Rebuild the carousel already standing on [index], for a list that has
  /// just been re-sorted under it.
  ///
  /// Not a jumpToPage: that lands a frame late, so for one frame the old page
  /// number shows whichever parish now sits at it, and the card visibly flips
  /// to it and back. A fresh controller with [initialPage] and a new key gets
  /// the very first frame right, and fires no page change — which would
  /// otherwise fly the camera to the card, away from where the user panned.
  /// Call inside setState.
  void _resetCarousel(int index) {
    final old = _pageController;
    _pageController =
        PageController(viewportFraction: 0.85, initialPage: index);
    _carouselGeneration++;
    // The old PageView lets go of it during this rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  /// A pin was tapped. It may not be in the carousel — a pin half off the edge
  /// of the view, say — so re-list around the view with it in front.
  void _onPinTapped(Parish parish) {
    final index = _nearbyParishes.indexOf(parish);
    if (index >= 0) {
      _selectParish(index);
      return;
    }
    _userMovedCamera = true;
    _followView(select: parish);
  }

  /// Zoom until a bubble's members come apart. Members that share a spot
  /// (two worship sites at one address) never will, so once zooming stops
  /// helping, pick the first and let the carousel show it.
  void _onClusterTapped(MapCluster<Parish> cluster) {
    final before = _mapController.camera.zoom;
    final insets = MediaQuery.paddingOf(context);
    _mapController.fitCamera(CameraFit.coordinates(
      coordinates: [
        for (final p in cluster.members) LatLng(p.latitude!, p.longitude!)
      ],
      maxZoom: 17,
      padding: EdgeInsets.fromLTRB(
          64, insets.top + 120, 64, _carouselTop(context) + 48),
    ));
    // fitCamera is not a gesture, so it doesn't schedule the follow itself.
    _userMovedCamera = true;
    final stuck = _mapController.camera.zoom - before < 0.25;
    _followView(select: stuck ? cluster.members.first : null);
  }

  double _distance(LatLng from, Parish p) {
    // Squared great-circle approximation; we only need to sort.
    final dLat = (p.latitude! - from.latitude);
    final dLon = (p.longitude! - from.longitude);
    return dLat * dLat + dLon * dLon;
  }

  void _selectParish(int index, {bool moveCamera = true, bool animatePage = true}) {
    if (index < 0 || index >= _nearbyParishes.length) return;
    setState(() => _selectedIndex = index);
    final parish = _nearbyParishes[index];
    if (moveCamera) {
      _mapController.move(
        LatLng(parish.latitude!, parish.longitude!),
        math.max(_mapController.camera.zoom, 14.0),
      );
    }
    if (animatePage && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _loadParishData() async {
    try {
      final parishes = await parishService.getParishes();

      setState(() {
        _parishes = parishes;
        _rebuildNearby();
      });

      // Same race as on Home: a stored ZIP can't resolve until the parish
      // data it resolves against has arrived.
      if (userLocation == null) {
        final fallback = await locationService.manualFallback(_parishes);
        if (fallback != null && mounted && userLocation == null) {
          _applyFix(fallback, recenter: true);
        }
      }
    } catch (e) {
      debugPrint('Error loading parish data: $e');
    }
  }

  /// Fetch a position and apply it. [recenter] moves the camera even if the
  /// user has panned — used by the my-location button, where recentring is
  /// the whole point.
  Future<void> _getUserLocation({bool recenter = false}) async {
    // Something on screen fast: a cached fix costs nothing and spares the
    // spinner on every resume.
    if (userLocation == null) {
      final cached = await locationService.lastKnown();
      if (cached != null && mounted && userLocation == null) {
        _applyFix(cached, recenter: true);
      }
    }

    final outcome = await locationService.current();
    if (!mounted) return;

    if (outcome.ok) {
      _applyFix(outcome.fix!, recenter: recenter);
      return;
    }

    // No device fix — fall back to a ZIP the user entered earlier, if any.
    final fallback = await locationService.manualFallback(_parishes);
    if (!mounted) return;
    if (fallback != null) {
      _applyFix(fallback, recenter: recenter);
      return;
    }

    setState(() {
      _locationFailure = outcome.failure;
      _isLoading = false;
    });
  }

  void _applyFix(LocationFix fix, {bool recenter = false}) {
    setState(() {
      userLocation = fix.position;
      _fix = fix;
      _locationFailure = null;
      _isLoading = false;
      _rebuildNearby();
    });

    // The camera used to be set once, through MapOptions.initialCenter, so a
    // later fix moved the marker off screen with no way to follow it.
    if (_mapReady && (recenter || !_userMovedCamera)) {
      _mapController.move(fix.position, _mapController.camera.zoom);
      if (recenter) _userMovedCamera = false;
      // The view moved without a gesture, so list what it now shows.
      // Recentring is asking to start over: nearest you first, from the top.
      _followView(fresh: recenter);
    }
  }

  Future<void> _promptForZip() async {
    final fix = await showZipLocationDialog(context, _parishes);
    if (fix == null || !mounted) return;
    _applyFix(fix, recenter: true);
  }

  @override
  Widget build(BuildContext context) {
    final localUserLocation = userLocation;

    // The carousel is a fixed strip over the map, so its cards can't scroll
    // their way out of trouble — at large text sizes a parish name plus its
    // city and next Mass overflowed a fixed height. It grows with the text, but
    // only up to [_carouselMaxHeight]: the card's text is bounded (a
    // two-line name, one line of city, one of time), so past that the extra
    // height was empty card over a map the user still needs to see.
    final carouselHeight = _carouselHeight(context);
    final carouselTop = _carouselTop(context);

    return Scaffold(
      backgroundColor: _bgColor,
      extendBodyBehindAppBar: true,
      appBar: widget.inTab
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _cardColor,
                  shape: BoxShape.circle,
                  border: cardBorderFor(isDark: _isDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: kPrimaryColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _accent),
                  const SizedBox(height: 24),
                  Text(
                    'Finding your location...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: _subtextColor,
                    ),
                  ),
                ],
              ),
            )
          : localUserLocation == null
              ? _buildLocationErrorState()
              : Stack(
                  children: [
                    // Map with the parchment (or, in dark mode, night)
                    // color filter applied to tiles only
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: localUserLocation,
                        initialZoom: 13.0,
                        minZoom: 8.0,
                        maxZoom: 18.0,
                        // North is always up. A twist gesture rotating the
                        // map is disorienting when the point is "where am I
                        // relative to these parishes", and nothing here draws
                        // a compass to rotate back with.
                        interactionOptions: InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                          cursorKeyboardRotationOptions:
                              CursorKeyboardRotationOptions.disabled(),
                        ),
                        onMapReady: () {
                          setState(() {
                            _mapReady = true;
                            _clusterZoomBucket =
                                (_mapController.camera.zoom * 2).round();
                          });
                          // Follow the view from the first frame, not only
                          // after the first pan: the carousel and its count
                          // are what's on screen, never "the 40 nearest".
                          WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _followView(fresh: true));
                        },
                        onPositionChanged: _onPositionChanged,
                      ),
                      children: [
                        ColorFiltered(
                          colorFilter: _isDark ? _nightFilter : _parchmentFilter,
                          child: TileLayer(
                            urlTemplate:
                                "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            // OSM's tile usage policy requires a real
                            // identifying User-Agent and blocks generic ones —
                            // keep this the actual application id.
                            userAgentPackageName: 'app.parishfinder',
                          ),
                        ),
                        MarkerLayer(
                          markers: [
                            ..._buildParishMarkers(),
                            if (userLocation != null) _buildUserLocationMarker(),
                          ],
                        ),
                      ],
                    ),
                    // Top pill. Once the user pans, the count describes where
                    // they used to be — so the same slot becomes the offer to
                    // re-sort around the new view instead of stating a stale
                    // number beside it.
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 60,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildTopPill()),
                    ),
                    // Recenter control. Also the only way back to yourself
                    // after panning, so it sits above the carousel.
                    Positioned(
                      right: 16,
                      bottom: carouselTop,
                      child: _buildRecenterButton(),
                    ),
                    // OSM credit. The ODbL wants attribution where the map is
                    // actually shown, not buried in About — so it stays put
                    // rather than hiding behind a tap. Sits level with the
                    // recenter button, clear of the carousel below.
                    Positioned(
                      left: 12,
                      bottom: carouselTop,
                      child: _buildMapAttribution(),
                    ),
                    // Bottom: swipeable parish carousel
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 20,
                      height: carouselHeight,
                      child: _buildParishCarousel(),
                    ),
                  ],
                ),
    );
  }

  /// The count pill. It describes whatever the carousel holds: the nearest
  /// parishes to you, or — once the map has been moved — what's in view.
  Widget _buildTopPill() {
    final following = _areaOrigin != null;
    final n = _nearbyParishes.length;
    final label = !following
        ? '$n parishes nearby'
        : _noneInView
            ? 'None in view · showing nearest'
            : n == 1
                ? '1 parish in view'
                : '$n parishes in view';
    return Semantics(
      label: label,
      liveRegion: true,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(24),
          border: cardBorderFor(isDark: _isDark),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              following ? Icons.crop_free : Icons.location_on,
              color: _accent,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOsmCopyright() async {
    final url = Uri.parse('https://www.openstreetmap.org/copyright');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing to recover; the credit text itself still discharges the licence.
    }
  }

  double _carouselHeight(BuildContext context) => context.scaled(116,
      max: math.min(
          _carouselMaxHeight, MediaQuery.sizeOf(context).height * 0.32));

  /// Distance from the bottom of the screen to the top of the carousel —
  /// everything above it is map the user can actually see.
  double _carouselTop(BuildContext context) =>
      20 + _carouselHeight(context) + 16;

  /// Ceiling for the carousel strip. Measured, not guessed: at the largest
  /// system font a card needs ~171px for its two-line name, city and Mass
  /// time, so this leaves a little headroom and no more. Without a ceiling
  /// the strip scaled to 300px and covered half the map.
  static const double _carouselMaxHeight = 180;

  Widget _buildMapAttribution() {
    // The attribution is a legal credit, not content — it should stay legible
    // without growing to compete with the map at large system font sizes, so
    // its text scales at most a little.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: _attributionChip(),
    );
  }

  Widget _attributionChip() {
    return Semantics(
      link: true,
      label: 'Map data from OpenStreetMap contributors. Opens the OpenStreetMap '
          'copyright page.',
      child: Material(
        color: _cardColor.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: _openOsmCopyright,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              '© OpenStreetMap contributors',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: _isDark
                    ? kTextDark.withValues(alpha: 0.75)
                    : kSecondaryColor.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecenterButton() {
    final usingZip = _fix?.source == LocationSource.manualZip;
    return Semantics(
      button: true,
      label: usingZip
          ? 'Centre on ZIP code ${_fix?.zip}'
          : 'Centre on my location',
      child: Material(
        color: _cardColor,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _getUserLocation(recenter: true),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              usingZip ? Icons.pin_drop_outlined : Icons.my_location,
              color: _accent,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: warningAccentFor(isDark: _isDark)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_off,
                color: warningAccentFor(isDark: _isDark),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to get location',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _locationFailureMessage(_locationFailure),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _subtextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _getUserLocation(recenter: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _isDark ? kBackgroundColorDark : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Some devices simply never produce a fix — a Wi-Fi-only tablet
            // out of range of known networks, or a user who declined the
            // permission outright. A ZIP keeps the map usable for them.
            TextButton.icon(
              onPressed: _parishes.isEmpty ? null : _promptForZip,
              icon: const Icon(Icons.pin_drop_outlined, size: 18),
              label: Text(
                'Enter a ZIP code instead',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(foregroundColor: _accent),
            ),
          ],
        ),
      ),
    );
  }

  static String _locationFailureMessage(LocationFailure? failure) {
    switch (failure) {
      case LocationFailure.permissionDeniedForever:
        return 'Location permission is turned off for ParishFinder. '
            'You can enable it in your device settings.';
      case LocationFailure.serviceDisabled:
        return 'Location services are turned off on this device.';
      case LocationFailure.timeout:
        return "We couldn't get a location fix — that's common indoors, "
            'and on tablets without GPS.';
      case LocationFailure.permissionDenied:
      case LocationFailure.unavailable:
      case null:
        return 'Please enable location services and grant permission '
            'to use this feature.';
    }
  }

  Marker _buildUserLocationMarker() {
    return Marker(
      point: userLocation!,
      width: 30.0,
      height: 30.0,
      child: Container(
        decoration: BoxDecoration(
          color: _accent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  /// Every parish on the map, with pins that would overlap merged into
  /// count bubbles. The selected parish anchors its own group, so the card on
  /// screen always has its pin, in the right place — whatever else is too
  /// close to draw is counted on that pin instead of piled beside it.
  List<Marker> _buildParishMarkers() {
    final selected = _selectedIndex < _nearbyParishes.length
        ? _nearbyParishes[_selectedIndex]
        : null;
    final zoom = _mapReady ? _mapController.camera.zoom : 13.0;
    final clusters = clusterByScreenDistance<Parish>(
      _mappable,
      position: (p) => LatLng(p.latitude!, p.longitude!),
      project: (ll) => const Epsg3857().latLngToPoint(ll, zoom),
      radius: _clusterRadius,
      anchor: selected,
    );
    final mine = selected == null ? null : clusters.first;
    return [
      for (final c in clusters)
        if (c != mine)
          c.isSingle ? _parishPin(c.members.single) : _clusterMarker(c),
      // Last, so it draws over everything else.
      if (mine != null) _selectedPin(mine),
    ];
  }

  /// The selected parish's pin, with a "+N" badge when it is standing in for
  /// neighbours too close to draw. Tapping it then zooms in like a bubble.
  Marker _selectedPin(MapCluster<Parish> group) {
    final parish = group.members.first;
    final hidden = group.members.length - 1;
    final pin = _parishPin(parish, isSelected: true,
        onTap: hidden > 0 ? () => _onClusterTapped(group) : null);
    if (hidden == 0) return pin;
    return Marker(
      point: pin.point,
      width: pin.width,
      height: pin.height,
      child: Semantics(
        label: '${parish.name}, and $hidden more nearby. Tap to zoom in',
        excludeSemantics: true,
        button: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: pin.child),
            Positioned(
              right: -6,
              top: -6,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _pinColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Text(
                      '+$hidden',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Deep plum vanishes into a night-washed map, so unselected pins (and the
  // bubbles that stand for them) go bronze in dark mode.
  Color get _pinColor => _isDark ? kAccentGoldDeep : kSecondaryColor;

  Marker _parishPin(Parish parish,
      {bool isSelected = false, VoidCallback? onTap}) {
    return Marker(
      point: LatLng(parish.latitude!, parish.longitude!),
      width: isSelected ? 52.0 : 38.0,
      height: isSelected ? 52.0 : 38.0,
      child: GestureDetector(
        onTap: onTap ?? () => _onPinTapped(parish),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected ? _accent : _pinColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: (isSelected ? _accent : Colors.black)
                    .withValues(alpha: isSelected ? 0.4 : 0.25),
                blurRadius: isSelected ? 14 : 6,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Icon(
            Icons.church,
            color: isSelected && _isDark ? kBackgroundColorDark : Colors.white,
            size: isSelected ? 26 : 20,
          ),
        ),
      ),
    );
  }

  /// A count bubble, in the unselected pins' colour so it reads as "more of
  /// those". Grows a little with the count — enough to tell Cleveland's
  /// dozens from a pair, not so much that the whole-diocese view is all disc.
  Marker _clusterMarker(MapCluster<Parish> cluster) {
    final n = cluster.members.length;
    final size = 40.0 + 12.0 * math.min(n, 30) / 30;
    return Marker(
      point: cluster.center,
      width: size,
      height: size,
      child: Semantics(
        button: true,
        label: '$n parishes here. Tap to zoom in',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => _onClusterTapped(cluster),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _pinColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                ),
              ],
            ),
            // A count on a fixed-size disc, not body text: shrink to fit
            // rather than spill at a large text scale.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$n',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParishCarousel() {
    if (_nearbyParishes.isEmpty) return const SizedBox.shrink();
    return PageView.builder(
      key: ValueKey(_carouselGeneration),
      controller: _pageController,
      itemCount: _nearbyParishes.length,
      onPageChanged: (i) => _selectParish(i, animatePage: false),
      itemBuilder: (context, i) {
        final parish = _nearbyParishes[i];
        final selected = i == _selectedIndex;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: selected ? 0 : 4,
          ),
          child: _MapParishCard(
            parish: parish,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ParishDetailPage(parish: parish),
              ),
            ),
          ),
        );
      },
    );
  }

}

class _MapParishCard extends StatelessWidget {
  final Parish parish;
  final VoidCallback onTap;

  const _MapParishCard({required this.parish, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final firstMass = parish.previewMassTime?.display;
    final isDark = themeNotifier.isDarkMode;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? kTextDark : Colors.black87;
    final subtextColor =
        isDark ? kTextDark.withValues(alpha: 0.7) : Colors.black54;
    final accent = primaryAccentFor(isDark: isDark);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: cardBorderFor(isDark: isDark),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // The glass thumbnail is decoration; the name is the point. At
              // large text sizes its fixed 64px (plus the gap) is the
              // difference between "Transfiguration Parish" reading straight
              // and breaking mid-word, so past [prefersStackedLayout] the
              // card gives the width to the text instead.
              if (!context.prefersStackedLayout) ...[
                ParishGlassHero(
                  seed: parish.parishId ?? parish.name,
                  patron: parish.name,
                  borderRadius: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: StainedGlassHeader(
                        seed: parish.parishId ?? parish.name,
                        patron: parish.name,
                        overlayDarken: 0.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      parish.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      parish.city,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (firstMass != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: accent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              firstMass,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: subtextColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
