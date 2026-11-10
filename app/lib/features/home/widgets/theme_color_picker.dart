import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/responsive.dart';
import 'package:ava_web/core/theme_controller.dart';

/// Dialog for choosing the app's theme color (saved via [themeProvider]).
void showThemeColorPicker(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: context.wp(32),
          vertical: context.hp(40),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: EdgeInsets.all(context.wp(22)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                gradient: LinearGradient(
                  colors: [
                    context.appColors.dialogSurface.withValues(alpha: 0.97),
                    context.appColors.dialogSurface.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: context.appColors.glass.withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'رنگ پوسته را انتخاب کنید',
                      style: context.text.titleMedium.copyWith(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: context.hp(20)),
                    Consumer(
                      builder: (context, ref, _) {
                        final currentSeed = ref.watch(
                          themeProvider.select((t) => t.seed),
                        );
                        return Wrap(
                          spacing: context.wp(16),
                          runSpacing: context.hp(16),
                          alignment: WrapAlignment.center,
                          children: kColorPresets.map((preset) {
                            final isSelected =
                                currentSeed.toARGB32() ==
                                preset.seed.toARGB32();
                            return Semantics(
  button: true,
  selected: isSelected,
  child: GestureDetector(
                              onTap: () {
                                ref.read(themeProvider.notifier).setSeed(preset.seed);
                                Navigator.pop(dialogContext);
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: context.wp(48),
                                    height: context.wp(48),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color.lerp(
                                            preset.seed,
                                            Colors.white,
                                            0.15,
                                          )!,
                                          preset.seed,
                                        ],
                                      ),
                                      border: Border.all(
                                        color: isSelected
                                            ? context.onBg
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: preset.seed.withValues(
                                            alpha: 0.45,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: context.sp(22),
                                          )
                                        : null,
                                  ),
                                  SizedBox(height: context.hp(6)),
                                  Text(
                                    preset.label,
                                    style: context.text.labelMedium,
                                  ),
                                ],
                              ),
                            ));
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
            ),
          ),
        ),
      );
    },
  );
}
