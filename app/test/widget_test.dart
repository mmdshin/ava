import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ava_web/app/router.dart';
import 'package:ava_web/core/favorites_controller.dart';
import 'package:ava_web/features/account/user_data_controller.dart';
import 'package:ava_web/core/theme_controller.dart';
import 'package:ava_web/data/content_repository.dart';
import 'package:ava_web/features/care_plans/recent_care_plans.dart';
import 'package:ava_web/features/home/home_screen.dart';
import 'package:ava_web/features/quiz/quiz_progress.dart';
import 'package:ava_web/features/quiz/screens/quiz_screen.dart';
import 'package:ava_web/features/quiz/screens/result_screen.dart';

import 'helpers.dart';

void main() {
  late ContentRepository content;
  late SharedPreferences prefs;

  setUpAll(() async {
    content = await loadTestContent();
  });

  setUp(() async {
    prefs = await mockPrefs();
  });

  /// Starts the app on the home tab.
  Future<void> startApp(WidgetTester tester) async {
    // Phone-width (bottom bar, not side rail) but tall, so the whole
    // home dashboard is built without scrolling.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(prefs, content));
    await settle(tester);
  }

  Future<void> goTo(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(Navigator).first)).go(location);
    await settle(tester);
  }

  testWidgets('starts on the home dashboard, and the app is RTL', (
    tester,
  ) async {
    await startApp(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('دستیار پرستاری آوا'), findsOneWidget);
    expect(find.text('تشخیص‌یاب'), findsOneWidget);
    // Bottom navigation bar (phone-sized test window)
    expect(find.byType(NavigationBar), findsOneWidget);

    final context = tester.element(find.text('دستیار پرستاری آوا'));
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('deep link opens a care plan by id', (tester) async {
    await startApp(tester);
    final plan = content.carePlans.first;

    await goTo(tester, AppRoutes.carePlan(plan.id));

    expect(find.text(plan.title), findsWidgets);
  });

  testWidgets('unknown care plan id shows the not-found page', (tester) async {
    await startApp(tester);

    await goTo(tester, AppRoutes.carePlan('does-not-exist'));

    expect(find.text('صفحه موردنظر پیدا نشد'), findsOneWidget);
  });

  testWidgets('unknown URL shows the not-found page', (tester) async {
    await startApp(tester);

    await goTo(tester, '/no/such/page');

    expect(find.text('صفحه موردنظر پیدا نشد'), findsOneWidget);
  });

  testWidgets('quiz result without an attempt redirects to the quiz', (
    tester,
  ) async {
    await startApp(tester);
    final quiz = content.quizzes.first;

    await goTo(tester, AppRoutes.quizResult(quiz.id));

    // Lands on the quiz itself, not an empty result. (Questions are
    // shuffled, so check for the quiz screen rather than a question.)
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.byType(ResultScreen), findsNothing);
  });

  testWidgets('bottom bar switches tabs', (tester) async {
    await startApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('ذخیره‌شده‌ها'),
      ),
    );
    await settle(tester);

    // Empty favorites tab
    expect(find.text('چیزی ذخیره نکرده‌اید'), findsOneWidget);
  });

  testWidgets('opened care plans show up in "recently viewed"', (
    tester,
  ) async {
    await startApp(tester);
    expect(find.text('اخیراً مشاهده‌شده'), findsNothing);

    final plan = content.carePlans.first;
    await goTo(tester, AppRoutes.carePlan(plan.id));
    await goTo(tester, AppRoutes.home);

    expect(find.text('اخیراً مشاهده‌شده'), findsOneWidget);
    expect(find.text(plan.title), findsWidgets);
  });

  group('state', () {
    test('theme mode cycles and is saved', () async {
      final container = makeContainer(prefs, content);
      final notifier = container.read(themeProvider.notifier);
      expect(container.read(themeProvider).mode, ThemeMode.system);

      await notifier.cycleMode();
      expect(container.read(themeProvider).mode, ThemeMode.light);
      await notifier.cycleMode();
      expect(container.read(themeProvider).mode, ThemeMode.dark);

      // "Restart": a new container reads the saved value back.
      final restarted = makeContainer(prefs, content);
      expect(restarted.read(themeProvider).mode, ThemeMode.dark);
    });

    test('quiz attempts: best and last score, from the server', () async {
      final api = FakeAvaApi();
      final container = makeContainer(prefs, content, api: api);
      await container.read(userDataProvider.future);
      final quiz = content.quizzes.first;
      final notifier = container.read(userDataProvider.notifier);
      Map<String, bool> answers(int right) => {
        for (final (i, q) in quiz.questions.indexed) q.id: i < right,
      };

      await notifier.recordAttempt(quizId: quiz.id, mode: 'exam', answers: answers(2));
      await notifier.recordAttempt(quizId: quiz.id, mode: 'exam', answers: answers(1));

      final saved = container.read(quizProgressProvider)[quiz.id]!;
      expect(saved.best, 2);
      expect(saved.last, 1);
      expect(saved.attempts, 2);
      expect(container.read(quizSummaryProvider).completed, 1);

      // Signing in on "another device" gets the same data.
      final other = makeContainer(prefs, content, api: api);
      expect((await other.read(userDataProvider.future)).progress[quiz.id]?.best, 2);
    });

    test('recently viewed: newest first, no duplicates', () async {
      final container = makeContainer(prefs, content);
      await container.read(userDataProvider.future);
      final notifier = container.read(userDataProvider.notifier);
      final ids = content.carePlans.map((p) => p.id).toList();

      await notifier.recordView(ids[0]);
      await notifier.recordView(ids[1]);
      await notifier.recordView(ids[0]);
      expect(container.read(recentCarePlanIdsProvider), [ids[0], ids[1]]);
    });

    test('favorites toggle, saved on the server', () async {
      final api = FakeAvaApi();
      final container = makeContainer(prefs, content, api: api);
      await container.read(userDataProvider.future);
      final plan = content.carePlans.first;

      await container.read(userDataProvider.notifier).toggleFavorite(plan.id);
      expect(container.read(favoritesProvider), {plan.id});
      expect(container.read(favoriteCarePlansProvider), [plan]);
      expect(api.favorites, {plan.id});

      await container.read(userDataProvider.notifier).toggleFavorite(plan.id);
      expect(container.read(favoritesProvider), isEmpty);
      expect(api.favorites, isEmpty);
    });

    test('a failed change is undone (e.g. offline)', () async {
      final api = FakeAvaApi();
      final container = makeContainer(prefs, content, api: api);
      await container.read(userDataProvider.future);
      api.offline = true;

      await container
          .read(userDataProvider.notifier)
          .toggleFavorite(content.carePlans.first.id);
      expect(container.read(favoritesProvider), isEmpty);
    });

    test('nothing personal is stored on the device', () async {
      final container = makeContainer(prefs, content);
      await container.read(userDataProvider.future);
      final notifier = container.read(userDataProvider.notifier);
      await notifier.toggleFavorite(content.carePlans.first.id);
      await notifier.setNote(content.carePlans.first.id, 'note');
      // Only the session, theme and quiz-mode preferences may be saved.
      expect(
        prefs.getKeys().difference({'session', 'theme_mode', 'theme_seed', 'quiz_mode'}),
        isEmpty,
      );
    });
  });
}
