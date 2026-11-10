import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/features/account/user_data_controller.dart';
import 'package:ava_web/core/favorites_controller.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.carePlan,
    required this.color,
    this.size = 22,
  });

  final CarePlan carePlan;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(
      favoritesProvider.select((ids) => ids.contains(carePlan.id)),
    );

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: isFavorite ? 'حذف از ذخیره‌شده‌ها' : 'ذخیره کردن',
        onPressed: () =>
            ref.read(userDataProvider.notifier).toggleFavorite(carePlan.id),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            key: ValueKey(isFavorite),
            color: isFavorite ? color : color.withValues(alpha: 0.55),
            size: size,
          ),
        ),
      ),
    );
  }
}
