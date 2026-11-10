import 'package:flutter_test/flutter_test.dart';
import 'package:ava_web/core/persian_text.dart';

void main() {
  group('normalizeForSearch', () {
    test('maps Arabic yeh/kaf to Persian', () {
      expect(normalizeForSearch('كيفيت'), normalizeForSearch('کیفیت'));
    });

    test('treats ZWNJ like a space and collapses whitespace', () {
      expect(normalizeForSearch('می‌شود'), 'می شود');
      expect(normalizeForSearch('  می   شود  '), 'می شود');
    });

    test('drops diacritics and tatweel', () {
      expect(normalizeForSearch('دَرد'), 'درد');
      expect(normalizeForSearch('درــد'), 'درد');
    });

    test('maps Persian and Arabic digits to Latin', () {
      expect(normalizeForSearch('۱۲۳'), '123');
      expect(normalizeForSearch('٤٥'), '45');
    });

    test('lowercases Latin text', () {
      expect(normalizeForSearch('ACS'), 'acs');
    });
  });

  group('searchMatches', () {
    test('matches across yeh/kaf variants', () {
      expect(searchMatches('خطر کاهش پرفیوژن بافت قلب', 'كاهش'), isTrue);
    });

    test('matches regardless of space / half-space / no space', () {
      const text = 'مشخص می شود با';
      expect(searchMatches(text, 'می‌شود'), isTrue);
      expect(searchMatches(text, 'میشود'), isTrue);
    });

    test('empty query matches everything', () {
      expect(searchMatches('درد حاد', '   '), isTrue);
    });

    test('non-matching query', () {
      expect(searchMatches('درد حاد', 'عفونت'), isFalse);
    });
  });

  group('findMatchRange', () {
    test('returns the range in the original text', () {
      const text = 'خطر کاهش پرفیوژن';
      final r = findMatchRange(text, 'كاهش')!;
      expect(text.substring(r.start, r.end), 'کاهش');
    });

    test('maps across a half-space in the original text', () {
      const text = 'اقدامات می‌شود';
      final r = findMatchRange(text, 'می شود')!;
      expect(text.substring(r.start, r.end), 'می‌شود');
    });

    test('maps across dropped diacritics', () {
      const text = 'دَرد حاد';
      final r = findMatchRange(text, 'درد')!;
      expect(text.substring(r.start, r.end), 'دَرد');
    });

    test('null when there is no match', () {
      expect(findMatchRange('درد حاد', 'عفونت'), isNull);
    });
  });
}
