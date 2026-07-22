import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/utils/schedule_parser.dart';
import 'package:parishfinder/widgets/mass_schedule_card.dart';

ScheduleEntry _entry(int day, int hour, int minute, {String? note}) =>
    ScheduleEntry(dayOfWeek: day, hour: hour, minute: minute, note: note);

Widget _wrap(List<ScheduleEntry> items) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MassScheduleCard(
            icon: const Icon(Icons.church),
            title: 'Mass Times',
            items: items,
            emptyMessage: 'No Mass times listed',
            color: Colors.red,
            cardColor: Colors.white,
            textColor: Colors.black,
            subtextColor: Colors.black54,
            isDark: false,
          ),
        ),
      ),
    );

void main() {
  testWidgets('weekend section lists the Saturday vigil before Sunday Masses',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _entry(7, 9, 0), // Sun 9:00 AM
      _entry(7, 11, 0), // Sun 11:00 AM
      _entry(6, 16, 30), // Sat 4:30 PM vigil
    ]));

    final rows = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    expect(rows.indexOf('Sat'), lessThan(rows.indexOf('Sun')));
    expect(rows.indexOf('4:30 PM'), lessThan(rows.indexOf('9:00 AM')));
  });

  testWidgets('weekday section stays ordered by clock time', (tester) async {
    await tester.pumpWidget(_wrap([
      _entry(2, 7, 0), // Tue 7:00 AM
      _entry(1, 8, 30), // Mon 8:30 AM
    ]));

    final rows = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    expect(rows.indexOf('7:00 AM'), lessThan(rows.indexOf('8:30 AM')));
  });

  testWidgets('a long note renders in full instead of being ellipsized',
      (tester) async {
    const longNote =
        'Daily Mass; in Parish Center Chapel. When school is in session, '
        'Tuesday Mass is in the Main Church';
    await tester.pumpWidget(_wrap([_entry(2, 8, 0, note: longNote)]));

    final noteText = tester.widget<Text>(find.text(longNote));
    expect(noteText.overflow, isNot(TextOverflow.ellipsis));
    expect(noteText.maxLines, isNull);
  });
}
