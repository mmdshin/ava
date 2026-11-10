import 'package:flutter/material.dart';
import 'package:ava_web/core/design_system.dart';

/// Heading above a group of content, with an optional "see all"-style
/// action on the other side.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            // Lets screen-reader users jump between sections.
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: context.text.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action!, style: context.text.labelLarge.inheritColor),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
