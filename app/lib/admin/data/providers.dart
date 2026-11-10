import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/admin/data/admin_api.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/core/config.dart';
import 'package:ava_web/features/account/session.dart';

/// The editing API with the signed-in session.
final adminApiProvider = Provider<AdminApi>(
  (ref) => HttpAdminApi(
    baseUrl: AppConfig.apiBaseUrl,
    token: () => ref.read(authProvider)?.token,
    onUnauthorized: () => ref.read(authProvider.notifier).expired(),
  ),
);

/// Roles from least to most privilages.
const roleRank = {'nurse': 0, 'editor': 1, 'reviewer': 2, 'admin': 3};

const roleLabels = {
  'nurse': 'کاربر',
  'editor': 'ویراستار',
  'reviewer': 'بازبین',
  'admin': 'مدیر',
};

/// The signed-in user's role ('' when signed out).
final roleProvider = Provider<String>(
  (ref) => ref.watch(authProvider)?.user.role ?? '',
);

/// Whether the signed-in user has at least [role].
bool hasRole(String current, String role) =>
    (roleRank[current] ?? -1) >= (roleRank[role] ?? 99);

// Lists, refreshed with `ref.invalidate(...)` after a change.

final categoriesListProvider = FutureProvider<List<CategoryInfo>>(
  (ref) => ref.watch(adminApiProvider).categories(),
);

/// Categories by id (empty while loading).
final categoryMapProvider = Provider<Map<String, CategoryInfo>>((ref) {
  final list =
      ref.watch(categoriesListProvider).value ?? const <CategoryInfo>[];
  return {for (final c in list) c.id: c};
});

/// Categories new plans and quizzes can use (not archived), in order.
final activeCategoriesProvider = Provider<List<CategoryInfo>>((ref) {
  final list =
      ref.watch(categoriesListProvider).value ?? const <CategoryInfo>[];
  return [
    for (final c in list)
      if (!c.meta.archived) c,
  ];
});

final carePlansListProvider = FutureProvider<List<PlanSummary>>(
  (ref) => ref.watch(adminApiProvider).carePlans(),
);

final quizzesListProvider = FutureProvider<List<QuizSummary>>(
  (ref) => ref.watch(adminApiProvider).quizzes(),
);

final quizProvider = FutureProvider.family<QuizDetail, String>(
  (ref, id) => ref.watch(adminApiProvider).quiz(id),
);

final domainsProvider = FutureProvider<List<DomainDetail>>(
  (ref) => ref.watch(adminApiProvider).domains(),
);

final tagsProvider = FutureProvider<List<TagInfo>>(
  (ref) => ref.watch(adminApiProvider).tags(),
);

final draftIssuesProvider = FutureProvider<DraftIssues>(
  (ref) => ref.watch(adminApiProvider).draftIssues(),
);

final draftChangesProvider = FutureProvider<List<DraftChange>>(
  (ref) => ref.watch(adminApiProvider).draftChanges(),
);

final versionsProvider = FutureProvider<List<VersionInfo>>(
  (ref) => ref.watch(adminApiProvider).versions(),
);

final freezeProvider = FutureProvider<FreezeState>(
  (ref) => ref.watch(adminApiProvider).freeze(),
);

final usersProvider = FutureProvider<List<AdminUser>>(
  (ref) => ref.watch(adminApiProvider).users(),
);

/// "entity:id" → "added" / "changed" / "removed", for items that differ
/// from the published version.
final draftStatusProvider = Provider<Map<String, String>>((ref) {
  final changes =
      ref.watch(draftChangesProvider).value ?? const <DraftChange>[];
  return {for (final c in changes) '${c.entity}:${c.id}': c.kind};
});

/// The latest changes (for the dashboard).
final recentActivityProvider = FutureProvider<List<AuditEntry>>(
  (ref) => ref.watch(adminApiProvider).audit(),
);

/// One item's history (entity, id).
final itemHistoryProvider =
    FutureProvider.family<List<AuditEntry>, (String, String)>(
      (ref, key) =>
          ref.watch(adminApiProvider).audit(entity: key.$1, entityId: key.$2),
    );

/// After any content edit: everything that summarizes the draft.
void refreshDraft(WidgetRef ref) {
  ref.invalidate(draftIssuesProvider);
  ref.invalidate(draftChangesProvider);
  ref.invalidate(recentActivityProvider);
  ref.invalidate(itemHistoryProvider);
}
