import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/parish.dart';
import '../services/location_service.dart';

/// Somewhere other than "here" to plan around — "Saturday in Akron".
///
/// Resolved entirely from our own parish data, the same way the offline ZIP
/// fallback is ([LocationService.centroidForZip]): a city is the centre of its
/// own parishes. Nothing is geocoded and nothing leaves the phone, so the
/// "location stays on-device" claim holds for planning too.
class PlanPlace {
  /// What the user picked, as it should read in a sentence: "Akron", "44107".
  final String label;

  final LatLng center;

  /// How far out still counts as "in" this place. A city's reach is its own
  /// spread — Cleveland's 45 parishes span the whole city, Bay Village's one
  /// doesn't span anything — plus a margin for the parish just over the line.
  final double radiusMiles;

  const PlanPlace(this.label, this.center, this.radiusMiles);

  /// Never smaller than this: a one-parish town still has neighbours worth
  /// showing.
  static const double minRadiusMiles = 6;

  /// Added past a city's farthest parish.
  static const double cityMarginMiles = 2;

  static const _distance = Distance();

  static double milesBetween(LatLng a, LatLng b) =>
      _distance.as(LengthUnit.Mile, a, b);

  /// Every city with at least one mappable parish, sorted, for the picker.
  static List<String> cities(List<Parish> parishes) => {
        for (final p in parishes)
          if (p.latitude != null && p.longitude != null && p.city.isNotEmpty)
            p.city,
      }.toList()
        ..sort();

  /// A city name (any case) or a five-digit ZIP, or null if neither names
  /// anywhere we have a parish.
  static PlanPlace? resolve(String query, List<Parish> parishes) {
    final q = query.trim();
    if (q.isEmpty) return null;

    final zip = LocationService.normalizeZip(q);
    if (zip != null && RegExp(r'^\d').hasMatch(q)) {
      final centre = LocationService.centroidForZip(zip, parishes);
      return centre == null ? null : PlanPlace(zip, centre, minRadiusMiles);
    }

    final inCity = [
      for (final p in parishes)
        if (p.latitude != null &&
            p.longitude != null &&
            p.city.toLowerCase() == q.toLowerCase())
          LatLng(p.latitude!, p.longitude!),
    ];
    if (inCity.isEmpty) return null;
    final centre = LatLng(
      inCity.map((p) => p.latitude).reduce((a, b) => a + b) / inCity.length,
      inCity.map((p) => p.longitude).reduce((a, b) => a + b) / inCity.length,
    );
    final spread =
        inCity.map((p) => milesBetween(centre, p)).reduce(math.max);
    // The label takes the data's own spelling, not what was typed.
    final name = parishes
        .firstWhere((p) => p.city.toLowerCase() == q.toLowerCase())
        .city;
    return PlanPlace(name, centre,
        math.max(minRadiusMiles, spread + cityMarginMiles));
  }

  @override
  bool operator ==(Object other) =>
      other is PlanPlace && other.label == label && other.center == center;

  @override
  int get hashCode => Object.hash(label, center);
}

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Sat, Oct 10" — a planned date as it reads on a chip.
String planDateLabel(DateTime d) =>
    '${_weekdayShort[d.weekday - 1]}, ${_monthShort[d.month - 1]} ${d.day}';
