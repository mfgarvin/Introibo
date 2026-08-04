import 'package:flutter_test/flutter_test.dart';
import 'package:parishfinder/utils/schedule_parser.dart';

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

ScheduleEntry windowEntry(String day, String start, String end) =>
    ScheduleEntry.fromJson(windowJson(day, start, end))!;

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

    test('language badge + classification', () {
      ScheduleEntry lang(String? l) =>
          ScheduleEntry.fromJson(massJson('Sunday', '09:00', language: l))!;

      // English (explicit, null, or empty) carries no badge.
      expect(lang(null).languageBadge, isNull);
      expect(lang('English').languageBadge, isNull);
      expect(lang(null).isEnglish, true);

      // Known languages map to short codes.
      expect(lang('Spanish').languageBadge, 'ES');
      expect(lang('Polish').languageBadge, 'PL');
      expect(lang('Latin N.O.').languageBadge, 'LA');

      // Compound strings resolve to the non-English language they mention.
      expect(lang('English & Italian').languageBadge, 'IT');
      expect(lang('Bilingual (English-Polish)').languageBadge, 'PL');
      expect(lang('Bilingual').languageBadge, 'BIL');

      // Spanish vs. Other classification (used by the search filter).
      expect(lang('Spanish').isSpanish, true);
      expect(lang('Spanish').isOtherLanguage, false);
      expect(lang('Polish').isOtherLanguage, true);
      expect(lang('Polish').isSpanish, false);
      expect(lang('English').isOtherLanguage, false);
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

    test('a window underway counts as in progress, not next week', () {
      final now = DateTime(2026, 1, 5, 10, 0); // Monday 10am
      final e = windowEntry('Monday', '08:00', '17:00');
      expect(e.isInProgress(now), true);
      expect(e.nextOccurrence(now), DateTime(2026, 1, 5, 8, 0));
      expect(e.minutesUntilNext(now), -120);
    });

    test('a finished window still rolls to next week', () {
      final now = DateTime(2026, 1, 5, 18, 0); // Monday, after it closed
      final e = windowEntry('Monday', '08:00', '17:00');
      expect(e.isInProgress(now), false);
      expect(e.nextOccurrence(now), DateTime(2026, 1, 12, 8, 0));
    });

    test('a window crossing midnight stays in progress after 00:00', () {
      final e = windowEntry('Monday', '22:00', '01:00');
      expect(e.isInProgress(DateTime(2026, 1, 6, 0, 30)), true); // Tuesday 12:30am
      expect(e.isInProgress(DateTime(2026, 1, 6, 1, 30)), false);
    });

    test('a dated window underway is not flagged past', () {
      final now = DateTime(2026, 1, 9, 14, 0);
      final e = ScheduleEntry.fromJson({
        ...windowJson('Friday', '13:00', '16:00'),
        'mass_date': '2026-01-09',
      })!;
      expect(e.isPast(now), false);
      expect(e.isInProgress(now), true);
    });

    test('an in-progress window outranks a sooner-starting entry', () {
      final now = DateTime(2026, 1, 5, 10, 0);
      final adoration = windowEntry('Monday', '08:00', '17:00');
      final mass = ScheduleEntry.fromJson(massJson('Monday', '12:00'))!;
      expect(ScheduleParser.findNextOccurrence([mass, adoration], now), adoration);
    });

    test('Mass paths skip an in-progress entry and point at the next one', () {
      final now = DateTime(2026, 1, 5, 10, 0); // Monday, 10 min into a 9:30 Mass
      final underway = windowEntry('Monday', '09:30', '10:30');
      expect(underway.nextOccurrence(now, kCountMassInProgress),
          DateTime(2026, 1, 12, 9, 30));
      expect(underway.minutesUntilNext(now, kCountMassInProgress), greaterThan(0));

      final later = ScheduleEntry.fromJson(massJson('Monday', '12:00'))!;
      expect(
        ScheduleParser.findNextOccurrence(
            [underway, later], now, kCountMassInProgress),
        later,
      );
    });

    test('a dated Mass under way is past for Mass paths, not for windows', () {
      final now = DateTime(2026, 1, 9, 13, 30);
      final e = ScheduleEntry.fromJson({
        ...windowJson('Friday', '13:00', '14:00'),
        'mass_date': '2026-01-09',
      })!;
      expect(e.isPast(now), false);
      expect(e.isPast(now, kCountMassInProgress), true);
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

  group('groupByDay', () {
    test('merges consecutive identical days into a range, Sunday first', () {
      final entries = ScheduleEntry.listFromJson([
        massJson('Monday', '08:00'),
        massJson('Tuesday', '08:00'),
        massJson('Wednesday', '08:00'),
        massJson('Thursday', '08:00'),
        massJson('Friday', '08:00'),
        massJson('Saturday', '16:30'),
        massJson('Sunday', '09:00'),
        massJson('Sunday', '11:00'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.map((g) => g.label).toList(), ['Sun', 'Mon–Fri', 'Sat']);
      expect(groups.first.entries.map((e) => e.hour).toList(), [9, 11]);
      expect(groups[1].entries.single.hour, 8);
    });

    test('different times on adjacent days do not merge', () {
      final entries = ScheduleEntry.listFromJson([
        massJson('Monday', '08:00'),
        massJson('Tuesday', '12:10'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.map((g) => g.label).toList(), ['Mon', 'Tue']);
    });

    test('a language mark blocks merging', () {
      final entries = ScheduleEntry.listFromJson([
        massJson('Monday', '08:00'),
        massJson('Tuesday', '08:00', language: 'Spanish'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.length, 2);
    });

    test('entries within a day are sorted by start time', () {
      final entries = ScheduleEntry.listFromJson([
        massJson('Sunday', '11:00'),
        massJson('Sunday', '07:30'),
        massJson('Sunday', '09:00'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.single.entries.map((e) => e.hour).toList(), [7, 9, 11]);
    });

    test('dated entries trail as their own date-labeled group', () {
      final entries = ScheduleEntry.listFromJson([
        massJson('Sunday', '09:00'),
        massJson('Thursday', '10:00', massDate: '2026-12-25'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.map((g) => g.label).toList(), ['Sun', 'Dec 25']);
    });

    test('confession windows group like plain times', () {
      final entries = ScheduleEntry.listFromJson([
        windowJson('Saturday', '15:00', '15:45'),
        windowJson('Wednesday', '18:00', '18:30'),
      ]);
      final groups = ScheduleParser.groupByDay(entries);
      expect(groups.map((g) => g.label).toList(), ['Wed', 'Sat']);
      expect(groups.last.entries.single.hasRange, true);
    });
  });
}
