import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/admin/admin_theme.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/screens/assessment_screen.dart';
import 'package:ava_web/admin/screens/categories_screen.dart';
import 'package:ava_web/admin/screens/care_plan_editor.dart';
import 'package:ava_web/admin/screens/care_plans_screen.dart';
import 'package:ava_web/admin/screens/dashboard_screen.dart';
import 'package:ava_web/admin/screens/history_screen.dart';
import 'package:ava_web/admin/screens/login_screen.dart';
import 'package:ava_web/admin/screens/publish_screen.dart';
import 'package:ava_web/admin/screens/quiz_editor.dart';
import 'package:ava_web/admin/screens/quizzes_screen.dart';
import 'package:ava_web/admin/screens/settings_screen.dart';
import 'package:ava_web/admin/screens/tags_screen.dart';
import 'package:ava_web/admin/screens/users_screen.dart';
import 'package:ava_web/admin/widgets/admin_shell.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/theme_controller.dart';
import 'package:ava_web/features/account/session.dart';

/// Admin panel routes. Everything needs a signed-in editor, reviewer
/// or admin; others are sent to /login (or see "no access" there).
abstract final class AdminRoutes {
  static const login = '/login';
  static const dashboard = '/';
  static const categories = '/categories';
  static const carePlans = '/care-plans';
  static const newCarePlan = '/care-plans/new';
  static String carePlan(String id) => '/care-plans/$id';
  static const quizzes = '/quizzes';
  static String quiz(String id) => '/quizzes/$id';
  static const assessment = '/assessment';
  static const tags = '/tags';
  static const publish = '/publish';
  static const history = '/history';
  static const users = '/users';
  static const settings = '/settings';
}

final adminRouterProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect when the user signs in or out, or their role
  // changes.
  final changes = ValueNotifier<int>(0);
  ref.listen(
    authProvider.select((s) => (s?.token, s?.user.role)),
    (_, _) => changes.value++,
  );
  ref.onDispose(changes.dispose);

  final router = GoRouter(
    initialLocation: AdminRoutes.dashboard,
    refreshListenable: changes,
    redirect: (context, state) {
      // Read the session itself, not roleProvider: this runs while
      // authProvider is still notifying, before derived providers like
      // roleProvider have caught up, so they can still hold the old role.
      final role = ref.read(authProvider)?.user.role ?? '';
      final allowed = hasRole(role, 'editor');
      final atLogin = state.matchedLocation == AdminRoutes.login;
      if (!allowed && !atLogin) return AdminRoutes.login;
      if (allowed && atLogin) return AdminRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: AdminRoutes.login, builder: (_, _) => const AdminLoginScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: AdminRoutes.dashboard, builder: (_, _) => const DashboardScreen()),
          GoRoute(
            path: AdminRoutes.carePlans,
            builder: (_, _) => const CarePlansScreen(),
            routes: [
              GoRoute(
                path: 'new',
                onExit: (context, _) => confirmLeave(context),
                builder: (_, state) => CarePlanEditor(
                  id: null,
                  initialKind: state.uri.queryParameters['kind'],
                ),
              ),
              GoRoute(
                path: ':id',
                onExit: (context, _) => confirmLeave(context),
                // A new key per plan, so going from one plan to another
                // starts a fresh editor.
                builder: (_, state) => CarePlanEditor(
                  key: ValueKey(state.pathParameters['id']),
                  id: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: AdminRoutes.quizzes,
            builder: (_, _) => const QuizzesScreen(),
            routes: [
              GoRoute(path: ':id', builder: (_, state) => QuizEditor(id: state.pathParameters['id']!)),
            ],
          ),
          GoRoute(path: AdminRoutes.categories, builder: (_, _) => const CategoriesScreen()),
          GoRoute(path: AdminRoutes.assessment, builder: (_, _) => const AssessmentScreen()),
          GoRoute(path: AdminRoutes.tags, builder: (_, _) => const TagsScreen()),
          GoRoute(path: AdminRoutes.publish, builder: (_, _) => const PublishScreen()),
          GoRoute(path: AdminRoutes.history, builder: (_, _) => const HistoryScreen()),
          GoRoute(path: AdminRoutes.users, builder: (_, _) => const UsersScreen()),
          GoRoute(path: AdminRoutes.settings, builder: (_, _) => const SettingsScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'مدیریت آوا',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: adminTheme(AppTheme.light(theme.seed)),
      darkTheme: adminTheme(AppTheme.dark(theme.seed)),
      themeMode: theme.mode,
      routerConfig: ref.watch(adminRouterProvider),
    );
  }
}
