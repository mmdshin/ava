import 'package:flutter/material.dart';
import 'package:ava_web/core/app_fonts.dart';
import 'package:ava_web/core/contrast.dart';
import 'package:ava_web/core/design_system.dart';

/// One selectable theme color, shown as a swatch in the "change theme
/// color" picker.
class AppColorPreset {
  const AppColorPreset({
    required this.id,
    required this.label,
    required this.seed,
  });

  final String id;
  final String label;
  final Color seed;
}

/// The colors offered in the theme-color picker
const List<AppColorPreset> kColorPresets = [
  AppColorPreset(id: 'teal', label: 'فیروزه‌ای', seed: Color(0xFF0E7490)),
  AppColorPreset(id: 'blue', label: 'آبی', seed: Color(0xFF2563EB)),
  AppColorPreset(id: 'violet', label: 'بنفش', seed: Color(0xFF6C4FD1)),
  AppColorPreset(id: 'green', label: 'سبز', seed: Color(0xFF16A34A)),
  AppColorPreset(id: 'rose', label: 'صورتی', seed: Color(0xFFE85D9C)),
  AppColorPreset(id: 'amber', label: 'کهربایی', seed: Color(0xFFF2994A)),
];

const Color kDefaultSeed = Color(0xFF0E7490);

class AppTheme {
  AppTheme._();

  static ThemeData light(Color seed) => _build(seed, Brightness.light);

  static ThemeData dark(Color seed) => _build(seed, Brightness.dark);

  static ThemeData _build(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final colors = AppColors.forSeed(seed, brightness);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.md + 2,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppFonts.familyName,
      textTheme: AppTypography.textTheme(colors.onBackground),
      scaffoldBackgroundColor: scheme.surface,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? colors.dialogSurface.withValues(alpha: 0.94)
              : Colors.transparent,
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: colors.onBackground,
        iconTheme: IconThemeData(color: colors.onBackground),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.dialogSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onBackground,
          side: BorderSide(color: colors.glass.withValues(alpha: 0.4)),
          minimumSize: const Size(64, 48),
          padding: buttonPadding,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.onBackground),
      ),
    );
  }
}

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.onBackground,
    required this.onBackgroundMuted,
    required this.glass,
    required this.glow,
    required this.brand,
    required this.dialogSurface,
    required this.success,
    required this.warning,
    required this.caution,
    required this.danger,
  });

  /// The big diagonal gradient behind every screen.
  final Gradient background;

  /// Primary text/icon color that sits directly on [background].
  final Color onBackground;

  /// Slightly muted variant (subtitles, captions, footers).
  final Color onBackgroundMuted;

  /// Base color used for glassmorphism card fills/borders — call sites
  /// apply their own alpha, e.g. `context.appColors.glass.withValues(alpha: 0.18)`.
  final Color glass;

  /// Base color used for the big soft decorative glow circles.
  final Color glow;

  /// Solid brand color for CTA buttons. Text/icons on it are always
  /// white, in both modes.
  final Color brand;

  /// Opaque background for dialogs and popups. Text on it uses [onBackground].
  final Color dialogSurface;

  /// Correct answers, high match scores.
  final Color success;

  /// Hints, highlights, section accents
  final Color warning;

  /// Middle scores
  final Color caution;

  /// Wrong answers, low scores.
  final Color danger;

  static const _lightStatus = (
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    caution: Color(0xFFC2410C),
    danger: Color(0xFFDC2626),
  );

  static const _darkStatus = (
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFACC15),
    caution: Color(0xFFFB923C),
    danger: Color(0xFFF87171),
  );

  /// Builds a full light/dark palette from a single seed color.
  factory AppColors.forSeed(Color seed, Brightness brightness) {
    if (seed.toARGB32() == kDefaultSeed.toARGB32()) {
      return brightness == Brightness.dark ? _tealDark : _tealLight;
    }
    return _accessible(_fromSeed(seed, brightness), brightness);
  }

  static AppColors _fromSeed(Color seed, Brightness brightness) {
    final hsl = HSLColor.fromColor(seed);
    Color shade(double lightness, [double satMul = 1]) => hsl
        .withLightness(lightness)
        .withSaturation((hsl.saturation * satMul).clamp(0.0, 1.0))
        .toColor();

    if (brightness == Brightness.dark) {
      return AppColors(
        background: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [shade(0.07, 0.7), shade(0.20), shade(0.34, 1.1)],
        ),
        onBackground: Colors.white,
        onBackgroundMuted: Colors.white70,
        glass: Colors.white,
        glow: Colors.white,
        brand: seed,
        dialogSurface: shade(0.12, 0.6),
        success: _darkStatus.success,
        warning: _darkStatus.warning,
        caution: _darkStatus.caution,
        danger: _darkStatus.danger,
      );
    }

    return AppColors(
      background: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [shade(0.97, 0.30), shade(0.92, 0.40), shade(0.86, 0.48)],
      ),
      onBackground: shade(0.17, 0.55),
      onBackgroundMuted: shade(0.42, 0.35),
      glass: shade(0.17, 0.55),
      glow: seed,
      brand: seed,
      dialogSurface: shade(0.98, 0.35),
      success: _lightStatus.success,
      warning: _lightStatus.warning,
      caution: _lightStatus.caution,
      danger: _lightStatus.danger,
    );
  }

  static final _tealLight = _accessible(
    AppColors(
      background: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFF2FAFB), Color(0xFFE1F1F4), Color(0xFFCCE7EC)],
      ),
      onBackground: const Color(0xFF0B2A33),
      onBackgroundMuted: const Color(0xFF4C707A),
      glass: const Color(0xFF0B2A33),
      glow: const Color(0xFF0E7490),
      brand: const Color(0xFF0E7490),
      dialogSurface: const Color(0xFFF6FBFC),
      success: _lightStatus.success,
      warning: _lightStatus.warning,
      caution: _lightStatus.caution,
      danger: _lightStatus.danger,
    ),
    Brightness.light,
  );

  static final _tealDark = _accessible(
    AppColors(
      background: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF07141F), Color(0xFF0B3A4A), Color(0xFF157A8C)],
      ),
      onBackground: Colors.white,
      onBackgroundMuted: Colors.white70,
      glass: Colors.white,
      glow: Colors.white,
      brand: const Color(0xFF0E7490),
      dialogSurface: const Color(0xFF0C2530),
      success: _darkStatus.success,
      warning: _darkStatus.warning,
      caution: _darkStatus.caution,
      danger: _darkStatus.danger,
    ),
    Brightness.dark,
  );

  /// Makes a palette meet WCAG AA, whatever the seed color:
  ///  - dark mode: gradient stops are darkened until white text reaches
  ///    7 : 1 on all of them (bright teal/green stops washed out text);
  ///  - muted text and the status colors reach 4.5 : 1 against the
  ///    hardest spot (the lightest/darkest gradient stop under a card);
  ///  - [brand] keeps 4.5 : 1 with the white text drawn on it.
  static AppColors _accessible(AppColors raw, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    var background = raw.background;
    if (dark && background is LinearGradient) {
      background = LinearGradient(
        begin: background.begin,
        end: background.end,
        stops: background.stops,
        colors: [
          for (final c in background.colors)
            ensureContrast(c, Colors.white, minRatio: 7),
        ],
      );
    }
    final worst = _hardestBackground(background, raw.glass, dark);

    return raw.copyWith(
      background: background,
      onBackgroundMuted: dark
          ? Colors.white.withValues(alpha: minimumAlpha(Colors.white, worst))
          : ensureContrast(raw.onBackgroundMuted, worst),
      success: ensureContrast(raw.success, worst),
      warning: ensureContrast(raw.warning, worst),
      caution: ensureContrast(raw.caution, worst),
      danger: ensureContrast(raw.danger, worst),
      brand: ensureContrast(raw.brand, Colors.white),
    );
  }

  /// The background color text has the least contrast with: the
  /// darkest (light mode) or lightest (dark mode) gradient stop, under
  /// a card's glass tint.
  static Color _hardestBackground(Gradient background, Color glass, bool dark) {
    final colors = background.colors.toList()
      ..sort((a, b) => a.computeLuminance().compareTo(b.computeLuminance()));
    final stop = dark ? colors.last : colors.first;
    return Color.alphaBlend(glass.withValues(alpha: 0.08), stop);
  }

  /// [contrastReference] for this palette's background.
  Color get contrastReference =>
      _hardestBackground(background, glass, !isLightColor(dialogSurface));

  /// [brand] as a foreground (icons, small text) on the background:
  /// darker in light mode, lighter in dark mode, always 4.5 : 1.
  Color get accent => ensureContrast(brand, contrastReference);

  @override
  AppColors copyWith({
    Gradient? background,
    Color? onBackground,
    Color? onBackgroundMuted,
    Color? glass,
    Color? glow,
    Color? brand,
    Color? dialogSurface,
    Color? success,
    Color? warning,
    Color? caution,
    Color? danger,
  }) {
    return AppColors(
      background: background ?? this.background,
      onBackground: onBackground ?? this.onBackground,
      onBackgroundMuted: onBackgroundMuted ?? this.onBackgroundMuted,
      glass: glass ?? this.glass,
      glow: glow ?? this.glow,
      brand: brand ?? this.brand,
      dialogSurface: dialogSurface ?? this.dialogSurface,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      caution: caution ?? this.caution,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Gradient.lerp(background, other.background, t)!,
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
      onBackgroundMuted: Color.lerp(
        onBackgroundMuted,
        other.onBackgroundMuted,
        t,
      )!,
      glass: Color.lerp(glass, other.glass, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      dialogSurface: Color.lerp(dialogSurface, other.dialogSurface, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Terse call-site access: `context.appColors`, `context.onBg`.
extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;

  /// Primary foreground color for text/icons sitting on the hero
  /// background gradient. White in dark mode, deep ink in light mode.
  Color get onBg => appColors.onBackground;

  /// Muted foreground (subtitles/captions/footers).
  Color get onBgMuted => appColors.onBackgroundMuted;

  /// [color] adjusted to stay readable as text/icon on the background
  /// (e.g. a disease color used for a label). See [ensureContrast].
  Color legible(Color color, {double minRatio = 4.5}) =>
      ensureContrast(color, appColors.contrastReference, minRatio: minRatio);
}
