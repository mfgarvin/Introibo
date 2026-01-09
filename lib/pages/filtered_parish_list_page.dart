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
  late SortOrder _sortOrder;

  @override
  void initState() {
    super.initState();
    // Set default sort order based on location availability
    _sortOrder = widget.userLocation != null
        ? SortOrder.nearestAndSoonest
        : SortOrder.alphabetical;
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

  /// Calculate composite score combining distance and time
  /// Lower score = better (closer and sooner)
  double _calculateCompositeScore(Parish parish) {
    final distance = _distances[parish.name] ?? double.infinity;
    final minutes = _minutesUntilNext[parish.name] ?? double.infinity.toInt();

    // If either is missing, return infinity
    if (distance == double.infinity || minutes == double.infinity.toInt()) {
      return double.infinity;
    }

    // Normalize both factors:
    // - Distance: each mile counts as ~15 minutes of "cost"
    // - Time: minutes until event
    // This means a parish 2 miles away with event in 30 mins = score ~60
    // vs a parish 1 mile away with event in 60 mins = score ~75
    final distanceWeight = distance * 15.0;
    final timeWeight = minutes.toDouble();

    // Weighted average: 40% distance, 60% time
    return (distanceWeight * 0.4) + (timeWeight * 0.6);
  }

  void _toggleSortOrder() {
    setState(() {
      final hasLocation = widget.userLocation != null;

      // Cycle through available sort modes
      if (hasLocation) {
        // Full cycle: nearestAndSoonest -> distance -> alphabetical -> nearestAndSoonest
        switch (_sortOrder) {
          case SortOrder.nearestAndSoonest:
            _sortOrder = SortOrder.distance;
            break;
          case SortOrder.distance:
            _sortOrder = SortOrder.alphabetical;
            break;
          case SortOrder.alphabetical:
            _sortOrder = SortOrder.nearestAndSoonest;
            break;
        }
      } else {
        // Without location, only alphabetical sort is available
        _sortOrder = SortOrder.alphabetical;
      }
      _applySorting();
    });
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
                  '${_filteredParishes.length} parishes',
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                  ),
                ),
              ),
              const Spacer(),
              // Sort toggle button (always visible)
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
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: _filteredParishes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final parish = _filteredParishes[index];
              final distance = _distances[parish.name];
              final minutesUntil = _minutesUntilNext[parish.name];
              return _ParishCard(
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

  String _formatTimeUntil(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else if (minutes < 1440) {
      // Less than 24 hours
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours hr';
      }
      return '${hours}h ${remainingMinutes}m';
    } else {
      // Days
      final days = (minutes / 1440).floor();
      final hours = ((minutes % 1440) / 60).floor();
      if (hours == 0) {
        return '$days day${days > 1 ? 's' : ''}';
      }
      return '${days}d ${hours}h';
    }
  }
}
