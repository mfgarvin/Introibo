import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parishfinder/models/parish.dart';
import 'package:parishfinder/widgets/plan_visit_card.dart';

import 'support/test_fonts.dart';

/// The Home planner sheet's sentence. Enter in the place word used to take
/// RawAutocomplete's first option — always "Near me" — so typing a city and
/// pressing Enter quietly planned around home instead.

const _lakewood = LatLng(41.48, -81.78);

Parish _parish(String id, String name, String city, double lat, double lon) {
  const days = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday',
    'sunday',
  ];
  return Parish.fromJson({
    'name': name,
    'parish_id': id,
    'address': '1 Main St',
    'city': city,
    'zip_code': city == 'Akron' ? '44320' : '44107',
    'latitude': lat,
    'longitude': lon,
    'schedules': {
      // 11:59 pm every day: still ahead whenever the suite runs today.
      'mass': [
        for (final d in days) {'day': d, 'start': '23:59', 'language': 'en'}
      ],
      'confession': [],
      'adoration': {'is_perpetual': false, 'times': []},
    },
  });
}

final _parishes = [
  _parish('1', 'Lakewood Parish', 'Lakewood', 41.481, -81.781),
  _parish('2', 'Akron Parish', 'Akron', 41.09, -81.56),
];

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PlanVisitCard(
          parishes: _parishes,
          userLocation: _lakewood,
          onOpenParish: (_) {},
          onSeeAll: (_, __, ___, ____) {},
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('starts near me', (tester) async {
    await _pump(tester);
    expect(find.text('Lakewood Parish'), findsOneWidget);
    expect(find.text('Akron Parish'), findsNothing);
  });

  for (final typed in ['Akron', 'akron', 'Akr', '44320']) {
    testWidgets('Enter after "$typed" plans around Akron', (tester) async {
      await _pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), typed);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Akron Parish'), findsOneWidget);
      expect(find.text('Lakewood Parish'), findsNothing);
    });
  }

  testWidgets('Enter on nowhere keeps the current place', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Toledo');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Lakewood Parish'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'me'), findsOneWidget);
  });

  testWidgets('the day menu offers weekday names, not dates',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('today'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    final inTwoDays = DateTime.now().add(const Duration(days: 2));
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday',
    ];
    expect(find.text(names[inTwoDays.weekday - 1]), findsOneWidget);
    expect(find.text('Pick a date…'), findsNothing);
  });
}
