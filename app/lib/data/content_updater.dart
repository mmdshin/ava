import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ava_web/data/content_repository.dart';

enum UpdateResult {
  /// The device already has the latest content.
  upToDate,

  /// Newer content was downloaded and saved.
  downloaded,

  /// The server has content this app version can't read.
  needsAppUpdate,

  /// No connection, server error, or invalid content.
  failed,
}

class ContentUnavailable implements Exception {
  const ContentUnavailable({required this.needsAppUpdate, this.cause});

  final bool needsAppUpdate;
  final Object? cause;

  @override
  String toString() =>
      'ContentUnavailable(needsAppUpdate: $needsAppUpdate, $cause)';
}

/// Downloads content from the server.
class ContentUpdater {
  ContentUpdater({
    required this.baseUrl,
    required this.prefs,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final SharedPreferences prefs;
  final Duration timeout;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<({int version, int schema})> _manifest() async {
    final res = await _client
        .get(_uri('/v1/content/manifest'))
        .timeout(timeout);
    if (res.statusCode != 200) {
      throw http.ClientException('manifest: HTTP ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      version: json['version'] as int,
      schema: json['schemaVersion'] as int,
    );
  }

  /// Downloads, checks and saves [version]; returns the repository.
  Future<ContentRepository> _download(int version) async {
    final res = await _client
        .get(_uri('/v1/content/bundle', {'version': '$version'}))
        .timeout(timeout * 4);
    if (res.statusCode != 200) {
      throw http.ClientException('bundle: HTTP ${res.statusCode}');
    }
    final raw = utf8.decode(res.bodyBytes);
    final bundle = ContentBundle.parseChecked(raw);
    if (bundle.meta.version != version) {
      throw const FormatException('the server sent another version');
    }
    await prefs.setString(ContentRepository.cacheKey, raw);
    return ContentRepository(bundle);
  }

  /// First start: get the latest content.
  Future<ContentRepository> downloadLatest() async {
    final ({int version, int schema}) manifest;
    try {
      manifest = await _manifest();
    } catch (e) {
      throw ContentUnavailable(needsAppUpdate: false, cause: e);
    }
    if (manifest.schema > ContentRepository.supportedSchemaVersion) {
      throw const ContentUnavailable(needsAppUpdate: true);
    }
    try {
      return await _download(manifest.version);
    } catch (e) {
      throw ContentUnavailable(needsAppUpdate: false, cause: e);
    }
  }

  /// Later starts: fetch a newer version in the background, if any.
  Future<UpdateResult> check(int currentVersion) async {
    try {
      final manifest = await _manifest();
      if (manifest.version <= currentVersion) return UpdateResult.upToDate;
      if (manifest.schema > ContentRepository.supportedSchemaVersion) {
        return UpdateResult.needsAppUpdate;
      }
      await _download(manifest.version);
      return UpdateResult.downloaded;
    } catch (e) {
      debugPrint('Content update failed: $e');
      return UpdateResult.failed;
    }
  }

  void close() => _client.close();
}
