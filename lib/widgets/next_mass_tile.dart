import 'dart:async';
import 'package:flutter/material.dart';
import '../models/parish.dart';
import '../utils/schedule_parser.dart';
import '../theme/app_text.dart';

/// A live tile showing the soonest upcoming Mass across a set of nearby parishes.
/// Self-tickers to keep the countdown fresh.
class NextMassTile extends StatefulWidget {
  final List<Parish> parishes;
  final String label;
  final Color accentColor;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;

  /// When the soonest Mass isn't today, show a "Tomorrow, 7:30 AM" chip
  /// instead of an "in Xh" countdown. Used for the nearby tile, where the
  /// concrete next time is more useful than a dead-end "No more today".
  final bool announceNoMoreToday;
  final void Function(Parish parish) onTap;

  const NextMassTile({
    super.key,
    required this.parishes,
    this.label = 'NEXT MASS NEARBY',
    required this.accentColor,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
    required this.onTap,
    this.announceNoMoreToday = false,
  });

  @override
  State<NextMassTile> createState() => _NextMassTileState();
}

class _NextMassTileState extends State<NextMassTile> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  ({Parish parish, ScheduleEntry entry, int minutes})? _findSoonest() {
    final now = DateTime.now();
    Parish? bestParish;
    ScheduleEntry? bestEntry;
    int bestMinutes = 1 << 30;

    for (final p in widget.parishes) {
      if (p.massTimes.isEmpty) continue;
      final next = ScheduleParser.findNextOccurrence(
          p.massTimes, now, kCountMassInProgress);
      if (next == null) continue;
      final m = next.minutesUntilNext(now, kCountMassInProgress);
      if (m < bestMinutes) {
        bestMinutes = m;
        bestParish = p;
        bestEntry = next;
      }
    }

    if (bestParish == null || bestEntry == null) return null;
    return (parish: bestParish, entry: bestEntry, minutes: bestMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final hit = _findSoonest();
    if (hit == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final occurrence = hit.entry.nextOccurrence(now, kCountMassInProgress);
    final today = DateTime(now.year, now.month, now.day);
    final daysAway =
        DateTime(occurrence.year, occurrence.month, occurrence.day)
            .difference(today)
            .inDays;
    final isToday = daysAway == 0;
    final isImminent = isToday && hit.minutes <= 60;

    final whenLabel = _whenLabel(daysAway, hit.entry.dayOfWeek);

    // When the next Mass is today we show the exact time + a live countdown.
    // When it's another day, the countdown ("in 18h") is noise — generalize to
    // a part-of-day phrase and, for the nearby tile, put the concrete next
    // time in the chip ("Tomorrow, 7:30 AM") rather than a subtext-echoing
    // "No more today".
    final String whenLine;
    final String? chipText;
    if (isToday) {
      whenLine = '$whenLabel · ${_formatTime(hit.entry.hour, hit.entry.minute)}';
      chipText = _formatCountdown(hit.minutes);
    } else {
      whenLine = '$whenLabel ${_partOfDay(hit.entry.hour)}';
      chipText = widget.announceNoMoreToday
          ? '$whenLabel, ${_formatTime(hit.entry.hour, hit.entry.minute)}'
          : null;
    }

    return _buildCompact(hit, whenLine, chipText, isImminent);
  }

  /// Full-width banner, ~72px tall — the only form the tile takes.
  ///
  /// It once swelled into a half-page square inside the last hour before a
  /// Mass. That made Home rearrange itself by the clock rather than by
  /// anything the user did, and on a tablet the square came out at half of an
  /// 800dp page. The countdown chip still goes gold when a Mass is imminent,
  /// which is the part that was actually carrying the urgency.
  Widget _buildCompact(
    ({Parish parish, ScheduleEntry entry, int minutes}) hit,
    String whenLine,
    String? chipText,
    bool isImminent,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onTap(hit.parish),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: widget.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.22),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label.replaceAll('\n', ' '),
                      style: AppText.kicker(color: widget.accentColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hit.parish.name,
                      style: AppText.bodyLarge(color: widget.textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      whenLine,
                      style: AppText.caption(color: widget.subtextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (chipText != null) ...[
                const SizedBox(width: 10),
                _countdownChip(chipText, isImminent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _countdownChip(String countdown, bool isImminent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isImminent
            ? Colors.amber.withValues(alpha: 0.95)
            : widget.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        countdown,
        style: AppText.label(
          color: isImminent ? Colors.black87 : widget.accentColor,
        ),
      ),
    );
  }

  String _formatCountdown(int minutes) {
    if (minutes < 1) return 'now';
    if (minutes < 60) return 'in ${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours < 24) {
      return mins == 0 ? 'in ${hours}h' : 'in ${hours}h ${mins}m';
    }
    final days = hours ~/ 24;
    return days == 1 ? 'tomorrow' : 'in ${days}d';
  }

  String _whenLabel(int daysAway, int dayOfWeek) {
    if (daysAway == 0) return 'Today';
    if (daysAway == 1) return 'Tomorrow';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[dayOfWeek - 1];
  }

  /// Coarse part-of-day used to generalize a non-today Mass time
  /// (e.g. "Tomorrow morning").
  String _partOfDay(int hour) {
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    if (hour < 21) return 'evening';
    return 'night';
  }

  String _formatTime(int hour, int minute) {
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final mer = hour >= 12 ? 'PM' : 'AM';
    final mm = minute.toString().padLeft(2, '0');
    return '$h12:$mm $mer';
  }
}
