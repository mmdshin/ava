import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/admin/admin_app.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

class QuizzesScreen extends ConsumerStatefulWidget {
  const QuizzesScreen({super.key});

  @override
  ConsumerState<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends ConsumerState<QuizzesScreen> {
  String _query = '';
  bool _showArchived = false;
  bool _reorder = false;

  Future<void> _create() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const QuizDialog(),
    );
    if (result == null || !mounted) return;
    await runAction(context, () async {
      final quiz = await ref
          .read(adminApiProvider)
          .createQuiz(result.$1, result.$2);
      ref.invalidate(quizzesListProvider);
      refreshDraft(ref);
      if (mounted) context.go(AdminRoutes.quiz(quiz.id));
    });
  }

  Future<void> _saveOrder(List<String> ids) => runAction(context, () async {
    await ref.read(adminApiProvider).reorderQuizzes(ids);
    ref.invalidate(quizzesListProvider);
    refreshDraft(ref);
  }, success: 'ترتیب ذخیره شد');

  @override
  Widget build(BuildContext context) {
    final quizzes = ref.watch(quizzesListProvider);
    return AdminPage(
      title: 'آزمون‌ها',
      subtitle:
          'آزمون‌های خودسنجی پرستاران؛ ترتیب این فهرست همان ترتیب نمایش در برنامه است.',
      actions: [
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
            onPressed: _create,
            icon: const Icon(Icons.add_rounded),
            label: const Text('آزمون جدید'),
          ),
      ],
      child: AsyncBody(
        value: quizzes,
        onRetry: () => ref.invalidate(quizzesListProvider),
        builder: (list) {
          final active = [
            for (final q in list)
              if (!q.meta.archived) q,
          ];
          if (_reorder) {
            return ReorderPanel(
              ids: [for (final q in active) q.id],
              onReorder: _saveOrder,
              itemBuilder: (context, i) =>
                  _QuizRow(quiz: active[i], compact: true),
            );
          }
          final shown = [
            for (final q in list)
              if ((_showArchived || !q.meta.archived) &&
                  (_query.isEmpty ||
                      q.title.contains(_query) ||
                      q.id.contains(_query.toLowerCase())))
                q,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SearchField(
                    hint: 'جستجوی آزمون',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  FilterPill(
                    label: 'بایگانی‌شده‌ها',
                    count: list.length - active.length,
                    selected: _showArchived,
                    onSelected: (v) => setState(() => _showArchived = v),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (shown.isEmpty)
                Panel(
                  child: EmptyState(
                    icon: Icons.quiz_outlined,
                    title: list.isEmpty
                        ? 'هنوز آزمونی ساخته نشده است'
                        : 'آزمونی پیدا نشد',
                    action: list.isEmpty
                        ? FilledButton.tonalIcon(
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('آزمون جدید'),
                          )
                        : null,
                  ),
                )
              else
                RowList(children: [for (final q in shown) _QuizRow(quiz: q)]),
            ],
          );
        },
      ),
    );
  }
}

class _QuizRow extends ConsumerWidget {
  const _QuizRow({required this.quiz, this.compact = false});
  final QuizSummary quiz;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = quiz;
    return ListRow(
      color: kindToneOf(context, ref, q.kind),
      dimmed: q.meta.archived,
      title: Text(q.title),
      subtitle: Text(
        '${kindShort(ref, q.kind)} · ${q.questions} سؤال · ${q.id}',
      ),
      trailing: [
        if (q.meta.archived) const ArchivedPill(),
        DraftPill(entity: 'quiz', id: q.id),
        if (!compact && q.meta.updatedAt != null)
          Text(
            relativeTime(q.meta.updatedAt),
            style: context.text.labelSmall.copyWith(color: context.onBgMuted),
          ),
        if (!compact) const ForwardChevron(),
      ],
      onTap: compact ? null : () => context.go(AdminRoutes.quiz(q.id)),
    );
  }
}

class QuizDialog extends ConsumerStatefulWidget {
  const QuizDialog({super.key, this.title = '', this.kind = ''});
  final String title;
  final String kind;

  @override
  ConsumerState<QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends ConsumerState<QuizDialog> {
  late final _title = TextEditingController(text: widget.title);
  late String _kind = widget.kind;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (_title.text.trim().isEmpty) return;
    Navigator.pop(context, (_title.text.trim(), _kind));
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: widget.title.isEmpty ? 'آزمون جدید' : 'ویرایش آزمون',
      width: 460,
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
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'عنوان آزمون'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('موضوع', style: context.text.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilterPill(
                label: 'ترکیبی',
                selected: _kind.isEmpty,
                onSelected: (_) => setState(() => _kind = ''),
              ),
              for (final k
                  in ref.watch(activeCategoriesProvider).map((c) => c.id))
                FilterPill(
                  label: kindShort(ref, k),
                  color: kindToneOf(context, ref, k),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
