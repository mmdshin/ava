import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/admin/admin_app.dart';
import 'package:ava_web/admin/admin_theme.dart';
import 'package:ava_web/admin/data/admin_api.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

/// One editable item of a section, with a stable key (so text fields
/// keep their state when items move) and a focus node (so Enter can
/// jump to a new item).
class _Line {
  _Line(this.text) : key = UniqueKey();
  String text;
  final Key key;
  final focus = FocusNode();
}

class _Section {
  _Section({required this.type, this.title = '', List<String>? items})
    : key = UniqueKey(),
      lines = [
        for (final i in items ?? ['']) _Line(i),
      ];

  String type;
  String title;
  final List<_Line> lines;
  final Key key;
  bool collapsed = false;

  TextEditingController? bulk;

  List<String> get items =>
      bulk == null ? [for (final l in lines) l.text] : bulk!.text.split('\n');

  int get filled => items.where((i) => i.trim().isNotEmpty).length;

  String get heading =>
      title.trim().isNotEmpty ? title.trim() : sectionLabels[type] ?? type;

  Map<String, dynamic> toJson() =>
      SectionDraft(type: type, title: title, items: items).toJson();

  void dispose() {
    for (final l in lines) {
      l.focus.dispose();
    }
    bulk?.dispose();
  }

  void disposeLater() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => dispose());
}

/// Focus nodes / controllers may only be disposed once the fields
/// using them are gone, i.e. after the next frame.
void _disposeLater(ChangeNotifier n) =>
    WidgetsBinding.instance.addPostFrameCallback((_) => n.dispose());

/// Create (id == null) or edit a care plan, with a live preview on
/// wide screens.
class CarePlanEditor extends ConsumerStatefulWidget {
  const CarePlanEditor({super.key, required this.id, this.initialKind});

  final String? id;
  final String? initialKind;

  @override
  ConsumerState<CarePlanEditor> createState() => _CarePlanEditorState();
}

class _CarePlanEditorState extends ConsumerState<CarePlanEditor> {
  PlanDetail? _loaded;
  Object? _loadError;
  bool _saving = false;
  bool _dirty = false;

  /// The chosen category; until one is chosen: ?kind= from the link, or
  /// the first disease in the list.
  String? _kindChoice;
  String get _kind {
    if (_kindChoice case final k?) return k;
    final active = ref.read(activeCategoriesProvider);
    if (active.any((c) => c.id == widget.initialKind))
      return widget.initialKind!;
    return (active.where((c) => !c.isGeneral).firstOrNull ?? active.firstOrNull)
            ?.id ??
        '';
  }

  set _kind(String kind) => _kindChoice = kind;
  String _title = '';
  List<String> _tags = [];
  List<_Section> _sections = [];
  Key _formKey = UniqueKey();

  bool get _isNew => widget.id == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _sections = [_Section(type: 'interventions'), _Section(type: 'outcomes')];
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    UnsavedChanges.active = false;
    for (final s in _sections) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final p = await ref.read(adminApiProvider).carePlan(widget.id!);
      if (!mounted) return;
      setState(() {
        for (final s in _sections) {
          s.disposeLater();
        }
        _loaded = p;
        _kind = p.kind;
        _title = p.title;
        _tags = [...p.tags];
        _sections = [
          for (final s in p.sections)
            _Section(
              type: s['type'] as String,
              title: s['title'] as String? ?? '',
              items: [...(s['items'] as List).cast<String>()],
            ),
        ];
        _setDirty(false);
        _formKey = UniqueKey();
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  void _setDirty(bool dirty) {
    _dirty = dirty;
    UnsavedChanges.active = dirty;
  }

  void _changed(VoidCallback fn) => setState(() {
    fn();
    _setDirty(true);
  });

  Map<String, dynamic> get _body => {
    'title': _title.trim(),
    'tags': _tags,
    'sections': [for (final s in _sections) s.toJson()],
  };

  /// Problems we can see before asking the server. Only a missing
  /// title blocks saving; the rest are hints.
  List<(bool, String)> get _issues => [
    if (_title.trim().isEmpty) (true, 'عنوان تشخیص پرستاری را بنویسید.'),
    if (_tags.isEmpty)
      (false, 'بدون برچسب، تشخیص‌یاب این برنامه را به کسی پیشنهاد نمی‌کند.'),
    if (_sections.isEmpty) (false, 'برنامه هیچ بخشی ندارد.'),
    for (final s in _sections)
      if (s.filled == 0) (false, 'بخش «${s.heading}» هیچ موردی ندارد.'),
    for (final t in sectionTypes)
      if (_sections.where((s) => s.type == t).length > 1)
        (false, 'بخش «${sectionLabels[t]}» بیش از یک بار آمده است.'),
  ];

  bool get _canSave =>
      !_saving && _title.trim().isNotEmpty && (_isNew || _dirty);

  Future<void> _save() async {
    if (!_canSave) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final api = ref.read(adminApiProvider);
    try {
      if (_isNew) {
        final created = await api.createCarePlan({..._body, 'kind': _kind});
        _afterSave();
        _setDirty(false);
        if (mounted) {
          toast(context, 'برنامه ساخته شد (در پیش‌نویس)');
          context.go(AdminRoutes.carePlan(created.id));
        }
        return;
      }
      final updated = await api.updateCarePlan(widget.id!, {
        ..._body,
        'revision': _loaded!.meta.revision,
      });
      _afterSave();
      if (!mounted) return;
      setState(() {
        _loaded = updated;
        _setDirty(false);
      });
      toast(context, 'ذخیره شد (در پیش‌نویس)');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showAdminError(context, e);
      if (!mounted) return;
      if (e is AdminException && e.code == 'conflict' && mounted) {
        final reload = await confirm(
          context,
          title: 'نسخه جدیدتر',
          message:
              'تغییرات شما ذخیره نشد. نسخه جدید را بارگیری کنیم؟ (تغییرات شما از بین می‌رود)',
          action: 'بارگیری',
        );
        if (reload) await _load();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _afterSave() {
    ref.invalidate(carePlansListProvider);
    ref.invalidate(tagsProvider);
    ref.invalidate(domainsProvider);
    refreshDraft(ref);
  }

  Future<void> _setArchived(bool archived) async {
    final ok =
        !archived ||
        await confirm(
          context,
          title: 'بایگانی برنامه',
          message:
              'این برنامه از نسخه بعدی حذف می‌شود (بعداً قابل بازگردانی است). ادامه می‌دهید؟',
          action: 'بایگانی',
          destructive: true,
        );
    if (!ok || !mounted) return;
    final done = await runAction(context, () async {
      await ref
          .read(adminApiProvider)
          .setArchived('care-plans', widget.id!, archived);
      _afterSave();
    }, success: archived ? 'بایگانی شد' : 'بازگردانده شد');
    if (done) await _load();
  }

  void _removeSection(int index) {
    final removed = _sections[index];
    _changed(() => _sections.removeAt(index));
    toast(
      context,
      'بخش «${removed.heading}» حذف شد',
      action: 'بازگردانی',
      onAction: () {
        if (mounted)
          _changed(
            () => _sections.insert(index.clamp(0, _sections.length), removed),
          );
      },
    );
  }

  void _addLine(_Section s, int at) {
    final line = _Line('');
    _changed(() => s.lines.insert(at, line));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => line.focus.requestFocus(),
    );
  }

  void _toggleBulk(_Section s) => setState(() {
    if (s.bulk == null) {
      s.bulk = TextEditingController(
        text: [
          for (final l in s.lines) l.text.trim(),
        ].where((t) => t.isNotEmpty).join('\n'),
      );
    } else {
      final items = s.bulk!.text
          .split('\n')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      for (final l in s.lines) {
        _disposeLater(l.focus);
      }
      s.lines
        ..clear()
        ..addAll([
          for (final i in items.isEmpty ? [''] : items) _Line(i),
        ]);
      _disposeLater(s.bulk!);
      s.bulk = null;
    }
  });

  @override
  Widget build(BuildContext context) {
    if (!_isNew && _loaded == null) {
      return AdminPage(
        title: 'برنامه مراقبتی',
        back: const ('برنامه‌های مراقبتی', AdminRoutes.carePlans),
        child: _loadError == null
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            : AsyncBody<void>(
                value: AsyncError(_loadError!, StackTrace.empty),
                builder: (_) => const SizedBox(),
                onRetry: _load,
              ),
      );
    }
    final loaded = _loaded;
    final colors = context.appColors;

    return SaveShortcut(
      onSave: _save,
      child: AdminPage(
        scroll: false,
        maxWidth: 1400,
        back: const ('برنامه‌های مراقبتی', AdminRoutes.carePlans),
        title: _isNew ? 'برنامه مراقبتی جدید' : loaded!.title,
        status: _dirty
            ? Pill('ذخیره نشده', color: colors.caution, icon: Icons.circle)
            : loaded == null
            ? null
            : loaded.meta.archived
            ? const ArchivedPill()
            : DraftPill(entity: 'care_plan', id: loaded.id),
        subtitle: _isNew
            ? 'شناسه پس از ذخیره ساخته می‌شود.'
            : [
                loaded!.id,
                kindTitle(ref, loaded.kind),
                'ویرایش ${loaded.meta.revision}',
                if (loaded.meta.updatedBy.isNotEmpty) loaded.meta.updatedBy,
                if (loaded.meta.updatedAt != null)
                  relativeTime(loaded.meta.updatedAt),
              ].join(' · '),
        actions: [
          if (loaded != null)
            RowMenu(
              actions: [
                MenuAction(
                  'تاریخچه این برنامه',
                  Icons.history_rounded,
                  () => _showHistory(context, loaded.id),
                ),
                MenuAction(
                  loaded.meta.archived ? 'بازگردانی' : 'بایگانی',
                  loaded.meta.archived
                      ? Icons.unarchive_rounded
                      : Icons.archive_outlined,
                  () => _setArchived(!loaded.meta.archived),
                  danger: !loaded.meta.archived,
                ),
              ],
            ),
          Builder(
            builder: (context) => MediaQuery.sizeOf(context).width < 1240
                ? OutlinedButton.icon(
                    onPressed: () => _showPreview(context),
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('پیش‌نمایش'),
                  )
                : const SizedBox.shrink(),
          ),
          Tooltip(
            message: 'Ctrl+S',
            child: FilledButton.icon(
              onPressed: _canSave ? _save : null,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('ذخیره'),
            ),
          ),
        ],
        child: LayoutBuilder(
          builder: (context, c) {
            final form = KeyedSubtree(key: _formKey, child: _form(context));
            if (c.maxWidth < 980) return form;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: form),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 360,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                    children: [
                      Text(
                        'پیش‌نمایش در برنامه',
                        style: context.text.labelLarge.copyWith(
                          color: context.onBgMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Panel(child: _preview(context)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final issues = _issues;
    final colors = context.appColors;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        if (issues.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Panel(
              accent: issues.any((i) => i.$1) ? colors.danger : colors.caution,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (blocking, text) in issues)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            blocking
                                ? Icons.error_outline_rounded
                                : Icons.info_outline_rounded,
                            size: 18,
                            color: context.legible(
                              blocking ? colors.danger : colors.caution,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(text, style: context.text.bodySmall),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        FormSection(
          title: 'مشخصات',
          icon: Icons.badge_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isNew) ...[
                Text('بیماری', style: context.text.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final k
                        in ref.watch(activeCategoriesProvider).map((c) => c.id))
                      FilterPill(
                        label: kindShort(ref, k),
                        color: kindToneOf(context, ref, k),
                        selected: _kind == k,
                        onSelected: (_) => _changed(() => _kind = k),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              TextFormField(
                initialValue: _title,
                autofocus: _isNew,
                decoration: const InputDecoration(
                  labelText: 'عنوان تشخیص پرستاری',
                  hintText: 'مثلاً: درد حاد',
                ),
                onChanged: (v) => _changed(() => _title = v),
              ),
            ],
          ),
        ),
        FormSection(
          title: 'برچسب‌ها',
          subtitle:
              'تشخیص‌یاب این برنامه را برای یافته‌هایی پیشنهاد می‌کند که برچسب مشترک دارند.',
          icon: Icons.sell_outlined,
          child: TagPicker(
            tags: _tags,
            onChanged: (t) => _changed(() => _tags = t),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Text('بخش‌ها', style: context.text.titleMedium),
              const SizedBox(width: AppSpacing.sm),
              CountBadge(_sections.length),
              const Spacer(),
              if (_sections.length > 1)
                TextButton(
                  onPressed: () => setState(() {
                    final collapse = _sections.any((s) => !s.collapsed);
                    for (final s in _sections) {
                      s.collapsed = collapse;
                    }
                  }),
                  child: Text(
                    _sections.any((s) => !s.collapsed)
                        ? 'بستن همه'
                        : 'باز کردن همه',
                  ),
                ),
            ],
          ),
        ),
        for (final (i, s) in _sections.indexed) _sectionEditor(context, i, s),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _addSectionButton(),
        ),
      ],
    );
  }

  Widget _addSectionButton() {
    final used = {for (final s in _sections) s.type};
    return PopupMenuButton<String>(
      tooltip: 'افزودن بخش',
      onSelected: (type) => _changed(() => _sections.add(_Section(type: type))),
      itemBuilder: (_) => [
        for (final t in sectionTypes)
          PopupMenuItem(
            value: t,
            child: Row(
              children: [
                Icon(sectionIcons[t], size: 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(sectionLabels[t]!)),
                if (used.contains(t)) const Icon(Icons.check_rounded, size: 18),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: context.adminLine),
          borderRadius: BorderRadius.circular(AppRadius.sm - 2),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded),
            SizedBox(width: AppSpacing.sm),
            Text('افزودن بخش'),
          ],
        ),
      ),
    );
  }

  Widget _sectionEditor(BuildContext context, int index, _Section s) {
    final accent = context.appColors.accent;
    return Padding(
      key: s.key,
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: s.collapsed ? 'باز کردن' : 'بستن',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      s.collapsed
                          ? Icons.expand_more_rounded
                          : Icons.expand_less_rounded,
                    ),
                    onPressed: () => setState(() => s.collapsed = !s.collapsed),
                  ),
                  Icon(sectionIcons[s.type], size: 20, color: accent),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: PopupMenuButton<String>(
                      tooltip: 'نوع بخش',
                      onSelected: (v) => _changed(() => s.type = v),
                      itemBuilder: (_) => [
                        for (final t in sectionTypes)
                          PopupMenuItem(
                            value: t,
                            child: Text(sectionLabels[t]!),
                          ),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              s.heading,
                              style: context.text.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            color: context.onBgMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  CountBadge(s.filled),
                  const Spacer(),
                  IconButton(
                    tooltip: s.bulk == null
                        ? 'ویرایش متنی (هر خط یک مورد)'
                        : 'ویرایش فهرستی',
                    visualDensity: VisualDensity.compact,
                    isSelected: s.bulk != null,
                    icon: const Icon(Icons.notes_rounded, size: 20),
                    onPressed: () => _toggleBulk(s),
                  ),
                  MoveButtons(
                    onUp: index == 0
                        ? null
                        : () => _changed(
                            () => _sections.insert(
                              index - 1,
                              _sections.removeAt(index),
                            ),
                          ),
                    onDown: index == _sections.length - 1
                        ? null
                        : () => _changed(
                            () => _sections.insert(
                              index + 1,
                              _sections.removeAt(index),
                            ),
                          ),
                  ),
                  IconButton(
                    tooltip: 'حذف بخش',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: context.appColors.danger,
                    ),
                    onPressed: () => _removeSection(index),
                  ),
                ],
              ),
            ),
            if (!s.collapsed) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      initialValue: s.title,
                      decoration: InputDecoration(
                        labelText: 'عنوان دلخواه (اختیاری)',
                        hintText: sectionLabels[s.type],
                      ),
                      onChanged: (v) => _changed(() => s.title = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (s.bulk != null)
                      TextField(
                        controller: s.bulk,
                        minLines: 5,
                        maxLines: 18,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          helperText:
                              'هر خط یک مورد. برای برگشت به فهرست، دوباره روی دکمه متن بزنید.',
                        ),
                        onChanged: (_) => _changed(() {}),
                      )
                    else ...[
                      for (final (j, line) in s.lines.indexed)
                        Padding(
                          key: line.key,
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 28,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Text(
                                    '${j + 1}.',
                                    style: context.text.labelLarge.copyWith(
                                      color: context.onBgMuted,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextFormField(
                                  initialValue: line.text,
                                  focusNode: line.focus,
                                  minLines: 1,
                                  maxLines: null,
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => _addLine(s, j + 1),
                                  onChanged: (v) =>
                                      _changed(() => line.text = v),
                                ),
                              ),
                              MoveButtons(
                                onUp: j == 0
                                    ? null
                                    : () => _changed(
                                        () => s.lines.insert(
                                          j - 1,
                                          s.lines.removeAt(j),
                                        ),
                                      ),
                                onDown: j == s.lines.length - 1
                                    ? null
                                    : () => _changed(
                                        () => s.lines.insert(
                                          j + 1,
                                          s.lines.removeAt(j),
                                        ),
                                      ),
                              ),
                              IconButton(
                                tooltip: 'حذف مورد',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () => _changed(
                                  () =>
                                      _disposeLater(s.lines.removeAt(j).focus),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () => _addLine(s, s.lines.length),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('افزودن مورد'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KindPill(_kind),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _title.trim().isEmpty ? '(بدون عنوان)' : _title.trim(),
          style: context.text.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final s in _sections)
          if (s.filled > 0) ...[
            Row(
              children: [
                Icon(
                  sectionIcons[s.type],
                  size: 18,
                  color: context.legible(colors.warning),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    s.heading,
                    style: context.text.titleSmall.copyWith(
                      color: context.legible(colors.warning),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final item in s.items)
              if (item.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppSpacing.xs,
                    right: AppSpacing.sm,
                  ),
                  child: Text(
                    '• ${item.trim()}',
                    style: context.text.bodySmall.copyWith(height: 1.7),
                  ),
                ),
            const SizedBox(height: AppSpacing.md),
          ],
        if (_sections.every((s) => s.filled == 0))
          Text(
            'هنوز موردی نوشته نشده است.',
            style: TextStyle(color: context.onBgMuted),
          ),
      ],
    );
  }

  void _showPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پیش‌نمایش'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(child: _preview(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, String id) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تاریخچه این برنامه'),
        content: SizedBox(
          width: 520,
          child: Consumer(
            builder: (context, ref, _) => AsyncBody(
              value: ref.watch(itemHistoryProvider(('care_plan', id))),
              builder: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'تغییری ثبت نشده است',
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, e) in list.indexed) ...[
                            if (i > 0) const Divider(height: 1),
                            ActivityRow(e),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }
}
