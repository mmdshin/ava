import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/core/providers.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/app/router.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/core/kind_style.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/gordon_assessment/widgets/finder_steps.dart';

class DiseaseKindSelectionScreen extends ConsumerWidget {
  const DiseaseKindSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentRepositoryProvider);
    final diseases = content.diseases;
    final general = content.general;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FlowAppBar(
        title: Text('تشخیص‌یاب', style: context.text.titleLarge),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 640 ? 4 : 2;
                  const gap = AppSpacing.md;
                  final tileWidth =
                      (constraints.maxWidth -
                          AppSpacing.lg * 2 -
                          gap * (columns - 1)) /
                      columns;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    children: [
                      const FinderSteps(current: 0),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'تشخیص پزشکی بیمار را انتخاب کنید',
                        style: context.text.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'در مرحله بعد، یافته‌های بررسی بیمار را بر اساس الگوهای '
                        'عملکردی گوردون انتخاب می‌کنید و برنامه‌های مراقبتی '
                        'مرتبط پیشنهاد می‌شود.',
                        style: context.text.bodyMedium.copyWith(
                          color: context.onBgMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children:
                            [
                                  for (final kind in diseases)
                                    SizedBox(
                                      width: tileWidth,
                                      child: _DiseaseTile(kind: kind),
                                    ),
                                  if (general != null)
                                    _GeneralCard(kind: general),
                                ]
                                .animate(interval: 50.ms)
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: 0.08, end: 0),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiseaseTile extends StatelessWidget {
  const _DiseaseTile({required this.kind});

  final Kind kind;

  @override
  Widget build(BuildContext context) {
    final color = context.kindTone(kind);
    final abbr = kindAbbr(kind);
    final nameStyle = context.text.titleMedium.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.35,
    );
    final nameLine =
        MediaQuery.textScalerOf(context).scale(nameStyle.fontSize ?? 16) * 1.35;
    final height = 44 + AppSpacing.md + nameLine * 2 + 2;

    return AppCard(
      accent: color,
      semanticLabel: kindLabel(kind),
      onTap: () => context.push(AppRoutes.assessmentFor(kind)),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(kindIcon(kind), color: Colors.white, size: 22),
                ),
                const Spacer(),
                if (abbr != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      abbr,
                      style: context.text.labelMedium.copyWith(
                        color: context.legible(color),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              kindName(kind),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: nameStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneralCard extends StatelessWidget {
  const _GeneralCard({required this.kind});

  final Kind kind;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.accent;

    return AppCard(
      semanticLabel: kindLabel(kind),
      onTap: () => context.push(AppRoutes.assessmentFor(kind)),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(kindIcon(kind), color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'تشخیص‌های عمومی',
              style: context.text.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: context.onBgMuted,
          ),
        ],
      ),
    );
  }
}
