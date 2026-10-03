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

/// Each pick is (word on the filter bar, item in its menu): tap the word,
/// then the choice.
Future<void> _pumpWithFilters(
    WidgetTester tester, List<(String, String)> picks) async {
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

  // A–Z lists every parish, so nothing but the filter decides who shows.
  await tester.tap(find.text('A–Z'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Filter'));
  await tester.pumpAndSettle();
  for (final (word, choice) in picks) {
    await tester.tap(find.text(word));
    await tester.pumpAndSettle();
    await tester.tap(find.text(choice).last);
    await tester.pumpAndSettle();
  }
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

  testWidgets('the Filter button opens, closes, and clears the bar',
      (tester) async {
    await _pumpWithFilters(tester, []);
    // Open, nothing set: the button offers to close.
    expect(find.text('Any day'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Any day'), findsNothing);
    expect(find.text('Filter'), findsOneWidget);
  });

  testWidgets('opening the bar leaves the button where it was',
      (tester) async {
    await _pumpWithFilters(tester, []);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final closed = tester.getCenter(find.text('Filter'));
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    final open = tester.getCenter(find.text('Close'));
    expect(open.dy, closeTo(closed.dy, 0.5));
    expect(open.dx, closeTo(closed.dx, 6)); // "Close" vs "Filter" width
  });

  testWidgets('on a phone: Filter shares the sort line; when, then where',
      (tester) async {
    await _pumpWithFilters(tester, []);
    // A Pixel 9 Pro is 412 logical pixels wide.
    tester.view.physicalSize = const Size(412, 915);
    await tester.pumpAndSettle();

    final button = tester.getCenter(find.text('Close'));
    final az = tester.getCenter(find.text('A–Z'));
    expect(button.dy, closeTo(az.dy, 2), reason: 'button beside the tabs');

    final day = tester.getCenter(find.text('Any day'));
    final time = tester.getCenter(find.text('Any time'));
    expect(time.dy, closeTo(day.dy, 0.5), reason: 'day and time share a line');
    expect(day.dy, greaterThan(az.dy), reason: 'the panel opens beneath');

    final near = tester.getCenter(find.text('near'));
    final field = tester.getCenter(find.byType(TextField));
    expect(field.dy, closeTo(near.dy, 2), reason: '"near" stays with its field');
    expect(near.dy, greaterThan(day.dy));

    final bubble = tester.getSize(find
        .ancestor(of: find.text('Any day'), matching: find.byType(Container))
        .first);
    expect(bubble.height, greaterThanOrEqualTo(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed, the filter costs no height of its own', (tester) async {
    await _pumpWithFilters(tester, []);
    final tabsOpen = tester.getCenter(find.text('A–Z')).dy;
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Any day'), findsNothing);
    // The tabs don't move when the panel goes; the list moves up instead.
    expect(tester.getCenter(find.text('A–Z')).dy, closeTo(tabsOpen, 0.5));
    expect(tester.getCenter(find.text('Filter')).dy,
        closeTo(tester.getCenter(find.text('A–Z')).dy, 2));
  });

  testWidgets('tapping away closes the place suggestions', (tester) async {
    await _pumpWithFilters(tester, []);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Lake');
    await tester.pumpAndSettle();
    expect(find.text('Lakewood'), findsWidgets);

    // The page title: outside the field, and not something that navigates.
    await tester.tapAt(tester.getCenter(find.text('Adoration').first));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
    // And the field shows the place in force again, not the half-typed text.
    expect(find.widgetWithText(TextField, 'me'), findsOneWidget);
  });

  testWidgets('filtering greys the sort tabs; Clear brings them back',
      (tester) async {
    SegmentedButton<SortOrder> tabs(WidgetTester t) =>
        t.widget(find.byType(SegmentedButton<SortOrder>));

    await _pumpWithFilters(tester, [('Any time', 'Afternoon')]);
    expect(tabs(tester).onSelectionChanged, isNull);
    // Tapping a greyed tab says why, instead of doing nothing.
    await tester.tap(find.text('Soonest'));
    await tester.pump();
    expect(find.textContaining('Clear the filter to change the sort'),
        findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(tabs(tester).onSelectionChanged, isNotNull);
    // The sort chosen before filtering is back.
    expect(tabs(tester).selected, {SortOrder.alphabetical});
    _expectListed(_all);
  });

  testWidgets('Afternoon keeps windows that are open in it, not just started',
      (tester) async {
    await _pumpWithFilters(tester, [('Any time', 'Afternoon')]);
    _expectListed([_longWindow, _noonStraddle, _perpetual]);
  });

  testWidgets('Morning keeps a window that runs on past noon', (tester) async {
    await _pumpWithFilters(tester, [('Any time', 'Morning')]);
    _expectListed([_longWindow, _noonStraddle, _early, _perpetual]);
  });

  testWidgets('Evening keeps an all-day window that opened in the morning',
      (tester) async {
    await _pumpWithFilters(tester, [('Any time', 'Evening')]);
    _expectListed([_longWindow, _perpetual]);
  });

  testWidgets('a perpetual chapel survives Today + Afternoon', (tester) async {
    // Only the perpetual chapel is asserted: whether the windowed chapels
    // are still on "today" depends on the hour the suite runs.
    await _pumpWithFilters(
        tester, [('Any day', 'Today'), ('Any time', 'Afternoon')]);
    expect(find.text(_perpetual), findsOneWidget);
    expect(find.text(_early), findsNothing);
  });

  testWidgets('a perpetual chapel survives a named day', (tester) async {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday',
    ];
    final inThreeDays = DateTime.now().add(const Duration(days: 3));
    await _pumpWithFilters(
        tester, [('Any day', names[inThreeDays.weekday - 1])]);
    expect(find.text(_perpetual), findsOneWidget);
  });
}
