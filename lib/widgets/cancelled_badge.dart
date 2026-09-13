import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show errorAccentFor;

/// Tiny pill marking a schedule slot the bulletin suspended for this week.
/// Rides beside the struck-through time on a schedule row — see
/// [ScheduleEntry.cancelled].
///
/// It carries the error hue rather than the card's own accent because it
/// contradicts the row it sits on: a Mass card is oxblood throughout, and a
/// marker in that same oxblood reads as one more part of the schedule rather
/// than as the line saying this one isn't happening.
class CancelledBadge extends StatelessWidget {
  final bool isDark;

  const CancelledBadge({super.key, required this.isDark});

  /// The word a row's time is struck through with, also used as a semantic
  /// label so the strikethrough — which a screen reader cannot see — is read
  /// aloud.
  static const String label = 'Cancelled';

  @override
  Widget build(BuildContext context) {
    final color = errorAccentFor(isDark: isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}
