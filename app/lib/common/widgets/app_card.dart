import 'package:flutter/material.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

/// The app's standard card: a translucent "glass" panel that reads well
/// on the background gradient in light and dark mode.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.accent,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.lg,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;

  final Color? accent;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Screen-reader label for tappable cards whose content isn't
  /// self-describing.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final glass = context.appColors.glass;
    final fill =
        accent?.withValues(alpha: 0.12) ?? glass.withValues(alpha: 0.08);
    final border =
        accent?.withValues(alpha: 0.38) ?? glass.withValues(alpha: 0.16);

    final content = Padding(padding: padding, child: child);

    final card = Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              splashColor: (accent ?? glass).withValues(alpha: 0.12),
              highlightColor: (accent ?? glass).withValues(alpha: 0.06),
              child: content,
            ),
    );

    if (semanticLabel == null) return card;
    return Semantics(button: onTap != null, label: semanticLabel, child: card);
  }
}
