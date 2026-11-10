import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ava_web/app/app.dart';
import 'package:ava_web/app/first_run.dart';
import 'package:ava_web/core/config.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/data/content_repository.dart';
import 'package:ava_web/data/content_updater.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  final prefs = await SharedPreferences.getInstance();
  final cached = ContentRepository.fromCache(prefs);
  if (cached != null) {
    _startApp(prefs, cached);

    unawaited(
      ContentUpdater(
        baseUrl: AppConfig.apiBaseUrl,
        prefs: prefs,
      ).check(cached.meta.version),
    );
    return;
  }

  runApp(
    FirstRunApp(
      updater: ContentUpdater(baseUrl: AppConfig.apiBaseUrl, prefs: prefs),
      onReady: (content) => _startApp(prefs, content),
    ),
  );
  FlutterNativeSplash.remove();
}

void _startApp(SharedPreferences prefs, ContentRepository content) {
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        contentRepositoryProvider.overrideWithValue(content),
      ],
      child: const AvaApp(),
    ),
  );
  FlutterNativeSplash.remove();
}
