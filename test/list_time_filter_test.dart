import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parishfinder/pages/filtered_parish_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

/// The list's day/time filter sheet, against adoration windows built to sit
/// on the period boundaries. Before 2026-10-02 a window counted only in the
/// period it *started* in, and a perpetual chapel — no entries at all —
/// vanished under any filter.

const _userLocation = LatLng(41.48, -81.78);

const _days = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// Every day, so the weekday never decides the outcome — only the hours do.
Map<String, dynamic> _parish(String id, String name,
        {String? start, String? end, bool endNextDay = false}) =>
    {
      'name': name,
      'parish_id': id,
      'address': '1 Main St',
      'city': 'Lakewood',
      'zip_code': '44107',
      'latitude': 41.48 + int.parse(id) / 1000,
      'longitude': -81.78,
      'schedules': {
        'mass': [],
        'confession': [],
        'adoration': {
          'is_perpetual': start == null,
          'times': [
            if (start != null)
              for (final day in _days)
                {
                  'day': day,
                  'start': start,
                  'end': end,
                  'end_next_day': endNextDay,
                  'notes': null,
                },
          ],
        },
      },
    };

const _longWindow = 'Long Window Parish'; // 7 am–10 pm
const _noonStraddle = 'Noon Straddle Parish'; // 11:30 am–12:30 pm
// The sheet offers no Night chip; this one is here to stay *out* of the
// daytime periods. Night's wrap is pinned in schedule_parser_test.
const _lateNight = 'Late Night Parish'; // 11 pm–1 am, past midnight
const _early = 'Early Parish'; // 6–8 am
const _perpetual = 'Perpetual Chapel Parish';
const _all = [_longWindow, _noonStraddle, _lateNight, _early, _perpetual];

Future<void> _pumpWithFilters(WidgetTester tester, List<String> chips) async {
  // Tall enough that every card is built — the list is lazy.
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(
    home: FilteredParishListPage(
      filter: ParishFilter.adoration,
      title: 'Adoration',
      accentColor: Colors.deepPurple,
      userLocation: _userLocation,
    ),
  ));
  await tester.pumpAndSettle();

  // Soonest hides the filter button; A–Z shows every parish to filter.
  await tester.tap(find.text('A–Z'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Filter'));
  await tester.pumpAndSettle();
  final sheet = find.byType(BottomSheet);
  for (final chip in chips) {
    await tester
        .tap(find.descendant(of: sheet, matching: find.text(chip)).first);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.descendant(of: sheet, matching: find.text('Done')));
  await tester.pumpAndSettle();
}

void _expectListed(List<String> shown) {
  for (final name in _all) {
    expect(find.text(name), shown.contains(name) ? findsOneWidget : findsNothing,
        reason: shown.contains(name)
            ? '$name should match the filter'
            : '$name should be filtered out');
  }
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'cached_parishes_json': json.encode([
        _parish('1', _longWindow, start: '07:00', end: '22:00'),
        _parish('2', _noonStraddle, start: '11:30', end: '12:30'),
        _parish('3', _lateNight,
            start: '23:00', end: '01:00', endNextDay: true),
        _parish('4', _early, start: '06:00', end: '08:00'),
        _parish('5', _perpetual),
      ]),
    });
  });

  testWidgets('Afternoon keeps windows that are open in it, not just started',
      (tester) async {
    await _pumpWithFilters(tester, ['Afternoon']);
    _expectListed([_longWindow, _noonStraddle, _perpetual]);
  });

  testWidgets('Morning keeps a window that runs on past noon', (tester) async {
    await _pumpWithFilters(tester, ['Morning']);
    _expectListed([_longWindow, _noonStraddle, _early, _perpetual]);
  });

  testWidgets('Evening keeps an all-day window that opened in the morning',
      (tester) async {
    await _pumpWithFilters(tester, ['Evening']);
    _expectListed([_longWindow, _perpetual]);
  });

  testWidgets('a perpetual chapel survives Today + Afternoon', (tester) async {
    // Only the perpetual chapel is asserted: whether the windowed chapels
    // are still on "today" depends on the hour the suite runs.
    await _pumpWithFilters(tester, ['Today', 'Afternoon']);
    expect(find.text(_perpetual), findsOneWidget);
    expect(find.text(_early), findsNothing);
  });

  testWidgets('a perpetual chapel survives a weekday filter', (tester) async {
    await _pumpWithFilters(tester, ['Wed']);
    expect(find.text(_perpetual), findsOneWidget);
  });
}
