import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/core/config.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/data/api_client.dart';

final apiProvider = Provider<AvaApi>(
  (ref) => HttpAvaApi(
    baseUrl: AppConfig.apiBaseUrl,
    token: () => ref.read(authProvider)?.token,
    onUnauthorized: () => ref.read(authProvider.notifier).expired(),
  ),
);

final authProvider = NotifierProvider<AuthNotifier, AuthSession?>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthSession?> {
  static const prefsKey = 'session';

  @override
  AuthSession? build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(prefsKey);
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(AuthSession? session) async {
    state = session;
    final prefs = ref.read(sharedPreferencesProvider);
    if (session == null) {
      await prefs.remove(prefsKey);
    } else {
      await prefs.setString(prefsKey, jsonEncode(session.toJson()));
    }
  }

  Future<void> login(String email, String password) async =>
      _save(await ref.read(apiProvider).login(email.trim(), password));

  Future<void> register({
    required String email,
    required String password,
    String displayName = '',
  }) async => _save(
    await ref
        .read(apiProvider)
        .register(
          email: email.trim(),
          password: password,
          displayName: displayName.trim(),
        ),
  );

  Future<void> logout() async {
    try {
      await ref.read(apiProvider).logout();
    } catch (_) {}
    await _save(null);
  }

  Future<void> changePassword(String current, String next) async =>
      _save(await ref.read(apiProvider).changePassword(current, next));

  Future<void> deleteAccount(String password) async {
    await ref.read(apiProvider).deleteAccount(password);
    await _save(null);
  }

  void expired() {
    if (state != null) _save(null);
  }
}
