import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ava_web/app/app.dart';
import 'package:ava_web/core/providers.dart';
import 'package:ava_web/data/api_client.dart';
import 'package:ava_web/data/content_repository.dart';
import 'package:ava_web/features/account/session.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';

import 'fake_api.dart';

export 'fake_api.dart';

/// The made-up sample content (test/fixtures/sample_bundle.json, the
/// same file the backend uses). Real content is never in the repo.
const sampleBundlePath = 'test/fixtures/sample_bundle.json';

String sampleBundleJson() => File(sampleBundlePath).readAsStringSync();

Map<String, dynamic> sampleBundle() =>
    jsonDecode(sampleBundleJson()) as Map<String, dynamic>;

ContentRepository? _content;

/// The sample content, loaded once per test file.
Future<ContentRepository> loadTestContent() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  return _content ??= ContentRepository(
    ContentBundle.parseChecked(sampleBundleJson()),
  );
}

/// Fresh in-memory SharedPreferences, signed in as the test user unless
/// [signedIn] is false.
Future<SharedPreferences> mockPrefs([
  Map<String, Object> values = const {},
  bool signedIn = true,
]) {
  SharedPreferences.setMockInitialValues({
    if (signedIn)
      AuthNotifier.prefsKey: jsonEncode(FakeAvaApi.testSession.toJson()),
    ...values,
  });
  return SharedPreferences.getInstance();
}

List<Object> _overrides(
  SharedPreferences prefs,
  ContentRepository content,
  AvaApi api,
) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  contentRepositoryProvider.overrideWithValue(content),
  apiProvider.overrideWithValue(api),
];

/// A ProviderContainer for logic tests (no widgets), disposed after the test.
ProviderContainer makeContainer(
  SharedPreferences prefs,
  ContentRepository content, {
  AvaApi? api,
}) {
  final container = ProviderContainer(
    overrides: _overrides(prefs, content, api ?? FakeAvaApi()).cast(),
  );
  addTearDown(container.dispose);
  return container;
}

/// The whole app, wired like main() but with test dependencies.
Widget testApp(
  SharedPreferences prefs,
  ContentRepository content, {
  AvaApi? api,
}) => ProviderScope(
  overrides: _overrides(prefs, content, api ?? FakeAvaApi()).cast(),
  child: const AvaApp(),
);

/// Like `pumpAndSettle`, but also waits out flutter_animate's staggered
/// start delays (`.animate(interval: ...)`, `delay: ...`). Those are
/// plain timers with no frames scheduled while they wait, so
/// `pumpAndSettle` alone returns early and the test ends with
/// "A Timer is still pending".
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

/// The sample content's categories (equal to the loaded ones: a [Kind]
/// is identified by its id).
abstract final class TestKinds {
  static const acs = Kind(id: 'acs', title: 'سندرم کرونری حاد', abbr: 'ACS', color: Color(0xFF17A398));
  static const chf = Kind(id: 'chf', title: 'نارسایی قلبی', abbr: 'CHF', color: Color(0xFF3D8BFF));
  static const mi = Kind(id: 'mi', title: 'انفارکتوس میوکارد', abbr: 'MI', color: Color(0xFFF2A93E));
  static const general = Kind(id: 'general', title: 'عمومی', color: Color(0xFFEF5875));
}
