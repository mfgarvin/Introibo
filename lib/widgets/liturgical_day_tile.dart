import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/liturgical_service.dart';

/// Tile for the day's liturgical context. Color swatch + season + the day's
/// title + optional memorial + a button that opens the USCCB daily readings.
///
/// Shows a locally-computed season + color immediately (offline, deterministic),
/// then asynchronously enriches the title/memorial from [liturgicalService]'s
/// calendar API when it's reachable. Never renders empty.
class LiturgicalDayTile extends StatefulWidget {
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;

  const LiturgicalDayTile({
    super.key,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
  });

  static const _readingsUrl = 'https://bible.usccb.org/daily-bible-reading';

  @override
  State<LiturgicalDayTile> createState() => _LiturgicalDayTileState();
}

class _LiturgicalDayTileState extends State<LiturgicalDayTile> {
  late LiturgicalDay _day;

  @override
  void initState() {
    super.initState();
    // Local baseline shows immediately; enrich from the API in the background.
    _day = liturgicalService.localToday();
    _enrich();
  }

  Future<void> _enrich() async {
    final enriched = await liturgicalService.fetchEnriched();
    if (!mounted || enriched == null) return;
    setState(() => _day = enriched);
  }

  Future<void> _openReadings() async {
    final uri = Uri.parse(LiturgicalDayTile._readingsUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the readings', style: GoogleFonts.inter())),
        );
      }
    }
  }

  /// Foreground color with enough contrast against the liturgical color that
  /// now fills the whole tile (dark ink on light colors like White; otherwise
  /// near-white).
  Color get _onColor =>
      _day.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

  String get _kicker {
    final season = _day.season.isEmpty ? '' : ' · ${_day.season}';
    return 'TODAY · ${_day.colorName}$season'.toUpperCase();
  }

  String get _title => _day.title;

  /// Testing aid: shows whether the displayed data is the offline built-in
  /// calendar or the live API enrichment. Tinted with [_onColor] so it stays
  /// legible against any liturgical color (the LIVE/BUILT-IN distinction is
  /// carried by the icon + label, not color).
  Widget _sourceBadge() {
    final isApi = _day.source == LiturgicalSource.api;
    final label = isApi ? 'LIVE API' : 'BUILT-IN';
    final icon = isApi ? Icons.cloud_done_outlined : Icons.calculate_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _onColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _onColor.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _onColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: _onColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memorial = _day.memorial;
    final onColor = _onColor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // The whole tile is the liturgical color of the day.
        color: _day.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _day.color.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _kicker,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: onColor.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _sourceBadge(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: onColor,
              height: 1.2,
            ),
          ),
          if (memorial != null && memorial.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              memorial,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: onColor.withValues(alpha: 0.85),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openReadings,
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text(
                'USCCB Daily Readings',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: onColor,
                backgroundColor: onColor.withValues(alpha: 0.08),
                side: BorderSide(color: onColor.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
