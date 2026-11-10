import 'package:flutter/material.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/core/responsive.dart';
import 'package:ava_web/core/app_theme.dart';

class DiagnosisCategoryItem extends StatelessWidget {
  const DiagnosisCategoryItem({
    super.key,
    required this.onSelectedCategory,
    required this.title,
    required this.color,
    required this.icon,
    this.count,
  });

  final VoidCallback onSelectedCategory;
  final String title;
  final Color color;
  final IconData icon;

  final int? count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelectedCategory,
        splashColor: color.withValues(alpha: 0.25),
        highlightColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.wp(18),
            vertical: context.hp(16),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.28),
                color.withValues(alpha: 0.09),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.24),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: context.wp(50),
                height: context.wp(50),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(context.wp(16)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.lerp(color, Colors.white, 0.15)!, color],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: context.sp(24)),
              ),

              SizedBox(width: context.wp(16)),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.onBg,
                      ),
                    ),
                    if (count != null) ...[
                      SizedBox(height: context.hp(4)),
                      Text(
                        "$count برنامه مراقبتی",
                        style: context.text.labelLarge.copyWith(
                          color: context.legible(color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(width: context.wp(8)),

              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: context.sp(15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
