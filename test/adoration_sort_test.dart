import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parishfinder/pages/filtered_parish_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lakewood, OH — the same point the debug build mocks.
const _userLocation = LatLng(41.48, -81.78);

/// Adoration open every day, all day: whenever the suite runs, it is underway.
List<Map<String, dynamic>> _allDayTimes() => [
      for (final day in [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday'
      ])
        {'day': day, 'start': '00:00', 'end': '23:59', 'notes': null},
    ];

Map<String, dynamic> _parish({
  required String id,
  required String name,
  required double lat,
  required double lon,
  required bool perpetual,
}) =>
    {
      'name': name,
      'parish_id': id,
      'address': '1 Main St',
      'city': 'Lakewood',
      'zip_code': '44107',
      'latitude': lat,
      'longitude': lon,
      'schedules': {
        'mass': [],
        'confession': [],
        'adoration': {
          'is_perpetual': perpetual,
          'times': perpetual ? [] : _allDayTimes(),
        },
      },
    };

Future<void> _pumpAdorationList(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: FilteredParishListPage(
      filter: ParishFilter.adoration,
      title: 'Adoration',
      accentColor: Colors.deepPurple,
      userLocation: _userLocation,
    ),
  ));
  // Cache read + the (test-harness-failed) network fetch.
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'cached_parishes_json': json.encode([
        // Half a mile away, open around the clock, no ScheduleEntry at all.
        _parish(
          id: '0001',
          name: 'Perpetual Chapel Parish',
          lat: 41.4805,
          lon: -81.7805,
          perpetual: true,
        ),
        // ~6 miles away, currently underway via an all-day entry.
        _parish(
          id: '0002',
          name: 'All Day Chapel Parish',
          lat: 41.55,
          lon: -81.70,
          perpetual: false,
        ),
      ]),
    });
  });

  testWidgets('perpetual chapels carry the Happening now badge',
      (tester) async {
    await _pumpAdorationList(tester);

    final card = find
        .ancestor(
          of: find.text('Perpetual Chapel Parish'),
          matching: find.byType(InkWell),
        )
        .last;
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Happening now')),
      findsOneWidget,
    );
    // And the card still says what perpetual means.
    expect(
      find.descendant(of: card, matching: find.text('Perpetual (24/7)')),
      findsOneWidget,
    );
  });

  testWidgets('a near perpetual chapel outranks a farther all-day chapel',
      (tester) async {
    await _pumpAdorationList(tester);

    final perpetual =
        tester.getTopLeft(find.text('Perpetual Chapel Parish')).dy;
    final allDay = tester.getTopLeft(find.text('All Day Chapel Parish')).dy;
    expect(perpetual, lessThan(allDay));
  });
}
