import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Custom icon widget for displaying SVG icons from assets.
///
/// Usage:
/// ```dart
/// CustomIcon.monstrance(color: Colors.blue, size: 24)
/// CustomIcon.confession(color: Colors.grey, size: 32)
/// ```
class CustomIcon extends StatelessWidget {
  final String assetPath;
  final Color? color;
  final double? size;

  const CustomIcon({
    super.key,
    required this.assetPath,
    this.color,
    this.size,
  });

  /// Monstrance icon - represents Eucharistic adoration
  factory CustomIcon.monstrance({Color? color, double? size}) {
    return CustomIcon(
      assetPath: 'assets/icons/monstrance.svg',
      color: color,
      size: size,
    );
  }

  /// Confession icon - represents the sacrament of reconciliation
  factory CustomIcon.confession({Color? color, double? size}) {
    return CustomIcon(
      assetPath: 'assets/icons/confession.svg',
      color: color,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: size ?? 24,
      height: size ?? 24,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
