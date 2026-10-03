import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart'
    show
        kCardColor,
        kCardColorDark,
        kTextDark,
        themeNotifier,
        cardBorderFor,
        primaryAccentFor,
        violetAccentFor,
        goldTextAccentFor;
import '../models/parish.dart';
import '../pages/filtered_parish_list_page.dart'
    show ParishFilter, TimeOfDayFilter;
import '../theme/app_text.dart';
import '../utils/plan_place.dart';
import '../utils/plan_query.dart';
import 'plan_words.dart';

/// "Show me Confession on Sat, Oct 3 in the afternoon near Akron" — the
/// planner as one sentence of tappable words on Home, answered right
/// beneath it. Each word is its own small menu, so changing one part of the
/// question is one tap, not a trip through a form.
class PlanVisitCard extends StatefulWidget {
  final List<Parish> parishes;

  /// Null when the device has no fix; the place word then starts empty and
  /// asks for a city or ZIP.
  final LatLng? userLocation;

  final void Function(Parish parish) onOpenParish;

  /// "See all": the full filtered list, opened already answering this plan.
  final void Function(ParishFilter filter, DateTime date,
      TimeOfDayFilter time, PlanPlace? place) onSeeAll;

  /// False inside a sheet, which is already the surface: no card of its
  /// own, and a title in its place.
  final bool framed;

  const PlanVisitCard({
    super.key,
    this.framed = true,
    required this.parishes,
    required this.userLocation,
    required this.onOpenParish,
    required this.onSeeAll,
  });

  @override
  State<PlanVisitCard> createState() => _PlanVisitCardState();
}

class _PlanVisitCardState extends State<PlanVisitCard> {
  /// Rows shown on the card before "See all".
  static const _preview = 4;

  ParishFilter _filter = ParishFilter.massTimes;
  late DateTime _date = _today;
  TimeOfDayFilter _time = TimeOfDayFilter.any;

  /// Null means near the user.
  PlanPlace? _place;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isDark => themeNotifier.isDarkMode;
  bool get _hasLocation => widget.userLocation != null;

  Color get _accent => switch (_filter) {
        ParishFilter.confession => violetAccentFor(isDark: _isDark),
        ParishFilter.adoration => goldTextAccentFor(isDark: _isDark),
        _ => primaryAccentFor(isDark: _isDark),
      };

  /// The day as it reads in the sentence: "today", "on Sunday".
  String _dateWord(DateTime d) => switch (d.difference(_today).inDays) {
        0 => 'today',
        1 => 'tomorrow',
        _ => 'on ${weekdayName(d.weekday)}',
      };

  static String _timeWord(TimeOfDayFilter t) => switch (t) {
        TimeOfDayFilter.any => 'any time',
        TimeOfDayFilter.morning => 'in the morning',
        TimeOfDayFilter.afternoon => 'in the afternoon',
        TimeOfDayFilter.evening => 'in the evening',
        TimeOfDayFilter.night => 'at night',
      };

  static String _filterWord(ParishFilter f) => switch (f) {
        ParishFilter.confession => 'Confession',
        ParishFilter.adoration => 'Adoration',
        _ => 'Mass',
      };

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? kTextDark : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;
    final sentence = AppText.bodyLarge(color: textColor);

    final origin = _place?.center ?? widget.userLocation;
    final hits = origin == null
        ? const <PlanHit>[]
        : planHits(
            parishes: widget.parishes,
            filter: _filter,
            day: _date,
            time: _time,
            origin: origin,
            radiusMiles: _place?.radiusMiles ?? kNearMeRadiusMiles,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: !widget.framed
          ? null
          : BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: cardBorderFor(isDark: isDark),
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
          if (!widget.framed) ...[
            Row(
              children: [
                Icon(Icons.event_note, color: _accent),
                const SizedBox(width: 8),
                Text('Plan ahead', style: AppText.titleLarge(color: textColor)),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text('Show me', style: sentence),
              MenuWord<ParishFilter>(
                label: _filterWord(_filter),
                values: const [
                  ParishFilter.massTimes,
                  ParishFilter.confession,
                  ParishFilter.adoration,
                ],
                itemLabel: _filterWord,
                onSelected: (f) => setState(() => _filter = f),
                accent: _accent,
              ),
              MenuWord<DateTime>(
                label: _dateWord(_date),
                values: comingWeek(_today),
                itemLabel: (d) => dayChoiceLabel(d, _today),
                onSelected: (d) => setState(() => _date = d),
                accent: _accent,
              ),
              MenuWord<TimeOfDayFilter>(
                label: _timeWord(_time),
                values: const [
                  TimeOfDayFilter.any,
                  TimeOfDayFilter.morning,
                  TimeOfDayFilter.afternoon,
                  TimeOfDayFilter.evening,
                ],
                itemLabel: _timeWord,
                onSelected: (t) => setState(() => _time = t),
                accent: _accent,
              ),
              Text('near', style: sentence),
              PlaceWord(
                parishes: widget.parishes,
                place: _place,
                hasLocation: _hasLocation,
                onChanged: (p) => setState(() => _place = p),
                accent: _accent,
                hintColor: subtextColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: subtextColor.withValues(alpha: 0.2)),
          const SizedBox(height: 6),
          if (origin == null)
            _note('Type a city or ZIP code to see what\'s there.',
                subtextColor)
          else if (hits.isEmpty)
            _note('Nothing then. Try another time, day or place.',
                subtextColor)
          else ...[
            for (final hit in hits.take(_preview))
              _hitRow(hit, textColor, subtextColor),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => widget.onSeeAll(_filter, _date, _time, _place),
                child: Text(
                  hits.length > _preview ? 'See all ${hits.length} →' : 'Open list →',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: _accent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _note(String text, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: AppText.body(color: color)),
      );

  Widget _hitRow(PlanHit hit, Color textColor, Color subtextColor) {
    final when = hit.isAllDay ? 'All day' : hit.entry!.timeLabel;
    return InkWell(
      onTap: () => widget.onOpenParish(hit.parish),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wide enough for "3:00 – 4:00 PM" on one line; a window's end
            // is the useful half of it.
            SizedBox(
              width: 112,
              child: Text(
                when,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: _accent),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hit.parish.name,
                // Fresh, so the weight picks the semibold file (see
                // wordStyle in plan_words.dart).
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: textColor),
              ),
            ),
            if (hit.miles != null) ...[
              const SizedBox(width: 8),
              Text(
                '${hit.miles!.toStringAsFixed(1)} mi',
                style: AppText.caption(color: subtextColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
