import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ava_web/core/app_fonts.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

void main() {
  group('type scale', () {
    final theme = AppTheme.light(kDefaultSeed);
    final styles = <String, TextStyle?>{
      'headlineMedium': theme.textTheme.headlineMedium,
      'headlineSmall': theme.textTheme.headlineSmall,
      'titleLarge': theme.textTheme.titleLarge,
      'titleMedium': theme.textTheme.titleMedium,
      'bodyLarge': theme.textTheme.bodyLarge,
      'bodyMedium': theme.textTheme.bodyMedium,
      'bodySmall': theme.textTheme.bodySmall,
      'labelLarge': theme.textTheme.labelLarge,
      'labelMedium': theme.textTheme.labelMedium,
    };

    test('every style has a size, Vazirmatn, and a Persian-friendly line height', () {
      styles.forEach((name, style) {
        expect(style, isNotNull, reason: name);
        expect(style!.fontSize, isNotNull, reason: name);
        expect(style.fontFamily, AppFonts.familyName, reason: name);
        expect(style.height, greaterThanOrEqualTo(1.3), reason: name);
      });
    });

    test('sizes decrease from headline to label', () {
      final sizes = styles.values.map((s) => s!.fontSize!).toList();
      for (var i = 1; i < sizes.length; i++) {
        expect(sizes[i], lessThanOrEqualTo(sizes[i - 1]));
      }
    });

    test('text sits on the background in the right color, both modes', () {
      for (final b in Brightness.values) {
        final t = b == Brightness.light
            ? AppTheme.light(kDefaultSeed)
            : AppTheme.dark(kDefaultSeed);
        final onBg = t.extension<AppColors>()!.onBackground;
        expect(t.textTheme.bodyLarge!.color, onBg, reason: b.name);
      }
    });

    test('responsive scale is 1 on a 390px phone and clamped', () {
      expect(AppTypography.responsiveTextScale(390), 1);
      expect(AppTypography.responsiveTextScale(200), 0.85);
      expect(AppTypography.responsiveTextScale(2000), 1.25);
    });
  });

  testWidgets('inheritColor lets filled-button text stay white', (tester) async {
    late Color? color;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(kDefaultSeed),
        home: Scaffold(
          body: FilledButton(
            onPressed: () {},
            child: Builder(
              builder: (context) {
                final style = DefaultTextStyle.of(
                  context,
                ).style.merge(context.text.bodyLarge.inheritColor);
                color = style.color;
                return const Text('x');
              },
            ),
          ),
        ),
      ),
    );
    expect(color, Colors.white);
  });
}
