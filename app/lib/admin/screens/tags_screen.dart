import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

enum _TagFilter { all, unused, noPlan }

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  String _query = '';
  _TagFilter _filter = _TagFilter.all;

  void _refresh() {
    ref.invalidate(tagsProvider);
    ref.invalidate(domainsProvider);
    ref.invalidate(carePlansListProvider);
    refreshDraft(ref);
  }

  Future<void> _edit(TagInfo? tag) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _TagDialog(tag: tag),
    );
    if (result == null || !mounted) return;
    final api = ref.read(adminApiProvider);
    await runAction(context, () async {
      if (tag == null) {
        await api.createTag(result.$1, result.$2);
      } else {
        await api.updateTag(tag.name, newName: result.$1, label: result.$2);
      }
      _refresh();
    }, success: 'ذخیره شد');
  }

  Future<void> _delete(TagInfo tag) async {
    if (!await confirm(
      context,
      title: 'حذف برچسب',
      message: 'برچسب ${tag.name} حذف شود؟',
      action: 'حذف',
      destructive: true,
    )) {
      return;
    }
    if (!mounted) return;
    await runAction(context, () async {
      await ref.read(adminApiProvider).deleteTag(tag.name);
      _refresh();
    }, success: 'حذف شد');
  }

  bool _noPlan(TagInfo t) => t.plans.isEmpty && t.findings.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider);
    final all = tags.value ?? const <TagInfo>[];
    final colors = context.appColors;

    return AdminPage(
      title: 'برچسب‌ها',
      subtitle:
          'برچسب‌ها یافته‌های بررسی را به برنامه‌های مراقبتی وصل می‌کنند: یافته و برنامه‌ای که برچسب مشترک دارند، به هم می‌رسند.',
      actions: [
        FilledButton.icon(
          onPressed: () => _edit(null),
          icon: const Icon(Icons.add_rounded),
          label: const Text('برچسب جدید'),
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
              SearchField(
                hint: 'جستجوی نام یا توضیح',
                onChanged: (v) => setState(() => _query = v),
              ),
              FilterPill(
                label: 'همه',
                count: all.length,
                selected: _filter == _TagFilter.all,
                onSelected: (_) => setState(() => _filter = _TagFilter.all),
              ),
              FilterPill(
                label: 'یافته بدون برنامه',
                count: all.where(_noPlan).length,
                color: colors.warning,
                selected: _filter == _TagFilter.noPlan,
                onSelected: (_) => setState(() => _filter = _TagFilter.noPlan),
              ),
              FilterPill(
                label: 'استفاده‌نشده',
                count: all.where((t) => t.unused).length,
                selected: _filter == _TagFilter.unused,
                onSelected: (_) => setState(() => _filter = _TagFilter.unused),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AsyncBody(
            value: tags,
            onRetry: () => ref.invalidate(tagsProvider),
            builder: (list) {
              final q = _query.toLowerCase();
              final shown = [
                for (final t in list)
                  if ((q.isEmpty ||
                          t.name.contains(q) ||
                          t.label.contains(_query)) &&
                      switch (_filter) {
                        _TagFilter.all => true,
                        _TagFilter.unused => t.unused,
                        _TagFilter.noPlan => _noPlan(t),
                      })
                    t,
              ];
              if (shown.isEmpty) {
                return const Panel(
                  child: EmptyState(
                    icon: Icons.sell_outlined,
                    title: 'برچسبی پیدا نشد',
                  ),
                );
              }
              return RowList(
                children: [
                  for (final t in shown)
                    ListRow(
                      key: ValueKey(t.name),
                      onTap: () => _edit(t),
                      leading: Icon(
                        Icons.sell_outlined,
                        size: 20,
                        color: context.onBgMuted,
                      ),
                      title: Wrap(
                        spacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(t.label.isEmpty ? t.name : t.label),
                          if (t.label.isNotEmpty)
                            Text(
                              t.name,
                              textDirection: TextDirection.ltr,
                              style: context.text.labelMedium.copyWith(
                                color: context.onBgMuted,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${t.plans.length} برنامه · ${t.findings.length} یافته',
                      ),
                      trailing: [
                        if (t.unused)
                          Pill('استفاده‌نشده', color: context.onBgMuted)
                        else if (_noPlan(t))
                          Tooltip(
                            message:
                                'یافته‌هایی با این برچسب به هیچ برنامه‌ای نمی‌رسند',
                            child: Pill(
                              'بدون برنامه',
                              color: colors.warning,
                              icon: Icons.link_off_rounded,
                            ),
                          ),
                        RowMenu(
                          actions: [
                            MenuAction(
                              'ویرایش',
                              Icons.edit_rounded,
                              () => _edit(t),
                            ),
                            MenuAction(
                              t.unused
                                  ? 'حذف'
                                  : 'حذف (فقط اگر استفاده نشده باشد)',
                              Icons.delete_outline_rounded,
                              t.unused ? () => _delete(t) : null,
                              danger: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TagDialog extends StatefulWidget {
  const _TagDialog({this.tag});
  final TagInfo? tag;

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late final _name = TextEditingController(text: widget.tag?.name ?? '');
  late final _label = TextEditingController(text: widget.tag?.label ?? '');
  static final _pattern = RegExp(r'^[a-z][a-z0-9_]*$');

  @override
  void dispose() {
    _name.dispose();
    _label.dispose();
    super.dispose();
  }

  String? get _nameError {
    final n = _name.text.trim();
    if (n.isEmpty || n == widget.tag?.name) return null;
    return _pattern.hasMatch(n)
        ? null
        : 'فقط حروف کوچک انگلیسی، عدد و _ (مثل chest_pain)';
  }

  bool get _valid => _name.text.trim().isNotEmpty && _nameError == null;

  void _submit() {
    if (_valid) Navigator.pop(context, (_name.text.trim(), _label.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final tag = widget.tag;
    final used = tag != null && !tag.unused;
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _label]),
      builder: (context, _) => FormDialog(
        title: tag == null ? 'برچسب جدید' : 'ویرایش برچسب',
        width: 440,
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
            TextField(
              controller: _label,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'توضیح فارسی',
                hintText: 'مثلاً: درد قفسه سینه',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _name,
              textDirection: TextDirection.ltr,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'نام انگلیسی',
                hintText: 'chest_pain',
                errorText: _nameError,
                helperText: used
                    ? 'تغییر نام در همه برنامه‌ها و یافته‌ها اعمال می‌شود.'
                    : null,
              ),
            ),
            if (used) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'استفاده در ${tag.plans.length} برنامه و ${tag.findings.length} یافته',
                style: context.text.bodySmall.copyWith(
                  color: context.onBgMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
