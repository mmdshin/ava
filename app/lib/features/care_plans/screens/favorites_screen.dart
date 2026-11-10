import 'package:ava_web/common/widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/app/router.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/care_plans/widgets/care_plan_item.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/favorites_controller.dart';
import 'package:ava_web/core/kind_style.dart';
import 'package:ava_web/core/responsive.dart';
import 'package:ava_web/common/widgets/responsive_page.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  void _openCarePlan(BuildContext context, CarePlan carePlan) {
    context.push(AppRoutes.carePlan(carePlan.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FlowAppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: context.onBg,
        title: Text(
          "ذخیره‌شده‌ها",
          style: context.text.titleLarge.copyWith(
            fontWeight: FontWeight.w900,
            color: context.onBg,
          ),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: ResponsivePage(
            child: Consumer(
              builder: (context, ref, _) {
                final carePlans = ref.watch(favoriteCarePlansProvider);

                if (carePlans.isEmpty) {
                  return const _EmptyFavorites();
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    context.wp(26),
                    context.hp(16),
                    context.wp(26),
                    context.hp(24),
                  ),
                  itemCount: carePlans.length + 1,
                  separatorBuilder: (ctx, index) =>
                      SizedBox(height: context.hp(14)),
                  itemBuilder: (ctx, index) {
                    if (index == 0) {
                      return Container(
                            padding: EdgeInsets.all(context.wp(16)),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              gradient: LinearGradient(
                                colors: [
                                  context.appColors.brand.withValues(
                                    alpha: 0.22,
                                  ),
                                  context.appColors.brand.withValues(
                                    alpha: 0.07,
                                  ),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: context.appColors.brand.withValues(
                                  alpha: 0.4,
                                ),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: context.wp(42),
                                  height: context.wp(42),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color.lerp(
                                          context.appColors.brand,
                                          Colors.white,
                                          0.15,
                                        )!,
                                        context.appColors.brand,
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.bookmark_rounded,
                                    color: Colors.white,
                                    size: context.sp(21),
                                  ),
                                ),
                                SizedBox(width: context.wp(14)),
                                Expanded(
                                  child: Text(
                                    "${carePlans.length} برنامه مراقبتی ذخیره‌شده",
                                    style: context.text.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 450.ms)
                          .slideY(begin: -0.15, end: 0);
                    }

                    final carePlan = carePlans[index - 1];
                    final color = context.kindTone(carePlan.kind);

                    return CarePlanItem(
                          color: color,
                          index: index - 1,
                          carePlan: carePlan,
                          onSelectedCarePlan: () =>
                              _openCarePlan(context, carePlan),
                        )
                        .animate()
                        .fadeIn(duration: 380.ms, delay: (index * 50).ms)
                        .slideX(begin: 0.12);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.wp(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: context.wp(70),
              height: context.wp(70),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.appColors.brand.withValues(alpha: 0.16),
              ),
              child: Icon(
                Icons.bookmark_border_rounded,
                color: context.appColors.accent,
                size: context.sp(32),
              ),
            ),
            SizedBox(height: context.hp(16)),
            Text(
              "چیزی ذخیره نکرده‌اید",
              style: context.text.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: context.hp(6)),
            Text(
              "با ضربه روی نماد نشان روی هر برنامه مراقبتی، آن را اینجا ذخیره کنید",
              textAlign: TextAlign.center,
              style: context.text.labelLarge.copyWith(
                color: context.onBg.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
