import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/app/router.dart';
import 'package:ava_web/common/messenger.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/core/theme_controller.dart';

/// Root widget: theme (from [themeProvider]) + routes (from
/// [routerProvider]).
class AvaApp extends ConsumerWidget {
  const AvaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'آوا',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appMessengerKey,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light(theme.seed),
      darkTheme: AppTheme.dark(theme.seed),
      themeMode: theme.mode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final base = Theme.of(context);
        final scale = AppTypography.responsiveTextScale(
          MediaQuery.sizeOf(context).width,
        );
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: math.max(1.0, 2.0 / scale),
          child: Theme(
            data: base.copyWith(
              textTheme: base.textTheme.apply(fontSizeFactor: scale),
            ),
            child: child!,
          ),
        );
      },
    );
  }
}
