import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

@immutable
class Kind {
  const Kind({
    required this.id,
    required this.title,
    required this.color,
    this.abbr = '',
    this.icon = 'medical_information',
  });

  factory Kind.fromJson(Map<String, dynamic> json) => Kind(
    id: json['id'] as String,
    title: json['title'] as String,
    abbr: json['abbr'] as String? ?? '',
    color: parseHexColor(json['color'] as String),
    icon: json['icon'] as String? ?? 'medical_information',
  );

  static const generalId = 'general';

  /// Stable id, also the prefix of its care plan ids
  final String id;

  /// Persian name
  final String title;

  /// Short code for cards
  final String abbr;

  /// Card color
  final Color color;

  /// Icon name
  final String icon;

  String get name => id;

  bool get isGeneral => id == generalId;

  @override
  bool operator ==(Object other) => other is Kind && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Kind($id)';
}

Color parseHexColor(String hex) {
  final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex.trim());
  if (m == null) throw FormatException('not a color: $hex');
  return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

/// The fixed set of section types a nursing care plan is made of
enum SectionType {
  definition('تعریف'),
  relatedTo('در ارتباط با'),
  definingCharacteristics('مشخص می‌شود با'),
  riskFactors('شواهد احتمالی'),
  interventions('اقدامات پرستاری'),
  outcomes('پیامد مطلوب');

  const SectionType(this.label);

  /// Default heading shown for this section.
  final String label;
}

class CarePlanSection {
  const CarePlanSection({
    required this.type,
    required this.items,
    String? title,
  }) : _title = title;

  factory CarePlanSection.fromJson(Map<String, dynamic> json) {
    return CarePlanSection(
      type: SectionType.values.byName(json['type'] as String),
      title: json['title'] as String?,
      items: List.unmodifiable((json['items'] as List).cast<String>()),
    );
  }

  final SectionType type;
  final List<String> items;

  final String? _title;

  String get title => _title ?? type.label;
}

class CarePlan {
  const CarePlan({
    required this.id,
    required this.kind,
    required this.title,
    required this.tags,
    required this.sections,
  });

  factory CarePlan.fromJson(
    Map<String, dynamic> json,
    Map<String, Kind> kinds,
  ) {
    final kind = json['kind'] as String;
    return CarePlan(
      id: json['id'] as String,
      kind:
          kinds[kind] ??
          (throw FormatException(
            'care plan "${json['id']}": unknown category "$kind"',
          )),
      title: json['title'] as String,
      tags: List.unmodifiable((json['tags'] as List).cast<String>()),
      sections: List.unmodifiable(
        (json['sections'] as List).map(
          (s) => CarePlanSection.fromJson(s as Map<String, dynamic>),
        ),
      ),
    );
  }

  final String id;
  final Kind kind;
  final String title;

  final List<String> tags;
  final List<CarePlanSection> sections;

  List<String> itemsOf(SectionType type) => [
    for (final s in sections)
      if (s.type == type) ...s.items,
  ];

  @override
  bool operator ==(Object other) => other is CarePlan && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
