import 'package:flutter/material.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

Future<String?> showNoteEditorSheet(
  BuildContext context, {
  required String planTitle,
  String initialText = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.appColors.dialogSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _NoteEditor(planTitle: planTitle, initialText: initialText),
  );
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.planTitle, required this.initialText});
  final String planTitle;
  final String initialText;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.appColors.glass;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('یادداشت من', style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.planTitle,
              style: context.text.bodySmall.copyWith(color: context.onBgMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
              style: context.text.bodyLarge,
              decoration: InputDecoration(
                hintText: 'نکات بالینی، توصیه‌های استاد، تجربه بخش…',
                hintStyle: context.text.bodyMedium.copyWith(
                  color: context.onBgMuted,
                ),
                filled: true,
                fillColor: glass.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: glass.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: glass.withValues(alpha: 0.2)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _controller.text),
                    child: const Text('ذخیره'),
                  ),
                ),
                if (widget.initialText.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.md),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: context.appColors.danger,
                    ),
                    onPressed: () => Navigator.pop(context, ''),
                    child: const Text('حذف یادداشت'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
