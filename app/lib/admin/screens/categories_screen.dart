import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/core/kind_style.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';

/// Colors offered for a category card (any "#RRGGBB" can be typed too).
const _swatches = [
  '#17A398',
  '#0E7490',
  '#3D8BFF',
  '#2563EB',
  '#6C4FD1',
  '#8B5CF6',
  '#E85D9C',
  '#EF5875',
  '#DC2626',
  '#F2994A',
  '#F2A93E',
  '#CA8A04',
  '#16A34A',
  '#4D7C0F',
  '#64748B',
  '#78716C',
];

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _reorder = false;
  bool _showArchived = false;

  void _refresh() {
    ref.invalidate(categoriesListProvider);
    ref.invalidate(carePlansListProvider);
    ref.invalidate(quizzesListProvider);
    refreshDraft(ref);
  }

  Future<void> _edit(CategoryInfo? c) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CategoryDialog(category: c),
    );
    if (body == null || !mounted) return;
    final api = ref.read(adminApiProvider);
    await runAction(
      context,
      () async {
        if (c == null) {
          await api.createCategory(body);
        } else {
          await api.updateCategory(c.id, {
            ...body,
            'revision': c.meta.revision,
          });
        }
        _refresh();
      },
      success: c == null
          ? 'دسته ساخته شد؛ حالا برایش برنامه مراقبتی بنویسید'
          : 'ذخیره شد',
    );
  }

  Future<void> _setArchived(CategoryInfo c, bool archived) async {
    if (archived &&
        !await confirm(
          context,
          title: 'حذف دسته «${c.title}»',
          message:
              'این دسته از نسخه بعدی برنامه حذف می‌شود. بعداً می‌توانید آن را بازگردانید.',
          action: 'حذف',
          destructive: true,
        )) {
      return;
    }
    if (!mounted) return;
    await runAction(context, () async {
      await ref
          .read(adminApiProvider)
          .setArchived('categories', c.id, archived);
      _refresh();
    }, success: archived ? 'دسته حذف شد' : 'دسته بازگردانده شد');
  }

  Future<void> _saveOrder(List<String> ids) => runAction(context, () async {
    await ref.read(adminApiProvider).reorderCategories(ids);
    _refresh();
  }, success: 'ترتیب ذخیره شد');

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesListProvider);
    final all = categories.value ?? const <CategoryInfo>[];
    final active = [
      for (final c in all)
        if (!c.meta.archived) c,
    ];
    final archivedCount = all.length - active.length;

    return AdminPage(
      title: 'دسته‌های بیماری',
      subtitle:
          'برنامه‌های مراقبتی و آزمون‌ها در این دسته‌ها قرار می‌گیرند. '
          'نام، رنگ کارت و آیکون همان چیزی است که پرستار در برنامه می‌بیند.',
      actions: [
        if (active.length > 1)
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
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('دسته جدید'),
          ),
      ],
      child: AsyncBody(
        value: categories,
        onRetry: () => ref.invalidate(categoriesListProvider),
        builder: (_) {
          if (_reorder) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'ردیف‌ها را بکشید؛ همین ترتیب در صفحه اصلی و فهرست تشخیص‌ها دیده می‌شود.',
                    style: context.text.bodySmall.copyWith(
                      color: context.onBgMuted,
                    ),
                  ),
                ),
                ReorderPanel(
                  ids: [for (final c in active) c.id],
                  onReorder: _saveOrder,
                  itemBuilder: (context, i) =>
                      _CategoryRow(category: active[i], compact: true),
                ),
              ],
            );
          }
          final shown = _showArchived ? all : active;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'پیش‌نمایش در برنامه',
                style: context.text.labelLarge.copyWith(
                  color: context.onBgMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final c in active)
                    SizedBox(width: 132, child: CategoryTile(kind: c.kind)),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Text('همه دسته‌ها', style: context.text.titleSmall),
                  const SizedBox(width: AppSpacing.sm),
                  CountBadge(active.length),
                  const Spacer(),
                  if (archivedCount > 0)
                    FilterPill(
                      label: 'حذف‌شده‌ها',
                      count: archivedCount,
                      selected: _showArchived,
                      onSelected: (v) => setState(() => _showArchived = v),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              RowList(
                children: [
                  for (final c in shown)
                    _CategoryRow(
                      key: ValueKey(c.id),
                      category: c,
                      onEdit: () => _edit(c),
                      onArchive: () => _setArchived(c, !c.meta.archived),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'دسته‌ای را که برنامه یا آزمون فعال دارد نمی‌توان حذف کرد؛ اول آن‌ها را بایگانی کنید. '
                'دسته «عمومی» همیشه می‌ماند: برنامه‌های آن در تشخیص‌یاب برای همه بیماری‌ها پیشنهاد می‌شوند.',
                style: context.text.bodySmall.copyWith(
                  color: context.onBgMuted,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.category,
    this.onEdit,
    this.onArchive,
    this.compact = false,
  });

  final CategoryInfo category;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = category;
    final tone = context.kindTone(c.kind);
    final archiveLabel = c.meta.archived
        ? 'بازگردانی'
        : c.isGeneral
        ? 'حذف (دسته عمومی همیشه می‌ماند)'
        : c.canArchive
        ? 'حذف'
        : 'حذف (اول برنامه‌ها و آزمون‌هایش را بایگانی کنید)';
    return ListRow(
      dimmed: c.meta.archived,
      onTap: compact ? null : onEdit,
      leading: CategoryBadge(kind: c.kind),
      title: Wrap(
        spacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(c.title),
          if (c.abbr.isNotEmpty) Pill(c.abbr, color: tone),
          if (c.isGeneral)
            Pill('مشترک همه بیماری‌ها', color: context.onBgMuted),
        ],
      ),
      subtitle: Text('${c.id} · ${c.plans} برنامه · ${c.quizzes} آزمون'),
      trailing: [
        if (c.meta.archived) const ArchivedPill(),
        DraftPill(entity: 'category', id: c.id),
        if (!compact)
          RowMenu(
            actions: [
              MenuAction('ویرایش', Icons.edit_rounded, onEdit),
              MenuAction(
                archiveLabel,
                c.meta.archived
                    ? Icons.unarchive_rounded
                    : Icons.delete_outline_rounded,
                c.meta.archived || c.canArchive ? onArchive : null,
                danger: !c.meta.archived,
              ),
            ],
          ),
      ],
    );
  }
}

class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.kind, this.size = 40});
  final Kind kind;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: kind.color, shape: BoxShape.circle),
    child: Icon(kindIcon(kind), color: Colors.white, size: size * 0.52),
  );
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.kind});
  final Kind kind;

  @override
  Widget build(BuildContext context) {
    final tone = context.kindTone(kind);
    final abbr = kindAbbr(kind);
    return Panel(
      accent: tone,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        height: 76,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(kindIcon(kind), color: tone),
                const Spacer(),
                if (abbr != null)
                  Text(
                    abbr,
                    style: context.text.labelMedium.copyWith(
                      color: context.legible(tone),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              kindName(kind),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});
  final CategoryInfo? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _title = TextEditingController(text: widget.category?.title ?? '');
  late final _abbr = TextEditingController(text: widget.category?.abbr ?? '');
  late final _id = TextEditingController(text: widget.category?.id ?? '');
  late final _hex = TextEditingController(
    text: widget.category?.color ?? _swatches.first,
  );
  late String _icon = widget.category?.icon ?? 'medical_information';

  bool _idTouched = false;

  static final _idFormat = RegExp(r'^[a-z][a-z0-9]{1,19}$');
  static final _hexFormat = RegExp(r'^#[0-9A-Fa-f]{6}$');

  bool get _isNew => widget.category == null;

  @override
  void dispose() {
    for (final c in [_title, _abbr, _id, _hex]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _color {
    final t = _hex.text.trim();
    return t.startsWith('#') ? t.toUpperCase() : '#${t.toUpperCase()}';
  }

  String? get _idError {
    if (!_isNew) return null;
    final id = _id.text.trim();
    if (id.isEmpty) return null;
    return _idFormat.hasMatch(id)
        ? null
        : 'حروف کوچک انگلیسی و عدد، 2 تا 20 نویسه، با حرف شروع شود';
  }

  String? get _hexError => _hexFormat.hasMatch(_color) ? null : 'مثل #17A398';

  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      _hexError == null &&
      (!_isNew || (_id.text.trim().isNotEmpty && _idError == null));

  void _submit() {
    if (!_valid) return;
    Navigator.pop(context, {
      if (_isNew) 'id': _id.text.trim(),
      'title': _title.text.trim(),
      'abbr': _abbr.text.trim(),
      'color': _color,
      'icon': _icon,
    });
  }

  Kind get _preview => Kind(
    id: _id.text.trim().isEmpty ? 'new' : _id.text.trim(),
    title: _title.text.trim().isEmpty ? 'نام بیماری' : _title.text.trim(),
    abbr: _abbr.text.trim(),
    color: _hexError == null ? parseHexColor(_color) : const Color(0xFF888888),
    icon: _icon,
  );

  @override
  Widget build(BuildContext context) {
    final accent = context.appColors.accent;
    return ListenableBuilder(
      listenable: Listenable.merge([_title, _abbr, _id, _hex]),
      builder: (context, _) => FormDialog(
        title: _isNew ? 'دسته جدید' : 'ویرایش «${widget.category!.title}»',
        width: 620,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: _valid ? _submit : null,
            child: const Text('ذخیره'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _title,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'نام بیماری',
                          hintText: 'مثلاً: بیماری انسدادی مزمن ریه',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _abbr,
                        textDirection: TextDirection.ltr,
                        onChanged: (v) {
                          if (_isNew && !_idTouched) {
                            _id.text = v.trim().toLowerCase().replaceAll(
                              RegExp('[^a-z0-9]'),
                              '',
                            );
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'نام کوتاه (اختیاری)',
                          hintText: 'COPD',
                          helperText: 'روی کارت‌ها نمایش داده می‌شود.',
                        ),
                      ),
                      if (_isNew) ...[
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _id,
                          textDirection: TextDirection.ltr,
                          onChanged: (_) => _idTouched = true,
                          decoration: InputDecoration(
                            labelText: 'شناسه انگلیسی',
                            hintText: 'copd',
                            errorText: _idError,
                            helperText:
                                'شناسه برنامه‌ها با آن ساخته می‌شود (copd-01) و بعداً عوض نمی‌شود.',
                            helperMaxLines: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'پیش‌نمایش',
                        style: context.text.labelMedium.copyWith(
                          color: context.onBgMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      CategoryTile(kind: _preview),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('رنگ کارت', style: context.text.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final hex in _swatches)
                  _Swatch(
                    color: parseHexColor(hex),
                    selected: _color == hex,
                    onTap: () => _hex.text = hex,
                  ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _hex,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'کد رنگ',
                      errorText: _hexError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('آیکون', style: context.text.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final MapEntry(key: name, value: icon)
                    in kindIcons.entries)
                  IconButton(
                    tooltip: name,
                    isSelected: _icon == name,
                    style: IconButton.styleFrom(
                      backgroundColor: _icon == name
                          ? accent.withValues(alpha: 0.15)
                          : null,
                      side: BorderSide(
                        color: _icon == name ? accent : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    icon: Icon(
                      icon,
                      color: _icon == name ? accent : context.onBgMuted,
                    ),
                    onPressed: () => setState(() => _icon = name),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? context.onBg : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}
