import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:ava_web/features/care_plans/models/care_plan.dart'
    show Kind, parseHexColor;

/// Data shapes of the server's editing API (/v1/admin/…)

/// A disease category as editors see it.
@immutable
class CategoryInfo {
  const CategoryInfo({
    required this.id,
    required this.title,
    required this.abbr,
    required this.color,
    required this.icon,
    required this.plans,
    required this.quizzes,
    required this.meta,
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> j) => CategoryInfo(
    id: j['id'] as String,
    title: j['title'] as String,
    abbr: j['abbr'] as String? ?? '',
    color: j['color'] as String,
    icon: j['icon'] as String? ?? 'medical_information',
    plans: j['plans'] as int? ?? 0,
    quizzes: j['quizzes'] as int? ?? 0,
    meta: Meta.fromJson(j),
  );

  final String id;
  final String title;
  final String abbr;

  /// "#RRGGBB"
  final String color;
  final String icon;

  /// Active care plans / quizzes in this category.
  final int plans;
  final int quizzes;
  final Meta meta;

  bool get isGeneral => id == Kind.generalId;

  /// Only empty categories can be removed, and never "general".
  bool get canArchive => !isGeneral && plans == 0 && quizzes == 0;

  Color get colorValue {
    try {
      return parseHexColor(color);
    } on FormatException {
      return const Color(0xFF888888);
    }
  }

  /// The same category as the app sees it (for its colors and icon).
  Kind get kind =>
      Kind(id: id, title: title, abbr: abbr, color: colorValue, icon: icon);
}

const sectionTypes = [
  'definition',
  'relatedTo',
  'definingCharacteristics',
  'riskFactors',
  'interventions',
  'outcomes',
];

/// Revision, archived flag and who changed it last.
@immutable
class Meta {
  const Meta({
    required this.revision,
    required this.archived,
    this.updatedAt,
    this.updatedBy = '',
  });

  factory Meta.fromJson(Map<String, dynamic> j) => Meta(
    revision: j['revision'] as int? ?? 1,
    archived: j['archived'] as bool? ?? false,
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    updatedBy: j['updatedBy'] as String? ?? '',
  );

  final int revision;
  final bool archived;
  final DateTime? updatedAt;
  final String updatedBy;
}

List<String> _strings(dynamic v) => (v as List? ?? const []).cast<String>();

@immutable
class PlanSummary {
  const PlanSummary({
    required this.id,
    required this.kind,
    required this.title,
    required this.tags,
    required this.meta,
  });

  factory PlanSummary.fromJson(Map<String, dynamic> j) => PlanSummary(
    id: j['id'] as String,
    kind: j['kind'] as String,
    title: j['title'] as String,
    tags: _strings(j['tags']),
    meta: Meta.fromJson(j),
  );

  final String id;
  final String kind;
  final String title;
  final List<String> tags;
  final Meta meta;
}

/// One section of a care plan, editable.
class SectionDraft {
  SectionDraft({required this.type, this.title = '', List<String>? items})
    : items = items ?? [''];

  factory SectionDraft.fromJson(Map<String, dynamic> j) => SectionDraft(
    type: j['type'] as String,
    title: j['title'] as String? ?? '',
    items: [..._strings(j['items'])],
  );

  String type;
  String title;
  List<String> items;

  Map<String, dynamic> toJson() => {
    'type': type,
    if (title.trim().isNotEmpty) 'title': title.trim(),
    'items': [
      for (final i in items)
        if (i.trim().isNotEmpty) i.trim(),
    ],
  };
}

@immutable
class PlanDetail {
  const PlanDetail({
    required this.id,
    required this.kind,
    required this.title,
    required this.tags,
    required this.sections,
    required this.meta,
  });

  factory PlanDetail.fromJson(Map<String, dynamic> j) => PlanDetail(
    id: j['id'] as String,
    kind: j['kind'] as String,
    title: j['title'] as String,
    tags: _strings(j['tags']),
    sections: [
      for (final s in (j['sections'] as List? ?? const []))
        s as Map<String, dynamic>,
    ],
    meta: Meta.fromJson(j),
  );

  final String id;
  final String kind;
  final String title;
  final List<String> tags;

  /// Raw sections; turn into [SectionDraft]s for editing.
  final List<Map<String, dynamic>> sections;
  final Meta meta;
}

@immutable
class QuizSummary {
  const QuizSummary({
    required this.id,
    required this.title,
    required this.kind,
    required this.questions,
    required this.meta,
  });

  factory QuizSummary.fromJson(Map<String, dynamic> j) => QuizSummary(
    id: j['id'] as String,
    title: j['title'] as String,
    kind: j['kind'] as String? ?? '',
    questions: j['questions'] as int? ?? 0,
    meta: Meta.fromJson(j),
  );

  final String id;
  final String title;
  final String kind;
  final int questions;
  final Meta meta;
}

@immutable
class QuestionDetail {
  const QuestionDetail({
    required this.id,
    required this.quizId,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.hint,
    required this.meta,
  });

  factory QuestionDetail.fromJson(Map<String, dynamic> j) => QuestionDetail(
    id: j['id'] as String,
    quizId: j['quizId'] as String? ?? '',
    text: j['text'] as String,
    options: _strings(j['options']),
    correctIndex: j['correctIndex'] as int,
    explanation: j['explanation'] as String? ?? '',
    hint: j['hint'] as String? ?? '',
    meta: Meta.fromJson(j),
  );

  final String id;
  final String quizId;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String hint;
  final Meta meta;
}

@immutable
class QuizDetail {
  const QuizDetail({
    required this.id,
    required this.title,
    required this.kind,
    required this.questions,
    required this.meta,
  });

  factory QuizDetail.fromJson(Map<String, dynamic> j) => QuizDetail(
    id: j['id'] as String,
    title: j['title'] as String,
    kind: j['kind'] as String? ?? '',
    questions: [
      for (final q in (j['questions'] as List? ?? const []))
        QuestionDetail.fromJson(q as Map<String, dynamic>),
    ],
    meta: Meta.fromJson(j),
  );

  final String id;
  final String title;
  final String kind;
  final List<QuestionDetail> questions;
  final Meta meta;
}

@immutable
class FindingDetail {
  const FindingDetail({
    required this.id,
    required this.domainId,
    required this.title,
    required this.tags,
    required this.plans,
    required this.meta,
  });

  factory FindingDetail.fromJson(Map<String, dynamic> j) => FindingDetail(
    id: j['id'] as String,
    domainId: j['domainId'] as String? ?? '',
    title: j['title'] as String,
    tags: _strings(j['tags']),
    plans: _strings(j['plans']),
    meta: Meta.fromJson(j),
  );

  final String id;
  final String domainId;
  final String title;
  final List<String> tags;

  /// Active care plans this finding leads to.
  final List<String> plans;
  final Meta meta;
}

@immutable
class DomainDetail {
  const DomainDetail({
    required this.id,
    required this.title,
    required this.findings,
    required this.meta,
  });

  factory DomainDetail.fromJson(Map<String, dynamic> j) => DomainDetail(
    id: j['id'] as String,
    title: j['title'] as String,
    findings: [
      for (final f in (j['findings'] as List? ?? const []))
        FindingDetail.fromJson(f as Map<String, dynamic>),
    ],
    meta: Meta.fromJson(j),
  );

  final String id;
  final String title;
  final List<FindingDetail> findings;
  final Meta meta;
}

@immutable
class TagInfo {
  const TagInfo({
    required this.name,
    required this.label,
    required this.plans,
    required this.findings,
  });

  factory TagInfo.fromJson(Map<String, dynamic> j) => TagInfo(
    name: j['name'] as String,
    label: j['label'] as String? ?? '',
    plans: _strings(j['plans']),
    findings: _strings(j['findings']),
  );

  final String name;
  final String label;
  final List<String> plans;
  final List<String> findings;

  bool get unused => plans.isEmpty && findings.isEmpty;
}

@immutable
class DraftChange {
  const DraftChange({
    required this.entity,
    required this.id,
    required this.title,
    required this.kind,
  });

  factory DraftChange.fromJson(Map<String, dynamic> j) => DraftChange(
    entity: j['entity'] as String,
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    kind: j['kind'] as String,
  );

  /// care_plan, quiz, question, domain, finding
  final String entity;
  final String id;
  final String title;

  /// added, changed, removed
  final String kind;
}

@immutable
class DraftIssues {
  const DraftIssues({required this.errors, required this.warnings});

  factory DraftIssues.fromJson(Map<String, dynamic> j) => DraftIssues(
    errors: _strings(j['errors']),
    warnings: _strings(j['warnings']),
  );

  final List<String> errors;
  final List<String> warnings;
}

@immutable
class FreezeState {
  const FreezeState({
    required this.frozen,
    this.reason = '',
    this.updatedBy = '',
  });

  factory FreezeState.fromJson(Map<String, dynamic> j) => FreezeState(
    frozen: j['frozen'] as bool? ?? false,
    reason: j['reason'] as String? ?? '',
    updatedBy: j['updatedBy'] as String? ?? '',
  );

  final bool frozen;
  final String reason;
  final String updatedBy;
}

@immutable
class VersionInfo {
  const VersionInfo({
    required this.version,
    required this.notes,
    required this.publishedBy,
    this.publishedAt,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> j) => VersionInfo(
    version: j['version'] as int,
    notes: j['notes'] as String? ?? '',
    publishedBy: j['publishedBy'] as String? ?? '',
    publishedAt: DateTime.tryParse(j['publishedAt'] as String? ?? ''),
  );

  final int version;
  final String notes;
  final String publishedBy;
  final DateTime? publishedAt;
}

@immutable
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.user,
    required this.action,
    required this.entity,
    required this.entityId,
    this.before,
    this.after,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    id: j['id'] as int,
    at: DateTime.parse(j['at'] as String),
    user: j['user'] as String? ?? '',
    action: j['action'] as String,
    entity: j['entity'] as String,
    entityId: j['entityId'] as String? ?? '',
    before: j['before'],
    after: j['after'],
  );

  final int id;
  final DateTime at;
  final String user;
  final String action;
  final String entity;
  final String entityId;
  final Object? before;
  final Object? after;
}

@immutable
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.lastLoginAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: j['id'] as int,
    email: j['email'] as String,
    displayName: j['displayName'] as String? ?? '',
    role: j['role'] as String,
    lastLoginAt: DateTime.tryParse(j['lastLoginAt'] as String? ?? ''),
  );

  final int id;
  final String email;
  final String displayName;
  final String role;
  final DateTime? lastLoginAt;
}
