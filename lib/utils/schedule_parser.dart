import 'package:flutter/foundation.dart';

/// Represents a parsed schedule entry with day and time
class ScheduleEntry {
  final int dayOfWeek; // 1 = Monday, 7 = Sunday (ISO standard)
  final int hour; // 0-23
  final int minute; // 0-59
  final String originalText;

  ScheduleEntry({
    required this.dayOfWeek,
    required this.hour,
    required this.minute,
    required this.originalText,
  });

  /// Calculate the next occurrence of this schedule entry from now
  DateTime nextOccurrence([DateTime? fromTime]) {
    final now = fromTime ?? DateTime.now();
    final currentDayOfWeek = now.weekday; // 1 = Monday, 7 = Sunday

    // Calculate days until this event
    int daysUntil = dayOfWeek - currentDayOfWeek;

    // If the event is today but already passed, add 7 days
    if (daysUntil == 0) {
      final eventTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (eventTime.isBefore(now)) {
        daysUntil = 7;
      }
    } else if (daysUntil < 0) {
      // Event is earlier in the week, so it's next week
      daysUntil += 7;
    }

    // Create the next occurrence datetime
    final nextDate = now.add(Duration(days: daysUntil));
    return DateTime(nextDate.year, nextDate.month, nextDate.day, hour, minute);
  }

  /// Get minutes until the next occurrence
  int minutesUntilNext([DateTime? fromTime]) {
    final now = fromTime ?? DateTime.now();
    final next = nextOccurrence(fromTime);
    return next.difference(now).inMinutes;
  }
}

/// Parses schedule strings into structured data
class ScheduleParser {
  // Map of day names to ISO day numbers (1 = Monday, 7 = Sunday)
  static final Map<String, int> _dayMap = {
    'monday': 1,
    'mon': 1,
    'tuesday': 2,
    'tue': 2,
    'tues': 2,
    'wednesday': 3,
    'wed': 3,
    'thursday': 4,
    'thu': 4,
    'thurs': 4,
    'friday': 5,
    'fri': 5,
    'saturday': 6,
    'sat': 6,
    'sunday': 7,
    'sun': 7,
  };

  /// Parse a list of schedule strings (e.g., ["Sunday: 9:00AM, 11:00AM", "Saturday: 4:30PM"])
  static List<ScheduleEntry> parseSchedule(List<String> scheduleStrings) {
    final entries = <ScheduleEntry>[];

    for (final scheduleString in scheduleStrings) {
      entries.addAll(_parseScheduleLine(scheduleString));
    }

    return entries;
  }

  /// Parse a single schedule line
  static List<ScheduleEntry> _parseScheduleLine(String line) {
    final entries = <ScheduleEntry>[];

    try {
      // Split on colon to separate day from times
      final parts = line.split(':');
      if (parts.length < 2) return entries;

      // Extract day of week
      final dayStr = parts[0].trim().toLowerCase();
      final dayOfWeek = _extractDayOfWeek(dayStr);
      if (dayOfWeek == null) return entries;

      // Extract times from the rest of the string
      final timesStr = parts.sublist(1).join(':'); // Rejoin in case there are multiple colons
      final times = _extractTimes(timesStr);

      // Create a ScheduleEntry for each time
      for (final time in times) {
        entries.add(ScheduleEntry(
          dayOfWeek: dayOfWeek,
          hour: time['hour']!,
          minute: time['minute']!,
          originalText: line,
        ));
      }
    } catch (e) {
      debugPrint('Error parsing schedule line "$line": $e');
    }

    return entries;
  }

  /// Extract day of week from string
  static int? _extractDayOfWeek(String dayStr) {
    // Check each day name/abbreviation
    for (final entry in _dayMap.entries) {
      if (dayStr.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Extract all times from a time string (e.g., "9:00AM, 11:00AM, 4:30PM - Vigil Mass")
  static List<Map<String, int>> _extractTimes(String timesStr) {
    final times = <Map<String, int>>[];

    // Regular expression to match times like "9:00AM", "11:30PM", "4:30PM"
    final timeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)', caseSensitive: false);
    final matches = timeRegex.allMatches(timesStr);

    for (final match in matches) {
      try {
        int hour = int.parse(match.group(1)!);
        final minute = int.parse(match.group(2)!);
        final meridiem = match.group(3)!.toUpperCase();

        // Convert to 24-hour format
        if (meridiem == 'PM' && hour != 12) {
          hour += 12;
        } else if (meridiem == 'AM' && hour == 12) {
          hour = 0;
        }

        times.add({'hour': hour, 'minute': minute});
      } catch (e) {
        debugPrint('Error parsing time from match: $e');
      }
    }

    return times;
  }

  /// Find the next occurrence from a list of schedule entries
  static ScheduleEntry? findNextOccurrence(List<ScheduleEntry> entries, [DateTime? fromTime]) {
    if (entries.isEmpty) return null;

    // Sort by minutes until next occurrence
    entries.sort((a, b) => a.minutesUntilNext(fromTime).compareTo(b.minutesUntilNext(fromTime)));

    return entries.first;
  }

  /// Get minutes until the next occurrence from a schedule list
  static int? getMinutesUntilNext(List<String> scheduleStrings, [DateTime? fromTime]) {
    final entries = parseSchedule(scheduleStrings);
    final next = findNextOccurrence(entries, fromTime);
    return next?.minutesUntilNext(fromTime);
  }
}
