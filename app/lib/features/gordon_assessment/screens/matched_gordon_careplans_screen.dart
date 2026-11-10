import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/app/router.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/core/kind_style.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/gordon_assessment/matching.dart';
import 'package:ava_web/features/gordon_assessment/models/assessment_item.dart';
import 'package:ava_web/features/gordon_assessment/widgets/finder_steps.dart';

class MatchedGordonCarePlansScreen extends ConsumerWidget {
  final List<AssessmentItem> selectedItems;
  final Kind selectedKind;

  const MatchedGordonCarePlansScreen({
    super.key,
    required this.selectedItems,
    required this.selectedKind,
  });

  List<String> get selectedTags =>
      {for (final i in selectedItems) ...i.tags}.toList();

  /// Back to the assessment. The selection is kept there; when this page
  /// was opened directly (e.g. a web refresh) there is nothing to pop.
  void _editFindings(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.assessmentFor(selectedKind));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = matchCarePlans(
      plans: ref.watch(carePlansProvider),
      selectedTags: selectedTags.toSet(),
      kind: selectedKind,
    );
    final specificPlans = matches.specific;
    final generalPlans = matches.general;

    Widget planCard(CarePlan plan, int index) =>
        _GlassPlanCard(
              plan: plan,
              selectedTags: selectedTags,
              reasons: [
                for (final i in matchReasons(plan, selectedItems)) i.title,
              ],
            )
            .animate()
            .fadeIn(delay: (30 * index).ms, duration: 350.ms)
            .slideY(begin: 0.08, end: 0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FlowAppBar(
        title: Text('برنامه‌های پیشنهادی', style: context.text.titleLarge),
        leading: IconButton(
          tooltip: 'بستن',
          icon: const Icon(Icons.close_rounded),
          onPressed: () async {
            final shouldClose = await _confirmClose(context);
            if (shouldClose == true && context.mounted) {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: matches.isEmpty
                  ? _EmptyResults(onEdit: () => _editFindings(context))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      children: [
                        const FinderSteps(current: 2),
                        const SizedBox(height: AppSpacing.lg),
                        _Summary(
                          planCount: specificPlans.length + generalPlans.length,
                          findingCount: selectedItems.length,
                          onEdit: () => _editFindings(context),
                        ).animate().fadeIn(duration: 300.ms),
                        if (specificPlans.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          _SectionHeader(
                            title: 'برنامه‌های اختصاصی بیماری',
                            subtitle: kindLabel(selectedKind),
                            icon: kindIcon(selectedKind),
                            color: context.kindTone(selectedKind),
                            count: specificPlans.length,
                          ),
                          for (final (i, plan) in specificPlans.indexed)
                            planCard(plan, i),
                        ],
                        if (generalPlans.isNotEmpty) ...[
                          SizedBox(
                            height: specificPlans.isNotEmpty
                                ? AppSpacing.xl
                                : AppSpacing.md,
                          ),
                          _SectionHeader(
                            title: 'برنامه‌های عمومی',
                            subtitle: 'قابل استفاده برای همه بیماران',
                            icon: Icons.healing_rounded,
                            color: context.appColors.accent,
                            count: generalPlans.length,
                          ),
                          for (final (i, plan) in generalPlans.indexed)
                            planCard(plan, i),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'این پیشنهادها جایگزین قضاوت بالینی نیستند؛ '
                          'هر برنامه را با شرایط بیمار تطبیق دهید.',
                          textAlign: TextAlign.center,
                          style: context.text.labelMedium.copyWith(
                            color: context.onBgMuted,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.planCount,
    required this.findingCount,
    required this.onEdit,
  });

  final int planCount;
  final int findingCount;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$planCount برنامه مراقبتی',
                style: context.text.headlineSmall,
              ),
              Text(
                'بر اساس $findingCount یافته انتخاب‌شده',
                style: context.text.bodyMedium.copyWith(
                  color: context.onBgMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('ویرایش یافته‌ها'),
        ),
      ],
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        const FinderSteps(current: 2),
        const SizedBox(height: AppSpacing.xxl),
        Icon(Icons.search_off_rounded, size: 72, color: context.onBgMuted),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'برنامه مراقبتی منطبقی یافت نشد',
          textAlign: TextAlign.center,
          style: context.text.titleMedium.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'برای این یافته‌ها هنوز برنامه مراقبتی ثبت نشده است',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium.copyWith(color: context.onBgMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('ویرایش یافته‌ها'),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.count,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: context.legible(color, minRatio: 3),
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: context.text.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: context.text.labelLarge.copyWith(
                    color: context.onBgMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$count',
              style: context.text.labelLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPlanCard extends StatelessWidget {
  final CarePlan plan;
  final List<String> selectedTags;
  final List<String> reasons;

  const _GlassPlanCard({
    required this.plan,
    required this.selectedTags,
    required this.reasons,
  });

  @override
  Widget build(BuildContext context) {
    final matchedCount = plan.tags
        .where((t) => selectedTags.contains(t))
        .length;
    final totalTags = plan.tags.length;
    final matchPercentage = (matchedCount / totalTags * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: context.onBg,
            collapsedIconColor: context.onBg.withValues(alpha: 0.7),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            title: Text(
              plan.title,
              style: context.text.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: totalTags == 0 ? 0 : matchedCount / totalTags,
                        minHeight: 6,
                        backgroundColor: context.appColors.glass.withValues(
                          alpha: 0.12,
                        ),
                        valueColor: AlwaysStoppedAnimation(
                          _getPriorityColor(context, matchPercentage),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      '${reasons.length} یافته منطبق',
                      style: context.text.labelLarge.copyWith(
                        color: context.onBgMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              _Reasons(reasons: reasons),
              _buildSection(
                context,
                SectionType.interventions.label,
                plan.itemsOf(SectionType.interventions),
              ),
              _buildSection(
                context,
                SectionType.outcomes.label,
                plan.itemsOf(SectionType.outcomes),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.carePlan(plan.id)),
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  label: const Text('مشاهده برنامه کامل'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<dynamic>? items,
  ) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.text.bodyLarge.copyWith(
            color: context.appColors.warning,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...items.map(
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsetsDirectional.only(
                    top: 10,
                    end: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.warning,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Expanded(
                  child: Text(
                    i.toString(),
                    style: context.text.bodyMedium.copyWith(height: 1.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Color _getPriorityColor(BuildContext context, int percentage) {
    if (percentage >= 70) return context.appColors.success;
    if (percentage >= 40) return context.appColors.caution;
    return context.appColors.brand;
  }
}

Future<bool?> _confirmClose(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: context.appColors.dialogSurface,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          "خروج از صفحه",
          style: context.text.headlineSmall.copyWith(
            fontWeight: FontWeight.w900,
            color: context.onBg,
          ),
        ),
        content: Text(
          "آیا مطمئن هستید که می‌خواهید این صفحه را ببندید؟",
          style: context.text.bodyLarge.copyWith(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "انصراف",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.onBgMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appColors.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
            ),
            child: Text("بستن", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );
}

class _Reasons extends StatelessWidget {
  const _Reasons({required this.reasons});
  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) return const SizedBox.shrink();
    final accent = context.appColors.success;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        accent: accent,
        radius: AppRadius.md,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_rounded, color: accent, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'چرا پیشنهاد شد؟',
                  style: context.text.titleSmall.copyWith(color: accent),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final r in reasons)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(r, style: context.text.labelLarge),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
