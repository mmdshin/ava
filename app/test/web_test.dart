import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks the installable web app (PWA) files in web/.
void main() {
  final manifest =
      jsonDecode(File('web/manifest.json').readAsStringSync())
          as Map<String, dynamic>;

  test('manifest describes an installable Persian app', () {
    expect(manifest['name'], isNotEmpty);
    expect(manifest['short_name'], isNotEmpty);
    expect(manifest['lang'], 'fa');
    expect(manifest['dir'], 'rtl');
    expect(manifest['display'], 'standalone');
    expect(manifest['start_url'], isNotEmpty);
  });

  test('every icon in the manifest exists, incl. 192, 512 and maskable', () {
    final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();
    for (final icon in icons) {
      expect(File('web/${icon['src']}').existsSync(), isTrue,
          reason: 'missing web/${icon['src']}');
    }
    final sizes = icons.map((i) => i['sizes']).toSet();
    expect(sizes, containsAll(['192x192', '512x512']));
    expect(icons.any((i) => i['purpose'] == 'maskable'), isTrue);
  });

  test('the offline worker is registered by the bootstrap', () {
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap, contains("register('ava_sw.js')"));
    expect(bootstrap, contains('{{flutter_js}}'));
    expect(bootstrap, contains('{{flutter_build_config}}'));
    expect(File('web/ava_sw.js').existsSync(), isTrue);
  });
}
