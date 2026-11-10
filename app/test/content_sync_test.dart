import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ava_web/core/jalali.dart';
import 'package:ava_web/data/content_repository.dart';
import 'package:ava_web/data/content_updater.dart';
import 'package:ava_web/data/content_validation.dart';

import 'helpers.dart';

/// The sample content as a server bundle with [version].
Map<String, dynamic> bundleJson({int version = 2, int schema = ContentRepository.supportedSchemaVersion}) =>
    sampleBundle()
      ..['version'] = version
      ..['schemaVersion'] = schema;

/// A fake content server.
MockClient fakeServer(Map<String, dynamic> bundle, {List<String>? log}) =>
    MockClient((request) async {
      log?.add(request.url.path);
      return switch (request.url.path) {
        '/v1/content/manifest' => http.Response(
          jsonEncode({
            'version': bundle['version'],
            'schemaVersion': bundle['schemaVersion'],
          }),
          200,
        ),
        '/v1/content/bundle' => http.Response.bytes(
          utf8.encode(jsonEncode(bundle)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
        _ => http.Response('not found', 404),
      };
    });

ContentUpdater updater(SharedPreferences prefs, http.Client client) =>
    ContentUpdater(baseUrl: 'https://api.test', prefs: prefs, client: client);

void main() {
  group('content validation (shared with the backend)', () {
    test('sample content: no errors, no warnings', () async {
      final repo = await loadTestContent();
      final issues = validateContent(
        categories: repo.categories,
        carePlans: repo.carePlans,
        quizzes: repo.quizzes,
        gordonDomains: repo.gordonDomains,
      );
      expect(issues.errors, isEmpty);
      expect(issues.warnings, isEmpty);
    });

    test('a broken answer key is an error', () {
      final json = bundleJson();
      ((json['quizzes'] as List).first['questions'] as List).first['correctIndex'] = 9;
      expect(
        () => ContentBundle.parseChecked(jsonEncode(json)),
        throwsFormatException,
      );
    });

    test('content without categories (schema 1) is refused', () {
      final json = bundleJson(schema: 1)..remove('categories');
      expect(() => ContentBundle.parseChecked(jsonEncode(json)), throwsFormatException);
    });

    test('a plan in an unknown category is refused', () {
      final json = bundleJson();
      (json['carePlans'] as List).first['kind'] = 'copd';
      expect(() => ContentBundle.parseChecked(jsonEncode(json)), throwsFormatException);
    });

    test('categories come in content order, with their colors', () {
      final json = bundleJson();
      final cats = json['categories'] as List;
      cats.insert(0, cats.removeAt(3)); // move "mi" first
      (cats.first as Map)['color'] = '#123456';
      final bundle = ContentBundle.parseChecked(jsonEncode(json));
      expect(bundle.categories.first.id, 'mi');
      expect(bundle.categories.first.color.toARGB32(), 0xFF123456);
    });

    test('a newer schema is refused', () {
      expect(
        () => ContentBundle.parseChecked(jsonEncode(bundleJson(schema: 99))),
        throwsFormatException,
      );
    });

    test('no real content in the app repo', () {
      // Content comes from the server; only the made-up sample is here.
      expect(Directory('assets/data').existsSync(), isFalse);
      expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('assets/data')));
      // Nor hidden in another file under assets/ (e.g. a zip of it).
      final suspicious = [
        for (final f in Directory('assets').listSync(recursive: true))
          if (f is File && RegExp(r'\.(json|zip|7z|rar|gz)$').hasMatch(f.path)) f.path,
      ];
      expect(suspicious, isEmpty, reason: 'keep content out of the repository');
    });
  });

  group('first start', () {
    test('downloads the content and keeps it for next time', () async {
      final prefs = await mockPrefs();
      expect(ContentRepository.fromCache(prefs), isNull);

      final repo = await updater(prefs, fakeServer(bundleJson(version: 3)))
          .downloadLatest();
      expect(repo.meta.version, 3);
      expect(ContentRepository.fromCache(prefs)?.meta.version, 3);
    });

    test('offline → ContentUnavailable (retry possible)', () async {
      final prefs = await mockPrefs();
      final offline = MockClient((_) async => throw const SocketException('offline'));
      await expectLater(
        updater(prefs, offline).downloadLatest(),
        throwsA(isA<ContentUnavailable>().having((e) => e.needsAppUpdate, 'needsAppUpdate', false)),
      );
    });

    test('content for a newer app → needsAppUpdate', () async {
      final prefs = await mockPrefs();
      await expectLater(
        updater(prefs, fakeServer(bundleJson(schema: ContentRepository.supportedSchemaVersion + 1))).downloadLatest(),
        throwsA(isA<ContentUnavailable>().having((e) => e.needsAppUpdate, 'needsAppUpdate', true)),
      );
      expect(ContentRepository.fromCache(prefs), isNull);
    });
  });

  group('background update', () {
    test('downloads a newer version for the next start', () async {
      final prefs = await mockPrefs();
      final calls = <String>[];
      final u = updater(prefs, fakeServer(bundleJson(version: 2), log: calls));

      expect(await u.check(1), UpdateResult.downloaded);
      expect(calls, ['/v1/content/manifest', '/v1/content/bundle']);
      expect(ContentRepository.fromCache(prefs)?.meta.version, 2);

      // Up to date: only the tiny manifest is fetched.
      calls.clear();
      expect(await u.check(2), UpdateResult.upToDate);
      expect(calls, ['/v1/content/manifest']);
    });

    test('invalid or unreachable content leaves the saved copy alone', () async {
      final prefs = await mockPrefs({
        ContentRepository.cacheKey: jsonEncode(bundleJson(version: 1)),
      });
      final broken = bundleJson(version: 2);
      ((broken['carePlans'] as List).first as Map)['tags'] = <String>[];

      expect(await updater(prefs, fakeServer(broken)).check(1), UpdateResult.failed);
      expect(
        await updater(prefs, MockClient((_) async => throw const SocketException('x'))).check(1),
        UpdateResult.failed,
      );
      expect(ContentRepository.fromCache(prefs)?.meta.version, 1);
    });

    test('corrupt saved content is ignored', () async {
      final prefs = await mockPrefs({ContentRepository.cacheKey: '{not json'});
      expect(ContentRepository.fromCache(prefs), isNull);
    });
  });

  group('Jalali dates', () {
    test('known dates', () {
      expect(toJalali(DateTime(2026, 3, 21)), (1405, 1, 1));
      expect(toJalali(DateTime(2026, 3, 20)), (1404, 12, 29));
      expect(toJalali(DateTime(2024, 3, 20)), (1403, 1, 1));
      expect(toJalali(DateTime(2026, 10, 23)), (1405, 8, 1));
    });

    test('formatted in Iran time', () {
      // 22:00 UTC on Oct 22 is already Oct 23 (01:30) in Tehran.
      expect(formatJalali(DateTime.utc(2026, 10, 22, 22)), '1405/08/01');
    });
  });
}
