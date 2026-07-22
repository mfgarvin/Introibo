import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/schedule_parser.dart';
import 'language_badge.dart';

/// Mass schedule card that presents the *standing weekly schedule* split into
/// a Weekend section (Saturday Vigil + Sunday) and a Weekday section, rather
/// than a rolling "next few days" view. One-off / holiday Masses (entries with
/// a `mass_date`) that are still upcoming are surfaced in a separate
/// "Upcoming / Special" section; past dated Masses are dropped.
class MassScheduleCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final List<ScheduleEntry> items;
  final String emptyMessage;
  final Color color;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final bool isDark;

  const MassScheduleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.items,
    required this.emptyMessage,
    required this.color,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
    required this.isDark,
  });

  /// A weekend Mass = any Sunday Mass, or a Saturday Mass at/after noon (Vigil).
  /// Saturday morning daily Mass stays in the weekday group.
  static bool _isWeekend(ScheduleEntry e) =>
      e.dayOfWeek == 7 || (e.dayOfWeek == 6 && e.hour >= 12);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final regular = items.where((e) => !e.isDated).toList();
    final weekend = regular.where(_isWeekend).toList();
    final weekday = regular.where((e) => !_isWeekend(e)).toList();

    // Upcoming dated/holiday Masses (next ~21 days), soonest first.
    final special = items
        .where((e) => e.isDated && !e.isPast(now))
        .where((e) => e.minutesUntilNext(now) <= 21 * 24 * 60)
        .toList()
      ..sort((a, b) => a.nextOccurrence(now).compareTo(b.nextOccurrence(now)));

    final hasAny =
        weekend.isNotEmpty || weekday.isNotEmpty || special.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 16),
          if (!hasAny)
            _emptyRow()
          else ...[
            // Weekend reads chronologically as the weekend is kept — Saturday
            // vigil first, then Sunday morning — so it orders by day, not by
            // clock time (which would bury a 4:30 PM vigil under 9:00 AM).
            _weeklySection('Weekend', weekend,
                isFirst: true, dayFirstOrder: true),
            _weeklySection('Weekday', weekday, isFirst: weekend.isEmpty),
            _specialSection(special, now),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: icon,
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _emptyRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: subtextColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              emptyMessage,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: subtextColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.18)),
        ),
      ],
    );
  }

  /// Weekend / weekday section. Rows with identical time + note are collapsed
  /// across days, e.g. five Mon–Fri 8:00 AM entries render as one "Mon–Fri" row.
  Widget _weeklySection(
    String label,
    List<ScheduleEntry> entries, {
    bool isFirst = false,
    bool dayFirstOrder = false,
  }) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final rows = _collapse(entries, dayFirstOrder: dayFirstOrder);
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(label),
          const SizedBox(height: 10),
          ...rows.map((r) => _row(r.daysLabel, r.entry.timeLabel, r.entry.note,
              r.entry.languageBadge)),
        ],
      ),
    );
  }

  Widget _specialSection(List<ScheduleEntry> entries, DateTime now) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Upcoming / Special'),
          const SizedBox(height: 10),
          ...entries.map((e) {
            final d = e.nextOccurrence(now);
            final dateLabel = '${e.dayLabel} ${d.month}/${d.day}';
            return _row(dateLabel, e.timeLabel, e.note, e.languageBadge);
          }),
        ],
      ),
    );
  }

  /// Notes longer than this get their own full-width line below the time
  /// instead of competing with it for the ~120px tail of the row.
  static const _inlineNoteMaxChars = 28;

  Widget _row(String dayLabel, String timeLabel, String? note,
      [String? languageBadge]) {
    final inlineNote =
        note != null && note.length <= _inlineNoteMaxChars ? note : null;
    final blockNote = note != null && inlineNote == null ? note : null;

    final noteStyle = GoogleFonts.inter(
      fontSize: 13,
      color: subtextColor,
      fontStyle: FontStyle.italic,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dayLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              SizedBox(
                width: 128,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        timeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (languageBadge != null) ...[
                      const SizedBox(width: 6),
                      LanguageBadge(label: languageBadge, color: color),
                    ],
                  ],
                ),
              ),
              if (inlineNote != null)
                Expanded(
                  child: Text(
                    inlineNote,
                    style: noteStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          // Long note: full width under the row, aligned with the time column
          // so it reads as an annotation on that Mass rather than a new entry.
          if (blockNote != null)
            Padding(
              padding: const EdgeInsets.only(left: 74, top: 2),
              child: Text(blockNote, style: noteStyle),
            ),
        ],
      ),
    );
  }

  /// Collapse entries that share an identical time + note into a single row
  /// spanning multiple days. Preserves day order (Mon..Sun) within a row.
  /// Rows sort by start time, or by day-then-time when [dayFirstOrder] is set.
  List<_CollapsedRow> _collapse(
    List<ScheduleEntry> entries, {
    bool dayFirstOrder = false,
  }) {
    final groups = <String, List<ScheduleEntry>>{};
    for (final e in entries) {
      final key = '${e.hour}:${e.minute}:${e.endHour}:${e.endMinute}:'
          '${e.language ?? ''}:${e.note ?? ''}';
      groups.putIfAbsent(key, () => []).add(e);
    }

    final rows = groups.values.map((g) {
      final days = g.map((e) => e.dayOfWeek).toSet().toList()..sort();
      return _CollapsedRow(
        entry: g.first,
        daysLabel: _daysLabel(days),
        firstDay: days.first,
      );
    }).toList()
      ..sort((a, b) {
        if (dayFirstOrder && a.firstDay != b.firstDay) {
          return a.firstDay.compareTo(b.firstDay);
        }
        final at = a.entry.hour * 60 + a.entry.minute;
        final bt = b.entry.hour * 60 + b.entry.minute;
        return at.compareTo(bt);
      });
    return rows;
  }

  static const _abbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _daysLabel(List<int> days) {
    if (days.length == 1) return _abbr[days.first - 1];
    // Contiguous run of 3+ → "Mon–Fri"
    final contiguous =
        days.length >= 3 && days.last - days.first == days.length - 1;
    if (contiguous) return '${_abbr[days.first - 1]}–${_abbr[days.last - 1]}';
    return days.map((d) => _abbr[d - 1]).join(', ');
  }
}

class _CollapsedRow {
  final ScheduleEntry entry;
  final String daysLabel;

  /// Earliest ISO weekday in the row — the sort key for day-ordered sections.
  final int firstDay;

  _CollapsedRow({
    required this.entry,
    required this.daysLabel,
    required this.firstDay,
  });
}
