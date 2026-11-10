import 'package:flutter/material.dart';
import 'package:ava_web/core/app_theme.dart';

/// The one shared screen background: the brand gradient plus two soft
/// glow blobs, behind [child].
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final glow = context.appColors.glow;
    final small = (size.shortestSide * 0.75).clamp(220.0, 520.0);
    final large = (size.shortestSide * 0.95).clamp(280.0, 680.0);

    return DecoratedBox(
      decoration: BoxDecoration(gradient: context.appColors.background),
      child: Stack(
        children: [
          Positioned(
            top: -small * 0.35,
            right: -small * 0.3,
            child: _GlowBlob(size: small, color: glow, opacity: 0.16),
          ),
          Positioned(
            bottom: -large * 0.4,
            left: -large * 0.35,
            child: _GlowBlob(size: large, color: glow, opacity: 0.12),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
