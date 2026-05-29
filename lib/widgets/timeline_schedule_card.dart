import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/schedule_parser.dart';

/// Schedule card that groups entries into Today / Tomorrow / This week / Beyond
/// buckets with relative time hints. Designed for Mass times where parishes
/// commonly have 5-15 entries spread across the week.
class TimelineScheduleCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final List<ScheduleEntry> items;
  final String emptyMessage;
  final Color color;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final bool isDark;

  const TimelineScheduleCard({
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

  @override
  Widget build(BuildContext context) {
    final buckets = ScheduleParser.groupByBucket(items);
    final hasUpcoming = buckets.values.any((l) => l.isNotEmpty);

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
          if (items.isEmpty || !hasUpcoming)
            _emptyRow()
          else ...[
            _section('Today', buckets['today']!, isFirst: true),
            _section('Tomorrow', buckets['tomorrow']!),
            _section('This week', buckets['thisWeek']!),
            _section('Beyond', buckets['beyond']!),
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

  Widget _section(String label, List<UpcomingEntry> entries, {bool isFirst = false}) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: Container(
                  height: 1,
                  color: color.withValues(alpha: 0.18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...entries.map((e) => _entryRow(e, label)),
        ],
      ),
    );
  }

  Widget _entryRow(UpcomingEntry e, String bucketLabel) {
    final showDay = bucketLabel == 'This week' || bucketLabel == 'Beyond';
    final note = e.noteLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Day chip (only shown for this-week / beyond)
          if (showDay)
            Container(
              width: 38,
              padding: const EdgeInsets.symmetric(vertical: 3),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                e.dayLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          // Time (or time range)
          SizedBox(
            width: 128,
            child: Text(
              e.timeLabel,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          // Note (e.g. "Vigil Mass", "Spanish")
          if (note != null)
            Expanded(
              child: Text(
                note,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: subtextColor,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
