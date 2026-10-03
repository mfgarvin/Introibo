import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/parish.dart';
import '../services/parish_service.dart';
import '../utils/layout_scale.dart';
import '../utils/plan_place.dart';
import '../utils/schedule_parser.dart';
import '../main.dart'
    show
        FavoritesManager,
        kBackgroundColor,
        kBackgroundColorDark,
        kCardColor,
        kCardColorDark,
        cardBorderFor,
        errorAccentFor,
        themeNotifier;
import 'parish_detail_page.dart';
import '../widgets/stained_glass_header.dart';
import '../widgets/language_badge.dart';
import '../widgets/plan_words.dart';

enum ParishFilter {
  massTimes,
  confession,
  adoration,
  all,
}

enum SortOrder {
  distance,
  alphabetical,
  nearestAndSoonest,
}

enum DayFilter {
  any,
  today,
  tomorrow,
}

enum TimeOfDayFilter {
  any,
  morning, // 5am-12pm
  afternoon, // 12pm-5pm
  evening, // 5pm-9pm
  night, // 9pm-5am
}

extension TimeOfDayFilterMinutes on TimeOfDayFilter {
  /// The period in minutes after midnight, half-open, for
  /// [ScheduleEntry.touchesPeriod]; null for [TimeOfDayFilter.any]. Night
  /// wraps, so its `to` is less than its `from`.
  ({int from, int to})? get minutes => switch (this) {
        TimeOfDayFilter.any => null,
        TimeOfDayFilter.morning => (from: 5 * 60, to: 12 * 60),
        TimeOfDayFilter.afternoon => (from: 12 * 60, to: 17 * 60),
        TimeOfDayFilter.evening => (from: 17 * 60, to: 21 * 60),
        TimeOfDayFilter.night => (from: 21 * 60, to: 5 * 60),
      };
}

class FilteredParishListPage extends StatefulWidget {
  final ParishFilter filter;
  final String title;
  final Color accentColor;
  final LatLng? userLocation;

  /// Planning entry ("Plan ahead" on Home): open already answering a question
  /// about a specific day, part of the day, or place. Any of them starts the
  /// list sorted by distance, since "Soonest" answers "now", not "Saturday".
  final DateTime? initialDate;
  final TimeOfDayFilter initialTimeOfDay;
  final PlanPlace? initialPlace;

  const FilteredParishListPage({
    super.key,
    required this.filter,
    required this.title,
    required this.accentColor,
    this.userLocation,
    this.initialDate,
    this.initialTimeOfDay = TimeOfDayFilter.any,
    this.initialPlace,
  });

  @override
  State<FilteredParishListPage> createState() => _FilteredParishListPageState();
}

class _FilteredParishListPageState extends State<FilteredParishListPage> {
  List<Parish> _parishes = [];
  List<Parish> _filteredParishes = [];

  /// Keyed by [FavoritesManager.keyFor], not by name — six parish names repeat
  /// across cities, and name keys made those records overwrite each other.
  final Map<String, double> _distances = {};
  final Map<String, int> _minutesUntilNext = {};
  bool _isLoading = true;
  SortOrder _sortOrder = SortOrder.nearestAndSoonest;
  bool _showAllParishes = false;
  DayFilter _dayFilter = DayFilter.any;
  TimeOfDayFilter _timeOfDayFilter = TimeOfDayFilter.any;

  /// Whether the filter bar is showing. It opens itself when the page is
  /// opened already filtering (from the planner), and only the Close button
  /// shuts it — which it offers only once every filter is back at default,
  /// so a filter can never be on with nothing on screen saying so.
  bool _filtersOpen = false;

  /// A specific calendar day to plan for. Mutually exclusive with
  /// [_dayFilter] — choosing one clears the other.
  DateTime? _planDate;

  /// Somewhere other than the user to measure from ("in Akron"). When set,
  /// distances, sorting and the radius cut all work from it.
  PlanPlace? _place;

  /// Where distances are measured from: the planned place, else the user.
  LatLng? get _origin => _place?.center ?? widget.userLocation;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// `cancelled` is re-derived from the *current* bulletin, so it describes
  /// this week only. Planning further out than that, a cancellation would
  /// hide a Mass that is almost certainly back by then — so beyond the week
  /// the standing schedule is used, and the list says so.
  bool get _planBeyondBulletin =>
      _planDate != null && _planDate!.difference(_today).inDays >= 7;

  /// 2 days in minutes
  static const int _twoDaysInMinutes = 2880;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
    _timeOfDayFilter = widget.initialTimeOfDay;
    _place = widget.initialPlace;
    final date = widget.initialDate;
    if (date != null) {
      final day = DateTime(date.year, date.month, date.day);
      // Today is better answered by the Today filter: it already knows which
      // of today's times have passed.
      if (day == _today) {
        _dayFilter = DayFilter.today;
      } else {
        _planDate = day;
      }
    }
    _filtersOpen = _isFiltering;
    _loadParishData();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Future<void> _loadParishData() async {
    try {
      final parishes = await parishService.getParishes();

      setState(() {
        _parishes = parishes;
        _calculateDistances();
        _calculateNextOccurrences();
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading parish data: $e');
    }
  }

  void _calculateDistances() {
    _distances.clear();
    final origin = _origin;
    if (origin == null) return;

    for (final parish in _parishes) {
      if (parish.latitude != null && parish.longitude != null) {
        _distances[FavoritesManager.keyFor(parish)] = _calculateDistance(
          origin.latitude,
          origin.longitude,
          parish.latitude!,
          parish.longitude!,
        );
      }
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusMiles = 3958.8;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMiles * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Whether a window already open counts as "soonest" for this list. True for
  /// confession/adoration (come and go); false for Mass — see
  /// [kCountMassInProgress]. The "all" list falls back to confession only when
  /// a parish has no Mass times, so it follows the schedule actually used.
  bool _countInProgressFor(Parish parish) {
    switch (widget.filter) {
      case ParishFilter.massTimes:
        return kCountMassInProgress;
      case ParishFilter.confession:
      case ParishFilter.adoration:
        return true;
      case ParishFilter.all:
        return parish.massTimes.isEmpty;
    }
  }

  void _calculateNextOccurrences() {
    for (final parish in _parishes) {
      // A perpetual chapel is open right now, so nothing is sooner. It carries
      // no ScheduleEntry, though, so the generic path below left it with no
      // countdown at all — which sorted it behind every scheduled parish and
      // then hid it entirely, because the two-day cap drops anything without
      // one. Rank it as open and move on.
      if (widget.filter == ParishFilter.adoration &&
          parish.adorationIsPerpetual) {
        _minutesUntilNext[FavoritesManager.keyFor(parish)] = 0;
        continue;
      }

      List<ScheduleEntry> scheduleToCheck = [];

      // Get the appropriate schedule based on filter
      switch (widget.filter) {
        case ParishFilter.massTimes:
          scheduleToCheck = parish.massTimes;
          break;
        case ParishFilter.confession:
          scheduleToCheck = parish.confTimes;
          break;
        case ParishFilter.adoration:
          scheduleToCheck = parish.adoration;
          break;
        case ParishFilter.all:
          scheduleToCheck =
              parish.massTimes.isNotEmpty ? parish.massTimes : parish.confTimes;
          break;
      }

      // Calculate minutes until next occurrence
      final minutes = ScheduleParser.minutesUntilNext(
          scheduleToCheck, null, _countInProgressFor(parish));
      if (minutes != null) {
        _minutesUntilNext[FavoritesManager.keyFor(parish)] = minutes;
      }
    }
  }

  void _applyFilter() {
    switch (widget.filter) {
      case ParishFilter.massTimes:
        _filteredParishes =
            _parishes.where((p) => p.massTimes.isNotEmpty).toList();
        break;
      case ParishFilter.confession:
        _filteredParishes =
            _parishes.where((p) => p.confTimes.isNotEmpty).toList();
        break;
      case ParishFilter.adoration:
        _filteredParishes = _parishes.where((p) => p.hasAdoration).toList();
        break;
      case ParishFilter.all:
        _filteredParishes = List.from(_parishes);
        break;
    }
    _applySorting();
  }

  void _applySorting() {
    if (_effectiveSort == SortOrder.distance && _origin != null) {
      _filteredParishes.sort((a, b) {
        final distA = _distances[FavoritesManager.keyFor(a)] ?? double.infinity;
        final distB = _distances[FavoritesManager.keyFor(b)] ?? double.infinity;
        return distA.compareTo(distB);
      });
    } else if (_effectiveSort == SortOrder.nearestAndSoonest &&
        _origin != null) {
      // Composite score: combine distance and time
      _filteredParishes.sort((a, b) {
        final scoreA = _calculateCompositeScore(a);
        final scoreB = _calculateCompositeScore(b);
        if (scoreA != scoreB) return scoreA.compareTo(scoreB);
        // Everything underway right now scores the same, so the nearer one
        // wins — otherwise a perpetual chapel across the street loses to an
        // all-day chapel on the far side of town.
        final distA = _distances[FavoritesManager.keyFor(a)] ?? double.infinity;
        final distB = _distances[FavoritesManager.keyFor(b)] ?? double.infinity;
        return distA.compareTo(distB);
      });
    } else {
      _filteredParishes.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  /// Distance cap in miles - parishes within this range are sorted by time
  static const double _distanceCapMiles = 10.0;

  /// Calculate composite score using distance cap approach
  /// - Within cap: sort by time (soonest first)
  /// - Beyond cap: pushed to bottom, sorted by distance
  double _calculateCompositeScore(Parish parish) {
    final key = FavoritesManager.keyFor(parish);
    final distance = _distances[key];
    final minutes = _minutesUntilNext[key];

    // If either is missing, return infinity
    if (distance == null || minutes == null) {
      return double.infinity;
    }

    // Distance cap scoring:
    // - Within 10 miles: score = minutes (0-9999 range, sorted by time)
    // - Beyond 10 miles: score = 10000 + distance (always after nearby parishes)
    if (distance <= _distanceCapMiles) {
      // In-progress entries come back negative (minutes since it started), and
      // a perpetual chapel is pinned at 0. Ranking by how long ago something
      // opened is meaningless, so everything happening now ties at 0 and the
      // caller's distance tiebreak decides.
      return minutes < 0 ? 0.0 : minutes.toDouble();
    } else {
      return 10000.0 + distance;
    }
  }

  bool _hasActiveFilters() {
    return _planDate != null ||
        _dayFilter != DayFilter.any ||
        _timeOfDayFilter != TimeOfDayFilter.any;
  }

  /// Any part of the filter bar away from its default, place included.
  bool get _isFiltering => _hasActiveFilters() || _place != null;

  /// The order actually used. A filter and a sort answer different questions
  /// ("Saturday afternoon near Akron" vs "what's soonest"), and both at once
  /// produced lists nobody could predict — so while filtering, the sort tabs
  /// stand aside and the answers line up nearest first, the way the planner's
  /// "See all" opens. Clearing the filter brings back the sort chosen before.
  SortOrder get _effectiveSort =>
      _isFiltering ? SortOrder.distance : _sortOrder;

  /// The schedule entries the time filters scan, based on filter type.
  /// Cancelled slots are out: "Confessions today" is a question about where a
  /// churchgoer can actually go today, so a suspended slot must not put a
  /// parish in the results or supply the times its card then samples.
  ///
  /// Except when planning past this week: see [_planBeyondBulletin].
  List<ScheduleEntry> _filterableEntries(Parish parish) {
    final entries = switch (widget.filter) {
      ParishFilter.massTimes => parish.massTimes,
      ParishFilter.confession => parish.confTimes,
      ParishFilter.adoration => parish.adoration,
      ParishFilter.all => [...parish.massTimes, ...parish.confTimes],
    };
    return _planBeyondBulletin ? entries : ScheduleParser.active(entries);
  }

  /// Whether a single entry satisfies every active filter.
  bool _entryMatchesFilters(
      Parish parish, ScheduleEntry entry, DateTime now, DateTime today) {
    // A planned date asks the one question that is right for every kind of
    // entry — dated, weekly, First Friday, anchored — rather than comparing
    // weekdays, which would put a First Friday Mass on every Friday.
    if (_planDate != null && !entry.occursOn(_planDate!)) return false;


    // Check time of day filter. A window counts in every period it overlaps
    // — an all-day chapel is open in the afternoon, not only in the morning
    // it opened in.
    final period = _timeOfDayFilter.minutes;
    if (period != null && !entry.touchesPeriod(period.from, period.to)) {
      return false;
    }

    // Check day filter
    if (_dayFilter != DayFilter.any) {
      final nextOccurrence =
          entry.nextOccurrence(now, _countInProgressFor(parish));
      final eventDay = DateTime(
          nextOccurrence.year, nextOccurrence.month, nextOccurrence.day);
      final daysUntil = eventDay.difference(today).inDays;

      bool matchesDay = false;
      switch (_dayFilter) {
        case DayFilter.today:
          matchesDay = daysUntil == 0;
          break;
        case DayFilter.tomorrow:
          matchesDay = daysUntil == 1;
          break;
        case DayFilter.any:
          matchesDay = true;
          break;
      }
      if (!matchesDay) return false;
    }

    return true;
  }

  /// Check if a parish has any schedule entries matching the current filters
  bool _matchesTimeFilters(Parish parish) {
    if (!_hasActiveFilters()) return true;

    // A perpetual chapel is open every day at every hour, so it answers any
    // day/time question — and it carries no entries, so it has to be let in
    // before the empty-schedule bail-out below drops it.
    if (widget.filter == ParishFilter.adoration && parish.adorationIsPerpetual) {
      return true;
    }

    final entries = _filterableEntries(parish);
    if (entries.isEmpty) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return entries.any((e) => _entryMatchesFilters(parish, e, now, today));
  }

  /// The entries matching the active filters, soonest occurrence first — what
  /// the card's times sample shows so it agrees with the filter.
  List<ScheduleEntry> _entriesMatchingFilters(Parish parish) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final countInProgress = _countInProgressFor(parish);
    return _filterableEntries(parish)
        .where((e) => _entryMatchesFilters(parish, e, now, today))
        .toList()
      ..sort((a, b) => a
          .nextOccurrence(now, countInProgress)
          .compareTo(b.nextOccurrence(now, countInProgress)));
  }

  /// Measure from [place] instead of the user (null: back to the user).
  void _setPlace(PlanPlace? place) {
    setState(() {
      _place = place;
      _calculateDistances();
      _applySorting();
    });
  }

  /// The days the bar offers: the relative ones, then the coming week by
  /// name. A plan for a date further out (opened that way) is offered too,
  /// so the bar can always show what it is answering.
  List<({DayFilter filter, DateTime? date})> get _dayChoices {
    final today = _today;
    final week = comingWeek(today).skip(2).toList();
    return [
      (filter: DayFilter.any, date: null),
      (filter: DayFilter.today, date: null),
      (filter: DayFilter.tomorrow, date: null),
      for (final d in week) (filter: DayFilter.any, date: d),
      if (_planDate != null && !week.contains(_planDate))
        (filter: DayFilter.any, date: _planDate),
    ];
  }

  String _dayChoiceLabel(({DayFilter filter, DateTime? date}) c) {
    final date = c.date;
    if (date != null) {
      return date.difference(_today).inDays < 7
          ? dayChoiceLabel(date, _today)
          : planDateLabel(date);
    }
    return switch (c.filter) {
      DayFilter.any => 'Any day',
      DayFilter.today => 'Today',
      DayFilter.tomorrow => 'Tomorrow',
    };
  }

  static String _timeLabel(TimeOfDayFilter t) => switch (t) {
        TimeOfDayFilter.any => 'Any time',
        TimeOfDayFilter.morning => 'Morning',
        TimeOfDayFilter.afternoon => 'Afternoon',
        TimeOfDayFilter.evening => 'Evening',
        TimeOfDayFilter.night => 'Night',
      };

  /// The question this list is answering, at the top, always — and each part
  /// of it a word to tap and change. Replaces a Filter button that opened a
  /// sheet: a filter you can't see is one you forget is on. It sits above the
  /// list rather than in it, so it stays put while the list scrolls, and
  /// changing the sort leaves it alone.
  /// The panel's first line: when — day and part of the day.
  Widget _whenWords(Color subtextColor) {
    final accent = widget.accentColor;
    final current = (filter: _dayFilter, date: _planDate);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        MenuWord<({DayFilter filter, DateTime? date})>(
          label: _dayChoiceLabel(current),
          values: _dayChoices,
          itemLabel: _dayChoiceLabel,
          onSelected: (c) => setState(() {
            _dayFilter = c.filter;
            _planDate = c.date;
            _applySorting();
          }),
          accent: accent,
          compact: true,
        ),
        MenuWord<TimeOfDayFilter>(
          label: _timeLabel(_timeOfDayFilter),
          values: const [
            TimeOfDayFilter.any,
            TimeOfDayFilter.morning,
            TimeOfDayFilter.afternoon,
            TimeOfDayFilter.evening,
          ],
          itemLabel: _timeLabel,
          onSelected: (t) => setState(() {
            _timeOfDayFilter = t;
            _applySorting();
          }),
          accent: accent,
          compact: true,
        ),
      ],
    );
  }

  void _clearFilters() {
    setState(() {
      _planDate = null;
      _dayFilter = DayFilter.any;
      _timeOfDayFilter = TimeOfDayFilter.any;
      _place = null;
      _calculateDistances();
      _applySorting();
    });
  }

  /// The Filter pill's height: the sort tabs' own. Material draws those 40px
  /// tall less the theme's density adjustment (compact on desktop), and does
  /// *not* grow them with the text scale — so neither does this. A minimum
  /// only: a label that needs more room at large text still gets it.
  double _filterRowHeight(BuildContext context) =>
      40 + Theme.of(context).visualDensity.baseSizeAdjustment.dy;

  /// The Filter button: Filter opens the bar; once open it is Clear while
  /// anything is set and Close when nothing is. A pill the height of the
  /// sort tabs beside it, so the two read as one line of controls.
  Widget _buildFilterButton(Color subtextColor) {
    final accent = widget.accentColor;
    final (label, icon, onTap) = !_filtersOpen
        ? ('Filter', Icons.filter_list, () => setState(() => _filtersOpen = true))
        : _isFiltering
            ? ('Clear', Icons.filter_list_off, _clearFilters)
            : ('Close', Icons.expand_less,
                () => setState(() => _filtersOpen = false));
    final highlighted = _filtersOpen;
    return Semantics(
      button: true,
      label: label == 'Filter' ? 'Show filters' : '$label filters',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: _filterRowHeight(context)),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: highlighted
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            // Stadium, with the tabs' own outline, so it reads as their kin.
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
                color: highlighted
                    ? accent.withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: highlighted ? accent : subtextColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: highlighted ? accent : subtextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortAndFilterRow(
      Color subtextColor, bool isDark, bool canSortByDistance) {
    final button = _buildFilterButton(subtextColor);
    if (!canSortByDistance) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Align(alignment: Alignment.centerRight, child: button),
      );
    }
    // No icons on the segments: beside the Filter pill there is room for the
    // words or the pictures, and with both "Soonest" broke across two lines.
    final tabs = SegmentedButton<SortOrder>(
          // Three segments across a phone give each about a third of the
          // width, which at large text sizes is narrower than the word
          // inside it — "Soonest" wrapped to "Soone / st". Stacked, each
          // segment gets the full width instead.
          direction: context.prefersStackedLayout
              ? Axis.vertical
              : Axis.horizontal,
          segments: const [
            ButtonSegment(
              value: SortOrder.nearestAndSoonest,
              label: Text('Soonest'),
            ),
            ButtonSegment(
              value: SortOrder.distance,
              label: Text('Nearest'),
            ),
            ButtonSegment(
              value: SortOrder.alphabetical,
              label: Text('A–Z'),
            ),
          ],
          selected: {_effectiveSort},
          // Greyed while filtering: see [_effectiveSort].
          onSelectionChanged: _isFiltering
              ? null
              : (selection) {
                  setState(() {
                    _sortOrder = selection.first;
                    _showAllParishes = false;
                    _applySorting();
                  });
                },
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor:
                widget.accentColor.withValues(alpha: 0.15),
            selectedForegroundColor: widget.accentColor,
            foregroundColor: subtextColor,
            textStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          showSelectedIcon: false,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        // Level with the tabs; when large text stacks them, at their top.
        crossAxisAlignment: context.prefersStackedLayout
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Expanded(
            // Greyed while filtering (see [_effectiveSort]). A tap on them
            // then says why, rather than a standing line of small print.
            child: _isFiltering
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(
                        content: Text(
                            'Sorted nearest first while filtering. '
                            'Clear the filter to change the sort.'),
                        duration: Duration(seconds: 3),
                      )),
                    child: tabs,
                  )
                : tabs,
          ),
          const SizedBox(width: 8),
          button,
        ],
      ),
    );
  }

  /// The filter itself, beneath the row that opened it: when on one line,
  /// where on the next, "near" never split from its field.
  Widget _buildFilterPanel(Color subtextColor) {
    // Fresh, not AppText.bodyLarge().copyWith: see [wordStyle].
    final prose = GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w400, color: subtextColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.accentColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _whenWords(subtextColor),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('near', style: prose),
                const SizedBox(width: 8),
                PlaceWord(
                  parishes: _parishes,
                  place: _place,
                  hasLocation: widget.userLocation != null,
                  onChanged: _setPlace,
                  accent: widget.accentColor,
                  hintColor: subtextColor,
                  compact: true,
                  width: 180,
                ),
              ],
            ),
            if (_planBeyondBulletin)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'From the regular schedule. Bulletins can change it '
                  'closer to the date.',
                  style: GoogleFonts.inter(fontSize: 12, color: subtextColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDarkMode;
    final backgroundColor = isDark ? kBackgroundColorDark : kBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: widget.accentColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.inter(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: widget.accentColor),
            )
          : _filteredParishes.isEmpty
              ? _buildEmptyState()
              : _buildParishList(),
    );
  }

  Widget _buildEmptyState() {
    final isDark = themeNotifier.isDarkMode;
    final subtextColor = isDark ? Colors.white70 : Colors.grey[600];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: isDark ? Colors.white38 : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No parishes found',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: subtextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParishList() {
    final canSortByDistance = _origin != null;
    final isDark = themeNotifier.isDarkMode;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    // A planned place keeps to its own reach ("in Akron" is not "anywhere,
    // Akron first"); near me keeps the whole list, nearest first, as before.
    final place = _place;
    final inPlace = place == null
        ? _filteredParishes
        : _filteredParishes.where((p) {
            final d = _distances[FavoritesManager.keyFor(p)];
            return d != null && d <= place.radiusMiles;
          }).toList();

    // Then the time filters
    final timeFilteredParishes = _hasActiveFilters()
        ? inPlace.where((p) => _matchesTimeFilters(p)).toList()
        : inPlace;

    // Then filter by 2-day limit when in "Soonest" mode (unless showing all)
    final displayedParishes = (_effectiveSort == SortOrder.nearestAndSoonest &&
            !_showAllParishes &&
            !_hasActiveFilters())
        ? timeFilteredParishes.where((p) {
            final minutes = _minutesUntilNext[FavoritesManager.keyFor(p)];
            return minutes != null && minutes <= _twoDaysInMinutes;
          }).toList()
        : timeFilteredParishes;

    final hiddenCount = timeFilteredParishes.length - displayedParishes.length;

    return Column(
      children: [
        // Sort tabs and the Filter button share one line: a closed filter
        // costs no height at all, and the button never moves as the bar
        // opens beneath it.
        _buildSortAndFilterRow(subtextColor, isDark, canSortByDistance),
        if (_filtersOpen) _buildFilterPanel(subtextColor),
        // Parish list
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: displayedParishes.length + (hiddenCount > 0 ? 1 : 0),
            itemBuilder: (context, index) {
              // Show "Show more" button at the end
              if (index == displayedParishes.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAllParishes = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.expand_more,
                            color: widget.accentColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hiddenCount == 1
                                ? 'Show 1 more parish'
                                : 'Show $hiddenCount more parishes',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final parish = displayedParishes[index];
              final parishKey = FavoritesManager.keyFor(parish);
              final distance = _distances[parishKey];
              final minutesUntil = _minutesUntilNext[parishKey];
              return Padding(
                padding: EdgeInsets.only(
                    bottom: index < displayedParishes.length - 1 ? 12 : 0),
                child: _ParishCard(
                  parish: parish,
                  filter: widget.filter,
                  accentColor: widget.accentColor,
                  distance: distance,
                  minutesUntilNext: minutesUntil,
                  showDistance:
                      _effectiveSort == SortOrder.distance && distance != null,
                  // Perpetual chapels are ranked at zero minutes above, which
                  // _formatTimeUntil renders as "Happening now" — exactly right
                  // for something open around the clock.
                  showTimeUntil: _effectiveSort == SortOrder.nearestAndSoonest &&
                      minutesUntil != null,
                  preferUpcoming: _effectiveSort == SortOrder.nearestAndSoonest &&
                      !_hasActiveFilters(),
                  filteredTimes: _hasActiveFilters()
                      ? _entriesMatchingFilters(parish)
                      : null,
                  filteredLabel: _planDate == null
                      ? 'Filtered'
                      : _dayChoiceLabel((filter: DayFilter.any, date: _planDate)),
                  cardColor: cardColor,
                  textColor: textColor,
                  subtextColor: subtextColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParishDetailPage(
                            parish: parish, focus: widget.filter),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ParishCard extends StatelessWidget {
  final Parish parish;
  final ParishFilter filter;
  final Color accentColor;
  final double? distance;
  final int? minutesUntilNext;
  final bool showDistance;
  final bool showTimeUntil;

  /// In Soonest mode the times sample shows the next upcoming day's schedule —
  /// what's left today, else tomorrow's, etc. — so it always agrees with the
  /// "Tomorrow morning" badge. Off whenever day/time filters are active, and in
  /// both A-Z and Nearest, which show the full day-grouped weekly schedule
  /// instead: neither sorts by time, so a card claiming to be about "next"
  /// would be answering a question its own ordering never asked.
  final bool preferUpcoming;

  /// When day/time filters are active, the entries that match them (soonest
  /// first) — shown instead of the weekly sample so the card reflects what
  /// was asked for. Null when no filters are active.
  final List<ScheduleEntry>? filteredTimes;

  /// What the row of [filteredTimes] is headed with: "Filtered", or the
  /// planned date when the list is answering one.
  final String filteredLabel;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final VoidCallback onTap;

  const _ParishCard({
    required this.parish,
    required this.filter,
    required this.accentColor,
    required this.onTap,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
    this.distance,
    this.minutesUntilNext,
    this.showDistance = false,
    this.showTimeUntil = false,
    this.preferUpcoming = false,
    this.filteredTimes,
    this.filteredLabel = 'Filtered',
  });

  /// The trailing pill: distance in Nearest, time-until in Soonest, neither in
  /// A–Z (where the row gets a chevron instead).
  Widget? _badge(Color accentColor) {
    final String label;
    if (showDistance && distance != null) {
      label = '${distance!.toStringAsFixed(1)} mi';
    } else if (showTimeUntil && minutesUntilNext != null) {
      label = _formatTimeUntil(minutesUntilNext!);
    } else {
      return null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge(accentColor);
    final stacked = context.prefersStackedLayout;

    return LayoutBuilder(builder: (context, constraints) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: cardBorderFor(isDark: themeNotifier.isDarkMode),
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
              // Header row.
              //
              // The trailing badge ("2.4 mi", "Tomorrow morning") used to be an
              // unconstrained sibling of the name, so it took whatever width it
              // wanted and left the name — inside an Expanded — with the
              // remainder. At large text sizes that remainder was a couple of
              // characters, and a parish name rendered one letter per line. Now
              // the badge is capped, and past [prefersStackedLayout] it moves
              // under the name entirely rather than competing with it.
              Row(
                children: [
                  ParishGlassHero(
                    seed: parish.parishId ?? parish.name,
                    patron: parish.name,
                    borderRadius: 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: StainedGlassHeader(
                          seed: parish.parishId ?? parish.name,
                          patron: parish.name,
                          overlayDarken: 0.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parish.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${parish.city} ${parish.zipCode}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: subtextColor,
                          ),
                        ),
                        if (badge != null && stacked) ...[
                          const SizedBox(height: 6),
                          Align(alignment: Alignment.centerLeft, child: badge),
                        ],
                      ],
                    ),
                  ),
                  if (badge != null && !stacked)
                    // A third of the row at most: enough for "Tomorrow morning"
                    // to wrap onto two lines, never enough to starve the name.
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: constraints.maxWidth / 3),
                      child: badge,
                    )
                  else if (badge == null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: subtextColor,
                    ),
                ],
              ),
              // Times section based on filter
              if (_getTimesToShow().isNotEmpty ||
                  (filter == ParishFilter.adoration &&
                      parish.adorationIsPerpetual)) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: subtextColor.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                _buildTimesSection(),
              ],
            ],
          ),
        ),
      );
    });
  }

  List<ScheduleEntry> _getTimesToShow() {
    switch (filter) {
      case ParishFilter.massTimes:
        return parish.massTimes;
      case ParishFilter.confession:
        return parish.confTimes;
      case ParishFilter.adoration:
        return parish.adoration;
      case ParishFilter.all:
        return parish.massTimes.isNotEmpty
            ? parish.massTimes
            : parish.confTimes;
    }
  }

  /// Whether an in-progress window counts as upcoming — mirrors the page's
  /// `_countInProgressFor` so the sample agrees with the "in Xh" chip.
  bool get _countInProgress {
    switch (filter) {
      case ParishFilter.massTimes:
        return kCountMassInProgress;
      case ParishFilter.confession:
      case ParishFilter.adoration:
        return true;
      case ParishFilter.all:
        return parish.massTimes.isEmpty;
    }
  }

  /// The next day with something upcoming: the soonest occurrence plus every
  /// other entry falling on that same date, sorted by occurrence, with a label
  /// ("Today" / "Tomorrow" / weekday). Null when nothing is upcoming.
  ({List<ScheduleEntry> entries, String label})? _nextUpcomingDay(
      List<ScheduleEntry> times) {
    final now = DateTime.now();
    final soonest =
        ScheduleParser.findNextOccurrence(times, now, _countInProgress);
    if (soonest == null) return null;
    final target = soonest.nextOccurrence(now, _countInProgress);
    final entries = times.where((e) {
      // findNextOccurrence already stepped over cancelled slots; this sweep
      // for everything else on that date has to do the same, or the "Today"
      // sample lists a Mass that isn't being said.
      if (e.cancelled || e.isPast(now, _countInProgress)) return false;
      final o = e.nextOccurrence(now, _countInProgress);
      return o.year == target.year &&
          o.month == target.month &&
          o.day == target.day;
    }).toList()
      ..sort((a, b) => a
          .nextOccurrence(now, _countInProgress)
          .compareTo(b.nextOccurrence(now, _countInProgress)));
    final today = DateTime(now.year, now.month, now.day);
    final daysUntil = DateTime(target.year, target.month, target.day)
        .difference(today)
        .inDays;
    final label = daysUntil == 0
        ? 'Today'
        : daysUntil == 1
            ? 'Tomorrow'
            : soonest.dayName;
    return (entries: entries, label: label);
  }

  /// Time text for entry [i] of a day group, dropping its meridiem when the
  /// following time shares it ("7:30 · 9:00 · 11:00 AM").
  String _groupedTime(List<ScheduleEntry> entries, int i) {
    final e = entries[i];
    final label = e.timeLabel;
    if (e.hasRange) return label;
    // A struck-out time has "CANCELLED" printed after it, which breaks the run
    // the shared meridiem depends on: "7:30 CANCELLED · 9:00 AM" no longer
    // reads as one morning list, so this time keeps its own AM/PM.
    if (e.cancelled) return label;
    if (i + 1 < entries.length) {
      final n = entries[i + 1];
      if (!n.hasRange && (e.hour >= 12) == (n.hour >= 12)) {
        return label.replaceFirst(RegExp(r'\s?(AM|PM)$'), '');
      }
    }
    return label;
  }

  /// One chip per day-run: "Sun 7:30 · 9:00 · 11:00 AM".
  /// Matches the language badge's weight and size — both are the same kind of
  /// mark: a small qualifier on a time.
  TextStyle get _ordinalSpanStyle => GoogleFonts.inter(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: accentColor,
        letterSpacing: 0.5,
      );

  /// Same mark, in the error hue — it contradicts the time it follows rather
  /// than qualifying it. See CancelledBadge for the full-size version.
  TextStyle get _cancelledSpanStyle => _ordinalSpanStyle.copyWith(
        color: errorAccentFor(isDark: themeNotifier.isDarkMode),
      );

  Widget _groupChip(ScheduleDayGroup group) {
    final base = GoogleFonts.inter(fontSize: 12, color: textColor);
    final spans = <TextSpan>[
      TextSpan(
        text: '${group.label} ',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: subtextColor,
        ),
      ),
    ];
    for (var i = 0; i < group.entries.length; i++) {
      final e = group.entries[i];
      if (i > 0) spans.add(TextSpan(text: ' · ', style: base));
      // These chips are the parish's standing schedule, so a slot suspended
      // this week keeps its place and is struck out — dropping it would say
      // the parish doesn't have a Monday Mass at all.
      spans.add(TextSpan(
        text: _groupedTime(group.entries, i),
        style: e.cancelled
            ? base.copyWith(
                decoration: TextDecoration.lineThrough,
                decorationColor: textColor)
            : base,
      ));
      if (e.cancelled) {
        spans.add(TextSpan(text: ' CANCELLED', style: _cancelledSpanStyle));
      }
      // These chips are the *standing weekly schedule* with no note beside
      // them, so a monthly slot would otherwise read as happening every week.
      // A day group can mix rules (groupByDay only keeps whole days apart), so
      // the marker rides on the time, not the day label.
      final ordinal = e.ordinalShortLabel;
      if (ordinal != null) {
        spans.add(TextSpan(text: ' $ordinal', style: _ordinalSpanStyle));
      }
      final badge = filter == ParishFilter.adoration ? null : e.languageBadge;
      if (badge != null) {
        spans.add(TextSpan(
          text: ' $badge',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: accentColor,
            letterSpacing: 0.5,
          ),
        ));
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: subtextColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(TextSpan(children: spans)),
    );
  }

  Widget _buildTimesSection() {
    var times = _getTimesToShow();
    String? dayLabel;
    var showingFiltered = false;
    if (filteredTimes != null && filteredTimes!.isNotEmpty) {
      times = filteredTimes!;
      showingFiltered = true;
    } else if (preferUpcoming) {
      final upcoming = _nextUpcomingDay(times);
      if (upcoming != null && upcoming.entries.isNotEmpty) {
        times = upcoming.entries;
        dayLabel = upcoming.label;
      }
    }

    IconData icon;
    switch (filter) {
      case ParishFilter.confession:
        icon = Icons.favorite_outline;
        break;
      case ParishFilter.adoration:
        icon = Icons.brightness_5;
        break;
      default:
        icon = Icons.access_time;
    }

    // The page header already names the schedule, so the per-card row carries
    // only qualifiers. Null hides the row entirely (A-Z, where the grouped
    // chips carry their own days).
    String? label;
    if (showingFiltered) {
      label = filteredLabel;
    } else if (dayLabel != null) {
      // Only Soonest reaches here, and it carries the "Tomorrow morning" badge
      // already, so [showTimeUntil] is the normal path; the [dayLabel] fallback
      // covers a card whose minutes-until never resolved. [times] is the
      // upcoming day's entries, so it answers the only question the label
      // needs: is there one Mass that day, or several?
      final single = times.length == 1;
      label = showTimeUntil
          ? switch (filter) {
              ParishFilter.confession => 'Next Confession',
              ParishFilter.adoration => 'Next Adoration',
              _ => single ? 'Next Mass' : 'Next Masses',
            }
          : dayLabel;
    }

    // Perpetual adoration: show a single descriptive chip instead of times.
    final isPerpetual =
        filter == ParishFilter.adoration && parish.adorationIsPerpetual;

    // Day-focused and filtered samples: up to 3 per-entry chips. The A-Z and
    // Nearest views instead show the whole schedule as day-grouped chips.
    final grouped = !showingFiltered && dayLabel == null;
    final displayTimes =
        grouped ? const <ScheduleEntry>[] : times.take(3).toList();
    final hasMore = !grouped && times.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (isPerpetual)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Perpetual (24/7)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            if (grouped)
              ...ScheduleParser.groupByDay(times).map(_groupChip)
            else ...[
              ...displayTimes.map((time) {
                final badge = filter == ParishFilter.adoration
                    ? null
                    : time.languageBadge;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: subtextColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dayLabel != null ? time.timeLabel : time.display,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                      if (time.ordinalShortLabel != null) ...[
                        const SizedBox(width: 4),
                        Text(time.ordinalShortLabel!, style: _ordinalSpanStyle),
                      ],
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        LanguageBadge(
                            label: badge,
                            color: accentColor,
                            tooltip: time.language),
                      ],
                    ],
                  ),
                );
              }),
              if (hasMore)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${times.length - 3} more',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }

  /// Returns a human-friendly time descriptor
  String _formatTimeUntil(int minutes) {
    final now = DateTime.now();
    final eventTime = now.add(Duration(minutes: minutes));

    // Check if event is today, tomorrow, or day after
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(eventTime.year, eventTime.month, eventTime.day);
    final daysUntil = eventDay.difference(today).inDays;

    // Get time of day descriptor
    final hour = eventTime.hour;
    String timeOfDay;
    if (hour >= 5 && hour < 12) {
      timeOfDay = 'morning';
    } else if (hour >= 12 && hour < 17) {
      timeOfDay = 'afternoon';
    } else if (hour >= 17 && hour < 21) {
      timeOfDay = 'evening';
    } else {
      timeOfDay = 'tonight';
    }

    if (minutes <= 0) {
      // Negative means a ranged entry (adoration/confession) is underway.
      return 'Happening now';
    } else if (minutes <= 30) {
      return 'Starting soon';
    } else if (minutes <= 60) {
      return 'Within the hour';
    } else if (daysUntil == 0) {
      // Today - handle "tonight" specially (not "This tonight")
      if (timeOfDay == 'tonight') {
        return 'Tonight';
      }
      return 'This $timeOfDay';
    } else if (daysUntil == 1) {
      // Tomorrow with time of day
      if (hour >= 5 && hour < 12) {
        return 'Tomorrow morning';
      } else if (hour >= 12 && hour < 17) {
        return 'Tomorrow afternoon';
      } else if (hour >= 17 && hour < 21) {
        return 'Tomorrow evening';
      } else {
        return 'Tomorrow night';
      }
    } else if (daysUntil == 2) {
      return 'In 2 days';
    } else {
      return 'In $daysUntil days';
    }
  }
}
