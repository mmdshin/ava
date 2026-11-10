import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ava_web/data/user_data.dart';

/// An error from the AvA server (or no connection at all).
class ApiException implements Exception {
  const ApiException(this.status, this.code, [this.message = '']);
  const ApiException.network() : this(0, 'network');
  final int status;
  final String code;
  final String message;

  bool get isNetwork => status == 0;

  /// What to tell the user, in Persian.
  String get userMessage => switch (code) {
    'network' => 'اتصال به سرور برقرار نشد. اینترنت را بررسی کنید.',
    'wrong_credentials' => 'ایمیل یا رمز عبور اشتباه است.',
    'email_taken' => 'با این ایمیل قبلاً حساب ساخته شده است.',
    'invalid_email' => 'ایمیل معتبر نیست.',
    'weak_password' => 'رمز عبور باید حداقل 8 نویسه باشد.',
    'too_many_attempts' =>
      'تلاش‌ها زیاد بود. چند دقیقه بعد دوباره امتحان کنید.',
    'signup_closed' => 'ثبت‌نام بسته است. با مدیر سامانه تماس بگیرید.',
    'unauthorized' => 'لطفاً دوباره وارد شوید.',
    'note_too_long' => 'یادداشت بیش از حد طولانی است.',
    _ => 'خطایی رخ داد. دوباره تلاش کنید.',
  };

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    email: json['email'] as String,
    displayName: json['displayName'] as String? ?? '',
    role: json['role'] as String,
  );

  final int id;
  final String email;
  final String displayName;

  /// nurse, editor, reviewer or admin.
  final String role;

  String get name => displayName.isNotEmpty ? displayName : email;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'role': role,
  };
}

/// A login: the secret token for requests and the user.
@immutable
class AuthSession {
  const AuthSession({required this.token, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: json['token'] as String,
    user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
  );

  final String token;
  final AppUser user;

  Map<String, dynamic> toJson() => {'token': token, 'user': user.toJson()};
}

/// The AvA server's account and user-data API
abstract interface class AvaApi {
  Future<AuthSession> login(String email, String password);
  Future<AuthSession> register({
    required String email,
    required String password,
    String displayName = '',
  });
  Future<void> logout();
  Future<AppUser> me();
  Future<AuthSession> changePassword(String current, String next);
  Future<void> deleteAccount(String password);

  Future<UserData> userData();
  Future<void> setFavorite(String planId, bool favorite);
  Future<void> setNote(String planId, String text);
  Future<void> recordView(String planId);
  Future<void> clearRecent();
  Future<UserData> recordAttempt({
    required String quizId,
    required String mode,
    required Map<String, bool> answers,
  });
}

class HttpAvaApi implements AvaApi {
  HttpAvaApi({
    required this.baseUrl,
    required this.token,
    required this.onUnauthorized,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String? Function() token;
  final void Function() onUnauthorized;
  final Duration timeout;
  final http.Client _client;

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Accept'] = 'application/json';
    if (token() case final t?) request.headers['Authorization'] = 'Bearer $t';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      );
    } on TimeoutException {
      throw const ApiException.network();
    } catch (e) {
      debugPrint('$method $path: $e');
      throw const ApiException.network();
    }

    final text = utf8.decode(res.bodyBytes);
    final json = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 200 && res.statusCode < 300) return json;

    final code = json is Map ? json['code'] as String? ?? 'error' : 'error';
    final message = json is Map ? json['error'] as String? ?? '' : '';
    if (res.statusCode == 401 && token() != null) onUnauthorized();
    throw ApiException(res.statusCode, code, message);
  }

  Map<String, dynamic> _map(dynamic json) => json as Map<String, dynamic>;

  @override
  Future<AuthSession> login(String email, String password) async =>
      AuthSession.fromJson(
        _map(
          await _send('POST', '/v1/auth/login', {
            'email': email,
            'password': password,
          }),
        ),
      );

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    String displayName = '',
  }) async => AuthSession.fromJson(
    _map(
      await _send('POST', '/v1/auth/register', {
        'email': email,
        'password': password,
        'displayName': displayName,
      }),
    ),
  );

  @override
  Future<void> logout() => _send('POST', '/v1/auth/logout');

  @override
  Future<AppUser> me() async =>
      AppUser.fromJson(_map(await _send('GET', '/v1/me')));

  @override
  Future<AuthSession> changePassword(String current, String next) async =>
      AuthSession.fromJson(
        _map(
          await _send('POST', '/v1/me/password', {
            'currentPassword': current,
            'newPassword': next,
          }),
        ),
      );

  @override
  Future<void> deleteAccount(String password) =>
      _send('DELETE', '/v1/me', {'password': password});

  @override
  Future<UserData> userData() async =>
      UserData.fromJson(_map(await _send('GET', '/v1/me/data')));

  @override
  Future<void> setFavorite(String planId, bool favorite) =>
      _send(favorite ? 'PUT' : 'DELETE', '/v1/me/favorites/$planId');

  @override
  Future<void> setNote(String planId, String text) => text.trim().isEmpty
      ? _send('DELETE', '/v1/me/notes/$planId')
      : _send('PUT', '/v1/me/notes/$planId', {'text': text});

  @override
  Future<void> recordView(String planId) =>
      _send('POST', '/v1/me/recent/$planId');

  @override
  Future<void> clearRecent() => _send('DELETE', '/v1/me/recent');

  @override
  Future<UserData> recordAttempt({
    required String quizId,
    required String mode,
    required Map<String, bool> answers,
  }) async => UserData.fromJson(
    _map(
      await _send('POST', '/v1/me/quiz-attempts', {
        'quizId': quizId,
        'mode': mode,
        'answers': answers,
      }),
    ),
  );
}
