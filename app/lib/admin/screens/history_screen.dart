import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/admin/admin_theme.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final List<AuditEntry> _entries = [];
  String _entity = '';
  bool _loading = false;
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _reload(String entity) async {
    setState(() {
      _entity = entity;
      _entries.clear();
      _done = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(adminApiProvider)
          .audit(
            entity: _entity,
            before: _entries.isEmpty ? null : _entries.last.id,
          );
      if (!mounted) return;
      setState(() {
        _entries.addAll(page);
        _done = page.length < 50;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group by day so long lists are easy to scan.
    final days = <String, List<AuditEntry>>{};
    for (final e in _entries) {
      days.putIfAbsent(formatDateTime(e.at).split(' ').first, () => []).add(e);
    }

    return AdminPage(
      title: 'تاریخچه تغییرات',
      subtitle:
          'هر ویرایش، انتشار و تغییر تنظیمات با نام انجام‌دهنده ثبت می‌شود.',
      actions: [
        IconButton(
          tooltip: 'بارگیری دوباره',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => _reload(_entity),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilterPill(
                label: 'همه',
                selected: _entity.isEmpty,
                onSelected: (_) => _reload(''),
              ),
              for (final e in entityLabels.entries)
                FilterPill(
                  label: e.value,
                  selected: _entity == e.key,
                  onSelected: (_) => _reload(e.key),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final MapEntry(key: day, value: list) in days.entries) ...[
            GroupHeader(title: day, count: list.length),
            RowList(
              children: [
                for (final e in list) _HistoryEntry(e, key: ValueKey(e.id)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (_error != null)
            AsyncBody<void>(
              value: AsyncError(_error!, StackTrace.empty),
              builder: (_) => const SizedBox(),
              onRetry: _loadMore,
            ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (!_done)
            Center(
              child: OutlinedButton(
                onPressed: _loadMore,
                child: const Text('موارد قدیمی‌تر'),
              ),
            )
          else if (_entries.isEmpty)
            const Panel(
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'چیزی ثبت نشده است',
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryEntry extends StatefulWidget {
  const _HistoryEntry(this.entry, {super.key});
  final AuditEntry entry;

  @override
  State<_HistoryEntry> createState() => _HistoryEntryState();
}

class _HistoryEntryState extends State<_HistoryEntry> {
  bool _open = false;
  bool _raw = false;

  static const _noise = {
    'revision',
    'updatedAt',
    'updatedBy',
    'createdAt',
    'createdBy',
  };

  bool get _hasDetails =>
      widget.entry.before != null || widget.entry.after != null;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActivityRow(
          e,
          onTap: _hasDetails ? () => setState(() => _open = !_open) : null,
        ),
        if (_open)
          Container(
            color: context.adminHover,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      formatDateTime(e.at),
                      style: context.text.labelSmall.copyWith(
                        color: context.onBgMuted,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _raw = !_raw),
                      child: Text(_raw ? 'فقط تفاوت‌ها' : 'JSON کامل'),
                    ),
                  ],
                ),
                if (_raw) _rawView(context, e) else _diffView(context, e),
              ],
            ),
          ),
      ],
    );
  }

  static String _pretty(Object? v) {
    if (v == null) return '—';
    if (v is String) return v.isEmpty ? '—' : v;
    if (v is List && v.every((i) => i is String))
      return v.isEmpty ? '—' : v.join('\n');
    return const JsonEncoder.withIndent('  ').convert(v);
  }

  Widget _diffView(BuildContext context, AuditEntry e) {
    final before = e.before;
    final after = e.after;
    if (before is! Map || after is! Map) return _rawView(context, e);
    final keys = {
      ...before.keys,
      ...after.keys,
    }.cast<String>().where((k) => !_noise.contains(k));
    final changed = [
      for (final k in keys)
        if (jsonEncode(before[k]) != jsonEncode(after[k])) k,
    ];
    if (changed.isEmpty) {
      return Text(
        'تفاوتی در محتوا نیست (فقط ترتیب یا اطلاعات ثبت).',
        style: TextStyle(color: context.onBgMuted),
      );
    }
    final colors = context.appColors;
    Widget cell(String text, Color color) => Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm - 6),
      ),
      child: SelectableText(text, style: context.text.bodySmall),
    );
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        TableRow(
          children: [
            const SizedBox(),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text('قبل', style: context.text.labelMedium),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text('بعد', style: context.text.labelMedium),
            ),
          ],
        ),
        for (final k in changed)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  0,
                  0,
                ),
                child: Text(
                  _fieldLabel(k),
                  style: context.text.labelMedium.copyWith(
                    color: context.onBgMuted,
                  ),
                ),
              ),
              cell(_pretty(before[k]), colors.danger),
              cell(_pretty(after[k]), colors.success),
            ],
          ),
      ],
    );
  }

  static String _fieldLabel(String k) =>
      const {
        'title': 'عنوان',
        'abbr': 'نام کوتاه',
        'color': 'رنگ',
        'icon': 'آیکون',
        'tags': 'برچسب‌ها',
        'sections': 'بخش‌ها',
        'kind': 'موضوع',
        'archived': 'بایگانی',
        'text': 'متن',
        'options': 'گزینه‌ها',
        'correctIndex': 'پاسخ درست',
        'explanation': 'توضیح',
        'hint': 'راهنمایی',
        'label': 'توضیح فارسی',
        'name': 'نام',
        'role': 'نقش',
        'frozen': 'قفل',
        'reason': 'دلیل',
        'notes': 'یادداشت',
      }[k] ??
      k;

  Widget _rawView(BuildContext context, AuditEntry e) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (label, value) in [('قبل', e.before), ('بعد', e.after)])
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelLarge),
                SelectableText(
                  value == null
                      ? '—'
                      : const JsonEncoder.withIndent('  ').convert(value),
                  textDirection: TextDirection.ltr,
                  style: context.text.bodySmall.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
