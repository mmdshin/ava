import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ava_web/data/content_repository.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/gordon_assessment/models/gordon_domain.dart';
import 'package:ava_web/features/quiz/models/quiz.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider'),
);

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => throw UnimplementedError('Override contentRepositoryProvider'),
);

// ---- Content -------------------------------------------------------------

/// Version and origin of the content in use (About page).
final contentMetaProvider = Provider<ContentMeta>(
  (ref) => ref.watch(contentRepositoryProvider).meta,
);

/// Disease categories in display order ("general" included).
final categoriesProvider = Provider<List<Kind>>(
  (ref) => ref.watch(contentRepositoryProvider).categories,
);

/// The category with this id (null when there's no such category).
final kindByIdProvider = Provider.family<Kind?, String>(
  (ref, id) => ref.watch(contentRepositoryProvider).kindById(id),
);

final carePlansProvider = Provider<List<CarePlan>>(
  (ref) => ref.watch(contentRepositoryProvider).carePlans,
);

final quizzesProvider = Provider<List<Quiz>>(
  (ref) => ref.watch(contentRepositoryProvider).quizzes,
);

final gordonDomainsProvider = Provider<List<GordonDomain>>(
  (ref) => ref.watch(contentRepositoryProvider).gordonDomains,
);

final carePlanByIdProvider = Provider.family<CarePlan?, String>(
  (ref, id) => ref.watch(contentRepositoryProvider).carePlanById(id),
);

final carePlansOfKindProvider = Provider.family<List<CarePlan>, Kind>(
  (ref, kind) => ref.watch(contentRepositoryProvider).carePlansOfKind(kind),
);

final quizByIdProvider = Provider.family<Quiz?, String>((ref, id) {
  for (final q in ref.watch(quizzesProvider)) {
    if (q.id == id) return q;
  }
  return null;
});
