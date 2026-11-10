import 'package:ava_web/features/gordon_assessment/models/assessment_item.dart';

class GordonDomain {
  const GordonDomain({
    required this.id,
    required this.title,
    required this.order,
    required this.items,
  });

  factory GordonDomain.fromJson(Map<String, dynamic> json) {
    return GordonDomain(
      id: json['id'] as String,
      title: json['title'] as String,
      order: json['order'] as int,
      items: List.unmodifiable(
        (json['items'] as List).map(
          (i) => AssessmentItem.fromJson(i as Map<String, dynamic>),
        ),
      ),
    );
  }

  final String id;
  final String title;
  final int order;
  final List<AssessmentItem> items;
}
