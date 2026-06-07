import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tiny pill marking a non-English Mass language, e.g. "ES", "PL".
/// Source value comes from [ScheduleEntry.languageBadge]; render only when
/// non-null (English Masses carry no badge).
class LanguageBadge extends StatelessWidget {
  final String label;
  final Color color;

  const LanguageBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
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
