import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Stable Hero tag for a parish so list-card chips morph into the detail header.
String parishHeroTag(String seed) => 'parish-glass-$seed';

/// A generative stained-glass-style abstract painted from a seed string.
///
/// Inspired by Gothic quarry-window construction: a tessellation of rhombic
/// "quarry" panes laid in a tilted grid, optionally framing a circular
/// **roundel** (medallion) in the upper third. Lead came is rendered as a
/// thick near-black stroke with slightly heavier joints where multiple cames
/// meet — the way real soldered cames build up at intersections.
///
/// Deterministic from the seed, so each parish has a stable visual identity.
class StainedGlassHeader extends StatelessWidget {
  final String seed;

  /// Bottom-of-image darken applied as a vertical gradient overlay. Higher
  /// values keep an overlaid display title legible across all palettes.
  final double overlayDarken;

  const StainedGlassHeader({
    super.key,
    required this.seed,
    this.overlayDarken = 0.45,
  });

  /// Reference paint size — matches the parish detail header's natural
  /// 2:1 aspect. The painter always renders here; FittedBox scales it to the
  /// parent. Keeps the rasterized layer cached so SliverAppBar over-scroll
  /// zoom is a visual zoom, not a re-generation of geometry. Square chips
  /// crop to the center which still includes the roundel.
  static const Size _refSize = Size(400, 200);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fixed-size painter scaled via FittedBox.cover.
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _refSize.width,
              height: _refSize.height,
              child: RepaintBoundary(
                child: CustomPaint(painter: _StainedGlassPainter(seed: seed)),
              ),
            ),
          ),
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
      ),
    );
  }
}

class _StainedGlassPainter extends CustomPainter {
  final String seed;

  _StainedGlassPainter({required this.seed});

  // Jewel-tone palettes. Convention: [deep, mid, bright, accent, highlight].
  // The roundel uses palette[3] (gold/amber) as its dominant inner color.
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
    // Emerald & copper
    [Color(0xFF0A2A1F), Color(0xFF14593F), Color(0xFF2E8B61), Color(0xFFB8732D), Color(0xFFE6B888)],
    // Indigo & pearl
    [Color(0xFF161644), Color(0xFF2F2E78), Color(0xFF504DA8), Color(0xFFD9D2C0), Color(0xFFF1ECDD)],
    // Crimson & saffron
    [Color(0xFF42060A), Color(0xFF8A1622), Color(0xFFC23842), Color(0xFFE5A623), Color(0xFFF7D77C)],
    // Midnight plum & rose-gold
    [Color(0xFF1E0A2A), Color(0xFF4A1E5A), Color(0xFF7A3E8E), Color(0xFFE19A78), Color(0xFFF6D8B8)],
    // Slate & seafoam
    [Color(0xFF0F1F2A), Color(0xFF2A4655), Color(0xFF4F7C8A), Color(0xFF8FD0BE), Color(0xFFD6EFE6)],
  ];

  /// Vary a base color in HSL space with per-shard hue/saturation/brightness
  /// shifts. Wider ranges than the original pass — the prior ±9° hue felt
  /// uniform across an entire window. Lightness range stays tighter; pushing
  /// it further produces muddy / washed-out shards.
  Color _varyColor(Color base, math.Random rng) {
    final hsl = HSLColor.fromColor(base);
    final dh = (rng.nextDouble() - 0.5) * 28; // ±14° hue shift
    final ds = (rng.nextDouble() - 0.5) * 0.32; // ±16% saturation
    final dl = (rng.nextDouble() - 0.5) * 0.22; // ±11% lightness
    return hsl
        .withHue((hsl.hue + dh) % 360)
        .withSaturation((hsl.saturation + ds).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + dl).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed.hashCode);
    final palette = _palettes[rng.nextInt(_palettes.length)];

    // Below this size we drop the roundel — it gets cramped on small chips.
    final showRoundel = math.min(size.width, size.height) >= 90;

    // ───────────── Base wash ─────────────
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette[0], palette[1]],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, basePaint);

    // ───────────── Roundel geometry ─────────────
    // Centered in upper-third for header use; for small chips we omit it.
    final roundelCenter = Offset(size.width * 0.5, size.height * 0.42);
    final roundelRadius = showRoundel
        ? math.min(size.width, size.height) * 0.26
        : 0.0;

    // ───────────── Quarry diamond tiling ─────────────
    // Classic Gothic quarry: rhombi (taller than wide), tiled with half-step
    // row offsets so diamonds interlock. Vertices are pre-computed in a grid
    // and jittered — adjacent diamonds share vertices, so the jitter propagates
    // naturally and edges remain seamless.
    final shortSide = math.min(size.width, size.height);
    final diamondH = (shortSide / 3.4).clamp(28.0, 80.0);
    final diamondW = diamondH * 0.78;

    const leadColor = Color(0xFF050507);
    final leadPaint = Paint()
      ..color = leadColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // We'll also dot the joints with small filled circles to suggest soldered
    // intersections — collected during the pass and stamped at the end.
    final joints = <Offset>[];

    // Tile diamonds with a shared-jitter cache so adjacent shards retain
    // matching corners. Each diamond computes its 4 ideal corner positions;
    // a cache keyed on the quantized (x, y) returns the same jittered offset
    // for vertices any two neighboring diamonds share.
    final jitterAmt = diamondH * 0.045;
    final jitterCache = <int, Offset>{};
    Offset jittered(double x, double y) {
      // Quantize to 0.1px granularity to make floating-point matches reliable
      final kx = (x * 10).round();
      final ky = (y * 10).round();
      final key = kx * 100000 + ky;
      return jitterCache.putIfAbsent(key, () {
        final jx = (rng.nextDouble() - 0.5) * 2 * jitterAmt;
        final jy = (rng.nextDouble() - 0.5) * 2 * jitterAmt;
        return Offset(x + jx, y + jy);
      });
    }

    final colSpan = (size.width / diamondW).ceil() + 2;
    final rowSpan = (size.height / (diamondH / 2)).ceil() + 2;

    for (int r = -1; r < rowSpan; r++) {
      for (int c = -1; c < colSpan; c++) {
        // Diamond center: alternate rows are offset horizontally by dw/2 so
        // diamonds interlock.
        final cx = c * diamondW + (r.isOdd ? diamondW / 2 : 0);
        final cy = r * (diamondH / 2);

        // Skip diamonds whose center is deep inside the roundel.
        if (showRoundel) {
          final d = (Offset(cx, cy) - roundelCenter).distance;
          if (d < roundelRadius - diamondH * 0.3) continue;
        }

        // Ideal corners
        final topIdeal = Offset(cx, cy - diamondH / 2);
        final rightIdeal = Offset(cx + diamondW / 2, cy);
        final bottomIdeal = Offset(cx, cy + diamondH / 2);
        final leftIdeal = Offset(cx - diamondW / 2, cy);

        // Jittered (shared with neighboring diamonds via cache)
        final top = jittered(topIdeal.dx, topIdeal.dy);
        final right = jittered(rightIdeal.dx, rightIdeal.dy);
        final bottom = jittered(bottomIdeal.dx, bottomIdeal.dy);
        final left = jittered(leftIdeal.dx, leftIdeal.dy);

        // Quick reject off-canvas
        if (right.dx < -4 || left.dx > size.width + 4 ||
            bottom.dy < -4 || top.dy > size.height + 4) {
          continue;
        }

        final diamondPath = Path()
          ..moveTo(top.dx, top.dy)
          ..lineTo(right.dx, right.dy)
          ..lineTo(bottom.dx, bottom.dy)
          ..lineTo(left.dx, left.dy)
          ..close();

        final centerVec = Offset(cx, cy);

        // If the roundel cuts through, subtract it from the diamond path.
        Path shardPath = diamondPath;
        if (showRoundel) {
          final centerDist = (centerVec - roundelCenter).distance;
          if (centerDist < roundelRadius + diamondH * 0.6) {
            final circle = Path()
              ..addOval(Rect.fromCircle(center: roundelCenter, radius: roundelRadius));
            shardPath = Path.combine(PathOperation.difference, diamondPath, circle);
          }
        }

        // Color choice — wider variation via HSL hue/sat/lightness shifts.
        // Bias colors toward field tones (palette[0..2]) but allow occasional
        // bright pops (palette[2..4]) so the surface doesn't feel monotonous.
        final pick = rng.nextDouble();
        final colorIdx = pick < 0.45
            ? 1 // mid (most common)
            : pick < 0.75
                ? 0 // deep
                : pick < 0.92
                    ? 2 // bright
                    : (rng.nextBool() ? 4 : 3); // occasional accent
        final shardColor = _varyColor(palette[colorIdx], rng);

        final bounds = shardPath.getBounds();
        if (bounds.isEmpty) continue;
        final shardPaint = Paint()
          ..shader = RadialGradient(
            center: Alignment(
              -0.5 + (rng.nextDouble() - 0.5) * 0.4,
              -0.5 + (rng.nextDouble() - 0.5) * 0.4,
            ),
            radius: 1.0 + rng.nextDouble() * 0.3,
            colors: [
              Color.lerp(shardColor, Colors.white, 0.20)!,
              shardColor,
              Color.lerp(shardColor, Colors.black, 0.25)!,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(bounds);

        canvas.drawPath(shardPath, shardPaint);
        canvas.drawPath(shardPath, leadPaint);

        // Joint dots (de-duped later)
        for (final v in [top, right, bottom, left]) {
          if (v.dx >= -2 && v.dx <= size.width + 2 &&
              v.dy >= -2 && v.dy <= size.height + 2) {
            joints.add(v);
          }
        }
      }
    }

    // ───────────── Roundel ─────────────
    if (showRoundel) {
      // Fill base — a deep contrast color from the palette
      final roundelFill = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            Color.lerp(palette[4], Colors.white, 0.15)!,
            palette[3],
            Color.lerp(palette[3], Colors.black, 0.25)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: roundelCenter, radius: roundelRadius));
      canvas.drawCircle(roundelCenter, roundelRadius, roundelFill);

      // Radial wedges — 8 segments, alternating two accent tones
      const wedgeCount = 8;
      final wedgeStartAngle = rng.nextDouble() * math.pi * 2;
      for (int i = 0; i < wedgeCount; i++) {
        final a0 = wedgeStartAngle + i * 2 * math.pi / wedgeCount;
        final a1 = wedgeStartAngle + (i + 1) * 2 * math.pi / wedgeCount;
        final wedge = Path()
          ..moveTo(roundelCenter.dx, roundelCenter.dy)
          ..lineTo(
            roundelCenter.dx + roundelRadius * math.cos(a0),
            roundelCenter.dy + roundelRadius * math.sin(a0),
          )
          ..arcToPoint(
            Offset(
              roundelCenter.dx + roundelRadius * math.cos(a1),
              roundelCenter.dy + roundelRadius * math.sin(a1),
            ),
            radius: Radius.circular(roundelRadius),
          )
          ..close();

        // Alternate between palette[3] (gold) and palette[2] (bright), with
        // per-wedge HSL variance so each wedge reads as its own piece of glass.
        final wColor = i.isEven ? palette[3] : palette[2];
        final wedgeColor = _varyColor(wColor, rng);

        final wedgePaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(wedgeColor, Colors.white, 0.10)!,
              wedgeColor,
              Color.lerp(wedgeColor, Colors.black, 0.15)!,
            ],
          ).createShader(wedge.getBounds());
        canvas.drawPath(wedge, wedgePaint);
        canvas.drawPath(wedge, leadPaint);
      }

      // Inner hub circle — small dark center jewel
      final hubRadius = roundelRadius * 0.18;
      final hubPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(palette[2], Colors.white, 0.30)!,
            palette[1],
          ],
        ).createShader(Rect.fromCircle(center: roundelCenter, radius: hubRadius));
      canvas.drawCircle(roundelCenter, hubRadius, hubPaint);
      canvas.drawCircle(roundelCenter, hubRadius, leadPaint);

      // Roundel outer boundary — a thicker ring of lead
      final ringPaint = Paint()
        ..color = leadColor.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5;
      canvas.drawCircle(roundelCenter, roundelRadius, ringPaint);
    }

    // ───────────── Soldered joints ─────────────
    // Stamp small filled dots at the diamond vertices to suggest soldered
    // came intersections. Skip any joints that fall inside the roundel (those
    // came from diamonds whose corners crossed the medallion boundary).
    final jointPaint = Paint()..color = leadColor.withValues(alpha: 0.9);
    final stamped = <Offset>{};
    for (final j in joints) {
      if (showRoundel && (j - roundelCenter).distance < roundelRadius) continue;
      // Snap to half-pixel precision so duplicate verts collapse
      final key = Offset((j.dx * 2).round() / 2, (j.dy * 2).round() / 2);
      if (stamped.contains(key)) continue;
      stamped.add(key);
      canvas.drawCircle(j, 2.0, jointPaint);
    }

    // ───────────── Final warm glow ─────────────
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
