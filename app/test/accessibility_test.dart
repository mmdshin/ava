import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ava_web/app/router.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/contrast.dart';
import 'package:ava_web/data/content_repository.dart';

import 'helpers.dart';

/// Accessibility checks: color contrast for every theme color, large
/// system text, and screen-reader labels on tappable things.
void main() {
  group('color contrast (WCAG AA)', () {
    for (final preset in kColorPresets) {
      for (final brightness in Brightness.values) {
        test('${preset.id} ${brightness.name}', () {
          final c = AppColors.forSeed(preset.seed, brightness);
          final bg = c.contrastReference;
          String why(String what) => '${preset.id} ${brightness.name}: $what';

          expect(contrastRatio(c.onBackground, bg), greaterThanOrEqualTo(4.5),
              reason: why('text'));
          final muted = Color.alphaBlend(c.onBackgroundMuted, bg);
          expect(contrastRatio(muted, bg), greaterThanOrEqualTo(4.5),
              reason: why('muted text'));
          for (final (name, color) in [
            ('success', c.success),
            ('warning', c.warning),
            ('caution', c.caution),
            ('danger', c.danger),
            ('accent', c.accent),
          ]) {
            expect(contrastRatio(color, bg), greaterThanOrEqualTo(4.5),
                reason: why(name));
          }
          expect(contrastRatio(Colors.white, c.brand),
              greaterThanOrEqualTo(4.5),
              reason: why('white text on brand buttons'));
        });
      }
    }

    test('ensureContrast keeps hue and reaches the target', () {
      const orange = Color(0xFFF2A93E);
      const light = Color(0xFFE1F1F4);
      final fixed = ensureContrast(orange, light);
      expect(contrastRatio(fixed, light), greaterThanOrEqualTo(4.5));
      expect(
        HSLColor.fromColor(fixed).hue,
        closeTo(HSLColor.fromColor(orange).hue, 2),
      );
    });
  });

  group('screens', () {
    late ContentRepository content;
    late SharedPreferences prefs;

    setUpAll(() async => content = await loadTestContent());
    setUp(() async => prefs = await mockPrefs());

    Future<void> open(WidgetTester tester, String location) async {
      GoRouter.of(tester.element(find.byType(Navigator).first)).go(location);
      await settle(tester);
    }

    final locations = {
      'home': AppRoutes.home,
      'care plans': AppRoutes.carePlans,
      'care plans of a kind': AppRoutes.carePlansOfKind(TestKinds.mi),
      'care plan': AppRoutes.carePlan('acs-01'),
      'quizzes': AppRoutes.quizzes,
      'favorites': AppRoutes.favorites,
      'finder: disease': AppRoutes.assessment,
      'finder: assessment': AppRoutes.assessmentFor(TestKinds.acs),
      'about': AppRoutes.about,
    };

    // A phone with the system font size at 200 %: nothing may overflow
    // (an overflow fails the test with the widget that clipped).
    for (final MapEntry(key: name, value: location) in locations.entries) {
      testWidgets('large text: $name', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(testApp(prefs, content));
        await settle(tester);
        await open(tester, location);
        expect(tester.takeException(), isNull);
      });
    }

    // Every tappable element has something for a screen reader to say.
    for (final name in ['home', 'finder: disease', 'finder: assessment', 'about']) {
      testWidgets('labelled tap targets: $name', (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(testApp(prefs, content));
        await settle(tester);
        await open(tester, locations[name]!);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });
}
