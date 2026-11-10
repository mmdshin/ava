import 'package:flutter/material.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

extension AdminSurfaces on BuildContext {
  bool get _dark => Theme.of(this).brightness == Brightness.dark;

  Color get adminCanvas => _dark
      ? Color.alphaBlend(
          Colors.black.withValues(alpha: 0.35),
          appColors.dialogSurface,
        )
      : Color.alphaBlend(
          appColors.brand.withValues(alpha: 0.035),
          const Color(0xFFF6F8F9),
        );

  Color get adminPanel => _dark ? appColors.dialogSurface : Colors.white;

  Color get adminLine => appColors.glass.withValues(alpha: _dark ? 0.14 : 0.11);

  Color get adminHover =>
      appColors.glass.withValues(alpha: _dark ? 0.07 : 0.045);
}

ThemeData adminTheme(ThemeData base) {
  final colors = base.extension<AppColors>()!;
  final dark = base.brightness == Brightness.dark;
  final canvas = dark
      ? Color.alphaBlend(
          Colors.black.withValues(alpha: 0.35),
          colors.dialogSurface,
        )
      : Color.alphaBlend(
          colors.brand.withValues(alpha: 0.035),
          const Color(0xFFF6F8F9),
        );
  final panel = dark ? colors.dialogSurface : Colors.white;
  final line = colors.glass.withValues(alpha: dark ? 0.14 : 0.11);

  final shape = WidgetStatePropertyAll<OutlinedBorder>(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm - 2),
    ),
  );
  const padding = WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm + 2,
    ),
  );
  const minSize = WidgetStatePropertyAll<Size>(Size(40, 42));

  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    scaffoldBackgroundColor: canvas,
    canvasColor: panel,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: panel,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style!.copyWith(
        minimumSize: minSize,
        padding: padding,
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style!.copyWith(
        minimumSize: minSize,
        padding: padding,
        shape: shape,
        side: WidgetStatePropertyAll(
          BorderSide(color: colors.glass.withValues(alpha: 0.22)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.onBackground,
        minimumSize: const Size(40, 38),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm - 2),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: outline(colors.glass.withValues(alpha: 0.2)),
      enabledBorder: outline(colors.glass.withValues(alpha: 0.2)),
      focusedBorder: outline(colors.accent, 1.6),
      errorBorder: outline(colors.danger),
      focusedErrorBorder: outline(colors.danger, 1.6),
      hintStyle: base.textTheme.bodyMedium?.copyWith(
        color: colors.onBackgroundMuted,
      ),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
    popupMenuTheme: PopupMenuThemeData(
      color: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: line),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 440,
    ),
  );
}
