import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/admin/admin_app.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final _notes = TextEditingController();
  bool _busy = false;
  bool _allWarnings = false;
  bool _allVersions = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _refresh() {
    refreshDraft(ref);
    ref.invalidate(versionsProvider);
    ref.invalidate(freezeProvider);
  }

  Future<void> _publish(int changes) async {
    final ok = await confirm(
      context,
      title: 'انتشار نسخه جدید',
      message:
          '$changes تغییر منتشر می‌شود و همه کاربران آن را در اجرای بعدی برنامه دریافت می‌کنند. منتشر شود؟',
      action: 'انتشار',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final version = await ref
          .read(adminApiProvider)
          .publish(_notes.text.trim());
      if (!mounted) return;
      _notes.clear();
      toast(context, 'نسخه $version منتشر شد');
    } catch (e) {
      if (!mounted) return;
      // Stop the spinner before showing the error dialog.
      setState(() => _busy = false);
      await showAdminError(context, e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  void _open(DraftChange c) {
    switch (c.entity) {
      case 'category':
        context.go(AdminRoutes.categories);
      case 'care_plan':
        context.go(AdminRoutes.carePlan(c.id));
      case 'quiz':
        context.go(AdminRoutes.quiz(c.id));
      case 'question':
        final quizId = c.id.contains('-q')
            ? c.id.substring(0, c.id.lastIndexOf('-q'))
            : '';
        if (quizId.isNotEmpty) context.go(AdminRoutes.quiz(quizId));
      case 'domain' || 'finding':
        context.go(AdminRoutes.assessment);
      case 'tag':
        context.go(AdminRoutes.tags);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final canPublish = hasRole(ref.watch(roleProvider), 'reviewer');
    final changes = ref.watch(draftChangesProvider);
    final issues = ref.watch(draftIssuesProvider);
    final versions = ref.watch(versionsProvider);
    final freeze = ref.watch(freezeProvider).value;
    final errors = issues.value?.errors ?? const <String>[];
    final changeCount = changes.value?.length ?? 0;

    return AdminPage(
      title: 'انتشار',
      subtitle:
          'ویرایش‌ها در پیش‌نویس می‌مانند و تا انتشار به کاربران نمی‌رسند.',
      actions: [
        IconButton(
          tooltip: 'بارگیری دوباره',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _refresh,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Step(
            number: 1,
            title: 'مرور تغییرات',
            subtitle: 'تفاوت پیش‌نویس با آخرین نسخه منتشرشده',
            state: changes.hasValue
                ? (changeCount == 0 ? _StepState.idle : _StepState.done)
                : _StepState.idle,
            trailing: changes.hasValue
                ? CountBadge(changeCount, color: colors.accent)
                : null,
            child: AsyncBody(
              value: changes,
              onRetry: _refresh,
              builder: (list) => list.isEmpty
                  ? Text(
                      'تغییری نیست؛ پیش‌نویس با آخرین نسخه یکی است.',
                      style: TextStyle(color: context.onBgMuted),
                    )
                  : _ChangeList(changes: list, onOpen: _open),
            ),
          ),
          _Step(
            number: 2,
            title: 'بررسی محتوا',
            subtitle: 'خطاها مانع انتشارند؛ هشدارها فقط برای اطلاع‌اند.',
            state: !issues.hasValue
                ? _StepState.idle
                : errors.isEmpty
                ? _StepState.done
                : _StepState.blocked,
            child: AsyncBody(
              value: issues,
              onRetry: _refresh,
              builder: (is_) {
                final warnings = _allWarnings
                    ? is_.warnings
                    : is_.warnings.take(5).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (is_.errors.isEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: context.legible(colors.success),
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Text('خطایی نیست.'),
                        ],
                      ),
                    for (final e in is_.errors)
                      _issue(
                        context,
                        e,
                        colors.danger,
                        Icons.error_outline_rounded,
                      ),
                    if (is_.warnings.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${is_.warnings.length} هشدار',
                        style: context.text.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final w in warnings)
                        _issue(
                          context,
                          w,
                          colors.caution,
                          Icons.warning_amber_rounded,
                        ),
                      if (is_.warnings.length > 5)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _allWarnings = !_allWarnings),
                            child: Text(
                              _allWarnings
                                  ? 'نمایش کمتر'
                                  : 'نمایش همه ${is_.warnings.length} هشدار',
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
          _Step(
            number: 3,
            title: 'انتشار نسخه جدید',
            subtitle: 'فقط بازبین‌ها و مدیران',
            state: (freeze?.frozen ?? false) || !canPublish
                ? _StepState.blocked
                : _StepState.idle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (freeze?.frozen ?? false)
                  _notice(
                    context,
                    colors.warning,
                    Icons.lock_rounded,
                    'انتشار قفل است: ${freeze!.reason}',
                  )
                else if (!canPublish)
                  Text(
                    'فقط بازبین‌ها و مدیران می‌توانند منتشر کنند.',
                    style: TextStyle(color: context.onBgMuted),
                  )
                else ...[
                  TextField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'یادداشت انتشار',
                      hintText:
                          'مثلاً: اصلاح اقدامات پرستاری درد حاد و افزودن سه سؤال',
                      helperText: 'در تاریخچه نسخه‌ها می‌ماند.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            _busy ||
                                errors.isNotEmpty ||
                                changeCount == 0 ||
                                _notes.text.trim().isEmpty
                            ? null
                            : () => _publish(changeCount),
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.rocket_launch_rounded),
                        label: Text(
                          changeCount == 0
                              ? 'انتشار'
                              : 'انتشار $changeCount تغییر',
                        ),
                      ),
                      if (errors.isNotEmpty)
                        Text(
                          'ابتدا خطاها را رفع کنید.',
                          style: TextStyle(
                            color: context.legible(colors.danger),
                          ),
                        )
                      else if (changeCount == 0)
                        Text(
                          'تغییری برای انتشار نیست.',
                          style: TextStyle(color: context.onBgMuted),
                        )
                      else if (_notes.text.trim().isEmpty)
                        Text(
                          'یادداشت انتشار را بنویسید.',
                          style: TextStyle(color: context.onBgMuted),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FormSection(
            title: 'نسخه‌های منتشرشده',
            icon: Icons.cloud_done_rounded,
            child: AsyncBody(
              value: versions,
              onRetry: _refresh,
              builder: (list) => list.isEmpty
                  ? Text(
                      'هنوز نسخه‌ای منتشر نشده است.',
                      style: TextStyle(color: context.onBgMuted),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, v)
                            in (_allVersions ? list : list.take(5))
                                .indexed) ...[
                          if (i > 0) const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (i == 0
                                                ? colors.success
                                                : context.onBgMuted)
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm - 6,
                                    ),
                                  ),
                                  child: Text(
                                    '${v.version}',
                                    style: context.text.labelLarge,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(v.notes.isEmpty ? '—' : v.notes),
                                      Text(
                                        '${formatDateTime(v.publishedAt)} · ${v.publishedBy}',
                                        style: context.text.labelSmall.copyWith(
                                          color: context.onBgMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (i == 0)
                                  Pill('نسخه فعلی', color: colors.success),
                              ],
                            ),
                          ),
                        ],
                        if (list.length > 5)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => _allVersions = !_allVersions),
                              child: Text(
                                _allVersions
                                    ? 'نمایش کمتر'
                                    : 'همه ${list.length} نسخه',
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(
    BuildContext context,
    Color color,
    IconData icon,
    String text,
  ) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppRadius.sm - 4),
    ),
    child: Row(
      children: [
        Icon(icon, color: context.legible(color), size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _issue(
    BuildContext context,
    String text,
    Color color,
    IconData icon,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.legible(color)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            textDirection: TextDirection.ltr,
            style: context.text.bodySmall,
          ),
        ),
      ],
    ),
  );
}

enum _StepState { idle, done, blocked }

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.child,
    required this.state,
    this.subtitle,
    this.trailing,
  });

  final int number;
  final String title;
  final String? subtitle;
  final Widget child;
  final _StepState state;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = switch (state) {
      _StepState.done => colors.success,
      _StepState.blocked => colors.danger,
      _StepState.idle => colors.accent,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: state == _StepState.done
                ? Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: context.legible(color),
                  )
                : Text(
                    '$number',
                    style: context.text.labelLarge.copyWith(
                      color: context.legible(color),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: context.text.titleMedium),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: context.text.bodySmall.copyWith(
                                  color: context.onBgMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  child,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChangeList extends StatelessWidget {
  const _ChangeList({required this.changes, required this.onOpen});
  final List<DraftChange> changes;
  final ValueChanged<DraftChange> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final byEntity = <String, List<DraftChange>>{};
    for (final c in changes) {
      byEntity.putIfAbsent(c.entity, () => []).add(c);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MapEntry(key: entity, value: list) in byEntity.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  entityIcons[entity] ?? Icons.circle_outlined,
                  size: 16,
                  color: context.onBgMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  entityLabels[entity] ?? entity,
                  style: context.text.labelLarge.copyWith(
                    color: context.onBgMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                CountBadge(list.length),
              ],
            ),
          ),
          for (final c in list)
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm - 4),
              onTap: c.kind == 'removed' && c.entity != 'care_plan'
                  ? null
                  : () => onOpen(c),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Pill(
                          switch (c.kind) {
                            'added' => 'جدید',
                            'removed' => 'حذف',
                            _ => 'ویرایش',
                          },
                          color: switch (c.kind) {
                            'added' => colors.success,
                            'removed' => colors.danger,
                            _ => colors.caution,
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      c.id,
                      textDirection: TextDirection.ltr,
                      style: context.text.labelSmall.copyWith(
                        color: context.onBgMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
