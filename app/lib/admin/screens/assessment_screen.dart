import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/admin/data/admin_api.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

/// Gordon patterns and their findings. Each finding shows the care
/// plans it leads to (by shared tags); findings that lead nowhere are
/// highlighted.
class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({super.key});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  bool _onlyWithoutPlan = false;
  bool _showArchived = false;
  String _query = '';
  final Set<String> _collapsed = {};

  void _refresh() {
    ref.invalidate(domainsProvider);
    ref.invalidate(tagsProvider);
    refreshDraft(ref);
  }

  Future<void> _editDomain(DomainDetail? d) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _DomainDialog(domain: d),
    );
    if (result == null || !mounted) return;
    final api = ref.read(adminApiProvider);
    await runAction(context, () async {
      if (d == null) {
        await api.createDomain(result.$1, result.$2);
      } else {
        await api.updateDomain(d.id, d.meta.revision, result.$2);
      }
      _refresh();
    }, success: 'ذخیره شد');
  }

  Future<void> _editFinding(String domainId, FindingDetail? f) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _FindingDialog(finding: f),
    );
    if (result == null || !mounted) return;
    final api = ref.read(adminApiProvider);
    await runAction(context, () async {
      if (f == null) {
        await api.createFinding(domainId, result);
      } else {
        await api.updateFinding(f.id, {...result, 'revision': f.meta.revision});
      }
      _refresh();
    }, success: 'ذخیره شد');
  }

  Future<void> _run(Future<void> Function() action, {String? success}) =>
      runAction(context, () async {
        await action();
        _refresh();
      }, success: success);

  bool _findingMatches(FindingDetail f) =>
      (_showArchived || !f.meta.archived) &&
      (!_onlyWithoutPlan || (f.plans.isEmpty && !f.meta.archived)) &&
      (_query.isEmpty ||
          f.title.contains(_query) ||
          f.tags.any((t) => t.contains(_query.toLowerCase())));

  @override
  Widget build(BuildContext context) {
    final api = ref.read(adminApiProvider);
    final domains = ref.watch(domainsProvider);
    final colors = context.appColors;
    final all = domains.value ?? const <DomainDetail>[];
    final orphanCount = [
      for (final d in all)
        if (!d.meta.archived)
          for (final f in d.findings)
            if (!f.meta.archived && f.plans.isEmpty) f,
    ].length;
    final filtering = _query.isNotEmpty || _onlyWithoutPlan;

    return AdminPage(
      title: 'بررسی گوردون',
      subtitle:
          'الگوها و یافته‌هایی که پرستار در تشخیص‌یاب انتخاب می‌کند. هر یافته با برچسب‌های مشترک به برنامه‌های مراقبتی می‌رسد.',
      actions: [
        FilledButton.icon(
          onPressed: () => _editDomain(null),
          icon: const Icon(Icons.add_rounded),
          label: const Text('الگوی جدید'),
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
                hint: 'جستجوی یافته یا برچسب',
                onChanged: (v) => setState(() => _query = v),
              ),
              FilterPill(
                label: 'بدون برنامه',
                count: orphanCount,
                color: orphanCount > 0 ? colors.warning : null,
                selected: _onlyWithoutPlan,
                onSelected: (v) => setState(() => _onlyWithoutPlan = v),
              ),
              FilterPill(
                label: 'بایگانی‌شده‌ها',
                selected: _showArchived,
                onSelected: (v) => setState(() => _showArchived = v),
              ),
              TextButton(
                onPressed: () => setState(() {
                  if (_collapsed.isEmpty) {
                    _collapsed.addAll(all.map((d) => d.id));
                  } else {
                    _collapsed.clear();
                  }
                }),
                child: Text(_collapsed.isEmpty ? 'بستن همه' : 'باز کردن همه'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AsyncBody(
            value: domains,
            onRetry: () => ref.invalidate(domainsProvider),
            builder: (list) {
              final activeDomains = [
                for (final d in list)
                  if (!d.meta.archived) d.id,
              ];
              final visibleDomains = [
                for (final d in list)
                  if ((_showArchived || !d.meta.archived) &&
                      (!filtering || d.findings.any(_findingMatches)))
                    d,
              ];
              if (visibleDomains.isEmpty) {
                return Panel(
                  child: EmptyState(
                    icon: _onlyWithoutPlan
                        ? Icons.task_alt_rounded
                        : Icons.search_off_rounded,
                    title: _onlyWithoutPlan
                        ? 'همه یافته‌ها به دست‌کم یک برنامه می‌رسند'
                        : 'موردی پیدا نشد',
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in visibleDomains)
                    _domainPanel(
                      context,
                      d,
                      api: api,
                      activeDomains: activeDomains,
                      collapsed: !filtering && _collapsed.contains(d.id),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _domainPanel(
    BuildContext context,
    DomainDetail d, {
    required AdminApi api,
    required List<String> activeDomains,
    required bool collapsed,
  }) {
    final colors = context.appColors;
    final activeFindings = [
      for (final f in d.findings)
        if (!f.meta.archived) f.id,
    ];
    final shown = [
      for (final f in d.findings)
        if (_findingMatches(f)) f,
    ];
    final orphans = d.findings
        .where((f) => !f.meta.archived && f.plans.isEmpty)
        .length;
    final di = activeDomains.indexOf(d.id);

    return Padding(
      key: ValueKey(d.id),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Opacity(
        opacity: d.meta.archived ? 0.65 : 1,
        child: Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(
                  () => collapsed
                      ? _collapsed.remove(d.id)
                      : _collapsed.add(d.id),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        collapsed
                            ? Icons.expand_more_rounded
                            : Icons.expand_less_rounded,
                        color: context.onBgMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(d.title, style: context.text.titleSmall),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      CountBadge(activeFindings.length),
                      if (orphans > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Pill('$orphans بدون برنامه', color: colors.warning),
                      ],
                      if (d.meta.archived) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const ArchivedPill(),
                      ],
                      const SizedBox(width: AppSpacing.sm),
                      DraftPill(entity: 'domain', id: d.id),
                      const Spacer(),
                      if (!d.meta.archived)
                        TextButton.icon(
                          onPressed: () => _editFinding(d.id, null),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('یافته جدید'),
                        ),
                      RowMenu(
                        actions: [
                          MenuAction(
                            'ویرایش عنوان الگو',
                            Icons.edit_rounded,
                            () => _editDomain(d),
                          ),
                          if (!d.meta.archived) ...[
                            MenuAction(
                              'انتقال به بالا',
                              Icons.arrow_upward_rounded,
                              di <= 0
                                  ? null
                                  : () => _run(
                                      () => api.reorderDomains(
                                        moved(activeDomains, di, -1),
                                      ),
                                    ),
                            ),
                            MenuAction(
                              'انتقال به پایین',
                              Icons.arrow_downward_rounded,
                              di < 0 || di == activeDomains.length - 1
                                  ? null
                                  : () => _run(
                                      () => api.reorderDomains(
                                        moved(activeDomains, di, 1),
                                      ),
                                    ),
                            ),
                          ],
                          MenuAction(
                            d.meta.archived ? 'بازگردانی الگو' : 'بایگانی الگو',
                            d.meta.archived
                                ? Icons.unarchive_rounded
                                : Icons.archive_outlined,
                            () => _run(
                              () => api.setArchived(
                                'domains',
                                d.id,
                                !d.meta.archived,
                              ),
                            ),
                            danger: !d.meta.archived,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!collapsed) ...[
                const Divider(height: 1),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'یافته‌ای نیست',
                      style: TextStyle(color: context.onBgMuted),
                    ),
                  ),
                for (final (i, f) in shown.indexed) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                    ),
                  _findingRow(context, d, f, api: api, active: activeFindings),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _findingRow(
    BuildContext context,
    DomainDetail d,
    FindingDetail f, {
    required AdminApi api,
    required List<String> active,
  }) {
    final colors = context.appColors;
    final fi = active.indexOf(f.id);
    final canMove = !f.meta.archived && !_onlyWithoutPlan && _query.isEmpty;
    return ListRow(
      key: ValueKey(f.id),
      dimmed: f.meta.archived,
      onTap: () => _editFinding(d.id, f),
      title: Text(f.title),
      subtitle: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TagChips(f.tags),
          if (f.plans.isNotEmpty)
            Tooltip(
              message: f.plans.join('\n'),
              child: Text('← ${f.plans.length} برنامه'),
            ),
        ],
      ),
      trailing: [
        if (f.meta.archived)
          const ArchivedPill()
        else if (f.plans.isEmpty)
          Pill(
            'بدون برنامه',
            color: colors.warning,
            icon: Icons.link_off_rounded,
          ),
        DraftPill(entity: 'finding', id: f.id),
        RowMenu(
          actions: [
            MenuAction(
              'ویرایش',
              Icons.edit_rounded,
              () => _editFinding(d.id, f),
            ),
            MenuAction(
              'انتقال به بالا',
              Icons.arrow_upward_rounded,
              !canMove || fi <= 0
                  ? null
                  : () => _run(
                      () => api.reorderFindings(d.id, moved(active, fi, -1)),
                    ),
            ),
            MenuAction(
              'انتقال به پایین',
              Icons.arrow_downward_rounded,
              !canMove || fi < 0 || fi == active.length - 1
                  ? null
                  : () => _run(
                      () => api.reorderFindings(d.id, moved(active, fi, 1)),
                    ),
            ),
            MenuAction(
              f.meta.archived ? 'بازگردانی' : 'بایگانی',
              f.meta.archived
                  ? Icons.unarchive_rounded
                  : Icons.archive_outlined,
              () => _run(
                () => api.setArchived('findings', f.id, !f.meta.archived),
              ),
              danger: !f.meta.archived,
            ),
          ],
        ),
      ],
    );
  }
}

class _DomainDialog extends StatefulWidget {
  const _DomainDialog({this.domain});
  final DomainDetail? domain;

  @override
  State<_DomainDialog> createState() => _DomainDialogState();
}

class _DomainDialogState extends State<_DomainDialog> {
  late final _id = TextEditingController(text: widget.domain?.id ?? '');
  late final _title = TextEditingController(text: widget.domain?.title ?? '');

  @override
  void dispose() {
    _id.dispose();
    _title.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      (widget.domain != null || _id.text.trim().isNotEmpty);

  void _submit() {
    if (_valid) Navigator.pop(context, (_id.text.trim(), _title.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.domain == null;
    return FormDialog(
      title: isNew ? 'الگوی جدید' : 'ویرایش الگو',
      width: 440,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        ListenableBuilder(
          listenable: Listenable.merge([_id, _title]),
          builder: (_, _) => FilledButton(
            onPressed: _valid ? _submit : null,
            child: const Text('ذخیره'),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'عنوان الگو',
              hintText: 'مثلاً: خواب و استراحت',
            ),
          ),
          if (isNew) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _id,
              textDirection: TextDirection.ltr,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'شناسه انگلیسی',
                hintText: 'sleep_rest',
                helperText: 'حروف کوچک انگلیسی و _ ؛ بعداً قابل تغییر نیست.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FindingDialog extends ConsumerStatefulWidget {
  const _FindingDialog({this.finding});
  final FindingDetail? finding;

  @override
  ConsumerState<_FindingDialog> createState() => _FindingDialogState();
}

class _FindingDialogState extends ConsumerState<_FindingDialog> {
  late final _id = TextEditingController(text: widget.finding?.id ?? '');
  late final _title = TextEditingController(text: widget.finding?.title ?? '');
  late List<String> _tags = [...?widget.finding?.tags];

  @override
  void dispose() {
    _id.dispose();
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (_title.text.trim().isEmpty) return;
    Navigator.pop(context, {
      if (widget.finding == null && _id.text.trim().isNotEmpty)
        'id': _id.text.trim(),
      'title': _title.text.trim(),
      'tags': _tags,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.finding == null;
    final colors = context.appColors;
    // Live answer to "where will this finding lead?".
    final plans =
        ref.watch(carePlansListProvider).value ?? const <PlanSummary>[];
    final reached = [
      for (final p in plans)
        if (!p.meta.archived && p.tags.any(_tags.contains)) p,
    ];

    return FormDialog(
      title: isNew ? 'یافته جدید' : 'ویرایش یافته',
      width: 540,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        ListenableBuilder(
          listenable: _title,
          builder: (_, _) => FilledButton(
            onPressed: _title.text.trim().isEmpty ? null : _submit,
            child: const Text('ذخیره'),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'عنوان یافته',
              hintText: 'مثلاً: درد قفسه سینه',
            ),
          ),
          if (isNew) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _id,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'شناسه انگلیسی (اختیاری)',
                hintText: 'hp_smoking',
                helperText: 'خالی بگذارید تا خودکار ساخته شود.',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('برچسب‌ها', style: context.text.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          TagPicker(tags: _tags, onChanged: (t) => setState(() => _tags = t)),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: (reached.isEmpty ? colors.warning : colors.success)
                  .withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(AppRadius.sm - 4),
            ),
            child: reached.isEmpty
                ? Text(
                    'با این برچسب‌ها، انتخاب این یافته هیچ برنامه‌ای را پیشنهاد نمی‌کند.',
                    style: context.text.bodySmall.copyWith(
                      color: context.legible(colors.warning),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'انتخاب این یافته ${reached.length} برنامه را پیشنهاد می‌کند:',
                        style: context.text.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final p in reached.take(6))
                        Text(
                          '• ${p.title}  (${kindShort(ref, p.kind)})',
                          style: context.text.bodySmall,
                        ),
                      if (reached.length > 6)
                        Text(
                          'و ${reached.length - 6} برنامه دیگر',
                          style: context.text.bodySmall.copyWith(
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
