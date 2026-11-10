import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/core/jalali.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/features/about/about_info.dart';

class AboutUS extends ConsumerWidget {
  const AboutUS({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentMetaProvider);
    final colors = context.appColors;

    final sections = <Widget>[
      const _Header(),
      _InfoCard(
        icon: Icons.health_and_safety_rounded,
        title: 'هشدار مهم',
        accent: colors.warning,
        child: Text(
          AboutInfo.disclaimer,
          style: context.text.bodyMedium.copyWith(height: 1.9),
        ),
      ),
      _InfoCard(
        icon: Icons.info_outline_rounded,
        title: 'درباره آوا',
        child: Text(
          AboutInfo.purpose,
          style: context.text.bodyMedium.copyWith(height: 1.9),
        ),
      ),
      _InfoCard(
        icon: Icons.school_rounded,
        title: 'دانشگاه',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AboutInfo.research,
              style: context.text.bodyMedium.copyWith(height: 1.9),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _InfoRow(label: 'دانشگاه', value: AboutInfo.university),
            const _InfoRow(label: 'دانشکده', value: AboutInfo.faculty),
            const _InfoRow(
              label: 'وب‌سایت',
              value: AboutInfo.universityWebsite,
              copyable: true,
            ),
            const _InfoRow(
              label: 'کد طرح',
              value: AboutInfo.projectCode,
              copyable: true,
            ),
            const _InfoRow(
              label: 'کد کارآزمایی بالینی',
              value: AboutInfo.trialCode,
              copyable: true,
            ),
          ],
        ),
      ),
      if (AboutInfo.references.isNotEmpty)
        _InfoCard(
          icon: Icons.menu_book_rounded,
          title: 'منابع',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, ref) in AboutInfo.references.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}.',
                          style: context.text.bodyMedium.copyWith(
                            color: context.onBgMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          ref,
                          textDirection: _directionOf(ref),
                          style: context.text.bodyMedium.copyWith(height: 1.7),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      _InfoCard(
        icon: Icons.new_releases_outlined,
        title: 'نسخه',
        child: Column(
          children: [
            const _InfoRow(label: 'نسخه برنامه', value: AboutInfo.appVersion),
            _InfoRow(label: 'نسخه محتوا', value: '${content.version}'),
            if (content.publishedAt case final date?)
              _InfoRow(
                label: 'آخرین به‌روزرسانی محتوا',
                value: formatJalali(date),
              ),
            if (AboutInfo.contactEmail.isNotEmpty)
              const _InfoRow(
                label: 'ارتباط با ما',
                value: AboutInfo.contactEmail,
                copyable: true,
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          '© AvA Nursing Assistant',
          textAlign: TextAlign.center,
          style: context.text.labelMedium.copyWith(color: context.onBgMuted),
        ),
      ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FlowAppBar(
        title: Text('درباره آوا', style: context.text.titleLarge),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                children:
                    [
                          for (final s in sections)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: s,
                            ),
                        ]
                        .animate(interval: 40.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.05, end: 0),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static TextDirection _directionOf(String text) =>
      RegExp(r'[؀-ۿ]').hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.appColors.glass.withValues(alpha: 0.10),
            border: Border.all(
              color: context.appColors.glass.withValues(alpha: 0.2),
            ),
          ),
          child: Image.asset(
            'assets/images/mums_logo.png',
            fit: BoxFit.contain,
            semanticLabel: 'نشان ${AboutInfo.university}',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          AboutInfo.appName,
          textAlign: TextAlign.center,
          style: context.text.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'نسخه ${AboutInfo.appVersion}',
          style: context.text.labelLarge.copyWith(color: context.onBgMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AboutInfo.university,
          textAlign: TextAlign.center,
          style: context.text.titleSmall,
        ),
        Text(
          AboutInfo.universityEnglish,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: context.text.labelMedium.copyWith(color: context.onBgMuted),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
    this.accent,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = context.legible(accent ?? context.appColors.brand);
    return AppCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  title,
                  style: context.text.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label کپی شد')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.bodyMedium.copyWith(color: context.onBgMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.text.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (copyable)
            IconButton(
              tooltip: 'کپی',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: const Icon(Icons.copy_rounded),
              onPressed: () => _copy(context),
            ),
        ],
      ),
    );
  }
}
