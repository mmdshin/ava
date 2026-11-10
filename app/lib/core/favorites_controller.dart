import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/features/account/user_data_controller.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';

/// Ids of the bookmarked care plans (from the user's server data).
///
///   ref.watch(favoritesProvider).contains(plan.id)
///   ref.read(userDataProvider.notifier).toggleFavorite(plan.id)
final favoritesProvider = Provider<Set<String>>((ref) => ref.watch(_favorites));

final _favorites = userDataProvider.select(
  (d) => d.value?.favorites ?? const <String>{},
);

final favoriteCarePlansProvider = Provider<List<CarePlan>>((ref) {
  final ids = ref.watch(_favorites);
  return [
    for (final p in ref.watch(carePlansProvider))
      if (ids.contains(p.id)) p,
  ];
});
