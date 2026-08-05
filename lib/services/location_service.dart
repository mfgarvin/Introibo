import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/parish.dart';

/// Dev override: set to a LatLng to skip GPS, or null to use real location.
/// Debug builds bypass Geolocator entirely; release builds always use the
/// device. This used to be declared twice — once in `main.dart` and once in
/// `find_parish_near_me_page.dart` — which is exactly how the two copies of
/// the location logic drifted apart.
const LatLng? kDevLocation = kDebugMode
    ? LatLng(41.48, -81.78) // Lakewood, OH - near several parishes
    : null;

/// Where a position came from. The UI uses this to decide whether to show
/// precise distances and whether to offer the ZIP fallback.
enum LocationSource {
  /// A real fix from the device (GPS, or Wi-Fi/cell via the fused provider).
  device,

  /// Derived on-device from a ZIP the user typed, using our own parish data.
  manualZip,

  /// The debug-only [kDevLocation] override.
  devOverride,
}

/// Why a location lookup failed. Each maps to different user-facing advice —
/// "grant permission" and "turn on location services" are not the same fix.
enum LocationFailure {
  /// Denied this time; asking again may still work.
  permissionDenied,

  /// Denied permanently — only a trip to system settings will change it.
  permissionDeniedForever,

  /// Location services are switched off device-wide.
  serviceDisabled,

  /// No fix inside the time limit. Common indoors, and on devices with no
  /// GPS hardware and no usable Wi-Fi positioning.
  timeout,

  /// Anything else the platform threw at us.
  unavailable,
}

@immutable
class LocationFix {
  final LatLng position;
  final LocationSource source;

  /// Radius of uncertainty in metres, when the platform reports one.
  final double? accuracyMeters;

  /// Set when [source] is [LocationSource.manualZip].
  final String? zip;

  const LocationFix(
    this.position,
    this.source, {
    this.accuracyMeters,
    this.zip,
  });

  /// True when the fix is too fuzzy to justify a "0.2 mi" label. Android 12+
  /// lets a user grant "Approximate" regardless of what we ask for, which
  /// lands around a 1-3 km grid; a ZIP centroid is no better.
  bool get isCoarse =>
      source == LocationSource.manualZip ||
      (accuracyMeters != null && accuracyMeters! > 500);
}

/// Result of a lookup: exactly one of [fix] or [failure] is non-null.
@immutable
class LocationOutcome {
  final LocationFix? fix;
  final LocationFailure? failure;

  const LocationOutcome.success(LocationFix this.fix) : failure = null;
  const LocationOutcome.failed(LocationFailure this.failure) : fix = null;

  bool get ok => fix != null;
}

/// Single source of truth for "where is the user".
///
/// Accuracy note: we ask for [LocationAccuracy.medium] (Android's
/// balanced-power priority), not high. High accuracy is GPS-first and will sit
/// waiting on a satellite lock that never arrives indoors — a church basement
/// being the exact place this app gets opened. Medium leans on Wi-Fi/cell via
/// the fused provider, returns in about a second, and lands within ~100 m,
/// which is far finer than a list sorted by nearest parish needs.
class LocationService extends ChangeNotifier {
  static const _manualZipKey = 'manual_location_zip';
  static const _defaultTimeout = Duration(seconds: 15);

  /// How long the cheap balanced-power pass gets before we escalate to GPS.
  static const _quickAttempt = Duration(seconds: 5);

  /// One attempt at a given accuracy. Returns null on timeout so the caller
  /// can escalate; anything else propagates.
  Future<Position?> _tryFix(LocationAccuracy accuracy, Duration limit) async {
    if (limit <= Duration.zero) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: limit,
        ),
      );
    } on TimeoutException {
      return null;
    }
  }

  String? _manualZip;
  bool _manualZipLoaded = false;
  LocationFix? _lastFix;

  /// The most recent fix from any caller. The Home and Map tabs both stay
  /// alive inside the RootShell's IndexedStack, so without this a ZIP typed
  /// on one tab left the other still showing "location unavailable".
  LocationFix? get lastFix => _lastFix;

  void _publish(LocationFix fix) {
    _lastFix = fix;
    notifyListeners();
  }

  /// The ZIP the user last entered, if any. Kept so the fallback survives a
  /// restart on a device that can never produce a fix.
  String? get manualZip => _manualZip;

  Future<void> _ensureManualZipLoaded() async {
    if (_manualZipLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _manualZip = prefs.getString(_manualZipKey);
    } catch (_) {
      // A prefs failure just means no stored fallback; not worth surfacing.
    }
    _manualZipLoaded = true;
  }

  /// A cached position, if the platform already has one. Returns immediately,
  /// so callers can paint something while [current] is still in flight.
  Future<LocationFix?> lastKnown() async {
    if (kDevLocation != null) {
      return LocationFix(kDevLocation!, LocationSource.devOverride);
    }
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      final fix = LocationFix(
        LatLng(position.latitude, position.longitude),
        LocationSource.device,
        accuracyMeters: position.accuracy,
      );
      _publish(fix);
      return fix;
    } catch (_) {
      // Throws when permission was never granted — same as "nothing cached".
      return null;
    }
  }

  /// Request a fresh fix, checking services and permission first.
  Future<LocationOutcome> current({Duration timeout = _defaultTimeout}) async {
    if (kDevLocation != null) {
      return LocationOutcome.success(
        LocationFix(kDevLocation!, LocationSource.devOverride),
      );
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationOutcome.failed(LocationFailure.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Only worth asking when it's a soft denial — deniedForever returns
        // immediately without showing anything, so don't pretend otherwise.
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationOutcome.failed(
          LocationFailure.permissionDeniedForever,
        );
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return const LocationOutcome.failed(LocationFailure.permissionDenied);
      }

      // Two passes, cheapest first.
      //
      // Balanced power leans on Wi-Fi/cell and usually answers in about a
      // second — the right first ask indoors, and the only one that works on
      // a tablet with no GPS chip. But it never starts the GPS provider, so
      // where there is no network positioning at all (rural, and the Android
      // emulator, whose `geo fix` feeds only the GPS provider) it returns
      // nothing. Falling back to GPS-first covers that, and costs the user
      // nothing when the quick pass already succeeded.
      var position = await _tryFix(LocationAccuracy.medium, _quickAttempt);
      position ??= await _tryFix(LocationAccuracy.high, timeout - _quickAttempt);
      if (position == null) {
        return const LocationOutcome.failed(LocationFailure.timeout);
      }

      final fix = LocationFix(
        LatLng(position.latitude, position.longitude),
        LocationSource.device,
        accuracyMeters: position.accuracy,
      );
      _publish(fix);
      return LocationOutcome.success(fix);
    } on TimeoutException {
      return const LocationOutcome.failed(LocationFailure.timeout);
    } on LocationServiceDisabledException {
      return const LocationOutcome.failed(LocationFailure.serviceDisabled);
    } catch (e) {
      debugPrint('LocationService: $e');
      return const LocationOutcome.failed(LocationFailure.unavailable);
    }
  }

  /// The stored ZIP fallback resolved against [parishes], or null if the user
  /// never set one (or the data no longer covers it).
  ///
  /// Only consulted when the device itself can't produce a fix, so a real
  /// position always wins and a stale ZIP can never quietly override it.
  Future<LocationFix?> manualFallback(List<Parish> parishes) async {
    await _ensureManualZipLoaded();
    final zip = _manualZip;
    if (zip == null) return null;
    final centre = centroidForZip(zip, parishes);
    if (centre == null) return null;
    final fix = LocationFix(centre, LocationSource.manualZip, zip: zip);
    _publish(fix);
    return fix;
  }

  /// Store [zip] as the fallback and resolve it. Returns null when no parish
  /// in the dataset carries that ZIP, in which case nothing is saved.
  Future<LocationFix?> setManualZip(String zip, List<Parish> parishes) async {
    final normalized = normalizeZip(zip);
    if (normalized == null) return null;
    final centre = centroidForZip(normalized, parishes);
    if (centre == null) return null;

    _manualZip = normalized;
    _manualZipLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_manualZipKey, normalized);
    } catch (_) {
      // Non-fatal: the fallback still works for this session.
    }
    final fix = LocationFix(centre, LocationSource.manualZip, zip: normalized);
    _publish(fix);
    return fix;
  }

  Future<void> clearManualZip() async {
    _manualZip = null;
    _manualZipLoaded = true;
    _lastFix = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_manualZipKey);
    } catch (_) {}
  }

  /// Five digits, or null if [raw] isn't one. ZIP+4 is truncated.
  static String? normalizeZip(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 5) return null;
    return digits.substring(0, 5);
  }

  /// Mean position of every parish carrying [zip].
  ///
  /// Deliberately offline: the parish records already ship both `zip_code` and
  /// coordinates, so a ZIP never has to be sent to a geocoding service. That
  /// keeps location entirely on-device and leaves the Play Data safety
  /// declaration untouched.
  static LatLng? centroidForZip(String zip, List<Parish> parishes) {
    final normalized = normalizeZip(zip);
    if (normalized == null) return null;

    double latSum = 0;
    double lonSum = 0;
    var count = 0;
    for (final parish in parishes) {
      if (parish.latitude == null || parish.longitude == null) continue;
      if (normalizeZip(parish.zipCode) != normalized) continue;
      latSum += parish.latitude!;
      lonSum += parish.longitude!;
      count++;
    }
    if (count == 0) return null;
    return LatLng(latSum / count, lonSum / count);
  }
}

/// Global singleton, matching the `parishService` pattern.
final locationService = LocationService();
