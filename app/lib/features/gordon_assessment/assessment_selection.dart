import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/gordon_assessment/models/assessment_item.dart';

@immutable
class AssessmentSelection {
  const AssessmentSelection({required this.kind, required this.items});

  final Kind kind;
  final List<AssessmentItem> items;

  /// Every tag of the selected findings, without duplicates.
  Set<String> get tags => {for (final i in items) ...i.tags};
}

/// The most recently submitted assessment (null until one is submitted).
final lastAssessmentProvider =
    NotifierProvider<LastAssessmentNotifier, AssessmentSelection?>(
      LastAssessmentNotifier.new,
    );

class LastAssessmentNotifier extends Notifier<AssessmentSelection?> {
  @override
  AssessmentSelection? build() => null;

  void submit(AssessmentSelection selection) => state = selection;
}
