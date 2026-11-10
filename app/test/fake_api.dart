import 'package:ava_web/data/api_client.dart';
import 'package:ava_web/data/user_data.dart';

/// An in-memory server for tests: one test user, their data, and
/// the same rules as the real server (progress, mistakes, recent list).
class FakeAvaApi implements AvaApi {
  FakeAvaApi({this.signupOpen = true});

  static const testEmail = 'nurse@example.ir';
  static const testPassword = 'secret-pass-1';
  static const testUser = AppUser(
    id: 1,
    email: testEmail,
    displayName: 'پرستار آزمایشی',
    role: 'nurse',
  );
  static const testSession = AuthSession(token: 'test-token', user: testUser);

  final bool signupOpen;
  final Map<String, String> passwords = {testEmail: testPassword};

  /// When true, every call fails as if offline.
  bool offline = false;

  /// Names of the calls made, in order.
  final calls = <String>[];

  final favorites = <String>{};
  final notes = <String, String>{};
  final recent = <String>[];
  final _attempts = <({String quizId, Map<String, bool> answers})>[];

  void _call(String name) {
    calls.add(name);
    if (offline) throw const ApiException.network();
  }

  @override
  Future<AuthSession> login(String email, String password) async {
    _call('login');
    if (passwords[email.trim().toLowerCase()] != password) {
      throw const ApiException(401, 'wrong_credentials');
    }
    return testSession;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    _call('register');
    if (!signupOpen) throw const ApiException(403, 'signup_closed');
    if (passwords.containsKey(email))
      throw const ApiException(409, 'email_taken');
    if (password.length < 8) throw const ApiException(400, 'weak_password');
    passwords[email] = password;
    return AuthSession(
      token: 'token-$email',
      user: AppUser(
        id: 2,
        email: email,
        displayName: displayName,
        role: 'nurse',
      ),
    );
  }

  @override
  Future<void> logout() async => _call('logout');

  @override
  Future<AppUser> me() async {
    _call('me');
    return testUser;
  }

  @override
  Future<AuthSession> changePassword(String current, String next) async {
    _call('changePassword');
    if (passwords[testEmail] != current) {
      throw const ApiException(401, 'wrong_credentials');
    }
    passwords[testEmail] = next;
    return const AuthSession(token: 'new-token', user: testUser);
  }

  @override
  Future<void> deleteAccount(String password) async {
    _call('deleteAccount');
    if (passwords[testEmail] != password) {
      throw const ApiException(401, 'wrong_credentials');
    }
    passwords.remove(testEmail);
  }

  UserData get data {
    final progress = <String, QuizScore>{};
    final latest = <String, bool>{};
    for (final a in _attempts) {
      latest.addAll(a.answers);
      if (a.quizId == 'mistakes') continue;
      final score = a.answers.values.where((ok) => ok).length;
      final before = progress[a.quizId];
      progress[a.quizId] = QuizScore(
        best: before == null || score > before.best ? score : before.best,
        last: score,
        total: a.answers.length,
        attempts: (before?.attempts ?? 0) + 1,
      );
    }
    return UserData(
      favorites: {...favorites},
      notes: {...notes},
      recent: [...recent],
      progress: progress,
      mistakes: {
        for (final e in latest.entries)
          if (!e.value) e.key,
      },
    );
  }

  @override
  Future<UserData> userData() async {
    _call('userData');
    return data;
  }

  @override
  Future<void> setFavorite(String planId, bool favorite) async {
    _call('setFavorite');
    favorite ? favorites.add(planId) : favorites.remove(planId);
  }

  @override
  Future<void> setNote(String planId, String text) async {
    _call('setNote');
    if (text.trim().isEmpty) {
      notes.remove(planId);
    } else {
      notes[planId] = text.trim();
    }
  }

  @override
  Future<void> recordView(String planId) async {
    _call('recordView');
    recent
      ..remove(planId)
      ..insert(0, planId);
    if (recent.length > 10) recent.removeRange(10, recent.length);
  }

  @override
  Future<void> clearRecent() async {
    _call('clearRecent');
    recent.clear();
  }

  @override
  Future<UserData> recordAttempt({
    required String quizId,
    required String mode,
    required Map<String, bool> answers,
  }) async {
    _call('recordAttempt');
    _attempts.add((quizId: quizId, answers: Map.of(answers)));
    return data;
  }
}
