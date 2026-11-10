import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/admin/admin_theme.dart';
import 'package:ava_web/admin/data/admin_api.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/core/jalali.dart';
import 'package:ava_web/core/kind_style.dart';

// ─── Labels and formatting ──────────────────────────────────────────

String formatDateTime(DateTime? t) {
  if (t == null) return '';
  final local = t.toUtc().add(const Duration(hours: 3, minutes: 30));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${formatJalali(t)} ${two(local.hour)}:${two(local.minute)}';
}

String relativeTime(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'همین حالا';
  if (d.inMinutes < 60) return '${d.inMinutes} دقیقه پیش';
  if (d.inHours < 24) return '${d.inHours} ساعت پیش';
  if (d.inDays < 7) return '${d.inDays} روز پیش';
  return formatJalali(t);
}

String kindTitle(WidgetRef ref, String kind) {
  if (kind.isEmpty) return 'ترکیبی';
  final c = ref.watch(categoryMapProvider)[kind];
  if (c == null) return kind;
  return c.abbr.isEmpty ? c.title : '${c.title} (${c.abbr})';
}

String kindShort(WidgetRef ref, String kind) => kind.isEmpty
    ? 'ترکیبی'
    : ref.watch(categoryMapProvider)[kind]?.title ?? kind;

Color kindToneOf(BuildContext context, WidgetRef ref, String kind) {
  final c = ref.watch(categoryMapProvider)[kind];
  return c == null ? context.onBgMuted : context.kindTone(c.kind);
}

const sectionLabels = {
  'definition': 'تعریف',
  'relatedTo': 'در ارتباط با',
  'definingCharacteristics': 'مشخص می‌شود با',
  'riskFactors': 'شواهد احتمالی',
  'interventions': 'اقدامات پرستاری',
  'outcomes': 'پیامد مطلوب',
};

const sectionIcons = {
  'definition': Icons.menu_book_rounded,
  'relatedTo': Icons.link_rounded,
  'definingCharacteristics': Icons.fact_check_rounded,
  'riskFactors': Icons.report_problem_rounded,
  'interventions': Icons.healing_rounded,
  'outcomes': Icons.flag_rounded,
};

const entityLabels = {
  'category': 'دسته بیماری',
  'care_plan': 'برنامه مراقبتی',
  'quiz': 'آزمون',
  'question': 'سؤال',
  'domain': 'الگوی گوردون',
  'finding': 'یافته',
  'tag': 'برچسب',
  'version': 'نسخه',
  'settings': 'تنظیمات',
  'user': 'کاربر',
};

const entityIcons = {
  'category': Icons.category_rounded,
  'care_plan': Icons.medical_information_rounded,
  'quiz': Icons.quiz_rounded,
  'question': Icons.help_outline_rounded,
  'domain': Icons.checklist_rounded,
  'finding': Icons.check_box_outlined,
  'tag': Icons.sell_rounded,
  'version': Icons.cloud_done_rounded,
  'settings': Icons.settings_rounded,
  'user': Icons.person_rounded,
};

const actionLabels = {
  'create': 'ایجاد',
  'update': 'ویرایش',
  'archive': 'بایگانی',
  'restore': 'بازگردانی',
  'reorder': 'ترتیب',
  'delete': 'حذف',
  'publish': 'انتشار',
  'freeze': 'قفل انتشار',
  'unfreeze': 'باز کردن انتشار',
  'set_role': 'تغییر نقش',
};

/// Status color of an audit action.
Color actionColor(BuildContext context, String action) {
  final c = context.appColors;
  return switch (action) {
    'create' || 'restore' => c.success,
    'archive' || 'delete' => c.danger,
    'publish' => c.accent,
    'freeze' || 'unfreeze' || 'set_role' => c.warning,
    _ => context.onBgMuted,
  };
}

// ─── Unsaved changes ────────────────────────────────────────────────

/// Set by an editor while it holds unsaved edits. Routes that host an
/// editor ask before leaving (see `onExit` in admin_app.dart), which
/// covers the sidebar, links and the browser's back button.
abstract final class UnsavedChanges {
  static bool active = false;
}

/// Asks before throwing away unsaved edits. True = go ahead.
Future<bool> confirmLeave(BuildContext context) async {
  if (!UnsavedChanges.active) return true;
  final leave = await confirm(
    context,
    title: 'تغییرات ذخیره نشده',
    message:
        'تغییراتی که ذخیره نکرده‌اید از بین می‌رود. از این صفحه خارج می‌شوید؟',
    action: 'خروج بدون ذخیره',
    cancel: 'ماندن',
    destructive: true,
  );
  if (leave) UnsavedChanges.active = false;
  return leave;
}

class SaveShortcut extends StatelessWidget {
  const SaveShortcut({super.key, required this.onSave, required this.child});
  final VoidCallback? onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    void save() => onSave?.call();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): save,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): save,
      },
      child: child,
    );
  }
}

// ─── Page structure ─────────────────────────────────────────────────

/// A page inside the admin shell. The header (back link, title,
/// status and actions) stays put while the content scrolls, so Save
/// and friends are always in reach.
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.scroll = true,
    this.back,
    this.status,
    this.maxWidth = 1120,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  /// Wrap [child] in a scroll view (false when it scrolls itself).
  final bool scroll;

  /// (label, path) of the parent page, shown as "← label".
  final (String, String)? back;

  /// Small widget next to the title (e.g. "unsaved" pill).
  final Widget? status;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final header = Container(
      decoration: BoxDecoration(
        color: context.adminCanvas,
        border: Border(bottom: BorderSide(color: context.adminLine)),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (back case (final label, final path))
                  Align(
                    // The way back is on the left, like the rest of AvA.
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: context.onBgMuted,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: () => context.go(path),
                      child: BackLabel(label),
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  style: context.text.headlineSmall,
                                ),
                              ),
                              ?status,
                            ],
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: context.text.bodyMedium.copyWith(
                                color: context.onBgMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (actions.isNotEmpty)
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: actions,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Widget constrained(Widget w) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: w,
      ),
    );

    const pad = EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xxl,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: scroll
              ? ListView(padding: pad, children: [constrained(child)])
              : constrained(
                  Padding(padding: pad.copyWith(bottom: 0), child: child),
                ),
        ),
      ],
    );
  }
}

/// A white (or dark) card with a hairline border.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accent,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: accent == null
          ? context.adminPanel
          : Color.alphaBlend(
              accent!.withValues(alpha: 0.08),
              context.adminPanel,
            ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: accent?.withValues(alpha: 0.45) ?? context.adminLine,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// A titled panel in forms and lists.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
    this.icon,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Panel(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: context.appColors.accent),
                  const SizedBox(width: AppSpacing.sm),
                ],
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
    );
  }
}

/// Rows inside a panel, separated by hairlines.
class RowList extends StatelessWidget {
  const RowList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) const Divider(height: 1),
            c,
          ],
        ],
      ),
    );
  }
}

/// One clickable list row: a colored edge, title line, details line
/// and trailing widgets (pills, menu).
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing = const [],
    this.color,
    this.onTap,
    this.dimmed = false,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final List<Widget> trailing;

  /// Thin colored bar at the start (e.g. the disease color).
  final Color? color;
  final VoidCallback? onTap;

  /// Archived items look faded.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: context.text.titleSmall,
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle.merge(
                    style: context.text.labelMedium.copyWith(
                      color: context.onBgMuted,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          for (final t in trailing) ...[
            const SizedBox(width: AppSpacing.sm),
            t,
          ],
        ],
      ),
    );
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: onTap == null
          ? row
          : InkWell(onTap: onTap, hoverColor: context.adminHover, child: row),
    );
  }
}

/// A heading between groups of rows: "label (count)" and actions.
class GroupHeader extends StatelessWidget {
  const GroupHeader({
    super.key,
    required this.title,
    this.count,
    this.color,
    this.trailing = const [],
  });
  final String title;
  final int? count;
  final Color? color;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(title, style: context.text.titleSmall),
          if (count != null) ...[
            const SizedBox(width: AppSpacing.sm),
            CountBadge(count!),
          ],
          const Spacer(),
          ...trailing,
        ],
      ),
    );
  }
}

/// A small rounded number.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.color});
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.onBgMuted;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: context.text.labelMedium.copyWith(
          color: context.legible(c),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Icon, a line of text and an optional button, for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.adminHover,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: context.onBgMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: context.text.titleSmall,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: context.text.bodySmall.copyWith(color: context.onBgMuted),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

/// A search box for list toolbars.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.width = 320,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          hintText: hint,
        ),
        onChanged: (v) => onChanged(v.trim()),
      ),
    );
  }
}

/// Filter chip with an optional color dot and count.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
    this.color,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final int? count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      showCheckmark: false,
      selected: selected,
      onSelected: onSelected,
      avatar: color == null
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
      label: Text(count == null ? label : '$label  $count'),
    );
  }
}

/// One entry of a [RowMenu].
class MenuAction {
  const MenuAction(this.label, this.icon, this.onTap, {this.danger = false});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
}

/// "⋯" button with less frequent row actions, so rows aren't a wall of
/// icons.
class RowMenu extends StatelessWidget {
  const RowMenu({
    super.key,
    required this.actions,
    this.tooltip = 'گزینه‌های بیشتر',
  });
  final List<MenuAction> actions;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final danger = context.appColors.danger;
    return PopupMenuButton<int>(
      tooltip: tooltip,
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (i) => actions[i].onTap?.call(),
      itemBuilder: (_) => [
        for (final (i, a) in actions.indexed)
          PopupMenuItem<int>(
            value: i,
            enabled: a.onTap != null,
            child: Row(
              children: [
                Icon(a.icon, size: 20, color: a.danger ? danger : null),
                const SizedBox(width: AppSpacing.md),
                Text(
                  a.label,
                  style: a.danger ? TextStyle(color: danger) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Loading, errors, feedback ──────────────────────────────────────

/// Loading / error / data for an [AsyncValue].
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      // Keep showing the old data while refreshing after an edit.
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: builder,
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: e is AdminException ? e.userMessage : 'دریافت اطلاعات انجام نشد',
        action: onRetry == null
            ? null
            : OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تلاش دوباره'),
              ),
      ),
    );
  }
}

/// Shows an error from the server, with the rule violations if any.
Future<void> showAdminError(BuildContext context, Object error) {
  final e = error is AdminException ? error : null;
  final danger = context.appColors.danger;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.error_outline_rounded, color: danger),
      title: const Text('انجام نشد'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e?.userMessage ?? 'خطایی رخ داد.'),
              for (final issue in e?.issues ?? const <String>[])
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '• $issue',
                    textDirection: TextDirection.ltr,
                    style: context.text.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('باشه'),
        ),
      ],
    ),
  );
}

/// A short message at the bottom of the screen, with an optional
/// action (e.g. undo).
void toast(
  BuildContext context,
  String message, {
  String? action,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action == null
            ? null
            : SnackBarAction(label: action, onPressed: onAction ?? () {}),
      ),
    );
}

/// Runs [action]; shows [success] as a snackbar, or the error. Returns
/// whether it worked.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) toast(context, success);
    return true;
  } catch (e) {
    if (context.mounted) await showAdminError(context, e);
    return false;
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'تأیید',
  String cancel = 'انصراف',
  bool destructive = false,
}) async {
  final danger = context.appColors.danger;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(message),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancel),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: danger)
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

/// A titled dialog with a form body and actions, sized for desktop.
class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.width = 480,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(child: child),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      actions: actions,
    );
  }
}

// ─── Small pieces ───────────────────────────────────────────────────

/// "ویرایش 3 · editor@example.ir · 2 ساعت پیش"
class MetaLine extends StatelessWidget {
  const MetaLine(this.meta, {super.key});
  final Meta meta;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      [
        'ویرایش ${meta.revision}',
        if (meta.updatedBy.isNotEmpty) meta.updatedBy,
        if (meta.updatedAt != null) relativeTime(meta.updatedAt),
      ].join(' · '),
      style: context.text.labelMedium.copyWith(color: context.onBgMuted),
    );
    return meta.updatedAt == null
        ? text
        : Tooltip(message: formatDateTime(meta.updatedAt), child: text);
  }
}

/// Small colored label.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon});
  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.appColors.accent;
    final fg = context.legible(c);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: context.text.labelMedium.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ArchivedPill extends StatelessWidget {
  const ArchivedPill({super.key});

  @override
  Widget build(BuildContext context) => Pill(
    'بایگانی‌شده',
    color: context.onBgMuted,
    icon: Icons.inventory_2_outlined,
  );
}

/// "جدید" / "ویرایش‌شده" when this item differs from the published
/// version.
class DraftPill extends ConsumerWidget {
  const DraftPill({super.key, required this.entity, required this.id});
  final String entity;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(draftStatusProvider.select((m) => m['$entity:$id']));
    final colors = context.appColors;
    return switch (kind) {
      'added' => Pill('جدید، منتشرنشده', color: colors.success),
      'changed' => Pill('ویرایش منتشرنشده', color: colors.caution),
      _ => const SizedBox.shrink(),
    };
  }
}

/// A disease label with its color.
class KindPill extends ConsumerWidget {
  const KindPill(this.kind, {super.key});
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Pill(kindShort(ref, kind), color: kindToneOf(context, ref, kind));
}

/// Up to [max] tags as small chips, then "+n".
class TagChips extends ConsumerWidget {
  const TagChips(this.tags, {super.key, this.max = 4});
  final List<String> tags;
  final int max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tags.isEmpty) {
      return Text(
        'بدون برچسب',
        style: TextStyle(color: context.appColors.warning),
      );
    }
    final labels = {
      for (final t in ref.watch(tagsProvider).value ?? const <TagInfo>[])
        t.name: t.label,
    };
    Widget chip(String text, {String? tip}) {
      final box = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: context.adminLine),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          text,
          textDirection: TextDirection.ltr,
          style: context.text.labelSmall,
        ),
      );
      return tip == null || tip.isEmpty
          ? box
          : Tooltip(message: tip, child: box);
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final t in tags.take(max)) chip(t, tip: labels[t]),
        if (tags.length > max)
          chip('+${tags.length - max}', tip: tags.skip(max).join(', ')),
      ],
    );
  }
}

/// Chips of the chosen tags, and a field to add known tags (with their
/// Persian labels). Unknown tags can't be added here: create them in
/// the tag list first, which keeps typos out.
class TagPicker extends ConsumerStatefulWidget {
  const TagPicker({super.key, required this.tags, required this.onChanged});

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  @override
  ConsumerState<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends ConsumerState<TagPicker> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(tagsProvider).value ?? const <TagInfo>[];
    final byName = {for (final t in all) t.name: t};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.tags.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final t in widget.tags)
                InputChip(
                  label: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: t),
                        if ((byName[t]?.label ?? '').isNotEmpty)
                          TextSpan(
                            text: '  ${byName[t]!.label}',
                            style: TextStyle(color: context.onBgMuted),
                          ),
                      ],
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  onDeleted: () =>
                      widget.onChanged([...widget.tags]..remove(t)),
                  deleteButtonTooltipMessage: 'حذف برچسب',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        RawAutocomplete<TagInfo>(
          textEditingController: _controller,
          focusNode: _focus,
          optionsBuilder: (v) {
            final q = v.text.trim().toLowerCase();
            return all.where(
              (t) =>
                  !widget.tags.contains(t.name) &&
                  (q.isEmpty || t.name.contains(q) || t.label.contains(q)),
            );
          },
          displayStringForOption: (t) => t.name,
          onSelected: (t) {
            widget.onChanged([...widget.tags, t.name]);
            _controller.clear();
            _focus.requestFocus();
          },
          fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
            controller: controller,
            focusNode: focus,
            onSubmitted: (_) => onSubmit(),
            decoration: const InputDecoration(
              hintText: 'افزودن برچسب: نام یا توضیح فارسی را بنویسید',
              prefixIcon: Icon(Icons.sell_outlined, size: 20),
              helperText:
                  'فقط برچسب‌های موجود؛ برچسب تازه را در صفحه «برچسب‌ها» بسازید.',
            ),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: AlignmentDirectional.topStart,
            child: Material(
              elevation: 6,
              color: context.adminPanel,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 300,
                  maxWidth: 420,
                ),
                child: options.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Text('برچسبی پیدا نشد'),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          for (final t in options)
                            ListTile(
                              dense: true,
                              title: Text(t.label.isEmpty ? t.name : t.label),
                              subtitle: t.label.isEmpty
                                  ? null
                                  : Text(
                                      t.name,
                                      textDirection: TextDirection.ltr,
                                    ),
                              trailing: Text(
                                '${t.plans.length} برنامه',
                                style: context.text.labelSmall.copyWith(
                                  color: context.onBgMuted,
                                ),
                              ),
                              onTap: () => onSelected(t),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Up/down buttons for ordering lists (accessible alternative to drag).
class MoveButtons extends StatelessWidget {
  const MoveButtons({super.key, this.onUp, this.onDown});
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'بالاتر',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
        onPressed: onUp,
      ),
      IconButton(
        tooltip: 'پایین‌تر',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.arrow_downward_rounded, size: 18),
        onPressed: onDown,
      ),
    ],
  );
}

/// [ids] with the item at [index] moved by [delta] (-1 up, +1 down).
List<String> moved(List<String> ids, int index, int delta) {
  final next = [...ids];
  final target = index + delta;
  if (target < 0 || target >= next.length) return next;
  final item = next.removeAt(index);
  next.insert(target, item);
  return next;
}

/// [ids] after a drag in a ReorderableListView (oldIndex → newIndex,
/// with Flutter's "newIndex counts the removed item" convention).
List<String> reordered(List<String> ids, int oldIndex, int newIndex) {
  final next = [...ids];
  if (newIndex > oldIndex) newIndex--;
  next.insert(newIndex, next.removeAt(oldIndex));
  return next;
}

/// A list the user can drag to reorder, inside a scrolling page. Each
/// row gets a drag handle; [onReorder] gets the new id order.
class ReorderPanel extends StatelessWidget {
  const ReorderPanel({
    super.key,
    required this.ids,
    required this.itemBuilder,
    required this.onReorder,
  });

  final List<String> ids;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ValueChanged<List<String>> onReorder;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: ids.length,
        onReorder: (o, n) {
          if (o == n || o + 1 == n) return;
          onReorder(reordered(ids, o, n));
        },
        itemBuilder: (context, i) => Material(
          key: ValueKey(ids[i]),
          color: context.adminPanel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i > 0) const Divider(height: 1),
              Row(
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Icon(Icons.drag_indicator_rounded),
                      ),
                    ),
                  ),
                  Expanded(child: itemBuilder(context, i)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "›" at the end of a row that opens something. Points right whatever
/// the text direction, since AvA's navigation flows left to right.
class ForwardChevron extends StatelessWidget {
  const ForwardChevron({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Icon(Icons.chevron_right_rounded, color: context.onBgMuted),
  );
}

/// "ویرایش برنامه مراقبتی acs-01 · editor@… · 5 دقیقه پیش"
class ActivityRow extends StatelessWidget {
  const ActivityRow(this.entry, {super.key, this.onTap});
  final AuditEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = actionColor(context, entry.action);
    return ListRow(
      onTap: onTap,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          shape: BoxShape.circle,
        ),
        child: Icon(
          entityIcons[entry.entity] ?? Icons.circle_outlined,
          size: 16,
          color: context.legible(color),
        ),
      ),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${actionLabels[entry.action] ?? entry.action} '),
            TextSpan(
              text: entityLabels[entry.entity] ?? entry.entity,
              style: TextStyle(
                color: context.onBgMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (entry.entityId.isNotEmpty)
              TextSpan(text: '  ${entry.entityId}'),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('${entry.user} · ${relativeTime(entry.at)}'),
      trailing: [
        if (onTap != null)
          Icon(Icons.expand_more_rounded, color: context.onBgMuted),
      ],
    );
  }
}
