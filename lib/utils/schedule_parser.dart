import 'package:flutter/foundation.dart';

/// A single structured schedule entry (one Mass, confession slot, or adoration
/// period). Built directly from the pre-parsed `schedules` objects in
/// `export.json` — see EXPORT_SHAPE_CHANGES.md. No string parsing happens
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

  /// Calculate the next occurrence of this entry from now.
  /// Dated entries return their fixed date/time (which may be in the past —
  /// callers filter those out). Weekly entries roll forward to the next match.
  DateTime nextOccurrence([DateTime? fromTime]) {
    final now = fromTime ?? DateTime.now();

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

  /// Get minutes until the next occurrence (negative for past dated entries).
  int minutesUntilNext([DateTime? fromTime]) {
    final now = fromTime ?? DateTime.now();
    return nextOccurrence(now).difference(now).inMinutes;
  }

  /// True if this is a dated entry whose occurrence is already in the past.
  bool isPast([DateTime? fromTime]) {
    if (date == null) return false;
    final now = fromTime ?? DateTime.now();
    return nextOccurrence(now).isBefore(now);
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
  String? get noteLabel {
    final parts = <String>[];
    if (language != null) parts.add(language!);
    if (note != null) parts.add(note!);
    return parts.isEmpty ? null : parts.join(' · ');
  }

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
  ) {
    return entries.where((e) => !e.isPast(now)).toList();
  }

  /// Find the soonest upcoming entry, or null.
  static ScheduleEntry? findNextOccurrence(
    List<ScheduleEntry> entries, [
    DateTime? fromTime,
  ]) {
    final now = fromTime ?? DateTime.now();
    final upcoming = _upcomingOnly(entries, now);
    if (upcoming.isEmpty) return null;
    upcoming.sort(
      (a, b) => a.minutesUntilNext(now).compareTo(b.minutesUntilNext(now)),
    );
    return upcoming.first;
  }

  /// Minutes until the soonest upcoming entry, or null.
  static int? minutesUntilNext(
    List<ScheduleEntry> entries, [
    DateTime? fromTime,
  ]) {
    final now = fromTime ?? DateTime.now();
    return findNextOccurrence(entries, now)?.minutesUntilNext(now);
  }

  /// Group entries by relative day buckets, sorted by occurrence.
  /// Buckets: 'today', 'tomorrow', 'thisWeek', 'beyond' (8+ days out).
  static Map<String, List<UpcomingEntry>> groupByBucket(
    List<ScheduleEntry> entries, [
    DateTime? fromTime,
  ]) {
    final now = fromTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcoming = _upcomingOnly(entries, now).map((e) {
      final next = e.nextOccurrence(now);
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
