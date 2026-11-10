import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/common/widgets/not_found_screen.dart';
import 'package:ava_web/core/kind_style.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/features/about/about_us.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/features/care_plans/screens/care_plan_screen.dart';
import 'package:ava_web/features/care_plans/screens/diagnosis_screen.dart';
import 'package:ava_web/features/care_plans/screens/diagnosis_tabs.dart';
import 'package:ava_web/features/care_plans/screens/favorites_screen.dart';
import 'package:ava_web/features/gordon_assessment/screens/disease_kind_selection_screen.dart';
import 'package:ava_web/features/gordon_assessment/assessment_selection.dart';
import 'package:ava_web/features/gordon_assessment/screens/gordon_assessment_page.dart';
import 'package:ava_web/features/gordon_assessment/screens/matched_gordon_careplans_screen.dart';
import 'package:ava_web/features/home/home_screen.dart';
import 'package:ava_web/features/quiz/screens/quiz_list_screen.dart';
import 'package:ava_web/features/quiz/models/quiz.dart';
import 'package:ava_web/features/quiz/quiz_attempt.dart';
import 'package:ava_web/features/quiz/quiz_mistakes.dart';
import 'package:ava_web/features/quiz/screens/quiz_screen.dart';
import 'package:ava_web/features/quiz/screens/result_screen.dart';
import 'package:ava_web/features/quiz/screens/review_answer_screen.dart';
import 'package:ava_web/app/app_shell.dart';
import 'package:ava_web/features/account/screens/account_screen.dart';
import 'package:ava_web/features/account/screens/login_screen.dart';
import 'package:ava_web/features/account/session.dart';
import 'package:ava_web/features/account/user_data_controller.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const carePlans = '/care-plans';
  static String carePlansOfKind(Kind kind) => '/care-plans/kind/${kind.name}';
  static String carePlan(String id) => '/care-plans/$id';
  static const favorites = '/favorites';
  static const quizzes = '/quizzes';
  static String quiz(String id) => '/quizzes/$id';
  static String quizResult(String id) => '/quizzes/$id/result';
  static String quizReview(String id) => '/quizzes/$id/review';
  static String get quizMistakes => quiz(mistakesQuizId);
  static const assessment = '/assessment';
  static String assessmentFor(Kind kind) => '/assessment/${kind.name}';
  static String assessmentResults(Kind kind) =>
      '/assessment/${kind.name}/results';
  static const about = '/about';
  static const account = '/account';
  static const login = '/login';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Full-screen pages go on the root navigator, above the tab shell.
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  // Re-run the redirect when the user signs in or out.
  final authChanges = ValueNotifier<int>(0);
  ref.listen(
    authProvider.select((s) => s?.token),
    (_, _) => authChanges.value++,
  );
  ref.onDispose(authChanges.dispose);

  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: AppRoutes.home,
    refreshListenable: authChanges,
    redirect: (context, state) {
      final signedIn = ref.read(authProvider) != null;
      final atLogin = state.matchedLocation == AppRoutes.login;
      if (!signedIn && !atLogin) {
        final from = state.uri.toString();
        return from == AppRoutes.home
            ? AppRoutes.login
            : '${AppRoutes.login}?from=${Uri.encodeComponent(from)}';
      }
      if (signedIn && atLogin) {
        final from = state.uri.queryParameters['from'];
        return from != null && from.startsWith('/') && !from.startsWith('//')
            ? from
            : AppRoutes.home;
      }
      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.account,
        builder: (context, state) => const AccountScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.carePlans,
                builder: (context, state) => const DiagnosisTabs(),
                routes: [
                  GoRoute(
                    path: 'kind/:kind',
                    builder: (context, state) =>
                        _KindPlansPage(kindName: state.pathParameters['kind']!),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) =>
                        _CarePlanPage(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.quizzes,
                builder: (context, state) => const _QuizListPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) =>
                        _QuizPage(id: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'result',
                        parentNavigatorKey: rootKey,
                        redirect: (context, state) =>
                            _requireAttempt(ref, state.pathParameters['id']!),
                        builder: (context, state) =>
                            _QuizResultPage(id: state.pathParameters['id']!),
                      ),
                      GoRoute(
                        path: 'review',
                        parentNavigatorKey: rootKey,
                        redirect: (context, state) =>
                            _requireAttempt(ref, state.pathParameters['id']!),
                        builder: (context, state) => _QuizResultPage(
                          id: state.pathParameters['id']!,
                          review: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.favorites,
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.assessment,
        builder: (context, state) => const DiseaseKindSelectionScreen(),
        routes: [
          GoRoute(
            path: ':kind',
            builder: (context, state) {
              final kind = ref
                  .read(contentRepositoryProvider)
                  .kindById(state.pathParameters['kind']!);
              return kind == null
                  ? const NotFoundScreen()
                  : GordonAssessmentPage(selectedKind: kind);
            },
            routes: [
              GoRoute(
                path: 'results',
                redirect: (context, state) {
                  final kind = state.pathParameters['kind']!;
                  final last = ref.read(lastAssessmentProvider);
                  return last?.kind.name == kind ? null : '/assessment/$kind';
                },
                builder: (context, state) => const _AssessmentResultsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutUS(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

String? _requireAttempt(Ref ref, String id) {
  final attempt = ref.read(lastQuizAttemptProvider);
  return attempt?.quizId == id ? null : AppRoutes.quiz(id);
}

class _KindPlansPage extends ConsumerWidget {
  const _KindPlansPage({required this.kindName});
  final String kindName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(kindByIdProvider(kindName));
    if (kind == null) return const NotFoundScreen();
    return DiagnosisScreen(
      title: kindLabel(kind),
      carePlans: ref.watch(carePlansOfKindProvider(kind)),
      color: context.kindTone(kind),
      icon: kindIcon(kind),
    );
  }
}

class _CarePlanPage extends ConsumerStatefulWidget {
  const _CarePlanPage({required this.id});
  final String id;

  @override
  ConsumerState<_CarePlanPage> createState() => _CarePlanPageState();
}

class _CarePlanPageState extends ConsumerState<_CarePlanPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(carePlanByIdProvider(widget.id)) != null) {
        ref.read(userDataProvider.notifier).recordView(widget.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(carePlanByIdProvider(widget.id));
    return plan == null
        ? const NotFoundScreen()
        : CarePlanScreen(carePlan: plan);
  }
}

class _QuizListPage extends ConsumerWidget {
  const _QuizListPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      QuizListScreen(quizzes: ref.watch(quizzesProvider));
}

class _QuizPage extends ConsumerStatefulWidget {
  const _QuizPage({required this.id});
  final String id;

  @override
  ConsumerState<_QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<_QuizPage> {
  late final Quiz? _quiz =
      (widget.id == mistakesQuizId
              ? ref.read(mistakesQuizProvider)
              : ref.read(quizByIdProvider(widget.id)))
          ?.shuffled();

  @override
  Widget build(BuildContext context) {
    final quiz = _quiz;
    return quiz == null ? const NotFoundScreen() : QuizScreen(quiz: quiz);
  }
}

class _QuizResultPage extends ConsumerWidget {
  const _QuizResultPage({required this.id, this.review = false});
  final String id;
  final bool review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attempt = ref.watch(lastQuizAttemptProvider);
    if (attempt == null || attempt.quizId != id) {
      return const NotFoundScreen();
    }
    return review
        ? ReviewAnswersScreen(attempt: attempt)
        : ResultScreen(attempt: attempt);
  }
}

class _AssessmentResultsPage extends ConsumerWidget {
  const _AssessmentResultsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(lastAssessmentProvider);
    if (selection == null) return const NotFoundScreen();
    return MatchedGordonCarePlansScreen(
      selectedItems: selection.items,
      selectedKind: selection.kind,
    );
  }
}
