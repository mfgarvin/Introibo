import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/models/parish.dart';
import 'package:parishfinder/utils/schedule_parser.dart';

/// Every schedule entry in a record, in the three lists the exporter writes.
List<Map<String, dynamic>> _entriesOf(Map<String, dynamic> record) {
  final s = record['schedules'] as Map<String, dynamic>? ?? const {};
  final adoration = s['adoration'] as Map<String, dynamic>? ?? const {};
  return [
    ...?(s['mass'] as List?)?.cast<Map<String, dynamic>>(),
    ...?(s['confession'] as List?)?.cast<Map<String, dynamic>>(),
    ...?(adoration['times'] as List?)?.cast<Map<String, dynamic>>(),
  ];
}

void main() {
  late final List<dynamic> records;
  setUpAll(() {
    records = jsonDecode(File('export.demo.json').readAsStringSync()) as List;
  });

  group('the real export', () {
    test('carries `cancelled` on every schedule entry', () {
      // The exporter promises the key is always present (EXPORT_SHAPE_CHANGES
      // in ../bulletin-v2). If that ever stops being true the app still reads
      // a missing key as "not cancelled", but the promise is worth pinning:
      // it is what lets a false here mean "the bulletin said nothing" rather
      // than "the scraper didn't look".
      var entries = 0;
      for (final r in records.cast<Map<String, dynamic>>()) {
        for (final e in _entriesOf(r)) {
          expect(e.containsKey('cancelled'), isTrue,
              reason: '${r['name']} has a schedule entry with no `cancelled`');
          expect(e['cancelled'], isA<bool>());
          entries++;
        }
      }
      expect(entries, greaterThan(1000));
    });

    test('parses end to end, with the flag carried onto every entry', () {
      var flagged = 0;
      for (final r in records.cast<Map<String, dynamic>>()) {
        final parish = Parish.fromJson(r);
        final json = _entriesOf(r).where((e) => e['cancelled'] == true).length;
        final parsed = [
          ...parish.massTimes,
          ...parish.confTimes,
          ...parish.adoration,
        ].where((e) => e.cancelled).length;
        // Entries the parser rejects outright (no day, no start) never reach
        // the model, so the parsed count can only be short of the JSON's.
        expect(parsed, lessThanOrEqualTo(json));
        flagged += parsed;
      }
      // Today's export has nothing suspended — a bulletin week with no
      // "NO MASS" in it — so this is a floor, not an assertion about content.
      expect(flagged, greaterThanOrEqualTo(0));
    });
  });

  group('a real parish with a suspended Mass', () {
    /// The first record with at least two weekday Masses, with its earliest
    /// one marked off the way a bulletin does it — the "8:45 am … NO MASS"
    /// case the field was added for. Built from live data rather than a
    /// hand-written record so the rest of the shape is exactly what ships.
    ({Parish parish, ScheduleEntry off}) suspendFirstWeekdayMass() {
      for (final r in records.cast<Map<String, dynamic>>()) {
        final masses = (r['schedules']?['mass'] as List?)
                ?.cast<Map<String, dynamic>>()
                .where((m) => m['mass_date'] == null)
                .toList() ??
            [];
        if (masses.length < 2) continue;
        final copy = jsonDecode(jsonEncode(r)) as Map<String, dynamic>;
        final target = (copy['schedules']['mass'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((m) =>
                m['day'] == masses.first['day'] &&
                m['start'] == masses.first['start']);
        target['cancelled'] = true;
        target['notes'] = 'Fr. Trask is away';
        final parish = Parish.fromJson(copy);
        return (
          parish: parish,
          off: parish.massTimes.firstWhere((e) => e.cancelled),
        );
      }
      fail('no record in export.demo.json has two weekly Masses');
    }

    test('keeps the slot in the schedule the page draws', () {
      final (parish: parish, off: off) = suspendFirstWeekdayMass();
      expect(parish.massTimes, contains(off));
      expect(off.note, 'Fr. Trask is away');
      // The standing schedule still has it, so the Mass card still lists it.
      expect(ScheduleParser.groupByDay(parish.massTimes).length,
          greaterThanOrEqualTo(1));
    });

    test('is never what the app offers as the next Mass', () {
      final (parish: parish, off: off) = suspendFirstWeekdayMass();
      // Checked from the minute before it would have started, which is when a
      // countdown is most likely to reach for it.
      final justBefore = off
          .nextOccurrence(DateTime.now(), kCountMassInProgress)
          .subtract(const Duration(minutes: 1));
      final next = ScheduleParser.findNextOccurrence(
          parish.massTimes, justBefore, kCountMassInProgress);
      expect(next, isNotNull);
      expect(next, isNot(off));
      expect(ScheduleParser.active(parish.massTimes), isNot(contains(off)));
    });

    test('is not the Mass a preview line advertises', () {
      final (parish: parish, off: off) = suspendFirstWeekdayMass();
      expect(parish.previewMassTime, isNotNull);
      expect(parish.previewMassTime, isNot(off));
      expect(parish.previewMassTime!.cancelled, isFalse);
    });
  });
}
