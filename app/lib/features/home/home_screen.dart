import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/features/account/user_data_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/app/router.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/common/widgets/section_header.dart';
import 'package:ava_web/common/widgets/responsive_page.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/kind_style.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/core/responsive.dart';
import 'package:ava_web/core/theme_controller.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/care_plans/recent_care_plans.dart';
import 'package:ava_web/features/care_plans/widgets/care_plan_search_delegate.dart';
import 'package:ava_web/features/home/widgets/theme_color_picker.dart';
import 'package:ava_web/features/quiz/quiz_progress.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _openSearch(BuildContext context, WidgetRef ref) async {
    final selected = await showSearch(
      context: context,
      delegate: CarePlanSearchDelegate(ref.read(carePlansProvider)),
    );
    if (selected != null && context.mounted) {
      context.push(AppRoutes.carePlan(selected.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentCarePlansProvider);
    final gap = SizedBox(height: context.hp(22));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FlowAppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.palette_rounded, color: context.onBg),
            tooltip: 'رنگ پوسته',
            onPressed: () => showThemeColorPicker(context),
          ),
          const _ThemeModeButton(),
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: context.onBg),
            tooltip: 'درباره ما',
            onPressed: () => context.push(AppRoutes.about),
          ),
          IconButton(
            icon: Icon(Icons.account_circle_rounded, color: context.onBg),
            tooltip: 'حساب کاربری',
            onPressed: () => context.push(AppRoutes.account),
          ),
          SizedBox(width: context.wp(4)),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: ResponsivePage(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: context.hp(24)),
              children:
                  [
                        const _Header(),
                        const _UserDataError(),
                        SizedBox(height: context.hp(18)),
                        _SearchField(onTap: () => _openSearch(context, ref)),
                        gap,
                        _AssessmentCard(
                          onTap: () => context.push(AppRoutes.assessment),
                        ),
                        gap,
                        SectionHeader(
                          title: 'دسته‌بندی بیماری‌ها',
                          action: 'همه',
                          onAction: () => context.go(AppRoutes.carePlans),
                        ),
                        const _KindShortcuts(),
                        gap,
                        SectionHeader(
                          title: 'پیشرفت آموزش',
                          action: 'آزمون‌ها',
                          onAction: () => context.go(AppRoutes.quizzes),
                        ),
                        const _QuizProgressCard(),
                        if (recent.isNotEmpty) ...[
                          gap,
                          const SectionHeader(title: 'اخیراً مشاهده‌شده'),
                          _RecentCarePlans(plans: recent),
                        ],
                        SizedBox(height: context.hp(28)),
                        Text(
                          '© AvA Nursing Assistant',
                          textAlign: TextAlign.center,
                          style: context.text.labelMedium.copyWith(
                            color: context.onBgMuted,
                          ),
                        ),
                      ]
                      .animate(interval: 60.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.06, end: 0),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ThemeModeButton extends ConsumerWidget {
  const _ThemeModeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider.select((t) => t.mode));
    final (icon, label) = switch (mode) {
      ThemeMode.dark => (Icons.dark_mode_rounded, 'پوسته: تیره'),
      ThemeMode.light => (Icons.light_mode_rounded, 'پوسته: روشن'),
      ThemeMode.system => (
        Icons.brightness_auto_rounded,
        'پوسته: مطابق دستگاه',
      ),
    };
    return IconButton(
      icon: Icon(icon, color: context.onBg),
      tooltip: label,
      onPressed: () => ref.read(themeProvider.notifier).cycleMode(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final glow = context.appColors.glow;
    const size = 56.0;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  context.appColors.brand,
                  Color.lerp(context.appColors.brand, Colors.white, 0.25)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.local_hospital_rounded,
              color: Colors.white,
              size: size * 0.52,
            ),
          ),
          SizedBox(width: context.wp(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('دستیار پرستاری آوا', style: context.text.headlineSmall),
                SizedBox(height: context.hp(2)),
                Text(
                  'تشخیص • آموزش • مراقبت',
                  style: context.text.bodySmall.copyWith(
                    color: context.onBgMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      radius: AppRadius.md,
      semanticLabel: 'جستجو',
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md + 2,
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: context.onBgMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'جستجوی تشخیص یا برنامه مراقبتی...',
              style: context.text.bodyMedium.copyWith(color: context.onBgMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.appColors.brand;
    return Material(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [brand, Color.lerp(brand, const Color(0xFF6C4FD1), 0.45)!],
          ),
          boxShadow: [
            BoxShadow(
              color: brand.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(context.wp(20)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تشخیص‌یاب',
                        style: context.text.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: context.hp(6)),
                      Text(
                        'یافته‌های بررسی بیمار را بر اساس الگوهای گوردون انتخاب کنید '
                        'تا برنامه‌های مراقبتی مناسب پیشنهاد شود.',
                        style: context.text.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.7,
                        ),
                      ),
                      SizedBox(height: context.hp(14)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.wp(14),
                          vertical: context.hp(8),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'شروع ارزیابی',
                          style: context.text.bodySmall.copyWith(
                            color: brand,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.wp(12)),
                Icon(
                  Icons.manage_search_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: context.wp(64),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KindShortcuts extends ConsumerWidget {
  const _KindShortcuts();

  static double _height(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final iconRow = math.max(
      24.0,
      scaler.scale(context.text.labelMedium.fontSize ?? 12) * 1.5,
    );
    final nameLines =
        scaler.scale(context.text.labelLarge.fontSize ?? 14) * 1.5 * 2;
    return AppSpacing.md * 2 + iconRow + AppSpacing.sm + nameLines + 4;
  }

  Widget _tile(BuildContext context, Kind kind) {
    final color = context.kindTone(kind);
    final name = kindName(kind);
    final abbr = kindAbbr(kind);
    return AppCard(
      accent: color,
      onTap: () => context.go(AppRoutes.carePlansOfKind(kind)),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kindIcon(kind), color: color),
              const Spacer(),
              if (abbr != null)
                Text(
                  abbr,
                  style: context.text.labelMedium.copyWith(
                    color: context.legible(color),
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kinds = ref.watch(categoriesProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >=
            120.0 * kinds.length + AppSpacing.md * (kinds.length - 1)) {
          return SizedBox(
            height: _height(context),
            child: Row(
              children: [
                for (final (i, kind) in kinds.indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(child: _tile(context, kind)),
                ],
              ],
            ),
          );
        }
        return SizedBox(
          height: _height(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: kinds.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) =>
                SizedBox(width: 124, child: _tile(context, kinds[i])),
          ),
        );
      },
    );
  }
}

class _QuizProgressCard extends ConsumerWidget {
  const _QuizProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(quizSummaryProvider);
    final glass = context.appColors.glass;
    final ratio = summary.total == 0 ? 0.0 : summary.completed / summary.total;
    final started = summary.completed > 0;

    return AppCard(
      onTap: () => context.go(AppRoutes.quizzes),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_rounded, color: context.appColors.warning),
              SizedBox(width: context.wp(10)),
              Expanded(
                child: Text(
                  started
                      ? '${summary.completed} از ${summary.total} آزمون انجام شده'
                      : '${summary.total} آزمون زبان استاندارد پرستاری',
                  style: context.text.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (started)
                Text(
                  'میانگین ${summary.avgPercent}٪',
                  style: context.text.labelLarge.copyWith(
                    color: context.onBgMuted,
                  ),
                ),
            ],
          ),
          SizedBox(height: context.hp(12)),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: glass.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(context.appColors.success),
            ),
          ),
          if (!started) ...[
            SizedBox(height: context.hp(10)),
            Text(
              'اولین آزمون را شروع کنید تا پیشرفت شما اینجا نمایش داده شود.',
              style: context.text.labelLarge.copyWith(color: context.onBgMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentCarePlans extends StatelessWidget {
  const _RecentCarePlans({required this.plans});
  final List<CarePlan> plans;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.wp(96),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: plans.length,
        separatorBuilder: (_, _) => SizedBox(width: context.wp(10)),
        itemBuilder: (context, i) {
          final plan = plans[i];
          final color = context.kindTone(plan.kind);
          return SizedBox(
            width: context.wp(170),
            child: AppCard(
              accent: color,
              radius: AppRadius.md,
              onTap: () => context.push(AppRoutes.carePlan(plan.id)),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(width: context.wp(10)),
                  Expanded(
                    child: Text(
                      plan.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UserDataError extends ConsumerWidget {
  const _UserDataError();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(userDataProvider);
    if (!data.hasError) return const SizedBox.shrink();
    final color = context.appColors.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: AppCard(
        accent: color,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: color),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text(
                'اطلاعات حساب شما (نشان‌شده‌ها، پیشرفت آزمون‌ها) دریافت نشد.',
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(userDataProvider),
              child: const Text('تلاش دوباره'),
            ),
          ],
        ),
      ),
    );
  }
}
