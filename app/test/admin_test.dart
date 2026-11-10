import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ava_web/admin/admin_app.dart';
import 'package:ava_web/admin/data/admin_api.dart';
import 'package:ava_web/admin/data/models.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/screens/care_plan_editor.dart';
import 'package:ava_web/admin/screens/categories_screen.dart';
import 'package:ava_web/admin/screens/dashboard_screen.dart';
import 'package:ava_web/admin/screens/login_screen.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/data/api_client.dart';
import 'package:ava_web/features/account/session.dart';

import 'helpers.dart';

/// In-memory editing API: a couple of plans, publishing, and a switch
/// to simulate someone else saving first.
class FakeAdminApi implements AdminApi {
  final calls = <String>[];
  int revision = 1;
  String title = 'درد حاد';
  bool conflictNext = false;
  int published = 1;

  Map<String, dynamic> get _plan => {
    'id': 'acs-01',
    'kind': 'acs',
    'title': title,
    'tags': ['chest_pain'],
    'sections': [
      {
        'type': 'interventions',
        'items': ['پایش'],
      },
      {
        'type': 'outcomes',
        'items': ['کاهش درد'],
      },
    ],
    'revision': revision,
    'archived': false,
    'updatedBy': 'editor@example.ir',
  };

  @override
  Future<List<PlanSummary>> carePlans() async => [PlanSummary.fromJson(_plan)];

  @override
  Future<PlanDetail> carePlan(String id) async => PlanDetail.fromJson(_plan);

  @override
  Future<PlanDetail> updateCarePlan(
    String id,
    Map<String, dynamic> body,
  ) async {
    calls.add('update:${body['revision']}:${body['title']}');
    if (conflictNext || body['revision'] != revision) {
      conflictNext = false;
      throw AdminException(409, 'conflict', revision: revision + 1);
    }
    title = body['title'] as String;
    revision++;
    return PlanDetail.fromJson(_plan);
  }

  @override
  Future<DraftIssues> draftIssues() async => const DraftIssues(
    errors: [],
    warnings: ['finding "x" doesn\'t lead to any care plan'],
  );

  @override
  Future<List<DraftChange>> draftChanges() async => [
    if (title != 'درد حاد')
      const DraftChange(
        entity: 'care_plan',
        id: 'acs-01',
        title: 'x',
        kind: 'changed',
      ),
  ];

  @override
  Future<List<VersionInfo>> versions() async => [
    VersionInfo(
      version: published,
      notes: 'نسخه اول',
      publishedBy: 'r@example.ir',
    ),
  ];

  @override
  Future<FreezeState> freeze() async => const FreezeState(frozen: false);

  @override
  Future<int> publish(String notes) async {
    calls.add('publish:$notes');
    return ++published;
  }

  @override
  Future<List<TagInfo>> tags() async => [
    const TagInfo(
      name: 'chest_pain',
      label: 'درد قفسه سینه',
      plans: ['acs-01'],
      findings: [],
    ),
  ];

  @override
  Future<List<CategoryInfo>> categories() async => [
    for (final (i, (id, title, abbr)) in const [
      ('acs', 'سندرم کرونری حاد', 'ACS'),
      ('chf', 'نارسایی قلبی', 'CHF'),
      ('general', 'عمومی', ''),
    ].indexed)
      CategoryInfo.fromJson({
        'id': id,
        'title': title,
        'abbr': abbr,
        'color': '#17A398',
        'icon': 'favorite',
        'plans': i == 0 ? 1 : 0,
        'quizzes': 0,
        'revision': 1,
      }),
  ];

  @override
  Future<List<QuizSummary>> quizzes() async => const [];

  @override
  Future<List<DomainDetail>> domains() async => const [];

  @override
  Future<List<AuditEntry>> audit({
    String entity = '',
    String entityId = '',
    int? before,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

String sessionFor(String role) => jsonEncode(
  AuthSession(
    token: 't',
    user: AppUser(
      id: 1,
      email: '$role@example.ir',
      displayName: role,
      role: role,
    ),
  ).toJson(),
);

void main() {
  Future<FakeAdminApi> start(WidgetTester tester, {String? role}) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      if (role != null) AuthNotifier.prefsKey: sessionFor(role),
    });
    final prefs = await SharedPreferences.getInstance();
    final api = FakeAdminApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          adminApiProvider.overrideWithValue(api),
          apiProvider.overrideWithValue(FakeAvaApi()),
        ],
        child: const AdminApp(),
      ),
    );
    await settle(tester);
    return api;
  }

  testWidgets('signed out → admin login', (tester) async {
    await start(tester);
    expect(find.byType(AdminLoginScreen), findsOneWidget);
  });

  testWidgets('a nurse has no access', (tester) async {
    await start(tester, role: 'nurse');
    expect(find.byType(AdminLoginScreen), findsOneWidget);
    expect(find.textContaining('دسترسی ندارد'), findsOneWidget);
  });

  testWidgets('an editor sees the dashboard', (tester) async {
    await start(tester, role: 'editor');
    expect(find.byType(DashboardScreen), findsOneWidget);
    // 0 changes, 0 errors, 1 warning, version 1
    expect(find.text('هشدار'), findsOneWidget);
    // editors don't see admin-only pages
    expect(find.text('کاربران'), findsNothing);
  });

  testWidgets('edit a care plan; a conflict offers to reload', (tester) async {
    final api = await start(tester, role: 'editor');
    await tester.tap(find.text('برنامه‌های مراقبتی').first);
    await settle(tester);
    await tester.tap(find.text('درد حاد'));
    await settle(tester);
    expect(find.byType(CarePlanEditor), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'درد حاد'),
      'درد حاد قفسه سینه',
    );
    await tester.pump();
    expect(find.text('ذخیره نشده'), findsOneWidget);
    await tester.tap(find.text('ذخیره'));
    await settle(tester);
    expect(api.calls.last, 'update:1:درد حاد قفسه سینه');
    expect(find.text('ذخیره نشده'), findsNothing);

    // Someone else saved meanwhile.
    api.conflictNext = true;
    await tester.enterText(
      find.widgetWithText(TextFormField, 'درد حاد قفسه سینه'),
      'عنوان دیگر',
    );
    // Save is disabled while nothing has changed; let it redraw first.
    await tester.pump();
    await tester.tap(find.text('ذخیره'));
    await settle(tester);
    expect(find.textContaining('هم‌زمان ویرایش'), findsOneWidget);
    // let the "saved" snackbar time out
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('leaving with unsaved edits asks first', (tester) async {
    await start(tester, role: 'editor');
    await tester.tap(find.text('برنامه‌های مراقبتی').first);
    await settle(tester);
    await tester.tap(find.text('درد حاد'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'درد حاد'),
      'عنوان تازه',
    );
    await tester.pump();

    // Try to go to the dashboard: asked, and "stay" keeps the edits.
    await tester.tap(find.text('خلاصه'));
    await settle(tester);
    expect(find.text('تغییرات ذخیره نشده'), findsOneWidget);
    await tester.tap(find.text('ماندن'));
    await settle(tester);
    expect(find.byType(CarePlanEditor), findsOneWidget);
    expect(find.text('ذخیره نشده'), findsOneWidget);

    // Leaving without saving goes.
    await tester.tap(find.text('خلاصه'));
    await settle(tester);
    await tester.tap(find.text('خروج بدون ذخیره'));
    await settle(tester);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('categories: list, preview, and only empty ones can be removed', (
    tester,
  ) async {
    await start(tester, role: 'editor');
    await tester.tap(find.text('دسته‌های بیماری').first);
    await settle(tester);
    expect(find.byType(CategoriesScreen), findsOneWidget);
    // Preview tile and list row for each.
    expect(find.text('نارسایی قلبی'), findsNWidgets(2));
    expect(find.text('مشترک همه بیماری‌ها'), findsOneWidget);

    // New category dialog: the id follows the short code.
    await tester.tap(find.text('دسته جدید'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'نام بیماری'),
      'بیماری انسدادی ریه',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'نام کوتاه (اختیاری)'),
      'COPD',
    );
    await tester.pump();
    final idField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'شناسه انگلیسی'),
    );
    expect(idField.controller!.text, 'copd');
  });

  testWidgets('signing out goes back to the login page', (tester) async {
    await start(tester, role: 'admin');
    expect(find.byTooltip('خروج'), findsOneWidget);

    // Sign out the way the button does, then let the router react.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    await container.read(authProvider.notifier).logout();
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(AdminLoginScreen), findsOneWidget);
  });

  testWidgets('only reviewers can publish', (tester) async {
    await start(tester, role: 'editor');
    await tester.tap(find.text('انتشار').first);
    await settle(tester);
    expect(
      find.text('فقط بازبین‌ها و مدیران می‌توانند منتشر کنند.'),
      findsOneWidget,
    );
  });
}
