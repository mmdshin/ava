class AssessmentItem {
  const AssessmentItem({
    required this.id,
    required this.title,
    required this.tags,
  });

  factory AssessmentItem.fromJson(Map<String, dynamic> json) {
    return AssessmentItem(
      id: json['id'] as String,
      title: json['title'] as String,
      tags: List.unmodifiable((json['tags'] as List).cast<String>()),
    );
  }

  final String id;
  final String title;
  final List<String> tags;
}
