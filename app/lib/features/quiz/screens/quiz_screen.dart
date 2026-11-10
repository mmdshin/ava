import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/features/account/user_data_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/app/router.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/features/quiz/models/quiz.dart';
import 'package:ava_web/features/quiz/quiz_attempt.dart';
import 'package:ava_web/features/quiz/quiz_mistakes.dart';
import 'package:ava_web/features/quiz/quiz_mode.dart';
import 'package:ava_web/features/quiz/quiz_progress.dart';
import 'package:ava_web/features/quiz/widgets/option_tile.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.quiz});

  final Quiz quiz;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  late final QuizMode _mode = ref.read(quizModeProvider);

  int _current = 0;
  final Map<int, int> _answers = {};

  final Set<int> _checked = {};
  final Set<int> _hintsShown = {};

  List<Question> get _questions => widget.quiz.questions;
  Question get _question => _questions[_current];
  bool get _practice => _mode == QuizMode.practice;
  bool get _isLast => _current == _questions.length - 1;
  bool get _currentChecked => _checked.contains(_current);
  int? get _chosen => _answers[_current];

  int get _correctSoFar =>
      _checked.where((i) => _questions[i].isCorrect(_answers[i])).length;

  void _choose(int option) {
    if (_currentChecked) return;
    HapticFeedback.selectionClick();
    setState(() => _answers[_current] = option);
  }

  void _check() {
    if (_chosen == null) return;
    final right = _question.isCorrect(_chosen);
    right ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
    setState(() => _checked.add(_current));
  }

  void _goTo(int index) => setState(() => _current = index);

  VoidCallback? get _primaryAction {
    if (_chosen == null) return null;
    if (_practice && !_currentChecked) return _check;
    return _isLast ? _finish : () => _goTo(_current + 1);
  }

  String get _primaryLabel {
    if (_practice && !_currentChecked) return 'بررسی پاسخ';
    if (_isLast) return _practice ? 'مشاهده نتیجه' : 'پایان آزمون';
    return _practice ? 'سؤال بعدی' : 'بعدی';
  }

  void _finish() {
    final quiz = widget.quiz;
    final answers = Map.of(_answers);
    final isMistakes = quiz.id == mistakesQuizId;
    final previous = ref.read(quizProgressProvider)[quiz.id];

    ref
        .read(lastQuizAttemptProvider.notifier)
        .record(
          QuizAttempt(
            quiz: quiz,
            answers: answers,
            previousBest: isMistakes ? null : previous?.best,
          ),
        );

    ref
        .read(userDataProvider.notifier)
        .recordAttempt(
          quizId: quiz.id,
          mode: _mode.name,
          answers: {
            for (final (i, q) in _questions.indexed)
              q.id: q.isCorrect(answers[i]),
          },
        );
    context.pushReplacement(AppRoutes.quizResult(quiz.id));
  }

  Future<void> _exit() async {
    if (_answers.isEmpty || await _confirmExit()) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<bool> _confirmExit() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('خروج از آزمون'),
            content: const Text(
              'پاسخ‌های این آزمون ذخیره نمی‌شوند. خارج می‌شوید؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ادامه آزمون'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('خروج'),
              ),
            ],
          ),
        ) ??
        false;
  }

  OptionState _stateOf(int option) {
    final chosen = option == _chosen;
    if (_practice && _currentChecked) {
      if (option == _question.correctIndex) return OptionState.correct;
      if (chosen) return OptionState.wrong;
      return OptionState.dimmed;
    }
    return chosen ? OptionState.selected : OptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final question = _question;

    final shortcuts = <ShortcutActivator, VoidCallback>{
      for (var i = 0; i < question.options.length && i < 6; i++)
        SingleActivator(
          LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
        ): () =>
            _choose(i),
      const SingleActivator(LogicalKeyboardKey.enter): () =>
          _primaryAction?.call(),
    };

    return PopScope(
      canPop: _answers.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _exit();
      },
      child: CallbackShortcuts(
        bindings: shortcuts,
        child: Focus(
          autofocus: true,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: FlowAppBar(
              leading: IconButton(
                tooltip: 'خروج از آزمون',
                icon: const Icon(Icons.close_rounded),
                onPressed: _exit,
              ),
              title: Text(widget.quiz.title, style: context.text.titleLarge),
            ),
            body: AppBackground(
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.sm,
                            AppSpacing.lg,
                            AppSpacing.md,
                          ),
                          child: _ProgressHeader(
                            current: _current,
                            total: _questions.length,
                            practice: _practice,
                            answered: _answers.keys.toSet(),
                            checked: {
                              for (final i in _checked)
                                i: _questions[i].isCorrect(_answers[i]),
                            },
                            correctSoFar: _correctSoFar,
                          ),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: ListView(
                              key: ValueKey(_current),
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.lg,
                              ),
                              children: [
                                _QuestionCard(
                                  number: _current + 1,
                                  text: question.text,
                                ),
                                if (question.hint != null && !_currentChecked)
                                  _Hint(
                                    hint: question.hint!,
                                    shown: _hintsShown.contains(_current),
                                    onToggle: () => setState(() {
                                      if (!_hintsShown.remove(_current)) {
                                        _hintsShown.add(_current);
                                      }
                                    }),
                                  ),
                                const SizedBox(height: AppSpacing.md),
                                for (final (i, option)
                                    in question.options.indexed) ...[
                                  OptionTile(
                                    key: ValueKey('option-$i'),
                                    index: i,
                                    text: option,
                                    state: _stateOf(i),
                                    onTap: _practice && _currentChecked
                                        ? null
                                        : () => _choose(i),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                ],
                                if (_practice && _currentChecked)
                                  _Feedback(
                                    key: const ValueKey('quiz-feedback'),
                                    correct: question.isCorrect(_chosen),
                                    correctLetter: optionLetter(
                                      question.correctIndex,
                                    ),
                                    explanation: question.explanation,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        _BottomBar(
                          showBack: !_practice && _current > 0,
                          onBack: () => _goTo(_current - 1),
                          primaryLabel: _primaryLabel,
                          onPrimary: _primaryAction,
                          primaryIcon: _practice && !_currentChecked
                              ? Icons.fact_check_rounded
                              : _isLast
                              ? Icons.flag_rounded
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.current,
    required this.total,
    required this.practice,
    required this.answered,
    required this.checked,
    required this.correctSoFar,
  });

  final int current;
  final int total;
  final bool practice;
  final Set<int> answered;

  final Map<int, bool> checked;
  final int correctSoFar;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Color segment(int i) {
      if (i == current) return colors.accent;
      if (practice) {
        return switch (checked[i]) {
          true => colors.success,
          false => colors.danger,
          null => colors.glass.withValues(alpha: 0.15),
        };
      }
      return answered.contains(i)
          ? colors.accent.withValues(alpha: 0.45)
          : colors.glass.withValues(alpha: 0.15);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'سؤال ${current + 1} از $total',
                style: context.text.labelLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (practice && checked.isNotEmpty)
              Text(
                '$correctSoFar درست از ${checked.length}',
                style: context.text.labelLarge.copyWith(
                  color: context.onBgMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: i == current ? 6 : 4,
                    decoration: BoxDecoration(
                      color: segment(i),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سؤال $number',
            style: context.text.labelLarge.copyWith(
              color: context.appColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            header: true,
            child: Text(
              text,
              style: context.text.titleMedium.copyWith(
                height: 1.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({
    required this.hint,
    required this.shown,
    required this.onToggle,
  });
  final String hint;
  final bool shown;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.warning;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: onToggle,
            style: TextButton.styleFrom(foregroundColor: color),
            icon: Icon(
              shown ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
            ),
            label: Text(shown ? 'پنهان کردن راهنمایی' : 'نمایش راهنمایی'),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: shown
                ? AppCard(
                    accent: color,
                    radius: AppRadius.md,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      hint,
                      style: context.text.bodyMedium.copyWith(height: 1.8),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    super.key,
    required this.correct,
    required this.correctLetter,
    this.explanation,
  });

  final bool correct;
  final String correctLetter;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final color = correct
        ? context.appColors.success
        : context.appColors.danger;
    return Semantics(
      liveRegion: true,
      child: AppCard(
        accent: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    correct
                        ? 'آفرین! پاسخ درست است'
                        : 'پاسخ درست گزینه «$correctLetter» است',
                    style: context.text.titleSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (explanation != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                explanation!,
                style: context.text.bodyMedium.copyWith(height: 1.8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.showBack,
    required this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
    required this.primaryIcon,
  });

  final bool showBack;
  final VoidCallback onBack;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  final IconData? primaryIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.appColors.dialogSurface.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: context.appColors.glass.withValues(alpha: 0.12),
          ),
        ),
      ),

      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            if (showBack) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  child: const BackLabel('قبلی'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: onPrimary,
                child: primaryIcon == null
                    ? NextLabel(primaryLabel)
                    : Directionality(
                        textDirection: TextDirection.rtl,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(primaryIcon, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(child: Text(primaryLabel)),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
