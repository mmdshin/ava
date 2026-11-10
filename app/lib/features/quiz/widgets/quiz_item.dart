import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/core/kind_style.dart';
import 'package:ava_web/features/quiz/models/quiz.dart';
import 'package:ava_web/features/quiz/quiz_progress.dart';

Color quizColor(BuildContext context, Quiz quiz) => switch (quiz.kind) {
  final kind? => context.kindTone(kind),
  null => context.appColors.accent,
};

IconData quizIcon(Quiz quiz) => switch (quiz.kind) {
  final kind? => kindIcon(kind),
  null => Icons.auto_awesome_rounded,
};

int estimatedMinutes(Quiz quiz) =>
    (quiz.questions.length / 2).ceil().clamp(1, 99);

class QuizCard extends StatelessWidget {
  const QuizCard({
    super.key,
    required this.quiz,
    required this.score,
    required this.onTap,
  });

  final Quiz quiz;
  final QuizScore? score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = quizColor(context, quiz);
    final count = quiz.questions.length;
    final details = [
      '$count سؤال',
      'حدود ${estimatedMinutes(quiz)} دقیقه',
      if (score case final s?) '${s.attempts} بار انجام شده',
    ].join(' · ');

    return AppCard(
      onTap: onTap,
      semanticLabel: [
        'آزمون ${quiz.title}',
        details,
        if (score case final s?) 'بهترین نتیجه ${s.bestPercent} درصد',
      ].join('، '),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(quizIcon(quiz), color: color, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  details,
                  style: context.text.labelLarge.copyWith(
                    color: context.onBgMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (score case final s?)
            ScoreRing(percent: s.bestPercent, size: 48)
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'جدید',
                style: context.text.labelMedium.copyWith(
                  color: context.legible(color),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Color scoreColor(BuildContext context, int percent) {
  final colors = context.appColors;
  if (percent >= 75) return colors.success;
  if (percent >= 50) return colors.caution;
  return colors.danger;
}

class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.percent,
    this.size = 48,
    this.stroke,
    this.animate = false,
    this.child,
  });

  final int percent;
  final double size;
  final double? stroke;
  final bool animate;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(context, percent);
    final target = percent / 100;

    Widget ring(double value) => SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: stroke ?? size / 10,
              strokeCap: StrokeCap.round,
              backgroundColor: context.appColors.glass.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          child ??
              Text(
                '$percent٪',
                style: context.text.labelMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
        ],
      ),
    );

    return Semantics(
      label: 'نتیجه $percent درصد',
      child: ExcludeSemantics(
        child: animate
            ? TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: target),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => ring(value),
              )
            : ring(target),
      ),
    );
  }
}
