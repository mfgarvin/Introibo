import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parishfinder/models/parish.dart';
import 'package:parishfinder/pages/filtered_parish_list_page.dart';
import 'package:parishfinder/utils/plan_place.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

/// Planning: a specific date, a named place, and the list page opened already
/// answering them — "Saturday in Akron, confession".

const _lakewood = LatLng(41.48, -81.78);

Map<String, dynamic> _parish(
  String id,
  String name, {
  required String city,
  required String zip,
  required double lat,
  required double lon,
  List<Map<String, dynamic>> mass = const [],
}) =>
    {
      'name': name,
      'parish_id': id,
      'address': '1 Main St',
      'city': city,
      'zip_code': zip,
      'latitude': lat,
      'longitude': lon,
      'schedules': {
        'mass': mass,
        'confession': [],
        'adoration': {'is_perpetual': false, 'times': []},
      },
    };

Map<String, dynamic> _mass(String day, String start,
        {List<int>? weeks, bool cancelled = false}) =>
    {
      'day': day,
      'start': start,
      'language': 'en',
      'notes': null,
      'cancelled': cancelled,
      if (weeks != null) 'weeks_of_month': weeks,
    };

const _dayNames = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

DateTime get _today {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// The first date on or after [from] for which [test] holds.
DateTime _firstFrom(DateTime from, bool Function(DateTime) test) {
  var d = from;
  while (!test(d)) {
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return d;
}

Future<void> _pumpPlan(
  WidgetTester tester, {
  DateTime? date,
  PlanPlace? place,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: FilteredParishListPage(
      // A fresh page per pump: the initial* arguments are read in initState.
      key: UniqueKey(),
      filter: ParishFilter.massTimes,
      title: 'Mass Times',
      accentColor: Colors.red,
      userLocation: _lakewood,
      initialDate: date,
      initialPlace: place,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('PlanPlace.resolve', () {
    final parishes = [
      _parish('1', 'A', city: 'Akron', zip: '44320', lat: 41.09, lon: -81.56),
      _parish('2', 'B', city: 'Akron', zip: '44310', lat: 41.11, lon: -81.50),
      _parish('3', 'C', city: 'Bay Village', zip: '44140', lat: 41.48,
          lon: -81.92),
    ].map(Parish.fromJson).toList();

    test('a city, in any case, is the centre of its own parishes', () {
      final p = PlanPlace.resolve('  akRON ', parishes)!;
      expect(p.label, 'Akron');
      expect(p.center.latitude, closeTo(41.10, 1e-9));
      expect(p.center.longitude, closeTo(-81.53, 1e-9));
    });

    test('a city reaches its farthest parish plus a margin, at least 6 mi',
        () {
      final akron = PlanPlace.resolve('Akron', parishes)!;
      final far = PlanPlace.milesBetween(
          akron.center, const LatLng(41.09, -81.56));
      final expected = far + PlanPlace.cityMarginMiles;
      expect(akron.radiusMiles,
          closeTo(expected < 6 ? 6 : expected, 1e-9));
      expect(PlanPlace.resolve('Bay Village', parishes)!.radiusMiles,
          PlanPlace.minRadiusMiles);
    });

    test('a ZIP resolves from the parishes carrying it', () {
      final p = PlanPlace.resolve('44140', parishes)!;
      expect(p.label, '44140');
      expect(p.center, const LatLng(41.48, -81.92));
    });

    test('nowhere we serve is null', () {
      expect(PlanPlace.resolve('Toledo', parishes), isNull);
      expect(PlanPlace.resolve('43604', parishes), isNull);
      expect(PlanPlace.resolve('', parishes), isNull);
    });

    test('cities are listed once each, sorted', () {
      expect(PlanPlace.cities(parishes), ['Akron', 'Bay Village']);
    });
  });

  test('planDateLabel', () {
    expect(planDateLabel(DateTime(2026, 10, 10)), 'Sat, Oct 10');
  });

  group('the list opened as a plan', () {
    setUpAll(loadAppFonts);

    // A First Friday Mass, a weekly Mass cancelled this week, and a parish
    // in Akron — far outside a Lakewood plan's reach.
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'cached_parishes_json': json.encode([
          _parish('1', 'First Friday Parish',
              city: 'Lakewood', zip: '44107', lat: 41.481, lon: -81.781,
              mass: [_mass('friday', '19:00', weeks: [1])]),
          _parish('2', 'Cancelled This Week Parish',
              city: 'Lakewood', zip: '44107', lat: 41.482, lon: -81.782,
              mass: [
                for (final d in _dayNames) _mass(d, '08:00', cancelled: true)
              ]),
          _parish('3', 'Akron Parish',
              city: 'Akron', zip: '44320', lat: 41.09, lon: -81.56,
              mass: [for (final d in _dayNames) _mass(d, '09:00')]),
        ]),
      });
    });

    testWidgets('a First Friday Mass is on the first Friday only',
        (tester) async {
      final firstFriday = _firstFrom(
          _today.add(const Duration(days: 1)),
          (d) => d.weekday == DateTime.friday && d.day <= 7);
      await _pumpPlan(tester, date: firstFriday);
      expect(find.text('First Friday Parish'), findsOneWidget);

      final secondFriday = firstFriday.add(const Duration(days: 7));
      await _pumpPlan(tester, date: secondFriday);
      expect(find.text('First Friday Parish'), findsNothing);
    });

    testWidgets('a cancellation counts this week, not next month',
        (tester) async {
      await _pumpPlan(tester, date: _today.add(const Duration(days: 2)));
      expect(find.text('Cancelled This Week Parish'), findsNothing);
      expect(find.textContaining('From the regular schedule'), findsNothing);

      await _pumpPlan(tester, date: _today.add(const Duration(days: 30)));
      expect(find.text('Cancelled This Week Parish'), findsOneWidget);
      expect(find.textContaining('From the regular schedule'), findsOneWidget);
    });

    testWidgets('a place keeps to its reach and measures from there',
        (tester) async {
      const akron = PlanPlace('Akron', LatLng(41.09, -81.56), 6);
      await _pumpPlan(tester, place: akron);
      expect(find.text('Akron Parish'), findsOneWidget);
      expect(find.text('First Friday Parish'), findsNothing);
      expect(find.widgetWithText(TextField, 'Akron'), findsOneWidget);
    });

    testWidgets('a plan for a date names it', (tester) async {
      final date = _today.add(const Duration(days: 3));
      await _pumpPlan(tester, date: date);
      // On the bar, and heading each card's times — by name, within a week.
      const names = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
        'Sunday',
      ];
      expect(find.text(names[date.weekday - 1]), findsWidgets);
      expect(find.text('Filtered'), findsNothing);
    });
  });
}
