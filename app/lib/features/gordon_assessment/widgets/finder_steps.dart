import 'package:flutter/material.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

class FinderSteps extends StatelessWidget {
  const FinderSteps({super.key, required this.current});

  /// 0 = choose disease, 1 = assessment, 2 = results.
  final int current;

  static const _labels = ['انتخاب بیماری', 'بررسی گوردون', 'پیشنهادها'];

  @override
  Widget build(BuildContext context) {
    final brand = context.appColors.brand;
    final muted = context.appColors.glass.withValues(alpha: 0.25);

    Widget dot(int i) {
      final done = i < current;
      final active = i == current;
      return Semantics(
        label: 'مرحله ${i + 1} از 3: ${_labels[i]}',
        selected: active,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active ? brand : Colors.transparent,
                border: Border.all(
                  color: done || active ? brand : muted,
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    )
                  : Text(
                      '${i + 1}',
                      style: context.text.labelLarge.copyWith(
                        color: active ? Colors.white : context.onBgMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: 96,
              child: Text(
                _labels[i],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium.copyWith(
                  color: active ? context.onBg : context.onBgMuted,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget line(int i) => Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(top: 14),
        color: i < current ? brand : muted,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [dot(0), line(0), dot(1), line(1), dot(2)],
      ),
    );
  }
}
