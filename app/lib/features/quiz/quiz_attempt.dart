import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/features/quiz/models/quiz.dart';
import 'package:ava_web/features/quiz/quiz_mistakes.dart';

@immutable
class QuizAttempt {
  const QuizAttempt({
    required this.quiz,
    required this.answers,
    this.previousBest,
  });

  final Quiz quiz;
  final Map<int, int> answers;

  final int? previousBest;

  String get quizId => quiz.id;
  int get score => quiz.score(answers);
  int get total => quiz.questions.length;
  int get wrong => total - score;
  int get percent => total == 0 ? 0 : (score * 100 / total).round();

  bool get isNewBest =>
      quiz.id != mistakesQuizId &&
      (previousBest == null || score > previousBest!);
}

final lastQuizAttemptProvider =
    NotifierProvider<LastQuizAttemptNotifier, QuizAttempt?>(
      LastQuizAttemptNotifier.new,
    );

class LastQuizAttemptNotifier extends Notifier<QuizAttempt?> {
  @override
  QuizAttempt? build() => null;

  void record(QuizAttempt attempt) => state = attempt;
}
