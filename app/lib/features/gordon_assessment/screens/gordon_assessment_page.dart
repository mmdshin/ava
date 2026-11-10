import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/app/router.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/core/kind_style.dart';
import 'package:ava_web/core/persian_text.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/gordon_assessment/assessment_selection.dart';
import 'package:ava_web/features/gordon_assessment/matching.dart';
import 'package:ava_web/features/gordon_assessment/models/assessment_item.dart';
import 'package:ava_web/features/gordon_assessment/models/gordon_domain.dart';
import 'package:ava_web/features/gordon_assessment/widgets/finder_steps.dart';

/// Icon per Gordon functional health pattern (by domain id).
IconData _domainIcon(String id) => switch (id) {
  'health_promotion' => Icons.health_and_safety_rounded,
  'nutrition' => Icons.restaurant_rounded,
  'elimination' => Icons.water_drop_rounded,
  'activity_rest' => Icons.directions_walk_rounded,
  'perception_cognition' => Icons.psychology_rounded,
  'self_perception' => Icons.self_improvement_rounded,
  'role_relationship' => Icons.family_restroom_rounded,
  'sexuality' => Icons.favorite_border_rounded,
  'coping_stress' => Icons.spa_rounded,
  'life_principles' => Icons.auto_awesome_rounded,
  'safety_protection' => Icons.shield_rounded,
  'comfort' => Icons.hotel_rounded,
  _ => Icons.category_rounded,
};

const _domainColors = [
  Color(0xFF3D8BFF),
  Color(0xFF17A398),
  Color(0xFF8B5CF6),
  Color(0xFFF2A93E),
  Color(0xFFEF5875),
  Color(0xFF0EA5E9),
];

class GordonAssessmentPage extends ConsumerStatefulWidget {
  const GordonAssessmentPage({super.key, required this.selectedKind});
  final Kind selectedKind;

  @override
  ConsumerState<GordonAssessmentPage> createState() =>
      _GordonAssessmentPageState();
}

class _GordonAssessmentPageState extends ConsumerState<GordonAssessmentPage> {
  final _selected = <String>{};
  final _expanded = <String>{};
  final _searchController = TextEditingController();
  final _sectionKeys = <String, GlobalKey>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Re-opening the finder for the same disease restores the last
    // submitted selection.
    final last = ref.read(lastAssessmentProvider);
    if (last != null && last.kind == widget.selectedKind) {
      _selected.addAll(last.items.map((i) => i.id));
    }
    // Start with the first pattern open so the page isn't a wall of
    // closed headers; patterns that already have selections open too.
    final domains = ref.read(gordonDomainsProvider);
    if (domains.isNotEmpty) _expanded.add(domains.first.id);
    for (final d in domains) {
      if (d.items.any((i) => _selected.contains(i.id))) _expanded.add(d.id);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AssessmentItem> _selectedItems(List<GordonDomain> domains) => [
    for (final d in domains)
      for (final i in d.items)
        if (_selected.contains(i.id)) i,
  ];

  void _toggle(AssessmentItem item) => setState(() {
    if (!_selected.remove(item.id)) _selected.add(item.id);
  });

  void _clearAll() => setState(_selected.clear);

  void _toggleSection(String id) => setState(() {
    if (!_expanded.remove(id)) _expanded.add(id);
  });

  /// Opens [id]'s section and scrolls to it (wide-screen pattern index).
  void _jumpTo(String id) {
    setState(() => _expanded.add(id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sectionKeys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _submit(List<GordonDomain> domains) {
    final items = _selectedItems(domains);
    if (items.isEmpty) return;
    ref
        .read(lastAssessmentProvider.notifier)
        .submit(AssessmentSelection(kind: widget.selectedKind, items: items));
    context.push(AppRoutes.assessmentResults(widget.selectedKind));
  }

  @override
  Widget build(BuildContext context) {
    final domains = ref.watch(gordonDomainsProvider);
    final items = _selectedItems(domains);
    final matches = matchCarePlans(
      plans: ref.watch(carePlansProvider),
      selectedTags: {for (final i in items) ...i.tags},
      kind: widget.selectedKind,
    );
    final matchCount = matches.specific.length + matches.general.length;

    final summary = _Summary(
      selectedCount: items.length,
      matchCount: matchCount,
      onSubmit: items.isEmpty ? null : () => _submit(domains),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FlowAppBar(
        title: Text('بررسی بیمار', style: context.text.titleLarge),
        actions: [
          if (_selected.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('پاک کردن همه'),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1000;
              final content = _buildContent(domains);

              if (!wide) {
                return Column(
                  children: [
                    Expanded(child: content),
                    _BottomBar(child: summary),
                  ],
                );
              }

              // Wide screens: pattern index | findings | selection panel.
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 260,
                        child: _DomainIndex(
                          domains: domains,
                          selected: _selected,
                          onTap: _jumpTo,
                        ),
                      ),
                      Expanded(child: content),
                      SizedBox(
                        width: 300,
                        child: _SelectionPanel(
                          items: items,
                          onRemove: _toggle,
                          summary: summary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<GordonDomain> domains) {
    final searching = normalizeForSearch(_query).isNotEmpty;
    final kind = widget.selectedKind;

    final sections = <Widget>[];
    for (var i = 0; i < domains.length; i++) {
      final d = domains[i];
      final visible = searching
          ? d.items.where((it) => searchMatches(it.title, _query)).toList()
          : d.items;
      if (searching && visible.isEmpty) continue;
      final key = _sectionKeys.putIfAbsent(d.id, GlobalKey.new);
      sections.add(
        Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _DomainSection(
            domain: d,
            color: context.legible(
              _domainColors[i % _domainColors.length],
              minRatio: 3,
            ),
            items: visible,
            selected: _selected,
            // While searching, every section with a match is open.
            expanded: searching || _expanded.contains(d.id),
            onToggleExpanded: () => _toggleSection(d.id),
            onToggleItem: _toggle,
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),

        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FinderSteps(current: 1),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(kindIcon(kind), color: context.kindTone(kind), size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      kind.isGeneral ? 'تشخیص‌های عمومی' : kindLabel(kind),
                      style: context.text.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'یافته‌هایی را که در بررسی بیمار دیده‌اید انتخاب کنید.',
                style: context.text.bodySmall.copyWith(
                  color: context.onBgMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (sections.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Text(
                    'یافته‌ای با «$_query» پیدا نشد',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium.copyWith(
                      color: context.onBgMuted,
                    ),
                  ),
                )
              else
                ...sections,
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final glass = context.appColors.glass;
    OutlineInputBorder border(double alpha) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: glass.withValues(alpha: alpha)),
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: context.text.bodyMedium,
        decoration: InputDecoration(
          hintText: 'جستجوی یافته (مثلاً درد، تنگی نفس)…',
          hintStyle: context.text.bodyMedium.copyWith(color: context.onBgMuted),
          prefixIcon: Icon(Icons.search_rounded, color: context.onBgMuted),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'پاک کردن جستجو',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: glass.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          border: border(0.18),
          enabledBorder: border(0.18),
          focusedBorder: border(0.45),
        ),
      ),
    );
  }
}

/// One Gordon pattern: header (icon, title, selected/total, chevron)
/// and, when expanded, its findings as selectable chips.
class _DomainSection extends StatelessWidget {
  const _DomainSection({
    required this.domain,
    required this.color,
    required this.items,
    required this.selected,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onToggleItem,
  });

  final GordonDomain domain;
  final Color color;
  final List<AssessmentItem> items;
  final Set<String> selected;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<AssessmentItem> onToggleItem;

  @override
  Widget build(BuildContext context) {
    final count = domain.items.where((i) => selected.contains(i.id)).length;
    final hasAny = count > 0;

    return AppCard(
      accent: hasAny ? color : null,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: hasAny ? 1 : 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _domainIcon(domain.id),
                      size: 20,
                      color: hasAny ? Colors.white : color,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(domain.title, style: context.text.titleSmall),
                  ),
                  _CountBadge(
                    count: count,
                    total: domain.items.length,
                    color: color,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: context.onBgMuted,
                      semanticLabel: expanded ? 'بستن' : 'باز کردن',
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final item in items)
                          _FindingChip(
                            label: item.title,
                            color: color,
                            selected: selected.contains(item.id),
                            onTap: () => onToggleItem(item),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.total,
    required this.color,
  });
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.18)
            : context.appColors.glass.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count/$total',
        style: context.text.labelMedium.copyWith(
          color: active ? context.onBg : context.onBgMuted,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// A finding the user can tick. Long labels wrap inside the chip.
class _FindingChip extends StatelessWidget {
  const _FindingChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.appColors.glass;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.18)
            : glass.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(
            color: selected ? color : glass.withValues(alpha: 0.2),
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(selected),
                    size: 18,
                    color: selected ? color : context.onBgMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    style: context.text.bodySmall.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.selectedCount,
    required this.matchCount,
    required this.onSubmit,
    this.vertical = false,
  });

  final int selectedCount;
  final int matchCount;
  final VoidCallback? onSubmit;
  final bool vertical;

  _Summary asVertical() => _Summary(
    selectedCount: selectedCount,
    matchCount: matchCount,
    onSubmit: onSubmit,
    vertical: true,
  );

  @override
  Widget build(BuildContext context) {
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          selectedCount == 0
              ? 'هنوز یافته‌ای انتخاب نشده'
              : '$selectedCount یافته انتخاب شده',
          style: context.text.titleSmall,
        ),
        const SizedBox(height: 2),
        Text(
          selectedCount == 0
              ? 'برای دیدن پیشنهادها، یافته‌ها را انتخاب کنید'
              : matchCount == 0
              ? 'هنوز برنامه مراقبتی منطبقی نیست'
              : '$matchCount برنامه مراقبتی منطبق',
          style: context.text.labelLarge.copyWith(
            color: matchCount > 0
                ? context.appColors.success
                : context.onBgMuted,
          ),
        ),
      ],
    );
    final button = FilledButton(
      onPressed: onSubmit,
      child: const NextLabel('مشاهده نتایج'),
    );

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          info,
          const SizedBox(height: AppSpacing.md),
          button,
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        if (constraints.maxWidth < 340 * textScale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              info,
              const SizedBox(height: AppSpacing.sm),
              button,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: info),
            const SizedBox(width: AppSpacing.md),
            button,
          ],
        );
      },
    );
  }
}

/// Sticky bottom bar on phones / narrow windows.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.dialogSurface,
        border: Border(
          top: BorderSide(color: colors.glass.withValues(alpha: 0.12)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide screens: list of patterns with counts; tap to jump to one.
class _DomainIndex extends StatelessWidget {
  const _DomainIndex({
    required this.domains,
    required this.selected,
    required this.onTap,
  });
  final List<GordonDomain> domains;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'الگوهای گوردون',
            style: context.text.labelLarge.copyWith(color: context.onBgMuted),
          ),
        ),
        for (var i = 0; i < domains.length; i++)
          Builder(
            builder: (context) {
              final d = domains[i];
              final n = d.items.where((it) => selected.contains(it.id)).length;
              final color = context.legible(
                _domainColors[i % _domainColors.length],
                minRatio: 3,
              );
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                horizontalTitleGap: AppSpacing.sm,
                minLeadingWidth: 20,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                leading: Icon(_domainIcon(d.id), color: color, size: 20),
                title: Text(d.title, style: context.text.bodySmall),
                trailing: n == 0
                    ? null
                    : CircleAvatar(
                        radius: 11,
                        backgroundColor: color,
                        child: Text(
                          '$n',
                          style: context.text.labelMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                onTap: () => onTap(d.id),
              );
            },
          ),
      ],
    );
  }
}

/// Wide screens: the selected findings (removable) + summary.
class _SelectionPanel extends StatelessWidget {
  const _SelectionPanel({
    required this.items,
    required this.onRemove,
    required this.summary,
  });
  final List<AssessmentItem> items;
  final ValueChanged<AssessmentItem> onRemove;
  final _Summary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            summary.asVertical(),
            if (items.isNotEmpty) ...[
              const Divider(height: AppSpacing.xxl),
              Flexible(
                // Rows (not InputChips): long findings wrap instead of
                // being clipped at the start.
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Material(
                            color: context.appColors.glass.withValues(
                              alpha: 0.06,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: AppSpacing.md,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: context.text.bodySmall,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف',
                                    visualDensity: VisualDensity.compact,
                                    iconSize: 18,
                                    onPressed: () => onRemove(item),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
