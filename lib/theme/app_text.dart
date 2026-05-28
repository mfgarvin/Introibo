import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Unified typography scale for Introibo.
///
/// Two families:
///   • Cormorant Garamond — display, headings, parish names. Set the tone.
///   • Inter — body, labels, captions. Stays out of the way.
///
/// The 7-step scale: display • titleHuge • titleLarge • bodyLarge • body • label • kicker.
/// Reach for these rather than rolling your own GoogleFonts.x(fontSize: …) call.
class AppText {
  AppText._();

  // ───────── Display & headings (Cormorant) ─────────

  /// Big hero text (parish name on the detail header).
  static TextStyle display({Color? color, List<Shadow>? shadows}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: 0.2,
        color: color,
        shadows: shadows,
      );

  /// App title / page hero (Introibo, About).
  static TextStyle titleHuge({Color? color}) => GoogleFonts.cormorantGaramond(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: 0.3,
        color: color,
      );

  /// Section headings and card titles ("Search Parishes", "Mass Times").
  static TextStyle titleLarge({Color? color}) => GoogleFonts.cormorantGaramond(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// Hero card headline ("Find a Mass today").
  static TextStyle titleHero({Color? color}) => GoogleFonts.cormorantGaramond(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: color,
      );

  // ───────── Body & labels (Inter) ─────────

  /// Prominent item title — parish names in lists, card primary text.
  static TextStyle bodyLarge({Color? color}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: color,
      );

  /// Default body text.
  static TextStyle body({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  /// Captions, addresses, secondary info.
  static TextStyle caption({Color? color}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// Time chips, distance badges — bold short text on tinted bg.
  static TextStyle label({Color? color}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// Tiny all-caps mini-label ("NEXT MASS NEARBY", "TONIGHT").
  static TextStyle kicker({Color? color}) => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
        height: 1.2,
        color: color,
      );
}
