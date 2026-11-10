import 'package:flutter/material.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/core/responsive.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/care_plans/widgets/favorite_button.dart';

class CarePlanItem extends StatelessWidget {
  const CarePlanItem({
    super.key,
    required this.onSelectedCarePlan,
    required this.carePlan,
    required this.color,
    required this.index,
  });

  final VoidCallback onSelectedCarePlan;
  final CarePlan carePlan;
  final Color color;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelectedCarePlan,
        splashColor: color.withValues(alpha: 0.22),
        highlightColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.wp(16),
            vertical: context.hp(14),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.24),
                color.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.45),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
              children: [
                Container(
                  width: context.wp(38),
                  height: context.wp(38),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(color, Colors.white, 0.15)!, color],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: context.text.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                SizedBox(width: context.wp(14)),

                Expanded(
                  child: Text(
                    carePlan.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),

                SizedBox(width: context.wp(4)),

                FavoriteButton(
                  carePlan: carePlan,
                  color: color,
                  size: context.sp(20),
                ),

                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color,
                  size: context.sp(14),
                ),
              ],
            ),
        ),
      ),
    );
  }
}
