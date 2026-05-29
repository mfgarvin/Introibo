import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/parish.dart';
import '../services/parish_service.dart';
import '../main.dart' show kPrimaryColor, kSecondaryColor, kBackgroundColor, kCardColor;
import '../widgets/stained_glass_header.dart';
import 'parish_detail_page.dart';

// Dev override: set to a LatLng to skip GPS, or null to use real location
const LatLng? kDevLocation = kDebugMode
    ? LatLng(41.48, -81.78) // Lakewood, OH - near several parishes
    : null;

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
  List<Parish> _parishes = [];
  List<Parish> _nearbyParishes = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.85);

  // Parchment/sepia tone — a soft warm wash that desaturates the map without
  // going full Stamen-Watercolor. Built from a standard sepia matrix scaled
  // back toward identity.
  static const _parchmentFilter = ColorFilter.matrix(<double>[
    0.55, 0.30, 0.10, 0, 18, // R
    0.20, 0.62, 0.10, 0, 14, // G
    0.12, 0.20, 0.50, 0, 5,  // B
    0,    0,    0,    1, 0,  // A
  ]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadParishData();
    _getUserLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  void _rebuildNearby() {
    if (userLocation == null) return;
    final withCoords = _parishes
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();
    withCoords.sort((a, b) {
      final da = _distance(userLocation!, a);
      final db = _distance(userLocation!, b);
      return da.compareTo(db);
    });
    _nearbyParishes = withCoords.take(40).toList();
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
    } catch (e) {
      debugPrint('Error loading parish data: $e');
    }
  }

  Future<void> _getUserLocation() async {
    // Use dev override if set
    if (kDevLocation != null) {
      debugPrint('Using dev location: ${kDevLocation!.latitude}, ${kDevLocation!.longitude}');
      setState(() {
        userLocation = kDevLocation;
        _isLoading = false;
        _rebuildNearby();
      });
      return;
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          debugPrint('Location permissions are denied');
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
        _rebuildNearby();
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localUserLocation = userLocation;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: widget.inTab
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kCardColor,
                  shape: BoxShape.circle,
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
                  const CircularProgressIndicator(color: kPrimaryColor),
                  const SizedBox(height: 24),
                  Text(
                    'Finding your location...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          : localUserLocation == null
              ? _buildLocationErrorState()
              : Stack(
                  children: [
                    // Map with parchment color filter applied to tiles only
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: localUserLocation,
                        initialZoom: 13.0,
                        minZoom: 8.0,
                        maxZoom: 18.0,
                      ),
                      children: [
                        ColorFiltered(
                          colorFilter: _parchmentFilter,
                          child: TileLayer(
                            urlTemplate:
                                "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            userAgentPackageName: 'com.example.introibo',
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
                    // Top pill: parish count
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 60,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: kCardColor,
                            borderRadius: BorderRadius.circular(24),
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
                              const Icon(Icons.location_on, color: kPrimaryColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${_nearbyParishes.length} parishes nearby',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom: swipeable parish carousel
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 20,
                      height: 150,
                      child: _buildParishCarousel(),
                    ),
                  ],
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
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off,
                color: Colors.orange,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to get location',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please enable location services and grant permission to use this feature.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _getUserLocation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
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
          ],
        ),
      ),
    );
  }

  Marker _buildUserLocationMarker() {
    return Marker(
      point: userLocation!,
      width: 30.0,
      height: 30.0,
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildParishMarkers() {
    final markers = <Marker>[];
    for (int i = 0; i < _nearbyParishes.length; i++) {
      final parish = _nearbyParishes[i];
      final isSelected = i == _selectedIndex;
      markers.add(
        Marker(
          point: LatLng(parish.latitude!, parish.longitude!),
          width: isSelected ? 52.0 : 38.0,
          height: isSelected ? 52.0 : 38.0,
          child: GestureDetector(
            onTap: () => _selectParish(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : kSecondaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? kPrimaryColor : Colors.black)
                        .withValues(alpha: isSelected ? 0.4 : 0.25),
                    blurRadius: isSelected ? 14 : 6,
                    spreadRadius: isSelected ? 2 : 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.church,
                color: Colors.white,
                size: isSelected ? 26 : 20,
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  Widget _buildParishCarousel() {
    if (_nearbyParishes.isEmpty) return const SizedBox.shrink();
    return PageView.builder(
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
            vertical: selected ? 0 : 8,
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
    final firstMass = parish.massTimes.isNotEmpty ? parish.massTimes.first.display : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Hero(
                tag: parishHeroTag(parish.parishId ?? parish.name),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: StainedGlassHeader(
                      seed: parish.parishId ?? parish.name,
                      overlayDarken: 0.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
                        color: Colors.black87,
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
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (firstMass != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: kSecondaryColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              firstMass,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: kSecondaryColor,
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
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
