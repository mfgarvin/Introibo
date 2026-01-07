// lib/services/parish_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parish.dart';

/// Global singleton instance
final parishService = ParishService._();

class ParishService {
  static const String _remoteUrl =
      'https://raw.githubusercontent.com/mfgarvin/bulletin/refs/heads/main/export.json';
  static const String _cacheKey = 'cached_parishes_json';
  static const String _cacheTimestampKey = 'cached_parishes_timestamp';

  List<Parish> _parishes = [];
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _isUsingCachedData = false;
  bool _requiresInternet = false;
  String? _errorMessage;
  DateTime? _lastUpdated;

  ParishService._();

  /// Returns cached parishes or loads them if not yet loaded
  Future<List<Parish>> getParishes() async {
    if (_isLoaded) {
      return _parishes;
    }

    if (_isLoading) {
      // Wait for existing load to complete
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _parishes;
    }

    await _loadParishData();
    return _parishes;
  }

  /// Force reload from remote URL
  Future<List<Parish>> refreshParishes() async {
    _isLoaded = false;
    _requiresInternet = false;
    await _loadParishData();
    return _parishes;
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

  Future<void> _loadParishData() async {
    _isLoading = true;
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
    try {
      final response = await http
          .get(Uri.parse(_remoteUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _parishes = data.map((json) => Parish.fromJson(json)).toList();
        _isLoaded = true;
        _isUsingCachedData = false;
        _lastUpdated = DateTime.now();

        // Save to cache
        await prefs.setString(_cacheKey, response.body);
        await prefs.setInt(_cacheTimestampKey, _lastUpdated!.millisecondsSinceEpoch);

        _isLoading = false;
        return;
      } else {
        _errorMessage = 'Server returned ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Could not connect to server';
    }

    // If we have cached data, mark as using cached
    if (_isLoaded && _parishes.isNotEmpty) {
      _isUsingCachedData = true;
      _isLoading = false;
      return;
    }

    // No cached data and no internet - require internet connection
    _requiresInternet = true;
    _errorMessage = 'Internet connection required to download parish data';
    _isLoading = false;
  }
}
