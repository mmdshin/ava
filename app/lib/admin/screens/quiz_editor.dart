import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/admin/admin_app.dart';
import 'package:ava_web/admin/admin_theme.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/screens/quizzes_screen.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/features/quiz/widgets/option_tile.dart';

class QuizEditor extends ConsumerStatefulWidget {
  const QuizEditor({super.key, required this.id});
  final String id;

  @override
  ConsumerState<QuizEditor> createState() => _QuizEditorState();
}

class _QuizEditorState extends ConsumerState<QuizEditor> {
  String _query = '';
  bool _compact = false;
  bool _reorder = false;
  bool _showArchived = false;

  String get id => widget.id;

  void _refresh() {
    ref.invalidate(quizProvider(id));
    ref.invalidate(quizzesListProvider);
    refreshDraft(ref);
  }

  Future<void> _editQuiz(QuizDetail quiz) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => QuizDialog(title: quiz.title, kind: quiz.kind),
    );
    if (result == null || !mounted) return;
    await runAction(context, () async {
      await ref
          .read(adminApiProvider)
          .updateQuiz(id, quiz.meta.revision, result.$1, result.$2);
      _refresh();
    }, success: 'ذخیره شد');
  }

  Future<void> _editQuestion(
    QuestionDetail? q, {
    Map<String, dynamic>? copyOf,
  }) async {
    final api = ref.read(adminApiProvider);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuestionDialog(
        question: q,
        initial: copyOf,
        onSave: (body) => runAction(context, () async {
          if (q == null) {
            await api.createQuestion(id, body);
          } else {
            await api.updateQuestion(q.id, {
              ...body,
              'revision': q.meta.revision,
            });
          }
          _refresh();
        }, success: 'سؤال ذخیره شد'),
      ),
    );
  }

  Future<void> _archive(String collection, String itemId, bool archived) async {
    if (archived &&
        !await confirm(
          context,
          title: collection == 'quizzes' ? 'بایگانی آزمون' : 'بایگانی سؤال',
          message:
              'از نسخه بعدی حذف می‌شود (بعداً قابل بازگردانی است). ادامه می‌دهید؟',
          action: 'بایگانی',
          destructive: true,
        )) {
      return;
    }
    if (!mounted) return;
    await runAction(context, () async {
      await ref
          .read(adminApiProvider)
          .setArchived(collection, itemId, archived);
      _refresh();
    }, success: archived ? 'بایگانی شد' : 'بازگردانده شد');
  }

  Future<void> _saveOrder(List<String> ids) => runAction(context, () async {
    await ref.read(adminApiProvider).reorderQuestions(id, ids);
    _refresh();
  }, success: 'ترتیب ذخیره شد');

  void _showHistory() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تاریخچه این آزمون'),
        content: SizedBox(
          width: 520,
          child: Consumer(
            builder: (context, ref, _) => AsyncBody(
              value: ref.watch(itemHistoryProvider(('quiz', id))),
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

  @override
  Widget build(BuildContext context) {
    final quiz = ref.watch(quizProvider(id));
    return AsyncBody(
      value: quiz,
      onRetry: () => ref.invalidate(quizProvider(id)),
      builder: (z) {
        final active = [
          for (final q in z.questions)
            if (!q.meta.archived) q,
        ];
        final archivedCount = z.questions.length - active.length;
        final shown = [
          for (final q in z.questions)
            if ((_showArchived || !q.meta.archived) &&
                (_query.isEmpty ||
                    q.text.contains(_query) ||
                    q.options.any((o) => o.contains(_query))))
              q,
        ];

        return AdminPage(
          back: const ('آزمون‌ها', AdminRoutes.quizzes),
          title: z.title,
          status: z.meta.archived
              ? const ArchivedPill()
              : DraftPill(entity: 'quiz', id: z.id),
          subtitle:
              '${kindTitle(ref, z.kind)} · ${active.length} سؤال · ${z.id}',
          actions: [
            RowMenu(
              actions: [
                MenuAction(
                  'ویرایش عنوان و موضوع',
                  Icons.edit_rounded,
                  () => _editQuiz(z),
                ),
                MenuAction(
                  'تاریخچه این آزمون',
                  Icons.history_rounded,
                  _showHistory,
                ),
                MenuAction(
                  z.meta.archived ? 'بازگردانی آزمون' : 'بایگانی آزمون',
                  z.meta.archived
                      ? Icons.unarchive_rounded
                      : Icons.archive_outlined,
                  () => _archive('quizzes', z.id, !z.meta.archived),
                  danger: !z.meta.archived,
                ),
              ],
            ),
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
                onPressed: () => _editQuestion(null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('سؤال جدید'),
              ),
          ],
          child: _reorder
              ? ReorderPanel(
                  ids: [for (final q in active) q.id],
                  onReorder: _saveOrder,
                  itemBuilder: (context, i) => ListRow(
                    title: Text(
                      active[i].text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SearchField(
                          hint: 'جستجو در متن سؤال‌ها',
                          onChanged: (v) => setState(() => _query = v),
                        ),
                        FilterPill(
                          label: 'فقط متن سؤال',
                          selected: _compact,
                          onSelected: (v) => setState(() => _compact = v),
                        ),
                        if (archivedCount > 0)
                          FilterPill(
                            label: 'بایگانی‌شده‌ها',
                            count: archivedCount,
                            selected: _showArchived,
                            onSelected: (v) =>
                                setState(() => _showArchived = v),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (shown.isEmpty)
                      Panel(
                        child: EmptyState(
                          icon: Icons.help_outline_rounded,
                          title: z.questions.isEmpty
                              ? 'این آزمون هنوز سؤالی ندارد'
                              : 'سؤالی پیدا نشد',
                          action: z.questions.isEmpty
                              ? FilledButton.tonalIcon(
                                  onPressed: () => _editQuestion(null),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('اولین سؤال'),
                                )
                              : null,
                        ),
                      ),
                    for (final q in shown)
                      Padding(
                        key: ValueKey(q.id),
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _QuestionCard(
                          number: active.indexOf(q) + 1,
                          question: q,
                          compact: _compact,
                          onEdit: () => _editQuestion(q),
                          onDuplicate: () => _editQuestion(
                            null,
                            copyOf: {
                              'text': q.text,
                              'options': q.options,
                              'correctIndex': q.correctIndex,
                              'explanation': q.explanation,
                              'hint': q.hint,
                            },
                          ),
                          onArchive: () =>
                              _archive('questions', q.id, !q.meta.archived),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.compact,
    required this.onEdit,
    required this.onDuplicate,
    required this.onArchive,
  });

  final int number;
  final QuestionDetail question;
  final bool compact;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final accent = context.appColors.accent;
    return Opacity(
      opacity: q.meta.archived ? 0.6 : 1,
      child: Panel(
        onTap: onEdit,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    q.meta.archived ? '–' : '$number',
                    style: context.text.labelLarge.copyWith(color: accent),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(q.text, style: context.text.titleSmall),
                  ),
                ),
                if (q.meta.archived) const ArchivedPill(),
                DraftPill(entity: 'question', id: q.id),
                IconButton(
                  tooltip: 'ویرایش سؤال',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  onPressed: onEdit,
                ),
                RowMenu(
                  actions: [
                    MenuAction(
                      'ساخت سؤال مشابه',
                      Icons.copy_rounded,
                      onDuplicate,
                    ),
                    MenuAction(
                      q.meta.archived ? 'بازگردانی' : 'بایگانی',
                      q.meta.archived
                          ? Icons.unarchive_rounded
                          : Icons.archive_outlined,
                      onArchive,
                      danger: !q.meta.archived,
                    ),
                  ],
                ),
              ],
            ),
            if (compact)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs, right: 40),
                child: Text(
                  'پاسخ درست: ${optionLetter(q.correctIndex)}) ${q.correctIndex < q.options.length ? q.options[q.correctIndex] : ''}',
                  style: context.text.bodySmall.copyWith(
                    color: context.legible(context.appColors.success),
                  ),
                ),
              )
            else ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(right: 40, left: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, o) in q.options.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: OptionTile(
                          index: i,
                          text: o,
                          state: i == q.correctIndex
                              ? OptionState.correct
                              : OptionState.idle,
                          compact: true,
                        ),
                      ),
                    if (q.explanation.isNotEmpty || q.hint.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: AppSpacing.xs),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: context.adminHover,
                          borderRadius: BorderRadius.circular(AppRadius.sm - 4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (q.explanation.isNotEmpty)
                              Text(
                                'توضیح: ${q.explanation}',
                                style: context.text.bodySmall,
                              ),
                            if (q.hint.isNotEmpty)
                              Text(
                                'راهنمایی: ${q.hint}',
                                style: context.text.bodySmall.copyWith(
                                  color: context.onBgMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class QuestionDialog extends StatefulWidget {
  const QuestionDialog({
    super.key,
    this.question,
    this.initial,
    required this.onSave,
  });

  final QuestionDetail? question;

  final Map<String, dynamic>? initial;
  final Future<bool> Function(Map<String, dynamic> body) onSave;

  @override
  State<QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<QuestionDialog> {
  final _text = TextEditingController();
  final _explanation = TextEditingController();
  final _hint = TextEditingController();
  final _textFocus = FocusNode();
  List<TextEditingController> _options = [];
  int _correct = 0;
  bool _busy = false;
  bool _tried = false;
  int _added = 0;

  bool get _isNew => widget.question == null;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    final init = widget.initial;
    _fill(
      text: q?.text ?? init?['text'] as String? ?? '',
      options:
          q?.options ??
          (init?['options'] as List?)?.cast<String>() ??
          const ['', '', '', ''],
      correct: q?.correctIndex ?? init?['correctIndex'] as int? ?? 0,
      explanation: q?.explanation ?? init?['explanation'] as String? ?? '',
      hint: q?.hint ?? init?['hint'] as String? ?? '',
    );
  }

  void _fill({
    required String text,
    required List<String> options,
    required int correct,
    required String explanation,
    required String hint,
  }) {
    final old = _options;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in old) {
        c.dispose();
      }
    });
    _text.text = text;
    _explanation.text = explanation;
    _hint.text = hint;
    _options = [for (final o in options) TextEditingController(text: o)];
    _correct = correct.clamp(0, _options.length - 1);
  }

  @override
  void dispose() {
    for (final c in [_text, _explanation, _hint, ..._options]) {
      c.dispose();
    }
    _textFocus.dispose();
    super.dispose();
  }

  String? get _problem {
    if (_text.text.trim().isEmpty) return 'متن سؤال را بنویسید.';
    final filled = _options.where((c) => c.text.trim().isNotEmpty).length;
    if (filled < 2) return 'دست‌کم دو گزینه لازم است.';
    if (_options.any((c) => c.text.trim().isEmpty))
      return 'گزینه خالی را پر یا حذف کنید.';
    if (_options[_correct].text.trim().isEmpty) return 'گزینه درست خالی است.';
    return null;
  }

  Future<void> _submit({bool next = false}) async {
    setState(() => _tried = true);
    if (_problem != null || _busy) return;
    setState(() => _busy = true);
    final ok = await widget.onSave({
      'text': _text.text.trim(),
      'options': [for (final c in _options) c.text.trim()],
      'correctIndex': _correct,
      'explanation': _explanation.text.trim(),
      'hint': _hint.text.trim(),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    if (!next) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _added++;
      _tried = false;
      _fill(
        text: '',
        options: const ['', '', '', ''],
        correct: 0,
        explanation: '',
        hint: '',
      );
    });
    _textFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final problem = _tried ? _problem : null;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _submit,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(context),
      },
      child: FormDialog(
        title: _isNew
            ? (_added == 0 ? 'سؤال جدید' : 'سؤال جدید (${_added + 1})')
            : 'ویرایش سؤال',
        width: 600,
        actions: [
          if (problem != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
              child: Text(
                problem,
                style: TextStyle(color: context.legible(colors.danger)),
              ),
            ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(_added > 0 ? 'بستن' : 'انصراف'),
          ),
          if (_isNew)
            OutlinedButton(
              onPressed: _busy ? null : () => _submit(next: true),
              child: const Text('ذخیره و سؤال بعدی'),
            ),
          Tooltip(
            message: 'Ctrl+Enter',
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('ذخیره'),
            ),
          ),
        ],
        child: RadioGroup<int>(
          groupValue: _correct,
          onChanged: (v) => setState(() => _correct = v ?? _correct),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _text,
                focusNode: _textFocus,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'متن سؤال'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text('گزینه‌ها', style: context.text.labelLarge),
                  ),
                  Text(
                    'دایره کنار گزینه درست را بزنید',
                    style: context.text.labelSmall.copyWith(
                      color: context.onBgMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final (i, c) in _options.indexed)
                Container(
                  key: ObjectKey(c),
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: i == _correct
                        ? colors.success.withValues(alpha: 0.08)
                        : null,
                    borderRadius: BorderRadius.circular(AppRadius.sm - 4),
                  ),
                  child: Row(
                    children: [
                      Radio<int>(value: i),
                      Expanded(
                        child: TextField(
                          controller: c,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'گزینه ${optionLetter(i)}',
                            suffixIcon: i == _correct
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: context.legible(colors.success),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف گزینه',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _options.length <= 2
                            ? null
                            : () => setState(() {
                                final removed = _options.removeAt(i);
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => removed.dispose(),
                                );
                                if (_correct > i) _correct--;
                                if (_correct >= _options.length) _correct = 0;
                              }),
                      ),
                    ],
                  ),
                ),
              if (_options.length < 6)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _options.add(TextEditingController())),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('افزودن گزینه'),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _explanation,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'توضیح پاسخ درست',
                  helperText: 'پس از پاسخ دادن به کاربر نشان داده می‌شود.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _hint,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'راهنمایی (اختیاری)',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
