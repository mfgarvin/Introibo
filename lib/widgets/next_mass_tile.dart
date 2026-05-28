import 'dart:async';
import 'package:flutter/material.dart';
import '../models/parish.dart';
import '../utils/schedule_parser.dart';
import '../theme/app_text.dart';
import 'stained_glass_header.dart';

/// A live tile showing the soonest upcoming Mass across a set of nearby parishes.
/// Self-tickers to keep the countdown fresh.
class NextMassTile extends StatefulWidget {
  final List<Parish> parishes;
  final String label;
  final Color accentColor;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
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
      final entries = ScheduleParser.parseSchedule(p.massTimes);
      final next = ScheduleParser.findNextOccurrence(entries, now);
      if (next == null) continue;
      final m = next.minutesUntilNext(now);
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

    final timeLabel = _formatTime(hit.entry.hour, hit.entry.minute);
    final countdown = _formatCountdown(hit.minutes);
    final whenLabel = _whenLabel(hit.entry, DateTime.now());
    final isImminent = hit.minutes <= 60;

    final seed = hit.parish.parishId ?? hit.parish.name;
    return AspectRatio(
      aspectRatio: 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onTap(hit.parish),
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: widget.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.accentColor.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // Full-bleed stained-glass watermark
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.30,
                      child: StainedGlassHeader(
                        seed: seed,
                        overlayDarken: 0.0,
                      ),
                    ),
                  ),
                  // Diagonal scrim from card color so the upper-left text stays legible
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.cardColor.withValues(alpha: 0.95),
                            widget.cardColor.withValues(alpha: 0.55),
                            widget.cardColor.withValues(alpha: 0.15),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top: kicker label + countdown chip
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.label,
                                style:
                                    AppText.kicker(color: widget.accentColor),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isImminent
                                    ? Colors.amber.withValues(alpha: 0.95)
                                    : widget.accentColor
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                countdown,
                                style: AppText.label(
                                  color: isImminent
                                      ? Colors.black87
                                      : widget.accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Middle: parish name
                        Text(
                          hit.parish.name,
                          style: AppText.bodyLarge(color: widget.textColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Bottom: when + time
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 14,
                              decoration: BoxDecoration(
                                color: widget.accentColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '$whenLabel · $timeLabel',
                                style:
                                    AppText.caption(color: widget.subtextColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  String _whenLabel(ScheduleEntry entry, DateTime now) {
    final occurrence = entry.nextOccurrence(now);
    final today = DateTime(now.year, now.month, now.day);
    final eventDay =
        DateTime(occurrence.year, occurrence.month, occurrence.day);
    final days = eventDay.difference(today).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[entry.dayOfWeek - 1];
  }

  String _formatTime(int hour, int minute) {
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final mer = hour >= 12 ? 'PM' : 'AM';
    final mm = minute.toString().padLeft(2, '0');
    return '$h12:$mm $mer';
  }
}
