import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parishfinder/models/parish.dart';
import 'package:parishfinder/pages/filtered_parish_list_page.dart';
import 'package:parishfinder/utils/plan_query.dart';

/// The Home planner's answer: one hit per parish, earliest fitting time,
/// soonest then nearest, inside the place's reach.

Parish _parish(
  String id, {
  double lat = 41.48,
  double lon = -81.78,
  List<Map<String, dynamic>> mass = const [],
  List<Map<String, dynamic>> confession = const [],
  bool perpetual = false,
}) =>
    Parish.fromJson({
      'name': 'Parish $id',
      'parish_id': id,
      'address': '1 Main St',
      'city': 'Lakewood',
      'zip_code': '44107',
      'latitude': lat,
      'longitude': lon,
      'schedules': {
        'mass': mass,
        'confession': confession,
        'adoration': {'is_perpetual': perpetual, 'times': []},
      },
    });

Map<String, dynamic> _e(String day, String start,
        {String? end, List<int>? weeks, bool cancelled = false}) =>
    {
      'day': day,
      'start': start,
      'end': end,
      'cancelled': cancelled,
      if (weeks != null) 'weeks_of_month': weeks,
    };

const _here = LatLng(41.48, -81.78);

// Saturday 2026-10-03, 9 am.
final _now = DateTime(2026, 10, 3, 9);
final _sat = DateTime(2026, 10, 3);

void main() {
  test('one hit per parish, at its earliest fitting time', () {
    final p = _parish('1', mass: [
      _e('saturday', '17:00'),
      _e('saturday', '10:00'),
    ]);
    final hits = planHits(
        parishes: [p],
        filter: ParishFilter.massTimes,
        day: _sat,
        origin: _here,
        now: _now);
    expect(hits, hasLength(1));
    expect(hits.single.start, DateTime(2026, 10, 3, 10));
  });

  test('today skips a Mass already begun, keeps a window still open', () {
    final mass = _parish('1', mass: [_e('saturday', '08:00')]);
    final conf =
        _parish('2', confession: [_e('saturday', '08:30', end: '10:00')]);
    expect(
        planHits(
            parishes: [mass],
            filter: ParishFilter.massTimes,
            day: _sat,
            now: _now),
        isEmpty);
    expect(
        planHits(
            parishes: [conf],
            filter: ParishFilter.confession,
            day: _sat,
            now: _now),
        hasLength(1));
  });

  test('soonest first, nearest among equals, outside the reach dropped', () {
    final near = _parish('near', lat: 41.481, mass: [_e('sunday', '10:00')]);
    final far = _parish('far', lat: 41.53, mass: [_e('sunday', '10:00')]);
    final early = _parish('early', lat: 41.52, mass: [_e('sunday', '08:00')]);
    final akron = _parish('akron', lat: 41.08, lon: -81.52,
        mass: [_e('sunday', '07:00')]);
    final hits = planHits(
      parishes: [far, akron, near, early],
      filter: ParishFilter.massTimes,
      day: DateTime(2026, 10, 4),
      origin: _here,
      radiusMiles: 10,
      now: _now,
    );
    expect(hits.map((h) => h.parish.parishId), ['early', 'near', 'far']);
  });

  test('a time of day keeps windows that overlap it', () {
    final p = _parish('1',
        confession: [_e('saturday', '11:00', end: '13:00')]);
    final hits = planHits(
        parishes: [p],
        filter: ParishFilter.confession,
        day: _sat,
        time: TimeOfDayFilter.afternoon,
        now: _now);
    expect(hits, hasLength(1));
  });

  test('monthly entries only on their week', () {
    final p = _parish('1', mass: [_e('friday', '19:00', weeks: [1])]);
    List<PlanHit> on(DateTime d) => planHits(
        parishes: [p], filter: ParishFilter.massTimes, day: d, now: _now);
    expect(on(DateTime(2026, 11, 6)), hasLength(1)); // 1st Friday
    expect(on(DateTime(2026, 11, 13)), isEmpty);
  });

  test('a cancellation hides a slot this week, not next month', () {
    final p = _parish('1',
        mass: [_e('sunday', '10:00', cancelled: true)]);
    List<PlanHit> on(DateTime d) => planHits(
        parishes: [p], filter: ParishFilter.massTimes, day: d, now: _now);
    expect(on(DateTime(2026, 10, 4)), isEmpty);
    expect(on(DateTime(2026, 11, 1)), hasLength(1));
  });

  test('a perpetual chapel fits any adoration plan and comes first', () {
    final chapel = _parish('chapel', perpetual: true);
    final hits = planHits(
        parishes: [chapel],
        filter: ParishFilter.adoration,
        day: _sat,
        time: TimeOfDayFilter.evening,
        now: _now);
    expect(hits.single.isAllDay, true);
  });
}
