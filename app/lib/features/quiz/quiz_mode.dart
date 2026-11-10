import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/core/providers.dart';

enum QuizMode { practice, exam }

final quizModeProvider = NotifierProvider<QuizModeNotifier, QuizMode>(
  QuizModeNotifier.new,
);

class QuizModeNotifier extends Notifier<QuizMode> {
  static const prefsKey = 'quiz_mode';

  @override
  QuizMode build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(prefsKey);
    return QuizMode.values.asNameMap()[saved] ?? QuizMode.practice;
  }

  Future<void> set(QuizMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(prefsKey, mode.name);
  }
}
