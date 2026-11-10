import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/features/quiz/models/quiz.dart';
import 'package:ava_web/features/quiz/quiz_attempt.dart';
import 'package:ava_web/features/quiz/widgets/option_tile.dart';

enum _Filter { wrong, correct, all }

class ReviewAnswersScreen extends StatefulWidget {
  const ReviewAnswersScreen({super.key, required this.attempt});

  final QuizAttempt attempt;

  @override
  State<ReviewAnswersScreen> createState() => _ReviewAnswersScreenState();
}

class _ReviewAnswersScreenState extends State<ReviewAnswersScreen> {
  late _Filter _filter = widget.attempt.wrong > 0 ? _Filter.wrong : _Filter.all;

  @override
  Widget build(BuildContext context) {
    final attempt = widget.attempt;
    final questions = attempt.quiz.questions;

    bool isCorrect(int i) => questions[i].isCorrect(attempt.answers[i]);
    final visible = [
      for (var i = 0; i < questions.length; i++)
        if (switch (_filter) {
          _Filter.all => true,
          _Filter.wrong => !isCorrect(i),
          _Filter.correct => isCorrect(i),
        })
          i,
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FlowAppBar(
        title: Text('مرور پاسخ‌ها', style: context.text.titleLarge),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                children: [
                  SegmentedButton<_Filter>(
                    segments: [
                      ButtonSegment(
                        value: _Filter.wrong,
                        label: Text('نادرست (${attempt.wrong})'),
                      ),
                      ButtonSegment(
                        value: _Filter.correct,
                        label: Text('درست (${attempt.score})'),
                      ),
                      ButtonSegment(
                        value: _Filter.all,
                        label: Text('همه (${attempt.total})'),
                      ),
                    ],
                    selected: {_filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _filter = s.first),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl),
                      child: Text(
                        _filter == _Filter.wrong
                            ? 'همه پاسخ‌ها درست بود 🎉'
                            : 'پاسخ درستی در این آزمون نبود',
                        textAlign: TextAlign.center,
                        style: context.text.titleMedium.copyWith(
                          color: context.onBgMuted,
                        ),
                      ),
                    ),
                  for (final (n, i) in visible.indexed)
                    Padding(
                      key: ValueKey('review-$i'),
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _ReviewCard(
                        number: i + 1,
                        question: questions[i],
                        answer: attempt.answers[i],
                      ),
                    ).animate().fadeIn(
                      delay: (40 * n.clamp(0, 8)).ms,
                      duration: 300.ms,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({
    required this.number,
    required this.question,
    required this.answer,
  });

  final int number;
  final Question question;
  final int? answer;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  late bool _showExplanation = !widget.question.isCorrect(widget.answer);

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final correct = q.isCorrect(widget.answer);
    final colors = context.appColors;
    final tone = correct ? colors.success : colors.danger;

    OptionState stateOf(int i) {
      if (i == q.correctIndex) return OptionState.correct;
      if (i == widget.answer) return OptionState.wrong;
      return OptionState.idle;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: tone,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                correct ? 'درست' : 'نادرست',
                style: context.text.labelLarge.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '· سؤال ${widget.number}',
                style: context.text.labelLarge.copyWith(
                  color: context.onBgMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            q.text,
            style: context.text.titleSmall.copyWith(
              height: 1.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (i, option) in q.options.indexed) ...[
            OptionTile(
              index: i,
              text: option,
              state: stateOf(i),
              compact: true,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (q.explanation case final explanation?) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _showExplanation = !_showExplanation),
              style: TextButton.styleFrom(foregroundColor: colors.warning),
              icon: Icon(
                _showExplanation
                    ? Icons.expand_less_rounded
                    : Icons.lightbulb_outline_rounded,
              ),
              label: Text(_showExplanation ? 'بستن توضیح' : 'نمایش توضیح'),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              alignment: Alignment.topCenter,
              child: _showExplanation
                  ? AppCard(
                      accent: colors.warning,
                      radius: AppRadius.md,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        explanation,
                        style: context.text.bodyMedium.copyWith(height: 1.8),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}
