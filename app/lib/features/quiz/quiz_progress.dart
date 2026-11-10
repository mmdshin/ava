import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/data/user_data.dart';
import 'package:ava_web/features/account/user_data_controller.dart';

export 'package:ava_web/data/user_data.dart' show QuizScore;

final quizProgressProvider = Provider<Map<String, QuizScore>>(
  (ref) => ref.watch(_progress),
);

final _progress = userDataProvider.select(
  (d) => d.value?.progress ?? const <String, QuizScore>{},
);

final quizSummaryProvider =
    Provider<({int completed, int total, int avgPercent})>((ref) {
      final quizzes = ref.watch(quizzesProvider);
      final progress = ref.watch(_progress);
      final taken = [
        for (final q in quizzes)
          if (progress[q.id] case final score?) score,
      ];
      final avg = taken.isEmpty
          ? 0
          : (taken.map((s) => s.bestPercent).reduce((a, b) => a + b) /
                    taken.length)
                .round();
      return (completed: taken.length, total: quizzes.length, avgPercent: avg);
    });
