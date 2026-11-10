import 'package:ava_web/common/widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/app/router.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/features/care_plans/widgets/care_plan_search_delegate.dart';
import 'package:ava_web/features/care_plans/screens/diagnosis_category_screen.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/responsive.dart';

class DiagnosisTabs extends ConsumerWidget {
  const DiagnosisTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPlans = ref.watch(carePlansProvider);
    return Scaffold(
      appBar: FlowAppBar(
        title: Text(
          'تشخیص پزشکی',
          style: context.text.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        foregroundColor: context.onBg,
        elevation: 0,
        actions: [
          Padding(
            padding: EdgeInsets.only(left: context.wp(12)),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () async {
                  final selected = await showSearch(
                    context: context,
                    delegate: CarePlanSearchDelegate(allPlans),
                  );
                  if (selected != null && context.mounted) {
                    context.push(AppRoutes.carePlan(selected.id));
                  }
                },
                child: Container(
                  width: context.wp(40),
                  height: context.wp(40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.appColors.glass.withValues(alpha: 0.14),
                    border: Border.all(
                      color: context.appColors.glass.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    semanticLabel: 'جستجو',
                    color: context.onBg,
                    size: context.sp(20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: DiagnosisCategoryScreen(allCarePlans: allPlans),
      ),
    );
  }
}
