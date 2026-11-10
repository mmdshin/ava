import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ava_web/admin/data/models.dart';

/// An error from the editing API.
class AdminException implements Exception {
  const AdminException(
    this.status,
    this.code, {
    this.message = '',
    this.issues = const [],
    this.revision,
  });

  const AdminException.network() : this(0, 'network');

  final int status;

  /// invalid, conflict, not_found, id_taken, tag_in_use, frozen,
  /// content_invalid, nothing_changed, forbidden, unauthorized, …
  final String code;

  /// The server's message (English).
  final String message;

  /// Rule violations (English, from the server's validator).
  final List<String> issues;

  /// On "conflict": the item's current revision.
  final int? revision;

  /// A short Persian explanation for editors.
  String get userMessage => switch (code) {
    'network' => 'اتصال به سرور برقرار نشد.',
    'invalid' => 'اطلاعات کامل یا درست نیست:',
    'conflict' =>
      'شخص دیگری این مورد را هم‌زمان ویرایش و ذخیره کرده است. صفحه را دوباره بارگیری کنید.',
    'not_found' => 'این مورد پیدا نشد.',
    'id_taken' => 'این شناسه قبلاً استفاده شده است.',
    'tag_in_use' => 'این برچسب هنوز در برنامه‌ها یا یافته‌ها استفاده می‌شود.',
    'category_in_use' =>
      'فقط دسته‌ای حذف می‌شود که هیچ برنامه یا آزمون فعالی ندارد؛ دسته «عمومی» هم همیشه می‌ماند.',
    'frozen' => 'انتشار محتوا فعلاً قفل است (مثلاً در دوره کارآزمایی بالینی).',
    'content_invalid' => 'محتوا خطا دارد؛ پیش از انتشار آن‌ها را رفع کنید:',
    'nothing_changed' => 'از آخرین نسخه منتشرشده تغییری نکرده است.',
    'forbidden' => 'اجازه این کار را ندارید.',
    'unauthorized' => 'دوباره وارد شوید.',
    'email_taken' => 'با این ایمیل قبلاً حساب ساخته شده است.',
    'weak_password' => 'رمز عبور باید حداقل 8 نویسه باشد.',
    'invalid_email' => 'ایمیل معتبر نیست.',
    _ => message.isEmpty ? 'خطایی رخ داد.' : message,
  };

  @override
  String toString() => 'AdminException($status, $code, $message, $issues)';
}

/// The server's editing API. An interface, so tests can fake it.
abstract interface class AdminApi {
  Future<List<CategoryInfo>> categories();
  Future<CategoryInfo> createCategory(Map<String, dynamic> body);
  Future<CategoryInfo> updateCategory(String id, Map<String, dynamic> body);
  Future<void> reorderCategories(List<String> ids);

  Future<List<PlanSummary>> carePlans();
  Future<PlanDetail> carePlan(String id);
  Future<PlanDetail> createCarePlan(Map<String, dynamic> body);
  Future<PlanDetail> updateCarePlan(String id, Map<String, dynamic> body);
  Future<void> reorderCarePlans(String kind, List<String> ids);

  Future<List<QuizSummary>> quizzes();
  Future<QuizDetail> quiz(String id);
  Future<QuizDetail> createQuiz(String title, String kind);
  Future<QuizDetail> updateQuiz(String id, int revision, String title, String kind);
  Future<void> reorderQuizzes(List<String> ids);
  Future<QuestionDetail> createQuestion(String quizId, Map<String, dynamic> body);
  Future<QuestionDetail> updateQuestion(String id, Map<String, dynamic> body);
  Future<void> reorderQuestions(String quizId, List<String> ids);

  Future<List<DomainDetail>> domains();
  Future<DomainDetail> createDomain(String id, String title);
  Future<DomainDetail> updateDomain(String id, int revision, String title);
  Future<void> reorderDomains(List<String> ids);
  Future<FindingDetail> createFinding(String domainId, Map<String, dynamic> body);
  Future<FindingDetail> updateFinding(String id, Map<String, dynamic> body);
  Future<void> reorderFindings(String domainId, List<String> ids);

  /// [collection]: categories, care-plans, quizzes, questions, domains, findings.
  Future<void> setArchived(String collection, String id, bool archived);

  Future<List<TagInfo>> tags();
  Future<void> createTag(String name, String label);
  Future<void> updateTag(String name, {String? newName, required String label});
  Future<void> deleteTag(String name);

  Future<DraftIssues> draftIssues();
  Future<List<DraftChange>> draftChanges();
  Future<List<VersionInfo>> versions();
  Future<List<AuditEntry>> audit({String entity = '', String entityId = '', int? before});

  /// Returns the new version number.
  Future<int> publish(String notes);
  Future<FreezeState> freeze();
  Future<FreezeState> setFreeze(bool frozen, String reason);

  Future<List<AdminUser>> users();
  Future<void> createUser({
    required String email,
    required String displayName,
    required String role,
    required String password,
  });
  Future<void> setRole(String email, String role);
}

/// [AdminApi] over HTTP.
class HttpAdminApi implements AdminApi {
  HttpAdminApi({
    required this.baseUrl,
    required this.token,
    required this.onUnauthorized,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String? Function() token;
  final void Function() onUnauthorized;
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
        await _client.send(request).timeout(const Duration(seconds: 30)),
      );
    } catch (e) {
      debugPrint('$method $path: $e');
      throw const AdminException.network();
    }
    final text = utf8.decode(res.bodyBytes);
    final json = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 200 && res.statusCode < 300) return json;

    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    var issues = <String>[];
    final raw = map['issues'];
    if (raw is List) {
      issues = raw.cast<String>();
    } else if (raw is Map) {
      // content_invalid: {"errors": [...], "warnings": [...]}
      issues = (raw['errors'] as List? ?? const []).cast<String>();
    }
    if (res.statusCode == 401) onUnauthorized();
    throw AdminException(
      res.statusCode,
      map['code'] as String? ?? 'error',
      message: map['error'] as String? ?? '',
      issues: issues,
      revision: map['revision'] as int?,
    );
  }

  Future<List<T>> _list<T>(String path, T Function(Map<String, dynamic>) f) async =>
      [for (final e in (await _send('GET', path) as List)) f(e as Map<String, dynamic>)];

  Future<Map<String, dynamic>> _map(String method, String path, [Object? body]) async =>
      await _send(method, path, body) as Map<String, dynamic>;

  String _q(String s) => Uri.encodeComponent(s);

  @override
  Future<List<CategoryInfo>> categories() => _list('/v1/admin/categories', CategoryInfo.fromJson);

  @override
  Future<CategoryInfo> createCategory(Map<String, dynamic> body) async =>
      CategoryInfo.fromJson(await _map('POST', '/v1/admin/categories', body));

  @override
  Future<CategoryInfo> updateCategory(String id, Map<String, dynamic> body) async =>
      CategoryInfo.fromJson(await _map('PUT', '/v1/admin/categories/${_q(id)}', body));

  @override
  Future<void> reorderCategories(List<String> ids) =>
      _send('PUT', '/v1/admin/categories/order', {'ids': ids});

  @override
  Future<List<PlanSummary>> carePlans() => _list('/v1/admin/care-plans', PlanSummary.fromJson);
  @override
  Future<PlanDetail> carePlan(String id) async =>
      PlanDetail.fromJson(await _map('GET', '/v1/admin/care-plans/${_q(id)}'));
  @override
  Future<PlanDetail> createCarePlan(Map<String, dynamic> body) async =>
      PlanDetail.fromJson(await _map('POST', '/v1/admin/care-plans', body));
  @override
  Future<PlanDetail> updateCarePlan(String id, Map<String, dynamic> body) async =>
      PlanDetail.fromJson(await _map('PUT', '/v1/admin/care-plans/${_q(id)}', body));
  @override
  Future<void> reorderCarePlans(String kind, List<String> ids) =>
      _send('PUT', '/v1/admin/care-plans/order', {'kind': kind, 'ids': ids});

  @override
  Future<List<QuizSummary>> quizzes() => _list('/v1/admin/quizzes', QuizSummary.fromJson);
  @override
  Future<QuizDetail> quiz(String id) async =>
      QuizDetail.fromJson(await _map('GET', '/v1/admin/quizzes/${_q(id)}'));
  @override
  Future<QuizDetail> createQuiz(String title, String kind) async =>
      QuizDetail.fromJson(await _map('POST', '/v1/admin/quizzes', {'title': title, 'kind': kind}));
  @override
  Future<QuizDetail> updateQuiz(String id, int revision, String title, String kind) async =>
      QuizDetail.fromJson(await _map('PUT', '/v1/admin/quizzes/${_q(id)}',
          {'revision': revision, 'title': title, 'kind': kind}));
  @override
  Future<void> reorderQuizzes(List<String> ids) =>
      _send('PUT', '/v1/admin/quizzes/order', {'ids': ids});
  @override
  Future<QuestionDetail> createQuestion(String quizId, Map<String, dynamic> body) async =>
      QuestionDetail.fromJson(await _map('POST', '/v1/admin/quizzes/${_q(quizId)}/questions', body));
  @override
  Future<QuestionDetail> updateQuestion(String id, Map<String, dynamic> body) async =>
      QuestionDetail.fromJson(await _map('PUT', '/v1/admin/questions/${_q(id)}', body));
  @override
  Future<void> reorderQuestions(String quizId, List<String> ids) =>
      _send('PUT', '/v1/admin/quizzes/${_q(quizId)}/questions/order', {'ids': ids});

  @override
  Future<List<DomainDetail>> domains() => _list('/v1/admin/domains', DomainDetail.fromJson);
  @override
  Future<DomainDetail> createDomain(String id, String title) async =>
      DomainDetail.fromJson(await _map('POST', '/v1/admin/domains', {'id': id, 'title': title}));
  @override
  Future<DomainDetail> updateDomain(String id, int revision, String title) async =>
      DomainDetail.fromJson(await _map('PUT', '/v1/admin/domains/${_q(id)}',
          {'revision': revision, 'title': title}));
  @override
  Future<void> reorderDomains(List<String> ids) =>
      _send('PUT', '/v1/admin/domains/order', {'ids': ids});
  @override
  Future<FindingDetail> createFinding(String domainId, Map<String, dynamic> body) async =>
      FindingDetail.fromJson(await _map('POST', '/v1/admin/domains/${_q(domainId)}/findings', body));
  @override
  Future<FindingDetail> updateFinding(String id, Map<String, dynamic> body) async =>
      FindingDetail.fromJson(await _map('PUT', '/v1/admin/findings/${_q(id)}', body));
  @override
  Future<void> reorderFindings(String domainId, List<String> ids) =>
      _send('PUT', '/v1/admin/domains/${_q(domainId)}/findings/order', {'ids': ids});

  @override
  Future<void> setArchived(String collection, String id, bool archived) =>
      _send('POST', '/v1/admin/$collection/${_q(id)}/${archived ? 'archive' : 'restore'}');

  @override
  Future<List<TagInfo>> tags() => _list('/v1/admin/tags', TagInfo.fromJson);
  @override
  Future<void> createTag(String name, String label) =>
      _send('POST', '/v1/admin/tags', {'name': name, 'label': label});
  @override
  Future<void> updateTag(String name, {String? newName, required String label}) =>
      _send('PUT', '/v1/admin/tags/${_q(name)}', {'name': newName ?? name, 'label': label});
  @override
  Future<void> deleteTag(String name) => _send('DELETE', '/v1/admin/tags/${_q(name)}');

  @override
  Future<DraftIssues> draftIssues() async =>
      DraftIssues.fromJson(await _map('GET', '/v1/admin/draft/issues'));
  @override
  Future<List<DraftChange>> draftChanges() =>
      _list('/v1/admin/draft/changes', DraftChange.fromJson);
  @override
  Future<List<VersionInfo>> versions() => _list('/v1/admin/versions', VersionInfo.fromJson);
  @override
  Future<List<AuditEntry>> audit({String entity = '', String entityId = '', int? before}) {
    final q = Uri(queryParameters: {
      if (entity.isNotEmpty) 'entity': entity,
      if (entityId.isNotEmpty) 'entityId': entityId,
      if (before != null) 'before': '$before',
      'limit': '50',
    }).query;
    return _list('/v1/admin/audit?$q', AuditEntry.fromJson);
  }

  @override
  Future<int> publish(String notes) async {
    final j = await _map('POST', '/v1/admin/publish', {'notes': notes});
    return (j['version'] as Map<String, dynamic>)['version'] as int;
  }

  @override
  Future<FreezeState> freeze() async =>
      FreezeState.fromJson(await _map('GET', '/v1/admin/settings/freeze'));
  @override
  Future<FreezeState> setFreeze(bool frozen, String reason) async => FreezeState.fromJson(
    await _map('PUT', '/v1/admin/settings/freeze', {'frozen': frozen, 'reason': reason}),
  );

  @override
  Future<List<AdminUser>> users() => _list('/v1/admin/users', AdminUser.fromJson);
  @override
  Future<void> createUser({
    required String email,
    required String displayName,
    required String role,
    required String password,
  }) => _send('POST', '/v1/admin/users', {
    'email': email,
    'displayName': displayName,
    'role': role,
    'password': password,
  });
  @override
  Future<void> setRole(String email, String role) =>
      _send('PUT', '/v1/admin/users/${_q(email)}/role', {'role': role});
}
