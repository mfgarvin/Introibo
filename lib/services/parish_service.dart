// lib/services/parish_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parish.dart';

/// Global singleton instance
final parishService = ParishService._();

class ParishService extends ChangeNotifier with WidgetsBindingObserver {
  static const String _remoteUrl =
      'https://raw.githubusercontent.com/mfgarvin/bulletin/refs/heads/main/export.json';
  static const String _cacheKey = 'cached_parishes_json';
  static const String _cacheTimestampKey = 'cached_parishes_timestamp';

  /// How old the data may get before the app quietly re-fetches it.
  ///
  /// A cold start always hits the network, but a phone rarely gives the app
  /// one: Android keeps the process cached and iOS keeps it suspended, often
  /// for weeks, and tapping the icon then *resumes* it — re-running neither
  /// `main()` nor any `initState()`. [_isLoaded] would stay true for the life
  /// of that process, so [getParishes] would keep handing out whatever was
  /// fetched the day the app was installed. This is the clock that stops it.
  ///
  /// A day is well inside the resolution of the data — bulletins are weekly —
  /// and the payload is ~560 KB, so the refetch costs little.
  static const Duration refreshInterval = Duration(hours: 24);

  /// How old the data may get before the user is warned that it may be wrong.
  ///
  /// Only reachable when the refresh above has been failing for a week, so an
  /// install with working connectivity never sees it.
  static const Duration staleThreshold = Duration(days: 7);

  List<Parish> _parishes = [];
  bool _isLoaded = false;
  Future<void>? _pendingLoad;
  Future<void>? _pendingRefresh;
  bool _isUsingCachedData = false;
  bool _requiresInternet = false;
  String? _errorMessage;
  DateTime? _lastUpdated;

  ParishService._();

  /// Test seams. The staleness math is a clock comparison and the refresh is a
  /// network call, so neither is observable in a widget test without these;
  /// production never reassigns them.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  @visibleForTesting
  static http.Client Function() clientFactory = http.Client.new;

  /// Return the singleton to its just-constructed state. The service is a
  /// global, so without this one test's data would leak into the next.
  @visibleForTesting
  void resetForTest() {
    _parishes = [];
    _isLoaded = false;
    _pendingLoad = null;
    _pendingRefresh = null;
    _isUsingCachedData = false;
    _requiresInternet = false;
    _errorMessage = null;
    _lastUpdated = null;
    now = DateTime.now;
    clientFactory = http.Client.new;
  }

  /// Start the lifecycle hook that keeps the data fresh across resumes.
  /// Call once, from `main()`.
  void init() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshIfStale());
    }
  }

  /// Returns cached parishes or loads them if not yet loaded
  Future<List<Parish>> getParishes() async {
    if (_isLoaded) {
      // Aged out while the process sat in the background — fetch in the
      // background and return what we have, so no screen waits on the network.
      unawaited(refreshIfStale());
      return _parishes;
    }
    await (_pendingLoad ??= _loadParishData());
    return _parishes;
  }

  /// The parishes already in memory, without awaiting a load. Empty until the
  /// first [getParishes] completes; prefer [getParishes] unless you know the
  /// data is loaded (a listener firing after a refresh, for instance).
  List<Parish> get parishes => List.unmodifiable(_parishes);

  /// Force reload from remote URL
  Future<List<Parish>> refreshParishes() async {
    _isLoaded = false;
    _requiresInternet = false;
    _pendingLoad = _loadParishData();
    await _pendingLoad;
    notifyListeners();
    return _parishes;
  }

  /// Re-fetch in the background if the data has aged past [refreshInterval].
  ///
  /// Silent by design, unlike [refreshParishes]: it never clears [isLoaded],
  /// so nothing on screen drops back to a spinner, and a failed attempt leaves
  /// the parishes already loaded exactly where they are. Cheap to call often —
  /// it returns immediately unless the data is actually due.
  Future<void> refreshIfStale() async {
    if (!_isLoaded || !_needsRefresh) return;
    // A resume can arrive while the previous attempt is still in flight
    // (a flaky network on a 10s timeout); share it rather than stacking.
    await (_pendingRefresh ??= () async {
      try {
        final wasStale = isStale;
        if (!await _fetchRemote()) {
          _isUsingCachedData = true;
          // Only worth a rebuild if it changed what the UI would say.
          if (isStale != wasStale) notifyListeners();
          return;
        }
        notifyListeners();
      } finally {
        _pendingRefresh = null;
      }
    }());
  }

  /// Check if data is loaded
  bool get isLoaded => _isLoaded;

  /// Returns true if using cached/offline data (couldn't reach server)
  bool get isUsingCachedData => _isUsingCachedData;

  /// Returns true if no data available and internet connection is required
  bool get requiresInternet => _requiresInternet;

  /// Get any error message from last load attempt
  String? get errorMessage => _errorMessage;

  /// Get the timestamp of when data was last successfully fetched from server
  DateTime? get lastUpdated => _lastUpdated;

  /// How long ago the data was last fetched, or null if it never has been.
  Duration? get dataAge {
    final updated = _lastUpdated;
    return updated == null ? null : now().difference(updated);
  }

  /// True when the data is old enough to tell the user about — see
  /// [staleThreshold].
  bool get isStale {
    final age = dataAge;
    return age != null && age >= staleThreshold;
  }

  bool get _needsRefresh {
    final age = dataAge;
    return age == null || age >= refreshInterval;
  }

  /// One attempt at the network copy. Returns true if it landed.
  ///
  /// Touches [_parishes], [_lastUpdated] and the cache only on success, so a
  /// caller that already has data keeps it when the network is down.
  Future<bool> _fetchRemote() async {
    final client = clientFactory();
    try {
      final response = await client
          .get(Uri.parse(_remoteUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _errorMessage = 'Server returned ${response.statusCode}';
        return false;
      }

      final List<dynamic> data = json.decode(response.body);
      _parishes = data.map((json) => Parish.fromJson(json)).toList();
      _isLoaded = true;
      _isUsingCachedData = false;
      _errorMessage = null;
      _lastUpdated = now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, response.body);
      await prefs.setInt(
          _cacheTimestampKey, _lastUpdated!.millisecondsSinceEpoch);
      return true;
    } catch (e) {
      _errorMessage = 'Could not connect to server';
      return false;
    } finally {
      client.close();
    }
  }

  Future<void> _loadParishData() async {
    _errorMessage = null;
    _isUsingCachedData = false;
    _requiresInternet = false;

    final prefs = await SharedPreferences.getInstance();

    // First, try to load from local cache for fast startup
    final cachedJson = prefs.getString(_cacheKey);
    final cachedTimestamp = prefs.getInt(_cacheTimestampKey);

    if (cachedJson != null) {
      try {
        final List<dynamic> data = json.decode(cachedJson);
        _parishes = data.map((json) => Parish.fromJson(json)).toList();
        _isLoaded = true;
        if (cachedTimestamp != null) {
          _lastUpdated = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
        }
      } catch (e) {
        // Cache is corrupted, will try remote
      }
    }

    // Now try to fetch fresh data from remote URL
    if (await _fetchRemote()) return;

    // If we have cached data, mark as using cached
    if (_isLoaded && _parishes.isNotEmpty) {
      _isUsingCachedData = true;
      return;
    }

    // No cached data and no internet - require internet connection
    _requiresInternet = true;
    _errorMessage = 'Internet connection required to download parish data';
  }
}
