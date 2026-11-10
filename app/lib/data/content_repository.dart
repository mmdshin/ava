import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ava_web/data/content_validation.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/gordon_assessment/models/gordon_domain.dart';
import 'package:ava_web/features/quiz/models/quiz.dart';

@immutable
class ContentMeta {
  const ContentMeta({
    required this.schemaVersion,
    required this.version,
    this.publishedAt,
  });
  final int schemaVersion;
  final int version;
  final DateTime? publishedAt;
}

class ContentRepository {
  ContentRepository(ContentBundle bundle)
    : meta = bundle.meta,
      categories = bundle.categories,
      _kindsById = {for (final k in bundle.categories) k.id: k},
      carePlans = bundle.carePlans,
      quizzes = bundle.quizzes,
      gordonDomains = List.unmodifiable(
        [...bundle.gordonDomains]..sort((a, b) => a.order.compareTo(b.order)),
      ),
      _carePlansById = {for (final p in bundle.carePlans) p.id: p};

  /// Highest content JSON shape this build can read.
  static const supportedSchemaVersion = 2;

  /// Oldest shape this build can read (2 added the categories).
  static const minSchemaVersion = 2;

  /// SharedPreferences key of the downloaded bundle (raw JSON).
  static const cacheKey = 'content_bundle';

  /// The content saved on this device, or null (first start, or the
  /// saved copy is unusable).
  static ContentRepository? fromCache(SharedPreferences prefs) {
    final raw = prefs.getString(cacheKey);
    if (raw == null) return null;
    try {
      return ContentRepository(ContentBundle.parseChecked(raw));
    } catch (e) {
      debugPrint('Ignoring saved content: $e');
      return null;
    }
  }

  final ContentMeta meta;

  /// Disease categories in display order ("general" included).
  final List<Kind> categories;
  final Map<String, Kind> _kindsById;
  final List<CarePlan> carePlans;
  final List<Quiz> quizzes;

  /// Sorted by [GordonDomain.order].
  final List<GordonDomain> gordonDomains;
  final Map<String, CarePlan> _carePlansById;

  CarePlan? carePlanById(String id) => _carePlansById[id];

  /// The category with this id, or null (e.g. an old link).
  Kind? kindById(String id) => _kindsById[id];

  /// The categories of specific diseases (all but "general").
  List<Kind> get diseases => [
    for (final k in categories)
      if (!k.isGeneral) k,
  ];

  /// The shared "general" category (always there in valid content).
  Kind? get general => _kindsById[Kind.generalId];

  List<CarePlan> carePlansOfKind(Kind kind) =>
      carePlans.where((p) => p.kind == kind).toList(growable: false);
}

/// One complete set of content: the JSON the server publishes
/// (`GET /v1/content/bundle`).
class ContentBundle {
  const ContentBundle({
    required this.meta,
    required this.categories,
    required this.carePlans,
    required this.quizzes,
    required this.gordonDomains,
  });

  factory ContentBundle.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) =>
        (json[key] as List).cast<Map<String, dynamic>>();
    final categories = List<Kind>.unmodifiable(
      list('categories').map(Kind.fromJson),
    );
    final kinds = {for (final k in categories) k.id: k};
    return ContentBundle(
      meta: ContentMeta(
        schemaVersion: json['schemaVersion'] as int,
        version: json['version'] as int,
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      ),
      categories: categories,
      carePlans: List.unmodifiable(
        list('carePlans').map((j) => CarePlan.fromJson(j, kinds)),
      ),
      quizzes: List.unmodifiable(
        list('quizzes').map((j) => Quiz.fromJson(j, kinds)),
      ),
      gordonDomains: List.unmodifiable(
        list('gordonDomains').map(GordonDomain.fromJson),
      ),
    );
  }

  /// Parses and checks content from the server (or its saved copy).
  factory ContentBundle.parseChecked(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final schema = json['schemaVersion'];
    if (schema is! int || schema > ContentRepository.supportedSchemaVersion) {
      throw FormatException('unsupported content schema $schema');
    }
    if (schema < ContentRepository.minSchemaVersion) {
      throw FormatException(
        'content schema $schema is too old (publish again from the admin panel)',
      );
    }
    final bundle = ContentBundle.fromJson(json);
    final issues = validateContent(
      categories: bundle.categories,
      carePlans: bundle.carePlans,
      quizzes: bundle.quizzes,
      gordonDomains: bundle.gordonDomains,
    );
    if (!issues.ok) {
      throw FormatException('invalid content: ${issues.errors.first}');
    }
    return bundle;
  }

  final ContentMeta meta;
  final List<Kind> categories;
  final List<CarePlan> carePlans;
  final List<Quiz> quizzes;
  final List<GordonDomain> gordonDomains;
}
