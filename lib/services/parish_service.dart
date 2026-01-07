// lib/services/parish_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/parish.dart';

/// Global singleton instance
final parishService = ParishService._();

class ParishService {
  static const String _remoteUrl =
      'https://raw.githubusercontent.com/mfgarvin/bulletin/refs/heads/main/export.json';
  static const String _localAsset = 'data/parishes.json';

  List<Parish> _parishes = [];
  bool _isLoaded = false;
  bool _isLoading = false;
  String? _errorMessage;

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
    await _loadParishData();
    return _parishes;
  }

  /// Check if data is loaded
  bool get isLoaded => _isLoaded;

  /// Get any error message from last load attempt
  String? get errorMessage => _errorMessage;

  Future<void> _loadParishData() async {
    _isLoading = true;
    _errorMessage = null;

    try {
      // Try loading from remote URL first
      final response = await http
          .get(Uri.parse(_remoteUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _parishes = data.map((json) => Parish.fromJson(json)).toList();
        _isLoaded = true;
        _isLoading = false;
        return;
      } else {
        _errorMessage = 'Server returned ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
    }

    // Fallback to local asset if remote fails
    try {
      final String localData = await rootBundle.loadString(_localAsset);
      final List<dynamic> data = json.decode(localData);
      _parishes = data.map((json) => Parish.fromJson(json)).toList();
      _isLoaded = true;
      _errorMessage = _errorMessage != null
          ? '$_errorMessage (using cached data)'
          : null;
    } catch (e) {
      _errorMessage = 'Failed to load parish data: $e';
      _parishes = [];
    }

    _isLoading = false;
  }
}
