import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/features/account/user_data_controller.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';

/// The user's personal note per care plan
final carePlanNotesProvider = Provider<Map<String, String>>(
  (ref) => ref.watch(
    userDataProvider.select((d) => d.value?.notes ?? const <String, String>{}),
  ),
);

String carePlanAsText(CarePlan plan, {String? kindLabel, String? note}) {
  final b = StringBuffer()..writeln('📋 ${plan.title}');
  if (kindLabel != null) b.writeln(kindLabel);
  for (final section in plan.sections) {
    b
      ..writeln()
      ..writeln('■ ${section.title}');
    for (final item in section.items) {
      b.writeln('• $item');
    }
  }
  if (note != null && note.trim().isNotEmpty) {
    b
      ..writeln()
      ..writeln('📝 یادداشت من')
      ..writeln(note.trim());
  }
  b
    ..writeln()
    ..write('— آوا، دستیار پرستاری');
  return b.toString();
}

String sectionAsText(CarePlan plan, CarePlanSection section) {
  final b = StringBuffer()
    ..writeln('${plan.title} — ${section.title}')
    ..writeln();
  for (final item in section.items) {
    b.writeln('• $item');
  }
  return b.toString().trimRight();
}
