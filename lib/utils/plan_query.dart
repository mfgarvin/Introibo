import 'package:latlong2/latlong.dart';

import '../models/parish.dart';
import '../pages/filtered_parish_list_page.dart'
    show ParishFilter, TimeOfDayFilter, TimeOfDayFilterMinutes;
import 'plan_place.dart';
import 'schedule_parser.dart';

/// One answer to "Saturday in Akron, confession": a parish, and the earliest
/// of its times that fits.
class PlanHit {
  final Parish parish;

  /// Null for a perpetual chapel, which is open the whole day.
  final ScheduleEntry? entry;

  /// When it starts on the planned day; null for a perpetual chapel.
  final DateTime? start;

  /// From the plan's origin; null when there is no origin to measure from.
  final double? miles;

  const PlanHit(this.parish, this.entry, this.start, this.miles);

  bool get isAllDay => entry == null;
}

/// How far "near me" reaches when no place was named — the same cap the list
/// page's Soonest sort treats as nearby.
const double kNearMeRadiusMiles = 10;

/// `cancelled` describes the current bulletin's week only, so it is honoured
/// for a plan inside that week and ignored past it, where it would hide a
/// Mass that is almost certainly back. See the list page's
/// `_planBeyondBulletin` for the same rule.
bool planBeyondBulletin(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(day.year, day.month, day.day).difference(today).inDays >= 7;
}

/// Every parish with a [filter] time on [day] within [time], within
/// [radiusMiles] of [origin], one hit per parish (its earliest fitting time),
/// soonest first and nearest among equals. A perpetual chapel fits any
/// adoration plan and sorts first.
///
/// For today, anything already over is left out: a Mass that has started, a
/// window that has closed.
List<PlanHit> planHits({
  required List<Parish> parishes,
  required ParishFilter filter,
  required DateTime day,
  TimeOfDayFilter time = TimeOfDayFilter.any,
  LatLng? origin,
  double? radiusMiles,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final date = DateTime(day.year, day.month, day.day);
  final isToday = date == DateTime(clock.year, clock.month, clock.day);
  final beyond = planBeyondBulletin(date, clock);
  final period = time.minutes;

  final hits = <PlanHit>[];
  for (final parish in parishes) {
    double? miles;
    if (origin != null) {
      if (parish.latitude == null || parish.longitude == null) continue;
      miles = PlanPlace.milesBetween(
          origin, LatLng(parish.latitude!, parish.longitude!));
      if (radiusMiles != null && miles > radiusMiles) continue;
    }

    if (filter == ParishFilter.adoration && parish.adorationIsPerpetual) {
      hits.add(PlanHit(parish, null, null, miles));
      continue;
    }

    final all = switch (filter) {
      ParishFilter.massTimes => parish.massTimes,
      ParishFilter.confession => parish.confTimes,
      ParishFilter.adoration => parish.adoration,
      ParishFilter.all => [...parish.massTimes, ...parish.confTimes],
    };
    final entries = beyond ? all : ScheduleParser.active(all);

    ScheduleEntry? best;
    DateTime? bestStart;
    for (final e in entries) {
      if (!e.occursOn(date)) continue;
      if (period != null && !e.touchesPeriod(period.from, period.to)) continue;
      final start = DateTime(date.year, date.month, date.day, e.hour, e.minute);
      if (isToday) {
        // A Mass is a moment you arrive for; a window is open until it ends.
        final over = e.endOf(start)?.isBefore(clock) ?? start.isBefore(clock);
        if (over) continue;
      }
      if (bestStart == null || start.isBefore(bestStart)) {
        best = e;
        bestStart = start;
      }
    }
    if (best != null) hits.add(PlanHit(parish, best, bestStart, miles));
  }

  hits.sort((a, b) {
    // Perpetual chapels first: open now, and all day.
    if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
    final t = (a.start ?? date).compareTo(b.start ?? date);
    if (t != 0) return t;
    return (a.miles ?? 0).compareTo(b.miles ?? 0);
  });
  return hits;
}
