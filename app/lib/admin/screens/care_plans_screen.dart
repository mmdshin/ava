import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/admin/admin_app.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

class CarePlansScreen extends ConsumerStatefulWidget {
  const CarePlansScreen({super.key});

  @override
  ConsumerState<CarePlansScreen> createState() => _CarePlansScreenState();
}

class _CarePlansScreenState extends ConsumerState<CarePlansScreen> {
  String _query = '';
  String _kind = '';
  bool _showArchived = false;
  bool _reorder = false;

  Future<void> _saveOrder(String kind, List<String> ids) async {
    await runAction(context, () async {
      await ref.read(adminApiProvider).reorderCarePlans(kind, ids);
      ref.invalidate(carePlansListProvider);
      refreshDraft(ref);
    }, success: 'ترتیب ذخیره شد');
  }

  bool _matches(PlanSummary p) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return p.title.contains(_query) ||
        p.id.toLowerCase().contains(q) ||
        p.tags.any((t) => t.contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(carePlansListProvider);
    final all = plans.value ?? const <PlanSummary>[];
    int countOf(String kind) =>
        all.where((p) => p.kind == kind && !p.meta.archived).length;
    final canReorder = _kind.isNotEmpty;

    return AdminPage(
      title: 'برنامه‌های مراقبتی',
      subtitle:
          'تشخیص‌های پرستاری هر بیماری. ترتیب این فهرست همان ترتیب نمایش در برنامه است.',
      actions: [
        if (canReorder)
          _reorder
              ? FilledButton.icon(
                  onPressed: () => setState(() => _reorder = false),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('پایان تغییر ترتیب'),
                )
              : OutlinedButton.icon(
                  onPressed: () => setState(() => _reorder = true),
                  icon: const Icon(Icons.swap_vert_rounded),
                  label: const Text('تغییر ترتیب'),
                ),
        if (!_reorder)
          FilledButton.icon(
            onPressed: () => context.go(
              _kind.isEmpty
                  ? AdminRoutes.newCarePlan
                  : '${AdminRoutes.newCarePlan}?kind=$_kind',
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('برنامه جدید'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!_reorder)
                SearchField(
                  hint: 'جستجو در عنوان، شناسه یا برچسب',
                  onChanged: (v) => setState(() => _query = v),
                ),
              FilterPill(
                label: 'همه',
                count: all.where((p) => !p.meta.archived).length,
                selected: _kind.isEmpty,
                onSelected: (_) => setState(() {
                  _kind = '';
                  _reorder = false;
                }),
              ),
              for (final k
                  in ref.watch(activeCategoriesProvider).map((c) => c.id))
                FilterPill(
                  label: kindShort(ref, k),
                  color: kindToneOf(context, ref, k),
                  count: countOf(k),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
              if (!_reorder)
                FilterPill(
                  label: 'بایگانی‌شده‌ها',
                  selected: _showArchived,
                  onSelected: (v) => setState(() => _showArchived = v),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AsyncBody(
            value: plans,
            onRetry: () => ref.invalidate(carePlansListProvider),
            builder: (all) {
              if (_reorder) {
                final ofKind = [
                  for (final p in all)
                    if (p.kind == _kind && !p.meta.archived) p,
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        'ردیف‌ها را با دستگیره بکشید و رها کنید؛ ترتیب بلافاصله ذخیره می‌شود.',
                        style: context.text.bodySmall.copyWith(
                          color: context.onBgMuted,
                        ),
                      ),
                    ),
                    ReorderPanel(
                      ids: [for (final p in ofKind) p.id],
                      onReorder: (ids) => _saveOrder(_kind, ids),
                      itemBuilder: (context, i) =>
                          _PlanRow(plan: ofKind[i], compact: true),
                    ),
                  ],
                );
              }

              final visible = [
                for (final p in all)
                  if ((_kind.isEmpty || p.kind == _kind) &&
                      (_showArchived || !p.meta.archived) &&
                      _matches(p))
                    p,
              ];
              if (visible.isEmpty) {
                return Panel(
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: _query.isEmpty
                        ? 'برنامه‌ای نیست'
                        : 'برنامه‌ای با «$_query» پیدا نشد',
                    action: FilledButton.tonalIcon(
                      onPressed: () => context.go(AdminRoutes.newCarePlan),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('برنامه جدید'),
                    ),
                  ),
                );
              }

              final known = [
                for (final c
                    in ref.watch(categoriesListProvider).value ??
                        const <CategoryInfo>[])
                  c.id,
              ];
              final groups = _kind.isEmpty
                  ? [
                      ...known,
                      ...{
                        for (final p in visible)
                          if (!known.contains(p.kind)) p.kind,
                      },
                    ]
                  : [_kind];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final k in groups)
                    if ([
                          for (final p in visible)
                            if (p.kind == k) p,
                        ]
                        case final list when list.isNotEmpty) ...[
                      GroupHeader(
                        title: kindTitle(ref, k),
                        count: list.length,
                        color: kindToneOf(context, ref, k),
                        trailing: [
                          TextButton.icon(
                            onPressed: () => context.go(
                              '${AdminRoutes.newCarePlan}?kind=$k',
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('افزودن'),
                          ),
                        ],
                      ),
                      RowList(
                        children: [for (final p in list) _PlanRow(plan: p)],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends ConsumerWidget {
  const _PlanRow({required this.plan, this.compact = false});
  final PlanSummary plan;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = plan;
    return ListRow(
      color: kindToneOf(context, ref, p.kind),
      dimmed: p.meta.archived,
      title: Text(p.title),
      subtitle: compact
          ? Text(p.id, textDirection: TextDirection.ltr)
          : Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(p.id, textDirection: TextDirection.ltr),
                TagChips(p.tags),
              ],
            ),
      trailing: [
        if (p.meta.archived) const ArchivedPill(),
        DraftPill(entity: 'care_plan', id: p.id),
        if (!compact && p.meta.updatedAt != null)
          Tooltip(
            message:
                '${p.meta.updatedBy} · ${formatDateTime(p.meta.updatedAt)}',
            child: Text(
              relativeTime(p.meta.updatedAt),
              style: context.text.labelSmall.copyWith(color: context.onBgMuted),
            ),
          ),
        if (!compact) const ForwardChevron(),
      ],
      onTap: compact ? null : () => context.go(AdminRoutes.carePlan(p.id)),
    );
  }
}
