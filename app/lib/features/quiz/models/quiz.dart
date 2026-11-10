import 'dart:math';

import 'package:ava_web/features/care_plans/models/care_plan.dart';

class Quiz {
  const Quiz({
    required this.id,
    required this.title,
    required this.questions,
    this.kind,
  });

  /// [kinds]: the content's categories by id.
  factory Quiz.fromJson(Map<String, dynamic> json, Map<String, Kind> kinds) {
    return Quiz(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: switch (json['kind']) {
        final String k when k.isNotEmpty =>
          kinds[k] ??
              (throw FormatException(
                'quiz "${json['id']}": unknown category "$k"',
              )),
        _ => null,
      },
      questions: List.unmodifiable(
        (json['questions'] as List).map(
          (q) => Question.fromJson(q as Map<String, dynamic>),
        ),
      ),
    );
  }

  final String id;
  final String title;
  final List<Question> questions;
  final Kind? kind;

  /// A copy with the questions in random order and each question's
  /// options shuffled (the correct answer moves with them), so every
  /// attempt is a little different and position can't be memorized.
  Quiz shuffled([Random? random]) {
    final rng = random ?? Random();
    final qs = [for (final q in questions) q.withShuffledOptions(rng)]
      ..shuffle(rng);
    return Quiz(
      id: id,
      title: title,
      kind: kind,
      questions: List.unmodifiable(qs),
    );
  }

  /// Number of correct answers. [answers] maps question index → chosen
  /// option index.
  int score(Map<int, int> answers) {
    var correct = 0;
    for (var i = 0; i < questions.length; i++) {
      if (questions[i].isCorrect(answers[i])) correct++;
    }
    return correct;
  }
}

class Question {
  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.hint,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      text: json['text'] as String,
      options: List.unmodifiable((json['options'] as List).cast<String>()),
      correctIndex: json['correctIndex'] as int,
      explanation: json['explanation'] as String?,
      hint: json['hint'] as String?,
    );
  }

  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String? explanation;
  final String? hint;

  bool isCorrect(int? answer) => answer == correctIndex;

  Question withShuffledOptions(Random rng) {
    final order = List<int>.generate(options.length, (i) => i)..shuffle(rng);
    return Question(
      id: id,
      text: text,
      options: List.unmodifiable([for (final i in order) options[i]]),
      correctIndex: order.indexOf(correctIndex),
      explanation: explanation,
      hint: hint,
    );
  }
}
