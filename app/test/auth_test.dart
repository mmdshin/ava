import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ava_web/app/router.dart';
import 'package:ava_web/data/content_repository.dart';
import 'package:ava_web/features/account/screens/account_screen.dart';
import 'package:ava_web/features/account/screens/login_screen.dart';
import 'package:ava_web/features/account/session.dart';
import 'package:ava_web/features/care_plans/screens/care_plan_screen.dart';
import 'package:ava_web/features/home/home_screen.dart';

import 'helpers.dart';

void main() {
  late ContentRepository content;
  setUpAll(() async => content = await loadTestContent());

  Future<FakeAvaApi> start(WidgetTester tester, {required bool signedIn}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeAvaApi();
    final prefs = await mockPrefs(const {}, signedIn);
    await tester.pumpWidget(testApp(prefs, content, api: api));
    await settle(tester);
    return api;
  }

  Future<void> goTo(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(Navigator).first)).go(location);
    await settle(tester);
  }

  Future<void> signIn(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byKey(const ValueKey('email')), email);
    await tester.enterText(find.byKey(const ValueKey('password')), password);
    await tester.tap(find.widgetWithText(FilledButton, 'ورود'));
    await settle(tester);
  }

  testWidgets('signed out → login; signing in opens the app', (tester) async {
    await start(tester, signedIn: false);
    expect(find.byType(LoginScreen), findsOneWidget);

    await signIn(tester, FakeAvaApi.testEmail, 'wrong-password');
    expect(find.text('ایمیل یا رمز عبور اشتباه است.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);

    await signIn(tester, FakeAvaApi.testEmail, FakeAvaApi.testPassword);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a deep link survives signing in', (tester) async {
    await start(tester, signedIn: false);
    final plan = content.carePlans.first;
    await goTo(tester, AppRoutes.carePlan(plan.id));
    expect(find.byType(LoginScreen), findsOneWidget);

    await signIn(tester, FakeAvaApi.testEmail, FakeAvaApi.testPassword);
    expect(find.byType(CarePlanScreen), findsOneWidget);
  });

  testWidgets('create an account', (tester) async {
    await start(tester, signedIn: false);
    await tester.tap(find.text('حساب ندارید؟ ثبت‌نام کنید'));
    await settle(tester);

    await tester.enterText(find.byKey(const ValueKey('email')), 'new@example.ir');
    await tester.enterText(find.byKey(const ValueKey('password')), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'ساخت حساب'));
    await settle(tester);
    expect(find.text('رمز عبور باید حداقل 8 نویسه باشد'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('password')), 'long-enough-1');
    await tester.tap(find.widgetWithText(FilledButton, 'ساخت حساب'));
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('sign out from the account page', (tester) async {
    final api = await start(tester, signedIn: true);
    await goTo(tester, AppRoutes.account);
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text(FakeAvaApi.testUser.displayName), findsOneWidget);

    await tester.tap(find.text('خروج از حساب'));
    await settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(api.calls, contains('logout'));
  });

  testWidgets('an expired session sends you to login', (tester) async {
    await start(tester, signedIn: true);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    container.read(authProvider.notifier).expired();
    await settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
