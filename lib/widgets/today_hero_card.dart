import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../pages/filtered_parish_list_page.dart';

/// What kind of schedule a hero suggestion is pointing the user toward.
enum HeroIntent { mass, confession, adoration }

/// A day-aware suggestion card that adapts its message and CTA to the
/// current weekday and time of day. Calls [onSelect] with the matching
/// intent so the host can route to the right filtered list.
class TodayHeroCard extends StatelessWidget {
  final void Function(HeroIntent intent) onSelect;
  final Color accentColor;
  final bool isDark;

  const TodayHeroCard({
    super.key,
    required this.onSelect,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final suggestion = _suggestionFor(now);
    final tint = _accentForIntent(suggestion.intent) ?? accentColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(suggestion.intent),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint,
                Color.lerp(tint, Colors.black, 0.28)!,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(suggestion.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.kicker,
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion.headline,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    if (suggestion.subline != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        suggestion.subline!,
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  _Suggestion _suggestionFor(DateTime now) {
    final weekday = now.weekday; // 1=Mon, 7=Sun
    final hour = now.hour;
    final dayName = _dayName(weekday);

    // Sunday morning → main Mass
    if (weekday == DateTime.sunday && hour < 13) {
      return _Suggestion(
        kicker: 'SUNDAY',
        headline: 'Find a Mass today',
        subline: 'Sunday Mass times nearby',
        icon: Icons.church,
        intent: HeroIntent.mass,
      );
    }
    // Sunday afternoon/evening → adoration / quiet
    if (weekday == DateTime.sunday) {
      return _Suggestion(
        kicker: 'SUNDAY EVENING',
        headline: 'A quiet hour of adoration',
        subline: 'Find a chapel for evening prayer',
        icon: Icons.brightness_2_outlined,
        intent: HeroIntent.adoration,
      );
    }
    // Saturday afternoon/evening → vigil Mass
    if (weekday == DateTime.saturday && hour >= 14) {
      return _Suggestion(
        kicker: 'TONIGHT',
        headline: 'Vigil Mass tonight',
        subline: 'See Saturday vigil schedules',
        icon: Icons.nights_stay,
        intent: HeroIntent.mass,
      );
    }
    // Saturday morning → confession (penitential traditional time)
    if (weekday == DateTime.saturday) {
      return _Suggestion(
        kicker: 'SATURDAY',
        headline: 'Confessions this morning',
        subline: 'Many parishes hear confessions before vigil',
        icon: Icons.self_improvement,
        intent: HeroIntent.confession,
      );
    }
    // Friday → confession
    if (weekday == DateTime.friday) {
      return _Suggestion(
        kicker: 'FRIDAY',
        headline: 'Confession this week',
        subline: 'Find a parish offering reconciliation',
        icon: Icons.self_improvement,
        intent: HeroIntent.confession,
      );
    }
    // Weekday morning → daily Mass
    if (hour < 11) {
      return _Suggestion(
        kicker: dayName.toUpperCase(),
        headline: 'Daily Mass this morning',
        subline: 'Weekday Mass times nearby',
        icon: Icons.wb_sunny_outlined,
        intent: HeroIntent.mass,
      );
    }
    // Weekday late evening → adoration
    if (hour >= 19) {
      return _Suggestion(
        kicker: 'TONIGHT',
        headline: 'A quiet hour of adoration',
        subline: 'Find a chapel for evening prayer',
        icon: Icons.brightness_2_outlined,
        intent: HeroIntent.adoration,
      );
    }
    // Default daytime weekday → Mass times
    return _Suggestion(
      kicker: dayName.toUpperCase(),
      headline: 'Find Mass times today',
      subline: 'Browse parishes near you',
      icon: Icons.access_time,
      intent: HeroIntent.mass,
    );
  }

  /// Color hint per intent — gives each kind of suggestion a recognizable
  /// hue without overriding caller-provided accent.
  Color? _accentForIntent(HeroIntent intent) {
    switch (intent) {
      case HeroIntent.mass:
        return null; // use caller accent
      case HeroIntent.confession:
        return const Color(0xFF3F95A1); // teal (matches primary)
      case HeroIntent.adoration:
        return const Color(0xFFD58A2A); // warm amber
    }
  }

  String _dayName(int weekday) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[weekday - 1];
  }
}

class _Suggestion {
  final String kicker;
  final String headline;
  final String? subline;
  final IconData icon;
  final HeroIntent intent;

  _Suggestion({
    required this.kicker,
    required this.headline,
    this.subline,
    required this.icon,
    required this.intent,
  });
}

/// Maps a hero intent to the matching [ParishFilter] for routing.
ParishFilter parishFilterForIntent(HeroIntent intent) {
  switch (intent) {
    case HeroIntent.mass:
      return ParishFilter.massTimes;
    case HeroIntent.confession:
      return ParishFilter.confession;
    case HeroIntent.adoration:
      return ParishFilter.adoration;
  }
}
