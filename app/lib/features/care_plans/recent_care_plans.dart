import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/features/account/user_data_controller.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';

/// Ids of recently opened care plans, newest first (server data).
final recentCarePlanIdsProvider = Provider<List<String>>(
  (ref) => ref.watch(_recent),
);

final _recent = userDataProvider.select(
  (d) => d.value?.recent ?? const <String>[],
);

/// The recently opened care plans themselves.
final recentCarePlansProvider = Provider<List<CarePlan>>((ref) {
  final ids = ref.watch(_recent);
  final repo = ref.watch(contentRepositoryProvider);
  return [
    for (final id in ids)
      if (repo.carePlanById(id) case final plan?) plan,
  ];
});
