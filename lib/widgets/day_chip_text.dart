import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// How the day label inside a schedule chip is sized.
///
/// Shared by the Mass card and the Confession/Adoration timeline card so that
/// a "Sat" reads the same on all three — they sit on the same page, and a day
/// set smaller in one card than another looks like a mistake rather than a
/// distinction.
///
/// Sizing by label length lets the common case (a single day) fill its chip,
/// while a run ("Mon–Fri") and a list ("Mon, Tue, Thu", which wraps) still
/// fit. Only the Mass card produces the longer forms; the timeline card's
/// rows are always one day.
///
/// A single day is set at the times' own size (15), not above it: at 17 and
/// bold the "Sat" outweighed the "4:00 PM" it labels and read as a heading.
double dayChipTextSize(String label) {
  if (label.length <= 3) return 15;
  if (label.length <= 8) return 13;
  return 11;
}

/// The day label's whole style, shared by every schedule chip on a parish
/// page. Medium, not bold: the chip's tint already sets the day apart from
/// its time, so the letters don't have to shout to be found. Built fresh
/// from google_fonts so the weight picks the right font file.
TextStyle dayChipTextStyle(String label, Color ink, {double? height}) =>
    GoogleFonts.inter(
      fontSize: dayChipTextSize(label),
      fontWeight: FontWeight.w500,
      color: ink,
      height: height,
    );

/// "Mon–Fri" and the like, as opposed to a comma-separated list. A run is one
/// idea and should shrink to one line rather than break across two.
bool isDayRun(String label) => label.contains('–');
