import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/admin/admin_app.dart';
import 'package:ava_web/admin/admin_theme.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/core/theme_controller.dart';
import 'package:ava_web/features/account/session.dart';

class _Dest {
  const _Dest(this.path, this.label, this.icon, [this.role = 'editor']);
  final String path;
  final String label;
  final IconData icon;
  final String role;
}

const _groups = <(String?, List<_Dest>)>[
  (
    null,
    [_Dest(AdminRoutes.dashboard, 'خلاصه', Icons.space_dashboard_rounded)],
  ),
  (
    'محتوا',
    [
      _Dest(AdminRoutes.categories, 'دسته‌های بیماری', Icons.category_rounded),
      _Dest(
        AdminRoutes.carePlans,
        'برنامه‌های مراقبتی',
        Icons.medical_information_rounded,
      ),
      _Dest(AdminRoutes.quizzes, 'آزمون‌ها', Icons.quiz_rounded),
      _Dest(AdminRoutes.assessment, 'بررسی گوردون', Icons.checklist_rounded),
      _Dest(AdminRoutes.tags, 'برچسب‌ها', Icons.sell_rounded),
    ],
  ),
  (
    'نسخه‌ها',
    [
      _Dest(AdminRoutes.publish, 'انتشار', Icons.rocket_launch_rounded),
      _Dest(AdminRoutes.history, 'تاریخچه', Icons.history_rounded),
    ],
  ),
  (
    'سامانه',
    [
      _Dest(AdminRoutes.users, 'کاربران', Icons.group_rounded, 'admin'),
      _Dest(AdminRoutes.settings, 'تنظیمات', Icons.tune_rounded, 'admin'),
    ],
  ),
];

bool _isCurrent(String path, String location) =>
    path == location || (path != '/' && location.startsWith(path));

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final groups = [
      for (final (title, dests) in _groups)
        if ([
              for (final d in dests)
                if (hasRole(role, d.role)) d,
            ]
            case final visible when visible.isNotEmpty)
          (title, visible),
    ];

    if (groups.isEmpty) return const Scaffold(body: SizedBox.shrink());

    final wide = MediaQuery.sizeOf(context).width >= 1000;
    Widget rtl(Widget w) =>
        Directionality(textDirection: TextDirection.rtl, child: w);

    if (wide) {
      return Scaffold(
        body: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              rtl(_Sidebar(groups: groups, location: location)),
              Expanded(child: rtl(SafeArea(left: false, child: child))),
            ],
          ),
        ),
      );
    }

    var current = 'مدیریت آوا';
    for (final (_, dests) in groups) {
      for (final d in dests) {
        if (_isCurrent(d.path, location)) current = d.label;
      }
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: context.adminPanel,
          shape: Border(bottom: BorderSide(color: context.adminLine)),
          title: rtl(Text(current, style: context.text.titleMedium)),
        ),
        drawer: Drawer(
          width: 272,
          backgroundColor: context.adminPanel,
          child: rtl(
            _Sidebar(groups: groups, location: location, inDrawer: true),
          ),
        ),
        body: rtl(SafeArea(child: child)),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.groups,
    required this.location,
    this.inDrawer = false,
  });

  final List<(String?, List<_Dest>)> groups;
  final String location;
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final changes = ref.watch(draftChangesProvider).value?.length ?? 0;
    final errors = ref.watch(draftIssuesProvider).value?.errors.length ?? 0;
    final frozen = ref.watch(freezeProvider).value?.frozen ?? false;

    void go(String path) {
      if (inDrawer) Navigator.pop(context);
      context.go(path);
    }

    Widget? badgeFor(_Dest d) {
      if (d.path != AdminRoutes.publish) return null;
      if (errors > 0) return CountBadge(errors, color: colors.danger);
      if (changes > 0) return CountBadge(changes, color: colors.accent);
      return null;
    }

    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: context.adminPanel,
        border: inDrawer
            ? null
            : Border(right: BorderSide(color: context.adminLine)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.brand,
                      borderRadius: BorderRadius.circular(AppRadius.sm - 4),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مدیریت آوا', style: context.text.titleSmall),
                        Text(
                          'ویرایش و انتشار محتوا',
                          style: context.text.labelSmall.copyWith(
                            color: context.onBgMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (frozen)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Pill(
                  'انتشار قفل است',
                  color: colors.warning,
                  icon: Icons.lock_rounded,
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                children: [
                  for (final (title, dests) in groups) ...[
                    if (title != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.xs,
                        ),
                        child: Text(
                          title,
                          style: context.text.labelMedium.copyWith(
                            color: context.onBgMuted,
                          ),
                        ),
                      ),
                    for (final d in dests)
                      _NavItem(
                        dest: d,
                        selected: _isCurrent(d.path, location),
                        badge: badgeFor(d),
                        onTap: () => go(d.path),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            const _UserBox(),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.dest,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final accent = context.appColors.accent;
    final fg = selected ? accent : context.onBg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm - 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm - 4),
            hoverColor: context.adminHover,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    dest.icon,
                    size: 20,
                    color: selected ? accent : context.onBgMuted,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      dest.label,
                      style: context.text.labelLarge.copyWith(
                        color: fg,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  ?badge,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserBox extends ConsumerWidget {
  const _UserBox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider)?.user;
    final role = ref.watch(roleProvider);
    final name = user?.name ?? '';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: context.appColors.accent.withValues(alpha: 0.15),
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: context.text.labelLarge.copyWith(
                color: context.appColors.accent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: context.text.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  roleLabels[role] ?? role,
                  style: context.text.labelSmall.copyWith(
                    color: context.onBgMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'تغییر حالت روشن/تیره',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.contrast_rounded, size: 20),
            onPressed: () => ref.read(themeProvider.notifier).cycleMode(),
          ),
          IconButton(
            tooltip: 'خروج',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () async {
              if (await confirmLeave(context)) {
                await ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }
}
