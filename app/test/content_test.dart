import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ava_web/data/content_repository.dart';
import 'package:ava_web/features/about/about_info.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/gordon_assessment/matching.dart';

import 'helpers.dart';

/// Content rules, checked on the sample content (test/fixtures). The
/// same rules guard real content on the server before publishing.
void main() {
  late ContentRepository repo;

  setUpAll(() async {
    repo = await loadTestContent();
  });

  group('care plans', () {
    test('load, with unique ids', () {
      expect(repo.carePlans, isNotEmpty);
      final ids = repo.carePlans.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every plan has a title, tags and non-empty sections', () {
      for (final p in repo.carePlans) {
        expect(p.title.trim(), isNotEmpty, reason: p.id);
        expect(p.tags, isNotEmpty, reason: p.id);
        expect(p.sections, isNotEmpty, reason: p.id);
        for (final s in p.sections) {
          expect(s.items, isNotEmpty, reason: '${p.id} ${s.title}');
        }
      }
    });

    test('every plan has interventions and outcomes', () {
      for (final p in repo.carePlans) {
        expect(p.itemsOf(SectionType.interventions), isNotEmpty, reason: p.id);
        expect(p.itemsOf(SectionType.outcomes), isNotEmpty, reason: p.id);
      }
    });

    test('every category has at least one plan', () {
      expect(repo.categories.map((k) => k.id), contains(Kind.generalId));
      for (final kind in repo.categories) {
        expect(repo.carePlansOfKind(kind), isNotEmpty, reason: kind.name);
      }
    });

    test('lookup by id', () {
      final first = repo.carePlans.first;
      expect(repo.carePlanById(first.id), same(first));
      expect(repo.carePlanById('does-not-exist'), isNull);
    });
  });

  group('quizzes', () {
    test('load, with unique quiz and question ids', () {
      expect(repo.quizzes, isNotEmpty);
      final ids = [
        for (final q in repo.quizzes) ...[q.id, ...q.questions.map((x) => x.id)],
      ];
      expect(ids.toSet().length, ids.length);
    });

    test('every question has 2+ distinct options and a valid answer', () {
      for (final quiz in repo.quizzes) {
        expect(quiz.questions, isNotEmpty, reason: quiz.id);
        for (final q in quiz.questions) {
          expect(q.options.length, greaterThanOrEqualTo(2), reason: q.id);
          expect(q.options.toSet().length, q.options.length, reason: q.id);
          expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1),
              reason: q.id);
        }
      }
    });

    test('scoring', () {
      final quiz = repo.quizzes.first;
      final allRight = {
        for (var i = 0; i < quiz.questions.length; i++)
          i: quiz.questions[i].correctIndex,
      };
      expect(quiz.score(allRight), quiz.questions.length);
      expect(quiz.score({}), 0);
    });
  });

  group('gordon assessment', () {
    test('domains load sorted, with unique item ids', () {
      final domains = repo.gordonDomains;
      expect(domains, isNotEmpty);
      for (var i = 1; i < domains.length; i++) {
        expect(domains[i].order, greaterThanOrEqualTo(domains[i - 1].order));
      }
      final ids = [for (final d in domains) ...d.items.map((i) => i.id)];
      expect(ids.toSet().length, ids.length);
    });

    // Catches tag typos: a plan tag no assessment item can select means
    // the diagnosis finder can never suggest that plan for it (this is
    // how 'Weakness' vs 'weakness' and 'restlessnes' slipped in).
    test('every care-plan tag can be selected in the assessment', () {
      final selectable = {
        for (final d in repo.gordonDomains)
          for (final item in d.items) ...item.tags,
      };
      final unreachable = {
        for (final p in repo.carePlans) ...p.tags,
      }.difference(selectable);
      expect(unreachable, isEmpty);
    });
  });

  // Content-quality checks: run on every `flutter test`, so mistakes in
  // assets/data/*.json show up immediately with the exact id to fix.
  group('content quality', () {
    final tagFormat = RegExp(r'^[a-z]+(_[a-z]+)*$');

    Iterable<String> allTags() sync* {
      for (final p in repo.carePlans) {
        yield* p.tags;
      }
      for (final d in repo.gordonDomains) {
        for (final i in d.items) {
          yield* i.tags;
        }
      }
    }

    test('tags are lowercase snake_case (catches "Weakness", "Oliguria")', () {
      final bad = {for (final t in allTags()) if (!tagFormat.hasMatch(t)) t};
      expect(bad, isEmpty);
    });

    test('tags look unique (catches typos like "restlessnes")', () {
      // Two tags that differ by one letter are almost always a typo.
      final tags = allTags().toSet().toList()..sort();
      final suspicious = <String>[];
      for (var i = 0; i < tags.length; i++) {
        for (var j = i + 1; j < tags.length; j++) {
          if (tags[i].length > 4 && _editDistance(tags[i], tags[j]) <= 1) {
            suspicious.add('${tags[i]} / ${tags[j]}');
          }
        }
      }
      expect(suspicious, isEmpty);
    });

    test('no repeated tags within a plan or finding', () {
      for (final p in repo.carePlans) {
        expect(p.tags.toSet().length, p.tags.length, reason: p.id);
      }
      for (final d in repo.gordonDomains) {
        for (final i in d.items) {
          expect(i.tags, isNotEmpty, reason: i.id);
          expect(i.tags.toSet().length, i.tags.length, reason: i.id);
        }
      }
    });

    test('plan ids follow "<kind>-NN"', () {
      for (final p in repo.carePlans) {
        expect(p.id, matches(RegExp('^${p.kind.name}-\\d{2}\$')));
      }
    });

    test('no duplicate plan titles within a kind', () {
      for (final kind in repo.categories) {
        final titles = [for (final p in repo.carePlansOfKind(kind)) p.title.trim()];
        expect(titles.toSet().length, titles.length, reason: kind.name);
      }
    });

    test('no duplicate or blank items inside a plan section', () {
      for (final p in repo.carePlans) {
        for (final s in p.sections) {
          final items = [for (final i in s.items) i.trim()];
          expect(items.where((i) => i.isEmpty), isEmpty,
              reason: '${p.id} ${s.title}');
          expect(items.toSet().length, items.length,
              reason: '${p.id} ${s.title}: duplicate item');
        }
      }
    });

    test('no duplicate finding titles in the assessment', () {
      final titles = [
        for (final d in repo.gordonDomains)
          for (final i in d.items) i.title.trim(),
      ];
      final seen = <String>{};
      final dupes = [for (final t in titles) if (!seen.add(t)) t];
      expect(dupes, isEmpty);
    });

    test('no duplicate questions or blank options in quizzes', () {
      final seen = <String>{};
      for (final quiz in repo.quizzes) {
        for (final q in quiz.questions) {
          expect(q.text.trim(), isNotEmpty, reason: q.id);
          expect(seen.add(q.text.trim()), isTrue,
              reason: '${q.id}: same question as another one');
          for (final o in q.options) {
            expect(o.trim(), isNotEmpty, reason: q.id);
          }
        }
      }
    });

    // Findings that no care plan uses yet: ticking them changes nothing
    // in the diagnosis finder. Known gaps are listed here on purpose.
    // When you add a plan for one, remove it from this list (the test
    // tells you); a NEW finding without a plan makes the test fail.
    const findingsWithoutPlan = <String>{};

    test('every finding leads to a plan (except the known gaps)', () {
      final planTags = {for (final p in repo.carePlans) ...p.tags};
      final orphans = {
        for (final d in repo.gordonDomains)
          for (final i in d.items)
            if (!i.tags.any(planTags.contains)) i.id,
      };
      expect(
        orphans.difference(findingsWithoutPlan),
        isEmpty,
        reason: 'new findings that no care plan uses',
      );
      expect(
        findingsWithoutPlan.difference(orphans),
        isEmpty,
        reason: 'these now have a plan — remove them from findingsWithoutPlan',
      );
    });
  });

  group('about', () {
    test('app version matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(r'^version:\s*([^+\s]+)', multiLine: true)
          .firstMatch(pubspec)!
          .group(1);
      expect(AboutInfo.appVersion, version,
          reason: 'update AboutInfo.appVersion when you bump the version');
    });
  });

  group('diagnosis finder matching', () {
    CarePlan plan(String id, Kind kind, List<String> tags) => CarePlan(
      id: id,
      kind: kind,
      title: id,
      tags: tags,
      sections: const [],
    );

    final plans = [
      plan('acs-1', TestKinds.acs, ['pain', 'anxiety']),
      plan('acs-2', TestKinds.acs, ['pain']),
      plan('chf-1', TestKinds.chf, ['pain', 'edema']),
      plan('gen-1', TestKinds.general, ['anxiety']),
      plan('gen-2', TestKinds.general, ['fever']),
    ];

    test('specific plans for the kind, general plans separately', () {
      final m = matchCarePlans(
        plans: plans,
        selectedTags: {'pain', 'anxiety'},
        kind: TestKinds.acs,
      );
      // acs-1 matches 2 tags, so it ranks above acs-2; chf is excluded.
      expect(m.specific.map((p) => p.id), ['acs-1', 'acs-2']);
      expect(m.general.map((p) => p.id), ['gen-1']);
    });

    test('general kind returns only general plans', () {
      final m = matchCarePlans(
        plans: plans,
        selectedTags: {'pain', 'fever'},
        kind: TestKinds.general,
      );
      expect(m.specific, isEmpty);
      expect(m.general.map((p) => p.id), ['gen-2']);
    });

    test('no selected tags → no matches', () {
      final m = matchCarePlans(plans: plans, selectedTags: {}, kind: TestKinds.acs);
      expect(m.isEmpty, isTrue);
    });

    test('real content: selecting every item suggests plans for each kind', () {
      // Sanity check on the real data: selecting everything for a kind
      // must suggest at least one plan.
      final allTags = {
        for (final d in repo.gordonDomains)
          for (final i in d.items) ...i.tags,
      };
      for (final kind in repo.categories) {
        final m = matchCarePlans(
          plans: repo.carePlans,
          selectedTags: allTags,
          kind: kind,
        );
        expect(m.isEmpty, isFalse, reason: kind.name);
      }
    });
  });
}

/// Levenshtein distance, for spotting near-identical tags.
int _editDistance(String a, String b) {
  if ((a.length - b.length).abs() > 1) return 2; // only care about <= 1
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List<int>.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}
