import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/parish.dart';
import '../services/parish_service.dart';
import '../utils/schedule_parser.dart';
import '../main.dart' show kBackgroundColor, kBackgroundColorDark, kCardColor, kCardColorDark, themeNotifier;
import 'parish_detail_page.dart';

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
  thisWeek,
}

enum TimeOfDayFilter {
  any,
  morning,    // 5am-12pm
  afternoon,  // 12pm-5pm
  evening,    // 5pm-9pm
  night,      // 9pm-5am
}

class FilteredParishListPage extends StatefulWidget {
  final ParishFilter filter;
  final String title;
  final Color accentColor;
  final LatLng? userLocation;

  const FilteredParishListPage({
    Key? key,
    required this.filter,
    required this.title,
    required this.accentColor,
    this.userLocation,
  }) : super(key: key);

  @override
  State<FilteredParishListPage> createState() => _FilteredParishListPageState();
}

class _FilteredParishListPageState extends State<FilteredParishListPage> {
  List<Parish> _parishes = [];
  List<Parish> _filteredParishes = [];
  Map<String, double> _distances = {};
  Map<String, int> _minutesUntilNext = {};
  bool _isLoading = true;
  SortOrder _sortOrder = SortOrder.nearestAndSoonest;
  bool _showAllParishes = false;
  DayFilter _dayFilter = DayFilter.any;
  TimeOfDayFilter _timeOfDayFilter = TimeOfDayFilter.any;
  Set<int> _selectedWeekdays = {}; // 1=Monday, 7=Sunday

  /// 2 days in minutes
  static const int _twoDaysInMinutes = 2880;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
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
    if (widget.userLocation == null) return;

    for (final parish in _parishes) {
      if (parish.latitude != null && parish.longitude != null) {
        _distances[parish.name] = _calculateDistance(
          widget.userLocation!.latitude,
          widget.userLocation!.longitude,
          parish.latitude!,
          parish.longitude!,
        );
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
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

  void _calculateNextOccurrences() {
    for (final parish in _parishes) {
      List<String> scheduleToCheck = [];

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
          scheduleToCheck = parish.massTimes.isNotEmpty
              ? parish.massTimes
              : parish.confTimes;
          break;
      }

      // Calculate minutes until next occurrence
      final minutes = ScheduleParser.getMinutesUntilNext(scheduleToCheck);
      if (minutes != null) {
        _minutesUntilNext[parish.name] = minutes;
      }
    }
  }

  void _applyFilter() {
    switch (widget.filter) {
      case ParishFilter.massTimes:
        _filteredParishes = _parishes
            .where((p) => p.massTimes.isNotEmpty)
            .toList();
        break;
      case ParishFilter.confession:
        _filteredParishes = _parishes
            .where((p) => p.confTimes.isNotEmpty)
            .toList();
        break;
      case ParishFilter.adoration:
        _filteredParishes = _parishes
            .where((p) => p.adoration.isNotEmpty)
            .toList();
        break;
      case ParishFilter.all:
        _filteredParishes = List.from(_parishes);
        break;
    }
    _applySorting();
  }

  void _applySorting() {
    if (_sortOrder == SortOrder.distance && widget.userLocation != null) {
      _filteredParishes.sort((a, b) {
        final distA = _distances[a.name] ?? double.infinity;
        final distB = _distances[b.name] ?? double.infinity;
        return distA.compareTo(distB);
      });
    } else if (_sortOrder == SortOrder.nearestAndSoonest && widget.userLocation != null) {
      // Composite score: combine distance and time
      _filteredParishes.sort((a, b) {
        final scoreA = _calculateCompositeScore(a);
        final scoreB = _calculateCompositeScore(b);
        return scoreA.compareTo(scoreB);
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
    final distance = _distances[parish.name];
    final minutes = _minutesUntilNext[parish.name];

    // If either is missing, return infinity
    if (distance == null || minutes == null) {
      return double.infinity;
    }

    // Distance cap scoring:
    // - Within 10 miles: score = minutes (0-9999 range, sorted by time)
    // - Beyond 10 miles: score = 10000 + distance (always after nearby parishes)
    if (distance <= _distanceCapMiles) {
      return minutes.toDouble();
    } else {
      return 10000.0 + distance;
    }
  }

  void _toggleSortOrder() {
    setState(() {
      // Cycle through: nearestAndSoonest -> distance -> alphabetical -> nearestAndSoonest
      if (_sortOrder == SortOrder.nearestAndSoonest) {
        _sortOrder = SortOrder.distance;
      } else if (_sortOrder == SortOrder.distance) {
        _sortOrder = SortOrder.alphabetical;
      } else {
        _sortOrder = SortOrder.nearestAndSoonest;
      }
      // Reset "show all" when switching sort modes
      _showAllParishes = false;
      _applySorting();
    });
  }

  bool _hasActiveFilters() {
    return _dayFilter != DayFilter.any ||
        _timeOfDayFilter != TimeOfDayFilter.any ||
        _selectedWeekdays.isNotEmpty;
  }

  /// Check if a parish has any schedule entries matching the current filters
  bool _matchesTimeFilters(Parish parish) {
    if (!_hasActiveFilters()) return true;

    // Get the schedule based on filter type
    List<String> scheduleStrings;
    switch (widget.filter) {
      case ParishFilter.massTimes:
        scheduleStrings = parish.massTimes;
        break;
      case ParishFilter.confession:
        scheduleStrings = parish.confTimes;
        break;
      case ParishFilter.adoration:
        scheduleStrings = parish.adoration;
        break;
      case ParishFilter.all:
        scheduleStrings = [...parish.massTimes, ...parish.confTimes];
        break;
    }

    final entries = ScheduleParser.parseSchedule(scheduleStrings);
    if (entries.isEmpty) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final entry in entries) {
      // Check weekday filter
      if (_selectedWeekdays.isNotEmpty && !_selectedWeekdays.contains(entry.dayOfWeek)) {
        continue;
      }

      // Check time of day filter
      if (_timeOfDayFilter != TimeOfDayFilter.any) {
        final hour = entry.hour;
        bool matchesTime = false;
        switch (_timeOfDayFilter) {
          case TimeOfDayFilter.morning:
            matchesTime = hour >= 5 && hour < 12;
            break;
          case TimeOfDayFilter.afternoon:
            matchesTime = hour >= 12 && hour < 17;
            break;
          case TimeOfDayFilter.evening:
            matchesTime = hour >= 17 && hour < 21;
            break;
          case TimeOfDayFilter.night:
            matchesTime = hour >= 21 || hour < 5;
            break;
          case TimeOfDayFilter.any:
            matchesTime = true;
            break;
        }
        if (!matchesTime) continue;
      }

      // Check day filter
      if (_dayFilter != DayFilter.any) {
        final nextOccurrence = entry.nextOccurrence(now);
        final eventDay = DateTime(nextOccurrence.year, nextOccurrence.month, nextOccurrence.day);
        final daysUntil = eventDay.difference(today).inDays;

        bool matchesDay = false;
        switch (_dayFilter) {
          case DayFilter.today:
            matchesDay = daysUntil == 0;
            break;
          case DayFilter.tomorrow:
            matchesDay = daysUntil == 1;
            break;
          case DayFilter.thisWeek:
            matchesDay = daysUntil <= 7;
            break;
          case DayFilter.any:
            matchesDay = true;
            break;
        }
        if (!matchesDay) continue;
      }

      // If we get here, this entry matches all filters
      return true;
    }

    return false;
  }

  void _showFilterSheet() {
    final isDark = themeNotifier.isDarkMode;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.filter_list, color: widget.accentColor),
                  const SizedBox(width: 8),
                  Text(
                    'Filter by Time',
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  if (_hasActiveFilters())
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          _dayFilter = DayFilter.any;
                          _timeOfDayFilter = TimeOfDayFilter.any;
                          _selectedWeekdays = {};
                        });
                        setState(() {});
                      },
                      child: Text(
                        'Clear',
                        style: GoogleFonts.lato(color: widget.accentColor),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Day filter
              Text(
                'When',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subtextColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildFilterChip('Any day', _dayFilter == DayFilter.any, () {
                    setSheetState(() => _dayFilter = DayFilter.any);
                    setState(() {});
                  }, cardColor, textColor, subtextColor),
                  _buildFilterChip('Today', _dayFilter == DayFilter.today, () {
                    setSheetState(() => _dayFilter = DayFilter.today);
                    setState(() {});
                  }, cardColor, textColor, subtextColor),
                  _buildFilterChip('Tomorrow', _dayFilter == DayFilter.tomorrow, () {
                    setSheetState(() => _dayFilter = DayFilter.tomorrow);
                    setState(() {});
                  }, cardColor, textColor, subtextColor),
                  _buildFilterChip('This week', _dayFilter == DayFilter.thisWeek, () {
                    setSheetState(() => _dayFilter = DayFilter.thisWeek);
                    setState(() {});
                  }, cardColor, textColor, subtextColor),
                ],
              ),
              const SizedBox(height: 16),

              // Time of day filter
              Text(
                'Time of day',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subtextColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildFilterChip('Any time', _timeOfDayFilter == TimeOfDayFilter.any, () {
                    setSheetState(() => _timeOfDayFilter = TimeOfDayFilter.any);
                    setState(() {});
                  }, cardColor, textColor, subtextColor),
                  _buildFilterChip('Morning', _timeOfDayFilter == TimeOfDayFilter.morning, () {
                    setSheetState(() => _timeOfDayFilter = TimeOfDayFilter.morning);
                    setState(() {});
                  }, cardColor, textColor, subtextColor),
                  _buildFilterChip('Afternoon', _timeOfDayFilter == TimeOfDayFilter.afternoon, () {
                    setSheetState(() => _timeOfDayFilter = TimeOfDayFilter.afternoon);
                    setState(() {});
                  }, cardColor, textColor, subtextColor),
                  _buildFilterChip('Evening', _timeOfDayFilter == TimeOfDayFilter.evening, () {
                    setSheetState(() => _timeOfDayFilter = TimeOfDayFilter.evening);
                    setState(() {});
                  }, cardColor, textColor, subtextColor),
                ],
              ),
              const SizedBox(height: 16),

              // Weekday filter
              Text(
                'Day of week',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subtextColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final day in [
                    (7, 'Sun'),
                    (1, 'Mon'),
                    (2, 'Tue'),
                    (3, 'Wed'),
                    (4, 'Thu'),
                    (5, 'Fri'),
                    (6, 'Sat'),
                  ])
                    _buildFilterChip(
                      day.$2,
                      _selectedWeekdays.contains(day.$1),
                      () {
                        setSheetState(() {
                          if (_selectedWeekdays.contains(day.$1)) {
                            _selectedWeekdays.remove(day.$1);
                          } else {
                            _selectedWeekdays.add(day.$1);
                          }
                        });
                        setState(() {});
                      },
                      cardColor,
                      textColor,
                      subtextColor,
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Done button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.lato(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool selected,
    VoidCallback onTap,
    Color cardColor,
    Color textColor,
    Color subtextColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? widget.accentColor : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? widget.accentColor : subtextColor.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }

  IconData _getSortIcon() {
    switch (_sortOrder) {
      case SortOrder.nearestAndSoonest:
        return Icons.schedule;
      case SortOrder.distance:
        return Icons.near_me;
      case SortOrder.alphabetical:
        return Icons.sort_by_alpha;
    }
  }

  String _getSortLabel() {
    switch (_sortOrder) {
      case SortOrder.nearestAndSoonest:
        return 'Soonest';
      case SortOrder.distance:
        return 'Nearest';
      case SortOrder.alphabetical:
        return 'A-Z';
    }
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
          style: GoogleFonts.lato(
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
            style: GoogleFonts.lato(
              fontSize: 18,
              color: subtextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParishList() {
    final canSortByDistance = widget.userLocation != null;
    final isDark = themeNotifier.isDarkMode;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    // Apply time filters first
    final timeFilteredParishes = _hasActiveFilters()
        ? _filteredParishes.where((p) => _matchesTimeFilters(p)).toList()
        : _filteredParishes;

    // Then filter by 2-day limit when in "Soonest" mode (unless showing all)
    final displayedParishes = (_sortOrder == SortOrder.nearestAndSoonest && !_showAllParishes && !_hasActiveFilters())
        ? timeFilteredParishes.where((p) {
            final minutes = _minutesUntilNext[p.name];
            return minutes != null && minutes <= _twoDaysInMinutes;
          }).toList()
        : timeFilteredParishes;

    final hiddenCount = timeFilteredParishes.length - displayedParishes.length;

    return Column(
      children: [
        // Results count and sort toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${displayedParishes.length} parishes',
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                  ),
                ),
              ),
              const Spacer(),
              // Filter button
              GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _hasActiveFilters()
                        ? widget.accentColor.withOpacity(0.1)
                        : (isDark ? Colors.white : Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: _hasActiveFilters()
                        ? Border.all(color: widget.accentColor.withOpacity(0.5))
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list,
                        size: 14,
                        color: _hasActiveFilters() ? widget.accentColor : subtextColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Filter',
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _hasActiveFilters() ? widget.accentColor : subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Sort toggle button
              if (canSortByDistance)
                GestureDetector(
                  onTap: _toggleSortOrder,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.grey).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getSortIcon(),
                          size: 14,
                          color: subtextColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getSortLabel(),
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
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
                            'Show $hiddenCount more parishes',
                            style: GoogleFonts.lato(
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
              final distance = _distances[parish.name];
              final minutesUntil = _minutesUntilNext[parish.name];
              return Padding(
                padding: EdgeInsets.only(bottom: index < displayedParishes.length - 1 ? 12 : 0),
                child: _ParishCard(
                  parish: parish,
                  filter: widget.filter,
                  accentColor: widget.accentColor,
                  distance: distance,
                  minutesUntilNext: minutesUntil,
                  showDistance: _sortOrder == SortOrder.distance && distance != null,
                  showTimeUntil: _sortOrder == SortOrder.nearestAndSoonest && minutesUntil != null,
                  cardColor: cardColor,
                  textColor: textColor,
                  subtextColor: subtextColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParishDetailPage(parish: parish),
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
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.church,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parish.name,
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${parish.city} ${parish.zipCode}',
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showDistance && distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${distance!.toStringAsFixed(1)} mi',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  )
                else if (showTimeUntil && minutesUntilNext != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatTimeUntil(minutesUntilNext!),
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: subtextColor,
                  ),
              ],
            ),
            // Times section based on filter
            if (_getTimesToShow().isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: subtextColor.withOpacity(0.2)),
              const SizedBox(height: 12),
              _buildTimesSection(),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _getTimesToShow() {
    switch (filter) {
      case ParishFilter.massTimes:
        return parish.massTimes;
      case ParishFilter.confession:
        return parish.confTimes;
      case ParishFilter.adoration:
        return parish.adoration;
      case ParishFilter.all:
        return parish.massTimes.isNotEmpty ? parish.massTimes : parish.confTimes;
    }
  }

  Widget _buildTimesSection() {
    final times = _getTimesToShow();
    IconData icon;
    String label;
    switch (filter) {
      case ParishFilter.confession:
        icon = Icons.favorite_outline;
        label = 'Confession';
        break;
      case ParishFilter.adoration:
        icon = Icons.brightness_5;
        label = 'Adoration';
        break;
      default:
        icon = Icons.access_time;
        label = 'Mass Times';
    }

    // Show up to 3 times
    final displayTimes = times.take(3).toList();
    final hasMore = times.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: accentColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ...displayTimes.map((time) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: subtextColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    time,
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: textColor,
                    ),
                  ),
                )),
            if (hasMore)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${times.length - 3} more',
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
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

    if (minutes <= 30) {
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
