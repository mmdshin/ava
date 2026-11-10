import 'package:flutter/material.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';

/// The category's raw card color; widgets use [KindToneContext.kindTone].
Color kindColor(Kind kind) => kind.color;

/// The icons editors can choose for a category. Keep in sync with the
/// backend's `content.CategoryIcons`.
const kindIcons = <String, IconData>{
  'monitor_heart': Icons.monitor_heart_rounded,
  'favorite': Icons.favorite_rounded,
  'bloodtype': Icons.bloodtype_rounded,
  'emergency': Icons.emergency_rounded,
  'health_and_safety': Icons.health_and_safety_rounded,
  'medical_information': Icons.medical_information_rounded,
  'local_hospital': Icons.local_hospital_rounded,
  'air': Icons.air_rounded,
  'psychology': Icons.psychology_rounded,
  'water_drop': Icons.water_drop_rounded,
  'medication': Icons.medication_rounded,
  'vaccines': Icons.vaccines_rounded,
  'healing': Icons.healing_rounded,
  'coronavirus': Icons.coronavirus_rounded,
  'sick': Icons.sick_rounded,
  'masks': Icons.masks_rounded,
  'child_care': Icons.child_care_rounded,
  'pregnant_woman': Icons.pregnant_woman_rounded,
  'elderly': Icons.elderly_rounded,
  'accessible': Icons.accessible_rounded,
  'visibility': Icons.visibility_rounded,
  'science': Icons.science_rounded,
};

IconData kindIcon(Kind kind) =>
    kindIcons[kind.icon] ?? Icons.medical_information_rounded;

String kindLabel(Kind kind) =>
    kind.abbr.isEmpty ? kind.title : '${kind.title} (${kind.abbr})';

String kindName(Kind kind) => kind.title;

String? kindAbbr(Kind kind) => kind.abbr.isEmpty ? null : kind.abbr;

extension KindToneContext on BuildContext {
  /// [kindColor] adjusted to stay visible on the current background
  /// (at least 3 : 1, the WCAG level for icons and bold text).
  Color kindTone(Kind kind) => legible(kindColor(kind), minRatio: 3);
}
