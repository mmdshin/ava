import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ava_web/app/router.dart';
import 'package:ava_web/data/content_repository.dart';
import 'package:ava_web/features/about/about_info.dart';
import 'package:ava_web/features/account/user_data_controller.dart';
import 'package:ava_web/features/care_plans/care_plan_notes.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/gordon_assessment/matching.dart';
import 'package:ava_web/features/gordon_assessment/models/assessment_item.dart';
import 'package:ava_web/features/gordon_assessment/screens/gordon_assessment_page.dart';
import 'package:ava_web/features/gordon_assessment/screens/matched_gordon_careplans_screen.dart';
import 'package:flutter/material.dart' show TextField;
import 'package:ava_web/features/quiz/quiz_mistakes.dart';
import 'package:ava_web/features/quiz/quiz_progress.dart';
import 'package:ava_web/features/quiz/screens/quiz_screen.dart';
import 'package:ava_web/features/quiz/screens/result_screen.dart';
import 'package:ava_web/features/quiz/screens/review_answer_screen.dart';

import 'helpers.dart';

void main() {
  late ContentRepository content;

  setUpAll(() async {
    content = await loadTestContent();
  });

  group('quiz shuffling', () {
    test('same questions, options moved, correct answer follows', () {
      final quiz = content.quizzes.first;
      final shuffled = quiz.shuffled(Random(42));

      expect(shuffled.id, quiz.id);
      expect(
        shuffled.questions.map((q) => q.id).toSet(),
        quiz.questions.map((q) => q.id).toSet(),
      );
      for (final q in shuffled.questions) {
        final original = quiz.questions.firstWhere((o) => o.id == q.id);
        expect(q.options.toSet(), original.options.toSet());
        // the option text marked correct is still the right one
        expect(
          q.options[q.correctIndex],
          original.options[original.correctIndex],
        );
      }
    });

    test('scoring works on the shuffled quiz', () {
      final shuffled = content.quizzes.first.shuffled(Random(7));
      final allRight = {
        for (var i = 0; i < shuffled.questions.length; i++)
          i: shuffled.questions[i].correctIndex,
      };
      expect(shuffled.score(allRight), shuffled.questions.length);
    });
  });

  group('mistakes', () {
    test('wrong answers are added, right answers removed', () async {
      final container = makeContainer(await mockPrefs(), content);
      await container.read(userDataProvider.future);
      final quiz = content.quizzes.first;
      final notifier = container.read(userDataProvider.notifier);

      // everything wrong
      await notifier.recordAttempt(
        quizId: quiz.id,
        mode: 'practice',
        answers: {for (final q in quiz.questions) q.id: false},
      );
      expect(
        container.read(quizMistakesProvider),
        quiz.questions.map((q) => q.id).toSet(),
      );
      final practice = container.read(mistakesQuizProvider)!;
      expect(practice.id, mistakesQuizId);
      expect(practice.questions.length, quiz.questions.length);

      // now answer the first question correctly in mistakes practice
      await notifier.recordAttempt(
        quizId: mistakesQuizId,
        mode: 'practice',
        answers: {quiz.questions[0].id: true},
      );
      expect(
        container.read(quizMistakesProvider),
        isNot(contains(quiz.questions[0].id)),
      );
      // practising mistakes doesn't create a score for "mistakes"
      expect(container.read(quizProgressProvider).keys, [quiz.id]);
    });

    test('no mistakes → no practice quiz', () async {
      final container = makeContainer(await mockPrefs(), content);
      await container.read(userDataProvider.future);
      expect(container.read(mistakesQuizProvider), isNull);
    });
  });

  group('care plan notes & text', () {
    test('notes are saved on the server, and empty text deletes them', () async {
      final api = FakeAvaApi();
      final container = makeContainer(await mockPrefs(), content, api: api);
      await container.read(userDataProvider.future);
      final id = content.carePlans.first.id;
      final notifier = container.read(userDataProvider.notifier);

      expect(await notifier.setNote(id, '  یادداشت آزمایشی  '), isTrue);
      expect(container.read(carePlanNotesProvider)[id], 'یادداشت آزمایشی');
      expect(api.notes[id], 'یادداشت آزمایشی');

      await notifier.setNote(id, '   ');
      expect(container.read(carePlanNotesProvider).containsKey(id), isFalse);
      expect(api.notes, isEmpty);
    });

    test('plain-text export has title, every section and item, and note', () {
      final plan = content.carePlans.first;
      final text = carePlanAsText(plan, note: 'نکته من');
      expect(text, contains(plan.title));
      for (final s in plan.sections) {
        expect(text, contains(s.title));
        for (final item in s.items) {
          expect(text, contains(item));
        }
      }
      expect(text, contains('نکته من'));
    });
  });

  group('diagnosis finder reasons', () {
    test('only selected findings sharing a tag are reasons', () {
      const plan = CarePlan(
        id: 'p',
        kind: TestKinds.general,
        title: 'p',
        tags: ['pain', 'anxiety'],
        sections: [],
      );
      const items = [
        AssessmentItem(id: 'a', title: 'درد', tags: ['pain']),
        AssessmentItem(id: 'b', title: 'تب', tags: ['fever']),
        AssessmentItem(id: 'c', title: 'اضطراب', tags: ['anxiety', 'x']),
      ];
      expect(matchReasons(plan, items).map((i) => i.id), ['a', 'c']);
    });
  });

  group('routes', () {
    late SharedPreferences prefs;
    setUp(() async => prefs = await mockPrefs());

    Future<void> start(WidgetTester tester, {FakeAvaApi? api}) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(prefs, content, api: api));
      await settle(tester);
    }

    Future<void> goTo(WidgetTester tester, String location) async {
      GoRouter.of(tester.element(find.byType(Navigator).first)).go(location);
      await settle(tester);
    }

    testWidgets('assessment results without a submission → the assessment', (
      tester,
    ) async {
      await start(tester);
      await goTo(tester, AppRoutes.assessmentResults(TestKinds.acs));
      expect(find.byType(GordonAssessmentPage), findsOneWidget);
    });

    testWidgets('finder flow: disease → tick finding → live summary → results', (
      tester,
    ) async {
      await start(tester);
      await goTo(tester, AppRoutes.assessment);

      // Step 1: all five options, "general" included.
      expect(find.text('تشخیص‌های عمومی'), findsOneWidget);
      await tester.tap(find.text('سندرم کرونری حاد'));
      await settle(tester);
      expect(find.byType(GordonAssessmentPage), findsOneWidget);

      // Step 2: nothing selected yet → results button disabled.
      expect(find.text('هنوز یافته‌ای انتخاب نشده'), findsOneWidget);

      // The first pattern starts open; tick its first finding.
      final first = content.gordonDomains.first.items.first;
      await tester.tap(find.text(first.title));
      await settle(tester);
      expect(find.text('1 یافته انتخاب شده'), findsOneWidget);

      await tester.tap(find.text('مشاهده نتایج'));
      await settle(tester);
      expect(find.byType(MatchedGordonCarePlansScreen), findsOneWidget);

      // "Edit findings" goes back with the selection kept.
      await tester.tap(find.text('ویرایش یافته‌ها'));
      await settle(tester);
      expect(find.byType(GordonAssessmentPage), findsOneWidget);
      expect(find.text('1 یافته انتخاب شده'), findsOneWidget);
    });

    testWidgets('finder search filters findings', (tester) async {
      await start(tester);
      await goTo(tester, AppRoutes.assessmentFor(TestKinds.general));

      await tester.enterText(find.byType(TextField), 'zzzz');
      await settle(tester);
      expect(find.text('یافته‌ای با «zzzz» پیدا نشد'), findsOneWidget);

      // A real finding title from a later pattern shows up (its section
      // opens automatically while searching).
      final last = content.gordonDomains.last.items.first;
      await tester.enterText(find.byType(TextField), last.title);
      await settle(tester);
      // once in the search box itself, once as the finding chip
      expect(find.text(last.title), findsNWidgets(2));
      expect(find.textContaining('پیدا نشد'), findsNothing);
    });

    testWidgets('about page shows the disclaimer and research codes', (
      tester,
    ) async {
      await start(tester);
      await goTo(tester, AppRoutes.about);
      expect(find.text('هشدار مهم'), findsOneWidget);
      expect(find.text(AboutInfo.trialCode), findsOneWidget);
      expect(find.text(AboutInfo.faculty), findsOneWidget);
      expect(find.text(AboutInfo.appVersion), findsOneWidget);
    });

    // Answers every question with option "الف" (index 0).
    Future<void> takeQuiz(WidgetTester tester, String id, {required bool practice}) async {
      final quiz = content.quizzes.firstWhere((q) => q.id == id);
      for (var i = 0; i < quiz.questions.length; i++) {
        await tester.tap(find.byKey(const ValueKey('option-0')));
        await settle(tester);
        if (practice) {
          await tester.tap(find.text('بررسی پاسخ'));
          await settle(tester);
          expect(find.byKey(const ValueKey('quiz-feedback')), findsOneWidget);
        }
        final last = i == quiz.questions.length - 1;
        await tester.tap(find.text(
          last
              ? (practice ? 'مشاهده نتیجه' : 'پایان آزمون')
              : (practice ? 'سؤال بعدی' : 'بعدی'),
        ));
        await settle(tester);
      }
    }

    testWidgets('practice mode: check, feedback, result, review', (
      tester,
    ) async {
      final api = FakeAvaApi();
      await start(tester, api: api);
      final quiz = content.quizzes.last;
      await goTo(tester, AppRoutes.quiz(quiz.id));
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.text('سؤال 1 از ${quiz.questions.length}'), findsOneWidget);

      await takeQuiz(tester, quiz.id, practice: true);
      expect(find.byType(ResultScreen), findsOneWidget);
      expect(api.calls, contains('recordAttempt'));

      await tester.tap(find.text('مرور پاسخ‌ها'));
      await settle(tester);
      expect(find.byType(ReviewAnswersScreen), findsOneWidget);
    });

    testWidgets('exam mode: back and forth, then result', (tester) async {
      prefs = await mockPrefs({'quiz_mode': 'exam'});
      await start(tester);
      final quiz = content.quizzes.last;
      await goTo(tester, AppRoutes.quiz(quiz.id));

      // Next is disabled until an answer is chosen; no instant feedback.
      await tester.tap(find.byKey(const ValueKey('option-1')));
      await settle(tester);
      await tester.tap(find.text('بعدی'));
      await settle(tester);
      expect(find.text('سؤال 2 از ${quiz.questions.length}'), findsOneWidget);
      await tester.tap(find.text('قبلی'));
      await settle(tester);
      expect(find.text('سؤال 1 از ${quiz.questions.length}'), findsOneWidget);
      expect(find.text('بررسی پاسخ'), findsNothing);

      await takeQuiz(tester, quiz.id, practice: false);
      expect(find.byType(ResultScreen), findsOneWidget);
    });

    testWidgets('mistakes practice with no mistakes → not found', (
      tester,
    ) async {
      await start(tester);
      await goTo(tester, AppRoutes.quizMistakes);
      expect(find.text('صفحه موردنظر پیدا نشد'), findsOneWidget);
    });
  });
}
