import 'package:flutter/foundation.dart';

/// A user's record for one quiz.
@immutable
class QuizScore {
  const QuizScore({
    required this.best,
    required this.last,
    required this.total,
    required this.attempts,
  });

  factory QuizScore.fromJson(Map<String, dynamic> json) => QuizScore(
    best: json['best'] as int,
    last: json['last'] as int,
    total: json['total'] as int,
    attempts: json['attempts'] as int,
  );

  final int best;
  final int last;
  final int total;
  final int attempts;
  int get bestPercent => total == 0 ? 0 : (best * 100 / total).round();
}

@immutable
class UserData {
  const UserData({
    this.favorites = const {},
    this.notes = const {},
    this.recent = const [],
    this.progress = const {},
    this.mistakes = const {},
  });

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
    favorites: {...(json['favorites'] as List).cast<String>()},
    notes: (json['notes'] as Map<String, dynamic>).cast<String, String>(),
    recent: List.unmodifiable((json['recent'] as List).cast<String>()),
    progress: {
      for (final e in (json['progress'] as Map<String, dynamic>).entries)
        e.key: QuizScore.fromJson(e.value as Map<String, dynamic>),
    },
    mistakes: {...(json['mistakes'] as List).cast<String>()},
  );

  static const empty = UserData();

  /// Care plan ids.
  final Set<String> favorites;

  /// Care plan id → the user's note.
  final Map<String, String> notes;

  /// Care plan ids, newest first.
  final List<String> recent;

  /// Quiz id → record (the mistakes practice has none).
  final Map<String, QuizScore> progress;

  /// Question ids the user most recently answered wrong.
  final Set<String> mistakes;

  UserData copyWith({
    Set<String>? favorites,
    Map<String, String>? notes,
    List<String>? recent,
  }) => UserData(
    favorites: favorites ?? this.favorites,
    notes: notes ?? this.notes,
    recent: recent ?? this.recent,
    progress: progress,
    mistakes: mistakes,
  );
}
