import 'package:flutter/foundation.dart';

/// Pass as `countInProgress` wherever the schedule is Mass times.
///
/// Confession and adoration are come-and-go, so a window already open is the
/// soonest thing available. A Mass is not: you're meant to be there for the
/// start, so an in-progress one is skipped in favour of the next Mass. Mass
/// entries carry no end time in today's `export.json` (so nothing can be "in
/// progress" anyway), but the intent is stated rather than assumed.
const bool kCountMassInProgress = false;

/// A single structured schedule entry (one Mass, confession slot, or adoration
/// period). Built directly from the pre-parsed `schedules` objects in
/// `export.json` — see EXPORT_SHAPE_CHANGES.md in the scraper repo
/// (`../bulletin-v2`), which is authoritative. No string parsing happens
/// anymore; every field arrives structured.
class ScheduleEntry {
  final int dayOfWeek; // 1 = Monday, 7 = Sunday (ISO standard)
  final int hour; // 0-23 — start time
  final int minute; // 0-59
  final int? endHour; // 0-23 — optional end time for ranges (e.g. confession windows)
  final int? endMinute;

  /// Non-null for one-off / holiday occurrences (Christmas, weddings, Holy
  /// Days). When set, the entry occurs on this specific date rather than
  /// recurring weekly. [dayOfWeek] still reflects the weekday the date falls on.
  final DateTime? date;

  /// Language note for Mass entries (null = English).
  final String? language;

  /// Free-text annotation ("Vigil Mass", "Christmas Eve", etc.).
  final String? note;

  ScheduleEntry({
    required this.dayOfWeek,
    required this.hour,
    required this.minute,
    this.endHour,
    this.endMinute,
    this.date,
    this.language,
    this.note,
  });

  bool get hasRange => endHour != null && endMinute != null;

  /// True for dated (holiday / one-off) entries.
  bool get isDated => date != null;

  static const Map<String, int> _dayMap = {
    'monday': 1,
    'tuesday': 2,
    'wednesday': 3,
    'thursday': 4,
    'friday': 5,
    'saturday': 6,
    'sunday': 7,
  };

  /// Build an entry from a structured schedule object:
  /// `{day, start, end?, mass_date?, language?, notes?}`.
  /// Returns null if the day or start time can't be read.
  static ScheduleEntry? fromJson(Map<String, dynamic> json) {
    final dayOfWeek = _dayMap[(json['day'] as String?)?.trim().toLowerCase()];
    final start = _parseHm(json['start']);
    if (dayOfWeek == null || start == null) {
      debugPrint('Skipping unparseable schedule entry: $json');
      return null;
    }
    final end = _parseHm(json['end']);
    return ScheduleEntry(
      dayOfWeek: dayOfWeek,
      hour: start.hour,
      minute: start.minute,
      endHour: end?.hour,
      endMinute: end?.minute,
      date: _parseDate(json['mass_date']),
      language: (json['language'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['language'] as String).trim(),
      note: (json['notes'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['notes'] as String).trim(),
    );
  }

  /// Parse a list of structured schedule objects into entries.
  static List<ScheduleEntry> listFromJson(dynamic jsonList) {
    if (jsonList is! List) return [];
    final out = <ScheduleEntry>[];
    for (final item in jsonList) {
      if (item is Map<String, dynamic>) {
        final e = ScheduleEntry.fromJson(item);
        if (e != null) out.add(e);
      }
    }
    return out;
  }

  /// Parse "HH:MM" (24-hour, zero-padded) into hour/minute.
  static ({int hour, int minute})? _parseHm(dynamic value) {
    if (value is! String) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return (hour: h, minute: m);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// End datetime of the occurrence beginning at [start], or null when the
  /// entry has no range. A window whose end is not after its start (e.g.
  /// 22:00–00:30) is treated as running into the next day.
  DateTime? endOf(DateTime start) {
    if (!hasRange) return null;
    final end =
        DateTime(start.year, start.month, start.day, endHour!, endMinute!);
    return end.isAfter(start) ? end : end.add(const Duration(days: 1));
  }

  /// Start of the window currently underway (adoration open now, confession
  /// line already going), or null when nothing is in progress. Only ranged
  /// entries can be in progress. Checks today and yesterday, since a window
  /// that crosses midnight began the day before.
  DateTime? currentWindowStart([DateTime? fromTime]) {
    if (!hasRange) return null;
    final now = fromTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final offset in const [0, -1]) {
      final day = today.add(Duration(days: offset));
      if (date != null) {
        if (day.year != date!.year ||
            day.month != date!.month ||
            day.day != date!.day) {
          continue;
        }
      } else if (day.weekday != dayOfWeek) {
        continue;
      }
      final start = DateTime(day.year, day.month, day.day, hour, minute);
      if (!now.isBefore(start) && now.isBefore(endOf(start)!)) return start;
    }
    return null;
  }

  /// True when a ranged entry's window contains [fromTime].
  bool isInProgress([DateTime? fromTime]) => currentWindowStart(fromTime) != null;

  /// Calculate the next occurrence of this entry from now.
  ///
  /// A ranged entry that is currently underway returns the start of the window
  /// in progress (in the past), so "soonest" ranks it ahead of anything still
  /// upcoming — you can walk into adoration or a confession line at any point.
  /// Mass paths pass [countInProgress] `false`: you're expected to be there for
  /// the start, so a Mass already under way should point at the next one.
  /// Dated entries return their fixed date/time (which may be in the past —
  /// callers filter those out). Weekly entries roll forward to the next match.
  DateTime nextOccurrence([DateTime? fromTime, bool countInProgress = true]) {
    final now = fromTime ?? DateTime.now();

    final inProgress = countInProgress ? currentWindowStart(now) : null;
    if (inProgress != null) return inProgress;

    if (date != null) {
      return DateTime(date!.year, date!.month, date!.day, hour, minute);
    }

    final currentDayOfWeek = now.weekday; // 1 = Monday, 7 = Sunday
    int daysUntil = dayOfWeek - currentDayOfWeek;

    if (daysUntil == 0) {
      final eventTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (eventTime.isBefore(now)) {
        daysUntil = 7;
      }
    } else if (daysUntil < 0) {
      daysUntil += 7;
    }

    final nextDate = now.add(Duration(days: daysUntil));
    return DateTime(nextDate.year, nextDate.month, nextDate.day, hour, minute);
  }

  /// Get minutes until the next occurrence (negative for past dated entries
  /// and for a ranged entry whose window is already underway).
  int minutesUntilNext([DateTime? fromTime, bool countInProgress = true]) {
    final now = fromTime ?? DateTime.now();
    return nextOccurrence(now, countInProgress).difference(now).inMinutes;
  }

  /// True if this is a dated entry whose occurrence is already in the past.
  /// A dated window still running counts as upcoming, not past — unless the
  /// caller isn't counting in-progress entries (see [nextOccurrence]).
  bool isPast([DateTime? fromTime, bool countInProgress = true]) {
    if (date == null) return false;
    final now = fromTime ?? DateTime.now();
    if (countInProgress && isInProgress(now)) return false;
    return nextOccurrence(now, countInProgress).isBefore(now);
  }

  /// Abbreviated weekday, e.g. "Sun".
  String get dayLabel {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[dayOfWeek - 1];
  }

  /// Full weekday, e.g. "Sunday".
  String get dayName {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return names[dayOfWeek - 1];
  }

  /// Human time, e.g. "10:30 AM", or "3:00 – 3:30 PM" for ranges.
  /// When both endpoints share a meridiem, the first one is dropped.
  String get timeLabel {
    final start = _format12(hour, minute);
    if (!hasRange) return start;
    final end = _format12(endHour!, endMinute!);
    final sameMeridiem = (hour >= 12) == (endHour! >= 12);
    if (sameMeridiem) {
      final startNoMer = start.replaceFirst(RegExp(r'\s?(AM|PM)$'), '');
      return '$startNoMer – $end';
    }
    return '$start – $end';
  }

  /// Compact label for chips and previews, e.g. "Sun · 9:00 AM".
  String get display => '$dayLabel · $timeLabel';

  /// Combined language + note annotation for muted display, or null.
  /// Mass views prefer [languageBadge] + [note] separately; this stays for
  /// confession/adoration cards (which never carry a language).
  String? get noteLabel {
    final parts = <String>[];
    if (language != null) parts.add(language!);
    if (note != null) parts.add(note!);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Keyword → short badge map, checked in order so that compound strings like
  /// "English & Italian" or "Bilingual (English-Polish)" resolve to the
  /// non-English language they mention.
  static const List<({String keyword, String badge})> _languageBadges = [
    (keyword: 'spanish', badge: 'ES'),
    (keyword: 'polish', badge: 'PL'),
    (keyword: 'croatian', badge: 'HR'),
    (keyword: 'slovenian', badge: 'SL'),
    (keyword: 'italian', badge: 'IT'),
    (keyword: 'german', badge: 'DE'),
    (keyword: 'korean', badge: 'KO'),
    (keyword: 'swahili', badge: 'SW'),
    (keyword: 'latin', badge: 'LA'),
  ];

  /// True when this entry is plain English (or unspecified, which means English).
  bool get isEnglish {
    final lang = language?.toLowerCase().trim();
    return lang == null || lang.isEmpty || lang == 'english';
  }

  /// Short uppercase badge for a non-English Mass (e.g. "ES", "PL"), or null
  /// when the Mass is in English. Falls back to "BIL" for generic bilingual
  /// notes and a 2-letter slice for anything unrecognized.
  String? get languageBadge {
    if (isEnglish) return null;
    final lang = language!.toLowerCase();
    for (final entry in _languageBadges) {
      if (lang.contains(entry.keyword)) return entry.badge;
    }
    if (lang.contains('bilingual')) return 'BIL';
    return language!.replaceAll(RegExp(r'[^A-Za-z]'), '').substring(0, 2).toUpperCase();
  }

  /// True when this Mass is (at least partly) in Spanish.
  bool get isSpanish =>
      !isEnglish && language!.toLowerCase().contains('spanish');

  /// True for a non-English Mass that isn't Spanish (Polish, Croatian, Latin…).
  bool get isOtherLanguage => !isEnglish && !isSpanish;

  static String _format12(int hour, int minute) {
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final mer = hour >= 12 ? 'PM' : 'AM';
    final mm = minute.toString().padLeft(2, '0');
    return '$h12:$mm $mer';
  }
}

/// Helpers over lists of [ScheduleEntry]. (Formerly a string parser — now that
/// `export.json` ships structured schedules, this only does occurrence math.)
class ScheduleParser {
  /// Entries that are upcoming: weekly entries always qualify; dated entries
  /// only while still in the future.
  static List<ScheduleEntry> _upcomingOnly(
    List<ScheduleEntry> entries,
    DateTime now,
    bool countInProgress,
  ) {
    return entries.where((e) => !e.isPast(now, countInProgress)).toList();
  }

  /// Find the soonest upcoming entry, or null. Pass [countInProgress] `false`
  /// for Mass schedules — see [ScheduleEntry.nextOccurrence].
  static ScheduleEntry? findNextOccurrence(
    List<ScheduleEntry> entries, [
    DateTime? fromTime,
    bool countInProgress = true,
  ]) {
    final now = fromTime ?? DateTime.now();
    final upcoming = _upcomingOnly(entries, now, countInProgress);
    if (upcoming.isEmpty) return null;
    upcoming.sort(
      (a, b) => a
          .minutesUntilNext(now, countInProgress)
          .compareTo(b.minutesUntilNext(now, countInProgress)),
    );
    return upcoming.first;
  }

  /// Minutes until the soonest upcoming entry, or null.
  static int? minutesUntilNext(
    List<ScheduleEntry> entries, [
    DateTime? fromTime,
    bool countInProgress = true,
  ]) {
    final now = fromTime ?? DateTime.now();
    return findNextOccurrence(entries, now, countInProgress)
        ?.minutesUntilNext(now, countInProgress);
  }

  /// Group entries by relative day buckets, sorted by occurrence.
  /// Buckets: 'today', 'tomorrow', 'thisWeek', 'beyond' (8+ days out).
  static Map<String, List<UpcomingEntry>> groupByBucket(
    List<ScheduleEntry> entries, [
    DateTime? fromTime,
    bool countInProgress = true,
  ]) {
    final now = fromTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcoming = _upcomingOnly(entries, now, countInProgress).map((e) {
      final next = e.nextOccurrence(now, countInProgress);
      final eventDay = DateTime(next.year, next.month, next.day);
      return UpcomingEntry(
        entry: e,
        occurrence: next,
        daysFromToday: eventDay.difference(today).inDays,
      );
    }).toList()
      ..sort((a, b) => a.occurrence.compareTo(b.occurrence));

    final buckets = <String, List<UpcomingEntry>>{
      'today': [],
      'tomorrow': [],
      'thisWeek': [],
      'beyond': [],
    };

    for (final u in upcoming) {
      if (u.daysFromToday == 0) {
        buckets['today']!.add(u);
      } else if (u.daysFromToday == 1) {
        buckets['tomorrow']!.add(u);
      } else if (u.daysFromToday <= 7) {
        buckets['thisWeek']!.add(u);
      } else {
        buckets['beyond']!.add(u);
      }
    }
    return buckets;
  }

  /// Group entries into day-runs for at-a-glance display: bucket by weekday,
  /// merge consecutive days whose schedules are identical ("Mon–Fri"), order
  /// Sunday first. Dated (holiday) entries trail as their own date groups.
  static List<ScheduleDayGroup> groupByDay(List<ScheduleEntry> entries) {
    final weekly = <int, List<ScheduleEntry>>{};
    final dated = <DateTime, List<ScheduleEntry>>{};
    for (final e in entries) {
      if (e.isDated) {
        final d = e.date!;
        (dated[DateTime(d.year, d.month, d.day)] ??= []).add(e);
      } else {
        (weekly[e.dayOfWeek] ??= []).add(e);
      }
    }

    int startMinutes(ScheduleEntry e) => e.hour * 60 + e.minute;
    for (final list in [...weekly.values, ...dated.values]) {
      list.sort((a, b) => startMinutes(a).compareTo(startMinutes(b)));
    }

    // Two days merge only when their schedules are indistinguishable on a
    // card: same times, ranges, and language marks.
    String signature(List<ScheduleEntry> list) => list
        .map((e) =>
            '${e.hour}:${e.minute}-${e.endHour}:${e.endMinute}-${e.languageBadge}')
        .join('|');

    final runs = <({int firstDay, int lastDay, List<ScheduleEntry> entries})>[];
    for (var day = 1; day <= 7; day++) {
      final todays = weekly[day];
      if (todays == null) continue;
      final prev = runs.isEmpty ? null : runs.last;
      if (prev != null &&
          prev.lastDay == day - 1 &&
          signature(prev.entries) == signature(todays)) {
        runs[runs.length - 1] =
            (firstDay: prev.firstDay, lastDay: day, entries: prev.entries);
      } else {
        runs.add((firstDay: day, lastDay: day, entries: todays));
      }
    }
    // Sunday-first: the run containing Sunday leads, then Mon..Sat order.
    runs.sort((a, b) => (a.lastDay == 7 ? 0 : a.firstDay)
        .compareTo(b.lastDay == 7 ? 0 : b.firstDay));

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return [
      for (final r in runs)
        ScheduleDayGroup(
          r.firstDay == r.lastDay
              ? days[r.firstDay - 1]
              : '${days[r.firstDay - 1]}–${days[r.lastDay - 1]}',
          r.entries,
        ),
      for (final d in dated.keys.toList()..sort())
        ScheduleDayGroup('${months[d.month - 1]} ${d.day}', dated[d]!),
    ];
  }
}

/// A run of days sharing an identical schedule, for compact card display
/// ("Mon–Fri" → 8:00 AM). Entries are sorted by start time.
class ScheduleDayGroup {
  final String label;
  final List<ScheduleEntry> entries;

  ScheduleDayGroup(this.label, this.entries);
}

/// A schedule entry paired with its next occurrence datetime.
class UpcomingEntry {
  final ScheduleEntry entry;
  final DateTime occurrence;
  final int daysFromToday;

  UpcomingEntry({
    required this.entry,
    required this.occurrence,
    required this.daysFromToday,
  });

  int get hour => entry.hour;
  int get minute => entry.minute;

  String get timeLabel => entry.timeLabel;
  String get dayLabel => entry.dayLabel;
  String? get noteLabel => entry.noteLabel;
}
