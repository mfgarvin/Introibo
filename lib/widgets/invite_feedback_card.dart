import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shown near the top of the parish detail page for parishes whose schedule was
/// never machine-verified from a bulletin (`invite_feedback` in the export).
/// These are the records where the person holding the phone knows more than we
/// do, so the ask is up front rather than buried at the bottom of the page.
///
/// Deliberately *not* an error or warning: the times may well be correct, and
/// nothing here should suggest the parish is at fault. It reads as an
/// invitation, in gold rather than the oxblood used for primary actions.
class InviteFeedbackCard extends StatelessWidget {
  final Color accent;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final VoidCallback onTap;

  const InviteFeedbackCard({
    super.key,
    required this.accent,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
            color: accent.withValues(alpha: 0.06),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.volunteer_activism_outlined,
                    color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Do you know this parish?',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "We weren't able to confirm this parish's schedule from a "
                      'bulletin, so these times may be out of date. If you '
                      'attend here, tell us what’s right.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: subtextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Confirm or correct the times',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 15, color: accent),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
