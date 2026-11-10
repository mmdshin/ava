import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG contrast helpers, used to keep every palette readable.
///
/// WCAG AA asks for a contrast ratio of at least 4.5 : 1 for normal text,
/// 3 : 1 for large/bold text and for icons.

/// The WCAG contrast ratio between two opaque colors (1 – 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

bool isLightColor(Color color) => color.computeLuminance() > 0.18;

Color ensureContrast(Color color, Color background, {double minRatio = 4.5}) {
  if (contrastRatio(color, background) >= minRatio) return color;
  final step = isLightColor(background) ? -0.02 : 0.02;
  var hsl = HSLColor.fromColor(color);
  for (var i = 0; i < 50; i++) {
    final lightness = (hsl.lightness + step).clamp(0.0, 1.0);
    hsl = hsl.withLightness(lightness);
    final candidate = hsl.toColor();
    if (contrastRatio(candidate, background) >= minRatio ||
        lightness == 0 ||
        lightness == 1) {
      return candidate;
    }
  }
  return hsl.toColor();
}

double minimumAlpha(
  Color color,
  Color background, {
  double minRatio = 4.5,
  double from = 0.7,
}) {
  for (var a = from; a < 1; a += 0.02) {
    final blended = Color.alphaBlend(color.withValues(alpha: a), background);
    if (contrastRatio(blended, background) >= minRatio) return a;
  }
  return 1;
}
