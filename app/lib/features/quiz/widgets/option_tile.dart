import 'package:flutter/material.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

/// How an answer option is shown.
enum OptionState {
  /// Not chosen.
  idle,

  /// Chosen, not checked yet.
  selected,

  /// The right answer (after checking / in review).
  correct,

  /// Chosen but wrong (after checking / in review).
  wrong,

  /// Neither chosen nor right, after checking: faded out.
  dimmed,
}

const optionLetters = ['الف', 'ب', 'ج', 'د', 'هـ', 'و'];

String optionLetter(int index) =>
    index < optionLetters.length ? optionLetters[index] : '${index + 1}';

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.index,
    required this.text,
    required this.state,
    this.onTap,
    this.compact = false,
  });

  final int index;
  final String text;
  final OptionState state;
  final VoidCallback? onTap;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final glass = colors.glass;

    final (Color? tone, IconData? icon) = switch (state) {
      OptionState.selected => (colors.accent, null),
      OptionState.correct => (colors.success, Icons.check_rounded),
      OptionState.wrong => (colors.danger, Icons.close_rounded),
      _ => (null, null),
    };

    final fill = tone?.withValues(alpha: 0.12) ?? glass.withValues(alpha: 0.05);
    final border = tone ?? glass.withValues(alpha: 0.16);
    final badgeSize = compact ? 28.0 : 34.0;

    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: badgeSize,
      height: badgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tone ?? Colors.transparent,
        border: Border.all(
          color: tone ?? glass.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: icon != null
          ? Icon(icon, size: compact ? 16 : 20, color: Colors.white)
          : Text(
              optionLetter(index),
              style: context.text.labelMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: tone != null ? Colors.white : context.onBgMuted,
              ),
            ),
    );

    final status = switch (state) {
      OptionState.correct => 'پاسخ درست',
      OptionState.wrong => 'پاسخ نادرست شما',
      _ => null,
    };

    return Semantics(
      button: onTap != null,
      selected: state == OptionState.selected,
      inMutuallyExclusiveGroup: true,
      hint: status,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: state == OptionState.dimmed ? 0.55 : 1,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: border, width: tone != null ? 1.6 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: compact ? AppSpacing.sm : AppSpacing.md,
              ),
              child: Row(
                children: [
                  badge,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      text,
                      style:
                          (compact
                                  ? context.text.bodyMedium
                                  : context.text.bodyLarge)
                              .copyWith(
                                height: 1.6,
                                fontWeight:
                                    state == OptionState.idle ||
                                        state == OptionState.dimmed
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
