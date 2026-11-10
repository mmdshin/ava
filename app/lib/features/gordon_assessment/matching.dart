import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/gordon_assessment/models/assessment_item.dart';

/// Result of matching assessment answers against care plans.
class CarePlanMatches {
  const CarePlanMatches({required this.specific, required this.general});

  /// Plans for the selected disease (empty when "general" was chosen).
  final List<CarePlan> specific;

  /// General plans that apply to any patient.
  final List<CarePlan> general;

  bool get isEmpty => specific.isEmpty && general.isEmpty;
}

/// Number of [plan]'s tags that were selected in the assessment.
int matchedTagCount(CarePlan plan, Set<String> selectedTags) =>
    plan.tags.where(selectedTags.contains).length;

/// Finds the care plans suggested by the assessment.
///
/// A plan matches when at least one of its tags was selected and it
/// belongs to [kind] or to the "general" category. Within each group, plans
/// with more matching tags come first; ties keep content order.
CarePlanMatches matchCarePlans({
  required List<CarePlan> plans,
  required Set<String> selectedTags,
  required Kind kind,
}) {
  List<CarePlan> rank(Iterable<CarePlan> candidates) {
    final scored = <({CarePlan plan, int score, int order})>[];
    var order = 0;
    for (final p in candidates) {
      final score = matchedTagCount(p, selectedTags);
      if (score > 0) scored.add((plan: p, score: score, order: order++));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.order.compareTo(b.order);
    });
    return [for (final s in scored) s.plan];
  }

  return CarePlanMatches(
    specific: kind.isGeneral
        ? const []
        : rank(plans.where((p) => p.kind == kind)),
    general: rank(plans.where((p) => p.kind.isGeneral)),
  );
}

/// The selected assessment findings that led to [plan] being suggested
/// (those sharing at least one tag with it) — shown as "why".
List<AssessmentItem> matchReasons(
  CarePlan plan,
  Iterable<AssessmentItem> selectedItems,
) => [
  for (final item in selectedItems)
    if (item.tags.any(plan.tags.contains)) item,
];
