import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/app/router.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/common/widgets/section_header.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/features/quiz/models/quiz.dart';
import 'package:ava_web/features/quiz/quiz_mistakes.dart';
import 'package:ava_web/features/quiz/quiz_mode.dart';
import 'package:ava_web/features/quiz/quiz_progress.dart';
import 'package:ava_web/features/quiz/widgets/quiz_item.dart';

class QuizListScreen extends ConsumerWidget {
  const QuizListScreen({super.key, required this.quizzes});

  final List<Quiz> quizzes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(quizProgressProvider);
    final mistakes = ref.watch(mistakesQuizProvider);
    final summary = ref.watch(quizSummaryProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FlowAppBar(
        title: Text('آزمون‌ها', style: context.text.titleLarge),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: quizzes.isEmpty
                  ? Center(
                      child: Text(
                        'آزمونی موجود نیست',
                        style: context.text.titleMedium,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 700 ? 2 : 1;
                        const gap = AppSpacing.md;
                        final cardWidth =
                            (constraints.maxWidth -
                                AppSpacing.lg * 2 -
                                gap * (columns - 1)) /
                            columns;

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.sm,
                            AppSpacing.lg,
                            AppSpacing.xl,
                          ),
                          children: [
                            Text(
                              'آموزش زبان استاندارد پرستاری',
                              style: context.text.headlineSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'با پاسخ به سؤال‌ها و خواندن توضیح هر پاسخ، '
                              'تشخیص‌ها و مداخلات پرستاری را تمرین کنید.',
                              style: context.text.bodyMedium.copyWith(
                                color: context.onBgMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _Overview(
                              completed: summary.completed,
                              total: summary.total,
                              average: summary.avgPercent,
                              mistakes: mistakes?.questions.length ?? 0,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const _ModePicker(),
                            if (mistakes != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              _MistakesCard(
                                count: mistakes.questions.length,
                                onTap: () =>
                                    context.push(AppRoutes.quizMistakes),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            const SectionHeader(title: 'همه آزمون‌ها'),
                            Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children:
                                  [
                                        for (final quiz in quizzes)
                                          SizedBox(
                                            width: cardWidth,
                                            child: QuizCard(
                                              quiz: quiz,
                                              score: progress[quiz.id],
                                              onTap: () => context.push(
                                                AppRoutes.quiz(quiz.id),
                                              ),
                                            ),
                                          ),
                                      ]
                                      .animate(interval: 40.ms)
                                      .fadeIn(duration: 300.ms)
                                      .slideY(begin: 0.06, end: 0),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.completed,
    required this.total,
    required this.average,
    required this.mistakes,
  });

  final int completed;
  final int total;
  final int average;
  final int mistakes;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Widget stat(String value, String label, IconData icon, Color color) =>
        Expanded(
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

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          stat(
            '$completed/$total',
            'آزمون انجام‌شده',
            Icons.task_alt_rounded,
            colors.accent,
          ),
          stat(
            completed == 0 ? '–' : '$average٪',
            'میانگین بهترین نتیجه',
            Icons.insights_rounded,
            colors.success,
          ),
          stat(
            '$mistakes',
            'سؤال برای مرور',
            Icons.replay_rounded,
            mistakes == 0 ? context.onBgMuted : colors.danger,
          ),
        ],
      ),
    );
  }
}

/// Practice (check each answer) vs exam (results at the end).
class _ModePicker extends ConsumerWidget {
  const _ModePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(quizModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<QuizMode>(
          segments: const [
            ButtonSegment(
              value: QuizMode.practice,
              icon: Icon(Icons.school_rounded),
              label: Text('آموزشی'),
            ),
            ButtonSegment(
              value: QuizMode.exam,
              icon: Icon(Icons.assignment_rounded),
              label: Text('آزمون'),
            ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              ref.read(quizModeProvider.notifier).set(s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          mode == QuizMode.practice
              ? 'پاسخ هر سؤال را همان لحظه بررسی کنید و توضیح آن را بخوانید.'
              : 'به همه سؤال‌ها پاسخ دهید و نتیجه را در پایان ببینید.',
          textAlign: TextAlign.center,
          style: context.text.labelLarge.copyWith(color: context.onBgMuted),
        ),
      ],
    );
  }
}

/// Entry point to "review my mistakes", shown only when there are some.
class _MistakesCard extends StatelessWidget {
  const _MistakesCard({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.danger;
    return AppCard(
      accent: color,
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.replay_rounded, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرور اشتباهات',
                  style: context.text.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$count سؤال که آخرین بار اشتباه پاسخ دادید',
                  style: context.text.labelLarge.copyWith(
                    color: context.onBgMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
        ],
      ),
    );
  }
}
