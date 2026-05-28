import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Stable Hero tag for a parish so list-card chips morph into the detail header.
String parishHeroTag(String seed) => 'parish-glass-$seed';

/// A generative stained-glass-style abstract painted from a seed string.
/// The same seed always produces the same image, so each parish has a stable
/// visual identity even without a real photo.
class StainedGlassHeader extends StatelessWidget {
  final String seed;
  final double overlayDarken;

  const StainedGlassHeader({
    super.key,
    required this.seed,
    this.overlayDarken = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _StainedGlassPainter(seed: seed)),
        // Soft vertical fade for header text legibility
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.05),
                Colors.black.withValues(alpha: overlayDarken),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StainedGlassPainter extends CustomPainter {
  final String seed;

  _StainedGlassPainter({required this.seed});

  // Jewel-tone palettes — pick one based on seed hash so different parishes
  // feel distinct without being garish.
  static const List<List<Color>> _palettes = [
    // Sapphire & gold
    [Color(0xFF0B2A4A), Color(0xFF1E5F8A), Color(0xFF3A7CA5), Color(0xFFC9A227), Color(0xFFE8D7A1)],
    // Burgundy & rose
    [Color(0xFF3D0C11), Color(0xFF7A1F2B), Color(0xFFB23A48), Color(0xFFE07A5F), Color(0xFFF2CC8F)],
    // Forest & ember
    [Color(0xFF1B3A2F), Color(0xFF2F5D50), Color(0xFF558C7A), Color(0xFFD4A256), Color(0xFFE8C39E)],
    // Vespers violet
    [Color(0xFF2A1A4A), Color(0xFF503A75), Color(0xFF7C5BA8), Color(0xFFC9A227), Color(0xFFEED68A)],
    // Twilight teal
    [Color(0xFF0B3142), Color(0xFF1B5E7A), Color(0xFF3A8DA8), Color(0xFFE0A458), Color(0xFFF5D78A)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed.hashCode);
    final palette = _palettes[rng.nextInt(_palettes.length)];

    // Base wash so leaded gaps between shards aren't pure black.
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette[0], palette[1]],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, basePaint);

    // Build a grid of points, lightly jittered, then split each cell into
    // two triangles along a per-cell diagonal. This guarantees uniform shards
    // with no slivers — closer to traditional leaded glass than free-form
    // triangulation.
    const cols = 4;
    const rows = 3;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    Offset gridPoint(int c, int r) {
      // Edges of the canvas stay anchored so we don't get gaps at the border
      final atEdgeX = c == 0 || c == cols;
      final atEdgeY = r == 0 || r == rows;
      final jitterX = atEdgeX ? 0.0 : (rng.nextDouble() - 0.5) * cellW * 0.45;
      final jitterY = atEdgeY ? 0.0 : (rng.nextDouble() - 0.5) * cellH * 0.45;
      return Offset(c * cellW + jitterX, r * cellH + jitterY);
    }

    // Pre-compute jittered grid
    final grid = List<List<Offset>>.generate(
      rows + 1,
      (r) => List<Offset>.generate(cols + 1, (c) => gridPoint(c, r)),
    );

    final leadPaint = Paint()
      ..color = const Color(0xFF0A0A0F).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final tl = grid[r][c];
        final tr = grid[r][c + 1];
        final bl = grid[r + 1][c];
        final br = grid[r + 1][c + 1];

        // Random diagonal per cell so the pattern feels less grid-like
        final splitNE = rng.nextBool();
        final tri1 = splitNE ? [tl, tr, br] : [tl, tr, bl];
        final tri2 = splitNE ? [tl, br, bl] : [tr, br, bl];

        for (final tri in [tri1, tri2]) {
          final path = Path()
            ..moveTo(tri[0].dx, tri[0].dy)
            ..lineTo(tri[1].dx, tri[1].dy)
            ..lineTo(tri[2].dx, tri[2].dy)
            ..close();

          final colorIdx = (rng.nextInt(palette.length) + c + r) % palette.length;
          final base = palette[colorIdx];
          final variance = 0.88 + rng.nextDouble() * 0.24;
          final shardColor = Color.fromARGB(
            255,
            (base.r * 255 * variance).round().clamp(0, 255),
            (base.g * 255 * variance).round().clamp(0, 255),
            (base.b * 255 * variance).round().clamp(0, 255),
          );

          final bounds = path.getBounds();
          final shardPaint = Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.4, -0.4),
              radius: 1.0,
              colors: [
                Color.lerp(shardColor, Colors.white, 0.15)!,
                shardColor,
                Color.lerp(shardColor, Colors.black, 0.18)!,
              ],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(bounds);

          canvas.drawPath(path, shardPaint);
          canvas.drawPath(path, leadPaint);
        }
      }
    }

    // Final warm glow from upper-left to suggest light through the glass
    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.6, -0.7),
        radius: 1.3,
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant _StainedGlassPainter old) => old.seed != seed;
}
