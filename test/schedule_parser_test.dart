import 'package:flutter_test/flutter_test.dart';
import 'package:introibo/utils/schedule_parser.dart';

/// Build a structured mass/confession entry like the ones in export.json.
Map<String, dynamic> massJson(
  String day,
  String start, {
  String? massDate,
  String? language,
  String? notes,
}) =>
    {
      'day': day,
      'start': start,
      'mass_date': massDate,
      'language': language,
      'notes': notes,
    };

Map<String, dynamic> windowJson(String day, String start, String end,
        {String? notes}) =>
    {'day': day, 'start': start, 'end': end, 'notes': notes};

void main() {
  group('ScheduleEntry.fromJson', () {
    test('parses a weekly Mass entry', () {
      final e = ScheduleEntry.fromJson(massJson('Sunday', '09:00'))!;
      expect(e.dayOfWeek, 7); // Sunday = 7 ISO
      expect(e.hour, 9);
      expect(e.minute, 0);
      expect(e.isDated, false);
      expect(e.hasRange, false);
    });

    test('parses an afternoon 24-hour time', () {
      final e = ScheduleEntry.fromJson(massJson('Saturday', '16:30'))!;
      expect(e.dayOfWeek, 6);
      expect(e.hour, 16);
      expect(e.minute, 30);
    });

    test('parses a confession window with start and end', () {
      final e = ScheduleEntry.fromJson(windowJson('Saturday', '09:30', '10:00'))!;
      expect(e.hasRange, true);
      expect(e.hour, 9);
      expect(e.endHour, 10);
      expect(e.endMinute, 0);
    });

    test('captures language and notes annotations', () {
      final e = ScheduleEntry.fromJson(
          massJson('Sunday', '12:30', language: 'Spanish', notes: 'Vigil'))!;
      expect(e.language, 'Spanish');
      expect(e.note, 'Vigil');
      expect(e.noteLabel, 'Spanish · Vigil');
    });

    test('parses a dated holiday Mass', () {
      final e = ScheduleEntry.fromJson(
          massJson('Thursday', '00:00', massDate: '2025-12-25', notes: 'Midnight Mass'))!;
      expect(e.isDated, true);
      expect(e.date, DateTime(2025, 12, 25));
      expect(e.hour, 0);
    });

    test('returns null for an unparseable entry', () {
      expect(ScheduleEntry.fromJson({'day': 'Funday', 'start': '09:00'}), isNull);
      expect(ScheduleEntry.fromJson({'day': 'Sunday', 'start': 'noon'}), isNull);
    });

    test('listFromJson skips bad entries', () {
      final list = ScheduleEntry.listFromJson([
        massJson('Sunday', '09:00'),
        {'day': 'Funday', 'start': '09:00'},
        massJson('Monday', '08:00'),
      ]);
      expect(list.length, 2);
    });
  });

  group('display helpers', () {
    test('display gives compact day + time', () {
      final e = ScheduleEntry.fromJson(massJson('Sunday', '09:00'))!;
      expect(e.display, 'Sun · 9:00 AM');
    });

    test('range timeLabel drops shared meridiem', () {
      final e = ScheduleEntry.fromJson(windowJson('Saturday', '15:00', '15:30'))!;
      expect(e.timeLabel, '3:00 – 3:30 PM');
    });

    test('noon and midnight format correctly', () {
      expect(ScheduleEntry.fromJson(massJson('Sunday', '12:00'))!.timeLabel, '12:00 PM');
      expect(ScheduleEntry.fromJson(massJson('Monday', '00:00'))!.timeLabel, '12:00 AM');
    });
  });

  group('occurrence math', () {
    test('next occurrence for an upcoming weekday', () {
      final now = DateTime(2026, 1, 5, 10, 0); // Monday
      final e = ScheduleEntry.fromJson(massJson('Wednesday', '14:00'))!;
      final next = e.nextOccurrence(now);
      expect(next.weekday, 3);
      expect(next.hour, 14);
    });

    test('minutes until later today', () {
      final now = DateTime(2026, 1, 5, 10, 0);
      final e = ScheduleEntry.fromJson(massJson('Monday', '17:00'))!;
      expect(e.minutesUntilNext(now), 420);
    });

    test('wraps to next week if already passed', () {
      final now = DateTime(2026, 1, 5, 10, 0);
      final e = ScheduleEntry.fromJson(massJson('Monday', '08:00'))!;
      final next = e.nextOccurrence(now);
      expect(next.weekday, 1);
      expect(next.day, 12);
    });

    test('dated entry occurs on its fixed date', () {
      final now = DateTime(2026, 1, 5, 10, 0);
      final e = ScheduleEntry.fromJson(massJson('Friday', '13:00', massDate: '2026-01-09'))!;
      final next = e.nextOccurrence(now);
      expect(next, DateTime(2026, 1, 9, 13, 0));
      expect(e.isPast(now), false);
    });

    test('past dated entry is flagged and excluded from soonest', () {
      final now = DateTime(2026, 1, 5, 10, 0);
      final past = ScheduleEntry.fromJson(massJson('Friday', '13:00', massDate: '2026-01-02'))!;
      expect(past.isPast(now), true);

      final weekly = ScheduleEntry.fromJson(massJson('Monday', '17:00'))!;
      final next = ScheduleParser.findNextOccurrence([past, weekly], now);
      expect(next, weekly); // past dated one is skipped
    });
  });

  group('ScheduleParser', () {
    test('finds the soonest from multiple entries', () {
      final now = DateTime(2026, 1, 5, 10, 0); // Monday
      final entries = ScheduleEntry.listFromJson([
        massJson('Wednesday', '14:00'),
        massJson('Monday', '17:00'),
        massJson('Saturday', '09:00'),
      ]);
      final next = ScheduleParser.findNextOccurrence(entries, now);
      expect(next?.dayOfWeek, 1);
      expect(next?.hour, 17);
    });

    test('minutesUntilNext returns null for empty list', () {
      expect(ScheduleParser.minutesUntilNext([]), isNull);
    });

    test('groupByBucket sorts entries into relative day buckets', () {
      final now = DateTime(2026, 1, 5, 10, 0); // Monday
      final entries = ScheduleEntry.listFromJson([
        massJson('Monday', '17:00'),   // today
        massJson('Tuesday', '08:00'),  // tomorrow
        massJson('Saturday', '09:00'), // this week
      ]);
      final buckets = ScheduleParser.groupByBucket(entries, now);
      expect(buckets['today']!.length, 1);
      expect(buckets['tomorrow']!.length, 1);
      expect(buckets['thisWeek']!.length, 1);
      expect(buckets['beyond']!.isEmpty, true);
    });
  });
}
