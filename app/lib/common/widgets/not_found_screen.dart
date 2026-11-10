import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/responsive.dart';

/// Shown for unknown URLs and ids that don't exist (e.g. an old shared
/// link to a care plan that was removed).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FlowAppBar(),
      body: AppBackground(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(context.wp(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.travel_explore_rounded,
                  size: context.wp(72),
                  color: context.onBgMuted,
                ),
                SizedBox(height: context.hp(16)),
                Text(
                  'صفحه موردنظر پیدا نشد',
                  textAlign: TextAlign.center,
                  style: context.text.titleLarge,
                ),
                SizedBox(height: context.hp(8)),
                Text(
                  'ممکن است این لینک قدیمی باشد یا محتوای آن حذف شده باشد.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall.copyWith(
                    color: context.onBgMuted,
                    height: 1.7,
                  ),
                ),
                SizedBox(height: context.hp(24)),
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.appColors.brand,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('بازگشت به خانه'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
