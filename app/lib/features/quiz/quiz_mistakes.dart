import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/features/account/user_data_controller.dart';
import 'package:ava_web/features/quiz/models/quiz.dart';

/// Id of the generated "review my mistakes" quiz (`/quizzes/mistakes`).
const mistakesQuizId = 'mistakes';

final quizMistakesProvider = Provider<Set<String>>(
  (ref) => ref.watch(_mistakes),
);

final _mistakes = userDataProvider.select(
  (d) => d.value?.mistakes ?? const <String>{},
);

final mistakesQuizProvider = Provider<Quiz?>((ref) {
  final ids = ref.watch(_mistakes);
  if (ids.isEmpty) return null;
  final questions = [
    for (final quiz in ref.watch(quizzesProvider))
      for (final q in quiz.questions)
        if (ids.contains(q.id)) q,
  ];
  if (questions.isEmpty) return null;
  return Quiz(
    id: mistakesQuizId,
    title: 'مرور اشتباهات',
    questions: List.unmodifiable(questions),
  );
});
