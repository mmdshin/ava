import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/data/content_repository.dart';
import 'package:ava_web/data/content_updater.dart';

class FirstRunApp extends StatelessWidget {
  const FirstRunApp({super.key, required this.updater, required this.onReady});

  final ContentUpdater updater;
  final void Function(ContentRepository content) onReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'آوا',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light(kDefaultSeed),
      darkTheme: AppTheme.dark(kDefaultSeed),
      home: FirstRunScreen(updater: updater, onReady: onReady),
    );
  }
}

class FirstRunScreen extends StatefulWidget {
  const FirstRunScreen({
    super.key,
    required this.updater,
    required this.onReady,
  });

  final ContentUpdater updater;
  final void Function(ContentRepository content) onReady;

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  ContentUnavailable? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content = await widget.updater.downloadLatest();
      widget.onReady(content);
    } on ContentUnavailable catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/mums_logo.png', width: 96),
                    const SizedBox(height: AppSpacing.lg),
                    Text('آوا', style: context.text.headlineMedium),
                    const SizedBox(height: AppSpacing.xl),
                    if (_loading) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'در حال دریافت محتوا…',
                        style: context.text.bodyMedium.copyWith(
                          color: context.onBgMuted,
                        ),
                      ),
                    ] else if (error != null) ...[
                      Icon(
                        error.needsAppUpdate
                            ? Icons.system_update_rounded
                            : Icons.wifi_off_rounded,
                        size: 48,
                        color: context.onBgMuted,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        error.needsAppUpdate
                            ? 'برای استفاده از محتوای جدید، برنامه را به‌روزرسانی کنید.'
                            : 'برای اولین اجرا به اینترنت نیاز است تا محتوا دریافت شود.',
                        textAlign: TextAlign.center,
                        style: context.text.bodyLarge,
                      ),
                      if (!error.needsAppUpdate) ...[
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('تلاش دوباره'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
