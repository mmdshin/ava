import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/gordon_assessment/models/gordon_domain.dart';
import 'package:ava_web/features/quiz/models/quiz.dart';

class ContentIssues {
  const ContentIssues({required this.errors, required this.warnings});

  final List<String> errors;
  final List<String> warnings;

  bool get ok => errors.isEmpty;
}

final _tagFormat = RegExp(r'^[a-z]+(_[a-z]+)*$');
final _categoryIdFormat = RegExp(r'^[a-z][a-z0-9]{1,19}$');

ContentIssues validateContent({
  required List<Kind> categories,
  required List<CarePlan> carePlans,
  required List<Quiz> quizzes,
  required List<GordonDomain> gordonDomains,
}) {
  final errors = <String>[];
  final warnings = <String>[];

  List<String> duplicates(Iterable<String> values) {
    final seen = <String>{};
    final dupes = <String>{};
    for (final v in values) {
      if (!seen.add(v.trim())) dupes.add(v.trim());
    }
    return dupes.toList();
  }

  // ---- categories
  final categoryIds = <String>{};
  for (final c in categories) {
    if (!_categoryIdFormat.hasMatch(c.id)) {
      errors.add('category "${c.id}": id must be lowercase letters or digits');
    }
    if (!categoryIds.add(c.id)) errors.add('category "${c.id}": duplicate id');
    if (c.title.trim().isEmpty)
      errors.add('category "${c.id}": title is empty');
  }
  for (final t in duplicates([for (final c in categories) c.title])) {
    errors.add('category title "$t" is used twice');
  }
  if (!categoryIds.contains(Kind.generalId)) {
    errors.add('the "${Kind.generalId}" category is missing');
  }

  // ---- Gordon assessment
  if (gordonDomains.isEmpty) errors.add('no Gordon domains');
  final selectable = <String>{};
  final findingIds = <String>{};
  for (final d in gordonDomains) {
    if (d.title.trim().isEmpty) errors.add('domain "${d.id}": empty title');
    for (final f in d.items) {
      if (!findingIds.add(f.id)) errors.add('finding "${f.id}": duplicate id');
      if (f.title.trim().isEmpty) errors.add('finding "${f.id}": empty title');
      if (f.tags.isEmpty) errors.add('finding "${f.id}": no tags');
      if (duplicates(f.tags).isNotEmpty) {
        errors.add('finding "${f.id}": repeated tags');
      }
      selectable.addAll(f.tags);
    }
  }
  for (final t in duplicates([
    for (final d in gordonDomains)
      for (final f in d.items) f.title,
  ])) {
    errors.add('finding title "$t" is used twice');
  }

  // ---- care plans
  final planIds = <String>{};
  final planTags = <String>{};
  for (final p in carePlans) {
    final where = 'care plan "${p.id}"';
    if (!RegExp('^${p.kind.name}-\\d{2,}\$').hasMatch(p.id)) {
      errors.add('$where: id must look like ${p.kind.name}-01');
    }
    if (!planIds.add(p.id)) errors.add('$where: duplicate id');
    if (p.title.trim().isEmpty) errors.add('$where: empty title');
    if (p.tags.isEmpty) errors.add('$where: no tags');
    if (duplicates(p.tags).isNotEmpty) errors.add('$where: repeated tags');
    for (final t in p.tags) {
      planTags.add(t);
      if (!selectable.contains(t)) {
        errors.add('$where: tag "$t" can\'t be selected in the assessment');
      }
    }
    if (p.sections.isEmpty) errors.add('$where: no sections');
    for (final (i, s) in p.sections.indexed) {
      if (s.items.isEmpty) errors.add('$where: section ${i + 1} is empty');
      if (s.items.any((item) => item.trim().isEmpty)) {
        errors.add('$where: section ${i + 1} has a blank item');
      }
      if (duplicates(s.items).isNotEmpty) {
        errors.add('$where: section ${i + 1} repeats an item');
      }
    }
    for (final required in [SectionType.interventions, SectionType.outcomes]) {
      if (p.itemsOf(required).isEmpty) {
        errors.add('$where: missing a ${required.name} section');
      }
    }
  }
  for (final kind in categories) {
    final titles = [
      for (final p in carePlans)
        if (p.kind == kind) p.title,
    ];
    if (titles.isEmpty) errors.add('no care plans for ${kind.name}');
    for (final t in duplicates(titles)) {
      errors.add('care plan title "$t" is used twice in ${kind.name}');
    }
  }
  for (final d in gordonDomains) {
    for (final f in d.items) {
      if (!f.tags.any(planTags.contains)) {
        warnings.add(
          'finding "${f.id}" (${f.title}) doesn\'t lead to any care plan',
        );
      }
    }
  }

  // ---- quizzes
  if (quizzes.isEmpty) errors.add('no quizzes');
  final quizIds = <String>{};
  final texts = <String>{};
  for (final quiz in quizzes) {
    if (!quizIds.add(quiz.id)) errors.add('quiz "${quiz.id}": duplicate id');
    if (quiz.title.trim().isEmpty) errors.add('quiz "${quiz.id}": empty title');
    if (quiz.questions.isEmpty) errors.add('quiz "${quiz.id}": no questions');
    for (final q in quiz.questions) {
      final at = 'question "${q.id}"';
      if (!quizIds.add(q.id)) errors.add('$at: duplicate id');
      if (q.text.trim().isEmpty) {
        errors.add('$at: empty text');
      } else if (!texts.add(q.text.trim())) {
        errors.add('$at: same text as another question');
      }
      if (q.options.length < 2) errors.add('$at: needs at least 2 options');
      if (q.options.any((o) => o.trim().isEmpty)) {
        errors.add('$at: blank option');
      }
      if (duplicates(q.options).isNotEmpty) errors.add('$at: repeated option');
      if (q.correctIndex < 0 || q.correctIndex >= q.options.length) {
        errors.add('$at: correct answer is not one of the options');
      }
    }
  }

  // ---- tags
  final tags = {...planTags, ...selectable}.toList()..sort();
  for (final t in tags) {
    if (!_tagFormat.hasMatch(t))
      errors.add('tag "$t" must be lowercase snake_case');
  }
  for (var i = 0; i < tags.length; i++) {
    for (var j = i + 1; j < tags.length; j++) {
      if (tags[i].length > 4 && editDistance(tags[i], tags[j]) <= 1) {
        errors.add(
          'tags "${tags[i]}" and "${tags[j]}" look like a typo of each other',
        );
      }
    }
  }

  return ContentIssues(errors: errors, warnings: warnings);
}

/// Levenshtein distance (returns 2 when lengths differ by more than one;
/// callers only care about 0, 1 or "more").
int editDistance(String a, String b) {
  if ((a.length - b.length).abs() > 1) return 2;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List<int>.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}
