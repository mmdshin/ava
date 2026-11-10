import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/admin/admin_app.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/features/account/session.dart';

/// Where things stand: what to do next, unpublished changes, problems,
/// the latest version, how much content there is and recent activity.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final name = ref.watch(authProvider)?.user.name ?? '';
    final canPublish = hasRole(ref.watch(roleProvider), 'reviewer');
    final changes = ref.watch(draftChangesProvider).value;
    final issues = ref.watch(draftIssuesProvider).value;
    final latest = ref.watch(versionsProvider).value?.firstOrNull;
    final freeze = ref.watch(freezeProvider).value;

    String count(int? n) => n == null ? '…' : '$n';
    final errors = issues?.errors.length;
    final warnings = issues?.warnings.length;

    return AdminPage(
      title: 'خلاصه',
      subtitle: name.isEmpty
          ? null
          : 'سلام $name؛ وضعیت محتوای آوا در یک نگاه.',
      actions: [
        IconButton(
          tooltip: 'بارگیری دوباره',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            refreshDraft(ref);
            ref.invalidate(versionsProvider);
            ref.invalidate(freezeProvider);
            ref.invalidate(categoriesListProvider);
            ref.invalidate(carePlansListProvider);
            ref.invalidate(quizzesListProvider);
            ref.invalidate(domainsProvider);
            ref.invalidate(tagsProvider);
          },
        ),
        FilledButton.icon(
          onPressed: () => context.go(AdminRoutes.newCarePlan),
          icon: const Icon(Icons.add_rounded),
          label: const Text('برنامه مراقبتی جدید'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NextStep(
            frozen: freeze?.frozen == true ? freeze!.reason : null,
            errors: errors,
            changes: changes?.length,
            latest: latest,
            canPublish: canPublish,
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 860
                  ? 4
                  : (c.maxWidth >= 440 ? 2 : 1);
              final w = (c.maxWidth - AppSpacing.md * (columns - 1)) / columns;
              Widget tile(Widget t) => SizedBox(width: w, child: t);
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  tile(
                    _StatTile(
                      label: 'تغییر منتشرنشده',
                      value: count(changes?.length),
                      icon: Icons.edit_note_rounded,
                      color: colors.accent,
                      onTap: () => context.go(AdminRoutes.publish),
                    ),
                  ),
                  tile(
                    _StatTile(
                      label: 'خطا (مانع انتشار)',
                      value: count(errors),
                      icon: Icons.error_outline_rounded,
                      color: (errors ?? 0) == 0
                          ? colors.success
                          : colors.danger,
                      onTap: () => context.go(AdminRoutes.publish),
                    ),
                  ),
                  tile(
                    _StatTile(
                      label: 'هشدار',
                      value: count(warnings),
                      icon: Icons.warning_amber_rounded,
                      color: colors.caution,
                      onTap: () => context.go(AdminRoutes.publish),
                    ),
                  ),
                  tile(
                    _StatTile(
                      label: 'آخرین نسخه منتشرشده',
                      value: latest == null ? '—' : '${latest.version}',
                      detail: latest == null
                          ? null
                          : relativeTime(latest.publishedAt),
                      icon: Icons.cloud_done_rounded,
                      color: colors.accent,
                      onTap: () => context.go(AdminRoutes.publish),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, c) {
              const content = _ContentCounts();
              const activity = _RecentActivity();
              if (c.maxWidth < 820) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    content,
                    SizedBox(height: AppSpacing.lg),
                    activity,
                  ],
                );
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: content),
                  SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 3, child: activity),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One banner telling the user what to do next.
class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.frozen,
    required this.errors,
    required this.changes,
    required this.latest,
    required this.canPublish,
  });

  /// The freeze reason, or null when publishing is open.
  final String? frozen;
  final int? errors;
  final int? changes;
  final VersionInfo? latest;
  final bool canPublish;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (
      Color color,
      IconData icon,
      String title,
      String message,
      String? button,
    ) = switch ((frozen, errors ?? 0, changes ?? 0)) {
      (final String reason, _, _) => (
        colors.warning,
        Icons.lock_rounded,
        'انتشار قفل است',
        'دلیل: $reason. ویرایش پیش‌نویس ادامه دارد، اما نسخه جدیدی منتشر نمی‌شود.',
        null,
      ),
      (_, final e, _) when e > 0 => (
        colors.danger,
        Icons.error_outline_rounded,
        '$e خطا مانع انتشار است',
        'پیش از انتشار نسخه بعدی باید این موارد رفع شوند.',
        'مشاهده خطاها',
      ),
      (_, _, final n) when n > 0 => (
        colors.accent,
        Icons.pending_actions_rounded,
        '$n تغییر هنوز منتشر نشده',
        canPublish
            ? 'تغییرات را مرور کنید و نسخه جدید را منتشر کنید تا به کاربران برسد.'
            : 'یک بازبین یا مدیر باید این تغییرات را منتشر کند تا به کاربران برسد.',
        canPublish ? 'بررسی و انتشار' : 'مشاهده تغییرات',
      ),
      _ => (
        colors.success,
        Icons.check_circle_rounded,
        'همه چیز منتشر شده است',
        latest == null
            ? 'هنوز نسخه‌ای منتشر نشده است.'
            : 'کاربران نسخه ${latest!.version} را می‌بینند (${formatDateTime(latest!.publishedAt)}).',
        null,
      ),
    };

    return Panel(
      accent: color,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.legible(color)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                Text(
                  message,
                  style: context.text.bodySmall.copyWith(
                    color: context.onBgMuted,
                  ),
                ),
              ],
            ),
          ),
          if (button != null) ...[
            const SizedBox(width: AppSpacing.md),
            FilledButton.tonal(
              onPressed: () => context.go(AdminRoutes.publish),
              child: Text(button),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppRadius.sm - 2),
            ),
            child: Icon(icon, color: context.legible(color)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: context.text.headlineSmall),
                Text(
                  label,
                  style: context.text.labelMedium.copyWith(
                    color: context.onBgMuted,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: context.text.labelSmall.copyWith(
                      color: context.onBgMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentCounts extends ConsumerWidget {
  const _ContentCounts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(activeCategoriesProvider);
    final plans = ref.watch(carePlansListProvider).value;
    final quizzes = ref.watch(quizzesListProvider).value;
    final domains = ref.watch(domainsProvider).value;
    final tags = ref.watch(tagsProvider).value;

    final findings = domains == null
        ? null
        : [
            for (final d in domains)
              if (!d.meta.archived)
                ...d.findings.where((f) => !f.meta.archived),
          ];
    final orphan = findings?.where((f) => f.plans.isEmpty).length ?? 0;

    Widget row(
      IconData icon,
      String label,
      int? n,
      String path, {
      String? note,
      Color? noteColor,
    }) => ListRow(
      leading: Icon(icon, size: 20, color: context.onBgMuted),
      title: Text(label),
      subtitle: note == null
          ? null
          : Text(note, style: TextStyle(color: noteColor)),
      trailing: [
        Text(n == null ? '—' : '$n', style: context.text.titleMedium),
        const ForwardChevron(),
      ],
      onTap: () => context.go(path),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('محتوا', style: context.text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        RowList(
          children: [
            row(
              Icons.category_rounded,
              'دسته بیماری',
              ref.watch(categoriesListProvider).hasValue
                  ? categories.length
                  : null,
              AdminRoutes.categories,
            ),
            row(
              Icons.medical_information_rounded,
              'برنامه مراقبتی',
              plans?.where((p) => !p.meta.archived).length,
              AdminRoutes.carePlans,
            ),
            row(
              Icons.quiz_rounded,
              'آزمون',
              quizzes?.where((q) => !q.meta.archived).length,
              AdminRoutes.quizzes,
            ),
            row(
              Icons.checklist_rounded,
              'یافته بررسی گوردون',
              findings?.length,
              AdminRoutes.assessment,
              note: orphan == 0
                  ? null
                  : '$orphan یافته به هیچ برنامه‌ای نمی‌رسد',
              noteColor: context.appColors.warning,
            ),
            row(Icons.sell_rounded, 'برچسب', tags?.length, AdminRoutes.tags),
          ],
        ),
      ],
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(recentActivityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('آخرین فعالیت‌ها', style: context.text.titleMedium),
            ),
            TextButton(
              onPressed: () => context.go(AdminRoutes.history),
              child: const Text('همه'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Panel(
          padding: EdgeInsets.zero,
          child: AsyncBody(
            value: activity,
            onRetry: () => ref.invalidate(recentActivityProvider),
            builder: (list) => list.isEmpty
                ? const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'هنوز تغییری ثبت نشده است',
                  )
                : Column(
                    children: [
                      for (final (i, e) in list.take(7).indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        ActivityRow(e),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
