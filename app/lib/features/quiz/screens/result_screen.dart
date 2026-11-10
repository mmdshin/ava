import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/app/router.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/features/quiz/quiz_attempt.dart';
import 'package:ava_web/features/quiz/quiz_mistakes.dart';
import 'package:ava_web/features/quiz/quiz_progress.dart';
import 'package:ava_web/features/quiz/widgets/quiz_item.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.attempt});

  final QuizAttempt attempt;

  static String verdict(int percent) => switch (percent) {
    >= 90 => 'عالی بود!',
    >= 75 => 'خیلی خوب',
    >= 50 => 'قابل قبول',
    _ => 'نیاز به مرور بیشتر',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiz = attempt.quiz;
    final colors = context.appColors;
    final isMistakes = quiz.id == mistakesQuizId;
    final best = ref.watch(quizProgressProvider)[quiz.id];
    final mistakesLeft = ref.watch(mistakesQuizProvider)?.questions.length ?? 0;
    final newRecord = attempt.isNewBest && attempt.previousBest != null;

    final sections = <Widget>[
      Center(
        child: ScoreRing(
          percent: attempt.percent,
          size: 168,
          stroke: 14,
          animate: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${attempt.percent}٪',
                style: context.text.headlineMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${attempt.score} از ${attempt.total}',
                style: context.text.labelLarge.copyWith(
                  color: context.onBgMuted,
                ),
              ),
            ],
          ),
        ),
      ),
      Column(
        children: [
          Text(
            verdict(attempt.percent),
            textAlign: TextAlign.center,
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            quiz.title,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium.copyWith(color: context.onBgMuted),
          ),
          if (newRecord) ...[
            const SizedBox(height: AppSpacing.sm),
            _Pill(
              icon: Icons.emoji_events_rounded,
              text:
                  'رکورد جدید! (قبلی ${attempt.previousBest} از ${attempt.total})',
              color: colors.warning,
            ),
          ],
        ],
      ),
      AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            _Stat(
              value: '${attempt.score}',
              label: 'پاسخ درست',
              icon: Icons.check_circle_rounded,
              color: colors.success,
            ),
            _Stat(
              value: '${attempt.wrong}',
              label: 'پاسخ نادرست',
              icon: Icons.cancel_rounded,
              color: colors.danger,
            ),
            if (isMistakes)
              _Stat(
                value: '$mistakesLeft',
                label: 'باقی‌مانده برای مرور',
                icon: Icons.replay_rounded,
                color: colors.accent,
              )
            else if (best != null)
              _Stat(
                value: '${best.bestPercent}٪',
                label: 'بهترین نتیجه',
                icon: Icons.emoji_events_rounded,
                color: colors.warning,
              ),
          ],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () =>
                context.pushReplacement(AppRoutes.quizReview(quiz.id)),
            icon: const Icon(Icons.fact_check_rounded),
            label: const Text('مرور پاسخ‌ها'),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (mistakesLeft > 0) ...[
            OutlinedButton.icon(
              onPressed: () => context.pushReplacement(AppRoutes.quizMistakes),
              icon: const Icon(Icons.replay_rounded),
              label: Text('تمرین سؤال‌های نادرست ($mistakesLeft)'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (!isMistakes) ...[
            OutlinedButton.icon(
              onPressed: () => context.pushReplacement(AppRoutes.quiz(quiz.id)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تکرار آزمون'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          TextButton(
            onPressed: () => context.go(AppRoutes.quizzes),
            child: const Text('بازگشت به آزمون‌ها'),
          ),
        ],
      ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FlowAppBar(
        leading: IconButton(
          tooltip: 'بستن',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go(AppRoutes.quizzes),
        ),
        title: Text('نتیجه آزمون', style: context.text.titleLarge),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                children:
                    [
                          for (final s in sections)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              child: s,
                            ),
                        ]
                        .animate(interval: 80.ms)
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.08, end: 0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        child: ExcludeSemantics(
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: context.text.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: context.text.labelMedium.copyWith(
                  color: context.onBgMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              text,
              style: context.text.labelLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
