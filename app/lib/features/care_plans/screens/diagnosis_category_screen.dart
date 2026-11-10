import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/app/router.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/care_plans/widgets/diagnosis_category_item.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ava_web/core/responsive.dart';
import 'package:ava_web/common/widgets/responsive_page.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/kind_style.dart';

class DiagnosisCategoryScreen extends ConsumerWidget {
  const DiagnosisCategoryScreen({super.key, required this.allCarePlans});

  final List<CarePlan> allCarePlans;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ResponsivePage(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                context.wp(22),
                context.hp(24),
                context.wp(22),
                context.hp(50),
              ),
              children: [
                Container(
                      padding: EdgeInsets.all(context.wp(16)),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        gradient: LinearGradient(
                          colors: [
                            context.onBg.withValues(alpha: 0.14),
                            context.onBg.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: context.onBg.withValues(alpha: 0.16),
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
                              color: context.appColors.brand.withValues(
                                alpha: 0.18,
                              ),
                            ),
                            child: Icon(
                              Icons.info_outline_rounded,
                              color: context.appColors.accent,
                              size: context.sp(22),
                            ),
                          ),
                          SizedBox(width: context.wp(14)),
                          Expanded(
                            child: Text(
                              "برای مشاهده تشخیص‌های پرستاری مربوطه، یکی از تشخیص‌های پزشکی زیر را انتخاب کنید",
                              style: context.text.bodySmall.copyWith(color: context.onBg.withValues(alpha: 0.85), fontWeight: FontWeight.w500, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 100.ms)
                    .slideY(begin: -0.15, end: 0),

                SizedBox(height: context.hp(24)),

                ...categories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final kind = entry.value;

                  final label = kindLabel(kind);
                  final color = context.kindTone(kind);
                  final icon = kindIcon(kind);
                  final filtered = allCarePlans
                      .where((cp) => cp.kind == kind)
                      .toList();

                  return Padding(
                        padding: EdgeInsets.only(bottom: context.hp(14)),
                        child: DiagnosisCategoryItem(
                          onSelectedCategory: () {
                            context.push(AppRoutes.carePlansOfKind(kind));
                          },
                          title: label,
                          color: color,
                          icon: icon,
                          count: filtered.length,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 550.ms, delay: (index * 100).ms)
                      .slideX(begin: 0.15, end: 0);
                }),
              ],
            ),
          ),
        ),
      );
  }
}
