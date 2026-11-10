import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/common/messenger.dart';
import 'package:ava_web/data/user_data.dart';
import 'package:ava_web/features/account/session.dart';

final userDataProvider = AsyncNotifierProvider<UserDataNotifier, UserData>(
  UserDataNotifier.new,
);

class UserDataNotifier extends AsyncNotifier<UserData> {
  @override
  Future<UserData> build() async {
    final token = ref.watch(authProvider.select((s) => s?.token));
    if (token == null) return UserData.empty;
    return ref.read(apiProvider).userData();
  }

  UserData get _current => state.value ?? UserData.empty;

  Future<bool> _optimistic(UserData next, Future<void> Function() send) async {
    final before = _current;
    state = AsyncData(next);
    try {
      await send();
      return true;
    } catch (e) {
      state = AsyncData(before);
      showApiError(e);
      return false;
    }
  }

  Future<void> toggleFavorite(String planId) {
    final on = !_current.favorites.contains(planId);
    final favorites = {..._current.favorites};
    if (on) {
      favorites.add(planId);
    } else {
      favorites.remove(planId);
    }
    return _optimistic(
      _current.copyWith(favorites: favorites),
      () => ref.read(apiProvider).setFavorite(planId, on),
    );
  }

  Future<bool> setNote(String planId, String text) {
    final notes = {..._current.notes};
    if (text.trim().isEmpty) {
      notes.remove(planId);
    } else {
      notes[planId] = text.trim();
    }
    return _optimistic(
      _current.copyWith(notes: notes),
      () => ref.read(apiProvider).setNote(planId, text.trim()),
    );
  }

  Future<void> recordView(String planId) async {
    final recent = [
      planId,
      ..._current.recent.where((id) => id != planId),
    ].take(10).toList(growable: false);
    state = AsyncData(_current.copyWith(recent: recent));
    try {
      await ref.read(apiProvider).recordView(planId);
    } catch (_) {}
  }

  Future<void> clearRecent() => _optimistic(
    _current.copyWith(recent: const []),
    () => ref.read(apiProvider).clearRecent(),
  );

  Future<bool> recordAttempt({
    required String quizId,
    required String mode,
    required Map<String, bool> answers,
  }) async {
    try {
      state = AsyncData(
        await ref
            .read(apiProvider)
            .recordAttempt(quizId: quizId, mode: mode, answers: answers),
      );
      return true;
    } catch (e) {
      showApiError(e);
      return false;
    }
  }
}
