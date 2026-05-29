// lib/services/liturgical_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Where a [LiturgicalDay] came from — the offline computed calendar, or the
/// remote API. Surfaced in the UI as a small badge while testing.
enum LiturgicalSource { local, api }

/// The liturgical context for a single day: color, season, the day's title,
/// and an optional memorial/feast note.
class LiturgicalDay {
  final Color color;
  final String colorName;
  final String season;
  final String title;
  final String? memorial;
  final LiturgicalSource source;

  const LiturgicalDay({
    required this.color,
    required this.colorName,
    required this.season,
    required this.title,
    this.memorial,
    required this.source,
  });
}

/// Provides the day's liturgical info in two tiers:
///
/// 1. [localToday] — computed offline from the date (Computus → season + color +
///    a generic title). Always available, instant, deterministic.
/// 2. [fetchEnriched] — the precise celebration title / memorial / color from
///    the free [calapi.inadiutorium.cz](http://calapi.inadiutorium.cz) general
///    calendar, cached per-day. Returns null on any failure; callers keep the
///    local baseline.
class LiturgicalService {
  // NOTE: plain HTTP, intentionally. calapi.inadiutorium.cz serves HTTPS only
  // over IPv6; its IPv4 address answers only on port 80 (HTTPS/443 is refused),
  // so https:// fails on every IPv4-only network. The data is public,
  // non-sensitive liturgical calendar info, so cleartext is acceptable here.
  // Android cleartext is allowed for just this domain via
  // android/app/src/main/res/xml/network_security_config.xml.
  static const _base =
      'http://calapi.inadiutorium.cz/api/v0/en/calendars/general-en';
  static const _cachePrefix = 'liturgy_';

  LiturgicalDay? _enriched;

  // ---- Tier 1: local computation -------------------------------------------

  /// Liturgical season + color + a generic title for [date], computed offline.
  LiturgicalDay localToday([DateTime? date]) {
    final now = date ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekday = _weekdayName(today.weekday);

    final easter = _easter(today.year);
    final ashWed = easter.subtract(const Duration(days: 46));
    final pentecost = easter.add(const Duration(days: 49));
    final goodFriday = easter.subtract(const Duration(days: 2));
    final palmSunday = easter.subtract(const Duration(days: 7));

    // Advent / Christmas can straddle the year boundary, so consider both the
    // current year's Advent and the previous year's Christmas season.
    final firstAdvent = _firstAdvent(today.year);
    final christmasStart = DateTime(today.year, 12, 25);
    final baptismThisYear = _baptismOfTheLord(today.year); // for Jan dates
    final prevChristmasStart = DateTime(today.year - 1, 12, 25);

    String season;
    Color color;
    String colorName;
    String of;

    bool inRange(DateTime d, DateTime start, DateTime end) =>
        !d.isBefore(start) && !d.isAfter(end);

    if (inRange(today, firstAdvent, DateTime(today.year, 12, 24))) {
      season = 'Advent';
      (color, colorName) = (const Color(0xFF6A1B9A), 'Violet');
      of = 'of Advent';
    } else if (inRange(today, christmasStart, _baptismOfTheLord(today.year + 1)) ||
        inRange(today, prevChristmasStart, baptismThisYear)) {
      season = 'Christmas';
      (color, colorName) = (const Color(0xFFE6D9A8), 'White');
      of = 'of the Christmas Season';
    } else if (inRange(today, ashWed, easter.subtract(const Duration(days: 1)))) {
      season = 'Lent';
      if (_sameDay(today, goodFriday) || _sameDay(today, palmSunday)) {
        (color, colorName) = (const Color(0xFFC62828), 'Red');
      } else {
        (color, colorName) = (const Color(0xFF6A1B9A), 'Violet');
      }
      of = 'of Lent';
    } else if (inRange(today, easter, pentecost)) {
      season = 'Easter';
      if (_sameDay(today, pentecost)) {
        (color, colorName) = (const Color(0xFFC62828), 'Red');
      } else {
        (color, colorName) = (const Color(0xFFE6D9A8), 'White');
      }
      of = 'of Easter';
    } else {
      season = 'Ordinary Time';
      (color, colorName) = (const Color(0xFF2E7D32), 'Green');
      of = 'in Ordinary Time';
    }

    return LiturgicalDay(
      color: color,
      colorName: colorName,
      season: season,
      title: '$weekday $of',
      source: LiturgicalSource.local,
    );
  }

  // ---- Tier 2: network enrichment ------------------------------------------

  /// Returns the precise celebration for today from calapi, or null on failure.
  Future<LiturgicalDay?> fetchEnriched() async {
    if (_enriched != null) return _enriched;

    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getString('$_cachePrefix$dateKey');
    if (cached != null) {
      final parsed = _parse(cached);
      if (parsed != null) {
        _enriched = parsed;
        return _enriched;
      }
    }

    try {
      final uri = Uri.parse('$_base/${now.year}/${now.month}/${now.day}');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final parsed = _parse(res.body);
        if (parsed != null) {
          _enriched = parsed;
          await _pruneAndCache(prefs, dateKey, res.body);
          return _enriched;
        }
      }
    } catch (e) {
      // Best-effort: the local baseline already covers season + color. (Note:
      // calapi.inadiutorium.cz serves HTTPS over IPv6 only — enrichment is a
      // no-op on IPv6-less networks, which is fine.)
      debugPrint('LiturgicalService: enrichment unavailable ($e)');
    }
    return null;
  }

  Future<void> _pruneAndCache(
      SharedPreferences prefs, String dateKey, String body) async {
    for (final k in prefs.getKeys()) {
      if (k.startsWith(_cachePrefix) && k != '$_cachePrefix$dateKey') {
        await prefs.remove(k);
      }
    }
    await prefs.setString('$_cachePrefix$dateKey', body);
  }

  LiturgicalDay? _parse(String body) {
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      final celebrations = (data['celebrations'] as List?) ?? const [];
      if (celebrations.isEmpty) return null;

      final primary = celebrations.first as Map<String, dynamic>;
      final colour = (primary['colour'] as String?) ?? 'green';
      final rank = (primary['rank'] as String?) ?? 'ferial';
      final title = (primary['title'] as String?) ?? 'Today';

      String? memorial;
      if (celebrations.length > 1) {
        memorial = celebrations
            .skip(1)
            .map((c) => (c as Map<String, dynamic>)['title'] as String?)
            .whereType<String>()
            .join(' · ');
      } else if (rank.toLowerCase() != 'ferial' &&
          rank.toLowerCase() != 'primary_liturgical_days') {
        memorial = _titleCase(rank.replaceAll('_', ' '));
      }
      if (memorial != null && memorial.isEmpty) memorial = null;

      final (color, colorName) = _colorFor(colour);
      return LiturgicalDay(
        color: color,
        colorName: colorName,
        season: _seasonName((data['season'] as String?) ?? ''),
        title: title,
        memorial: memorial,
        source: LiturgicalSource.api,
      );
    } catch (_) {
      return null;
    }
  }

  // ---- Date math -----------------------------------------------------------

  /// Easter Sunday (Gregorian) via the Anonymous/Meeus Computus algorithm.
  DateTime _easter(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  /// First Sunday of Advent: the Sunday three weeks before the last Sunday
  /// on or before Christmas Eve.
  DateTime _firstAdvent(int year) {
    final christmasEve = DateTime(year, 12, 24);
    // Last Sunday on or before Dec 24 = the Fourth Sunday of Advent.
    final fourth =
        christmasEve.subtract(Duration(days: christmasEve.weekday % 7));
    return fourth.subtract(const Duration(days: 21));
  }

  /// Baptism of the Lord ≈ first Sunday after Epiphany (Jan 6) — ends the
  /// Christmas season. Approximation suitable for season coloring.
  DateTime _baptismOfTheLord(int year) {
    final epiphany = DateTime(year, 1, 6);
    final daysToSunday = (7 - epiphany.weekday % 7) % 7;
    final next = daysToSunday == 0 ? 7 : daysToSunday;
    return epiphany.add(Duration(days: next));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekdayName(int weekday) {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return names[weekday - 1];
  }

  // ---- Mapping helpers -----------------------------------------------------

  (Color, String) _colorFor(String colour) {
    switch (colour.toLowerCase()) {
      case 'violet':
      case 'purple':
        return (const Color(0xFF6A1B9A), 'Violet');
      case 'white':
        return (const Color(0xFFE6D9A8), 'White');
      case 'red':
        return (const Color(0xFFC62828), 'Red');
      case 'rose':
      case 'pink':
        return (const Color(0xFFE57399), 'Rose');
      case 'black':
        return (const Color(0xFF37474F), 'Black');
      case 'green':
      default:
        return (const Color(0xFF2E7D32), 'Green');
    }
  }

  String _seasonName(String season) {
    switch (season.toLowerCase()) {
      case 'advent':
        return 'Advent';
      case 'christmas':
        return 'Christmas';
      case 'lent':
        return 'Lent';
      case 'easter':
        return 'Easter';
      case 'ordinary':
        return 'Ordinary Time';
      default:
        return season.isEmpty ? '' : _titleCase(season);
    }
  }

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Global singleton.
final liturgicalService = LiturgicalService();
