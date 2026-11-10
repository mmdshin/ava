import 'package:flutter/material.dart';
import 'package:ava_web/core/app_fonts.dart';

abstract final class AppRadius {
  /// Chips, small badges, inputs.
  static const double sm = 14;

  /// Buttons, list tiles, small cards.
  static const double md = 18;

  /// Cards and panels (the default for [AppCard]).
  static const double lg = 22;

  /// Dialogs, hero cards, bottom sheets.
  static const double xl = 28;

  /// Fully rounded (pills, capsules).
  static const double pill = 999;
}

/// Spacing scale (logical px, before responsive scaling).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// The app's type scale, tuned for Persian (Vazirmatn): taller line
/// heights than Material's defaults so diacritics and descenders don't
/// collide, and slightly heavier titles.
abstract final class AppTypography {
  static TextTheme textTheme(Color color) {
    TextStyle s(double size, FontWeight weight, double height) => TextStyle(
      fontFamily: AppFonts.familyName,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
    );

    return TextTheme(
      displayLarge: s(36, FontWeight.w900, 1.3),
      displayMedium: s(32, FontWeight.w900, 1.3),
      displaySmall: s(28, FontWeight.w900, 1.3),
      headlineLarge: s(30, FontWeight.w900, 1.35),
      headlineMedium: s(26, FontWeight.w900, 1.35),
      headlineSmall: s(22, FontWeight.w800, 1.4),
      titleLarge: s(19, FontWeight.w800, 1.45),
      titleMedium: s(17, FontWeight.w700, 1.5),
      titleSmall: s(15, FontWeight.w700, 1.5),
      bodyLarge: s(16, FontWeight.w500, 1.75),
      bodyMedium: s(14.5, FontWeight.w400, 1.7),
      bodySmall: s(13.5, FontWeight.w400, 1.6),
      labelLarge: s(13, FontWeight.w600, 1.4),
      labelMedium: s(12, FontWeight.w600, 1.4),
      labelSmall: s(11, FontWeight.w600, 1.4),
    );
  }

  /// Width-based text scale: 1.0 on a ~390 px phone, between 0.85
  /// (very small phones) and 1.25 (tablets / desktop).
  static double responsiveTextScale(double screenWidth) =>
      (screenWidth / 390).clamp(0.85, 1.25);
}

/// Non-nullable access to the theme's text styles:
///
///   Text('...', style: context.text.titleLarge)
///   Text('...', style: context.text.bodyMedium.copyWith(color: x))
extension AppTextContext on BuildContext {
  AppText get text => AppText(Theme.of(this).textTheme);
}

class AppText {
  const AppText(this._t);
  final TextTheme _t;

  TextStyle get displayLarge => _t.displayLarge!;
  TextStyle get displayMedium => _t.displayMedium!;
  TextStyle get displaySmall => _t.displaySmall!;
  TextStyle get headlineLarge => _t.headlineLarge!;
  TextStyle get headlineMedium => _t.headlineMedium!;
  TextStyle get headlineSmall => _t.headlineSmall!;
  TextStyle get titleLarge => _t.titleLarge!;
  TextStyle get titleMedium => _t.titleMedium!;
  TextStyle get titleSmall => _t.titleSmall!;
  TextStyle get bodyLarge => _t.bodyLarge!;
  TextStyle get bodyMedium => _t.bodyMedium!;
  TextStyle get bodySmall => _t.bodySmall!;
  TextStyle get labelLarge => _t.labelLarge!;
  TextStyle get labelMedium => _t.labelMedium!;
  TextStyle get labelSmall => _t.labelSmall!;
}

extension TextStyleInheritColor on TextStyle {
  /// This style without its color, so the text takes the color of its
  /// surroundings.
  TextStyle get inheritColor => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    height: height,
    letterSpacing: letterSpacing,
  );
}
