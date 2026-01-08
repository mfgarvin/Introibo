import 'package:flutter_test/flutter_test.dart';
import 'package:mass_gpt/utils/schedule_parser.dart';

void main() {
  group('ScheduleParser', () {
    test('parses single time on Sunday', () {
      final entries = ScheduleParser.parseSchedule(['Sunday: 9:00AM']);

      expect(entries.length, 1);
      expect(entries[0].dayOfWeek, 7); // Sunday = 7 in ISO
      expect(entries[0].hour, 9);
      expect(entries[0].minute, 0);
    });

    test('parses multiple times on same day', () {
      final entries = ScheduleParser.parseSchedule(['Sunday: 9:00AM, 11:00AM']);

      expect(entries.length, 2);
      expect(entries[0].hour, 9);
      expect(entries[1].hour, 11);
    });

    test('parses PM times correctly', () {
      final entries = ScheduleParser.parseSchedule(['Saturday: 4:30PM']);

      expect(entries.length, 1);
      expect(entries[0].dayOfWeek, 6); // Saturday = 6
      expect(entries[0].hour, 16); // 4:30 PM = 16:30 in 24-hour
      expect(entries[0].minute, 30);
    });

    test('handles vigil mass annotations', () {
      final entries = ScheduleParser.parseSchedule(['Saturday: 4:30PM - Vigil Mass']);

      expect(entries.length, 1);
      expect(entries[0].hour, 16);
      expect(entries[0].minute, 30);
    });

    test('parses multiple schedule lines', () {
      final entries = ScheduleParser.parseSchedule([
        'Sunday: 9:00AM, 11:00AM',
        'Saturday: 8:00AM, 4:30PM - Vigil Mass',
      ]);

      expect(entries.length, 4);
    });

    test('handles noon (12:00PM) correctly', () {
      final entries = ScheduleParser.parseSchedule(['Sunday: 12:00PM']);

      expect(entries.length, 1);
      expect(entries[0].hour, 12); // 12:00 PM stays as 12
    });

    test('handles midnight (12:00AM) correctly', () {
      final entries = ScheduleParser.parseSchedule(['Monday: 12:00AM']);

      expect(entries.length, 1);
      expect(entries[0].hour, 0); // 12:00 AM becomes 0
    });

    test('calculates next occurrence for upcoming event', () {
      // Test on a Monday at 10:00 AM
      final testTime = DateTime(2026, 1, 5, 10, 0); // Monday, Jan 5, 2026, 10:00 AM

      // Parse a Wednesday 2:00 PM mass
      final entries = ScheduleParser.parseSchedule(['Wednesday: 2:00PM']);
      expect(entries.length, 1);

      final next = entries[0].nextOccurrence(testTime);

      // Should be Wednesday, Jan 7, 2026, 2:00 PM
      expect(next.weekday, 3); // Wednesday
      expect(next.hour, 14);
      expect(next.minute, 0);
    });

    test('calculates next occurrence for event later today', () {
      // Test on a Monday at 10:00 AM
      final testTime = DateTime(2026, 1, 5, 10, 0);

      // Parse a Monday 5:00 PM mass
      final entries = ScheduleParser.parseSchedule(['Monday: 5:00PM']);
      expect(entries.length, 1);

      final minutesUntil = entries[0].minutesUntilNext(testTime);

      // Should be 7 hours = 420 minutes
      expect(minutesUntil, 420);
    });

    test('calculates next occurrence wraps to next week if event passed', () {
      // Test on a Monday at 10:00 AM
      final testTime = DateTime(2026, 1, 5, 10, 0);

      // Parse a Monday 8:00 AM mass (already passed)
      final entries = ScheduleParser.parseSchedule(['Monday: 8:00AM']);
      expect(entries.length, 1);

      final next = entries[0].nextOccurrence(testTime);

      // Should be next Monday
      expect(next.weekday, 1); // Monday
      expect(next.day, 12); // Jan 12
    });

    test('finds soonest occurrence from multiple times', () {
      final testTime = DateTime(2026, 1, 5, 10, 0); // Monday 10:00 AM

      final entries = ScheduleParser.parseSchedule([
        'Wednesday: 2:00PM',
        'Monday: 5:00PM',
        'Saturday: 9:00AM',
      ]);

      final next = ScheduleParser.findNextOccurrence(entries, testTime);

      // Should pick Monday 5:00 PM (soonest)
      expect(next?.dayOfWeek, 1);
      expect(next?.hour, 17);
    });

    test('getMinutesUntilNext returns correct value', () {
      final testTime = DateTime(2026, 1, 5, 10, 0); // Monday 10:00 AM

      final minutes = ScheduleParser.getMinutesUntilNext(
        ['Monday: 5:00PM'],
        testTime,
      );

      // 7 hours = 420 minutes
      expect(minutes, 420);
    });

    test('handles empty schedule gracefully', () {
      final minutes = ScheduleParser.getMinutesUntilNext([]);
      expect(minutes, null);
    });

    test('handles invalid schedule format gracefully', () {
      final entries = ScheduleParser.parseSchedule(['Invalid schedule']);
      expect(entries, isEmpty);
    });
  });
}
