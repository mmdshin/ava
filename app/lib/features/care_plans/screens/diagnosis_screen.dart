import 'package:ava_web/features/care_plans/widgets/care_plan_item.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/app/router.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ava_web/core/responsive.dart';
import 'package:ava_web/common/widgets/responsive_page.dart';
import 'package:ava_web/core/app_theme.dart';

class DiagnosisScreen extends StatelessWidget {
  const DiagnosisScreen({
    super.key,
    required this.title,
    required this.carePlans,
    required this.color,
    this.icon = Icons.medical_information_rounded,
  });

  final String title;
  final List<CarePlan> carePlans;
  final Color color;
  final IconData icon;

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
            title,
            style: context.text.titleLarge.copyWith(fontWeight: FontWeight.w900, color: context.onBg),
          ),
      ),
      body: AppBackground(child: SafeArea(
              child: ResponsivePage(
                child: carePlans.isEmpty
                    ? _EmptyState(color: color)
                    : ListView.separated(
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          gradient: LinearGradient(
                                            colors: [
                                              color.withValues(alpha: 0.22),
                                              color.withValues(alpha: 0.07),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          border: Border.all(
                                            color: color.withValues(alpha: 0.4),
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
                                                      color,
                                                      Colors.white,
                                                      0.15,
                                                    )!,
                                                    color,
                                                  ],
                                                ),
                                              ),
                                              child: Icon(
                                                icon,
                                                color: Colors.white,
                                                size: context.sp(21),
                                              ),
                                            ),
                                            SizedBox(width: context.wp(14)),
                                            Expanded(
                                              child: Text(
                                                "${carePlans.length} تشخیص پرستاری مرتبط",
                                                style: context.text.bodyMedium.copyWith(fontWeight: FontWeight.w700),
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
                      ),
              ),
            )),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.color});

  final Color color;

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
                  color: color.withValues(alpha: 0.16),
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  color: color,
                  size: context.sp(32),
                ),
              ),
              SizedBox(height: context.hp(16)),
              Text(
                "موردی یافت نشد",
                style: context.text.bodyLarge.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: context.hp(6)),
              Text(
                "برای این دسته تشخیص پرستاری ثبت نشده است",
                textAlign: TextAlign.center,
                style: context.text.labelLarge.copyWith(color: context.onBg.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ),
    );
  }
}
