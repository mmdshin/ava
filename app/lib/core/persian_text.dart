/// Text normalization for searching Persian content.
///
/// The same word can be typed several ways that look identical on
/// screen but are different characters, so a plain `contains()` misses
/// matches:
///   - Arabic Yeh/Kaf (ي ك, from Arabic keyboards and some sources) vs.
///     Persian Yeh/Kaf (ی ک)
///   - ZWNJ (half-space, "می‌شود") vs. a normal space ("می شود") vs.
///     no space at all
///   - optional diacritics (fatha, kasra, tanwin, shadda …) and tatweel
///   - hamza forms (أ إ آ ؤ ة) that people often type without the hamza
///   - Persian/Arabic digits vs. Latin digits
///
/// [normalizeForSearch] maps all of these to one canonical form. Run it
/// on both the query and the content before comparing.
String normalizeForSearch(String input) => _normalize(input, null);

({int start, int end})? findMatchRange(String text, String query) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return null;
  final origin = <int>[];
  final t = _normalize(text, origin);
  final i = t.indexOf(q);
  if (i < 0) return null;
  final last = i + q.length - 1;
  final lastOrigin = origin[last];
  final lastLen =
      text.codeUnitAt(lastOrigin) >= 0xD800 &&
          text.codeUnitAt(lastOrigin) <= 0xDBFF
      ? 2
      : 1;
  return (start: origin[i], end: lastOrigin + lastLen);
}

String _normalize(String input, List<int>? origin) {
  final buffer = StringBuffer();
  var lastWasSpace = true;
  var offset = 0;

  void write(int ch, int from) {
    buffer.writeCharCode(ch);
    if (origin != null) {
      origin.add(from);
      if (ch > 0xFFFF) origin.add(from);
    }
  }

  for (final rune in input.runes) {
    final from = offset;
    offset += rune > 0xFFFF ? 2 : 1;

    final lower = rune < 0x80 && rune >= 0x41 && rune <= 0x5A
        ? rune + 0x20
        : rune;
    final mapped = _charMap[lower];
    if (mapped == _drop) continue;
    final ch = mapped ?? lower;

    if (_isSpace(ch)) {
      if (!lastWasSpace) write(0x20, from);
      lastWasSpace = true;
      continue;
    }
    write(ch, from);
    lastWasSpace = false;
  }

  var out = buffer.toString();
  if (out.endsWith(' ')) {
    out = out.substring(0, out.length - 1);
    origin?.removeLast();
  }
  return out;
}

/// Same as [normalizeForSearch] but also removes every space, so
/// "میشود", "می شود" and "می‌شود" all match each other.
String compactForSearch(String input) =>
    normalizeForSearch(input).replaceAll(' ', '');

/// Whether [text] contains [query] after normalization. Matches if the
/// spaced or the space-insensitive form matches.
bool searchMatches(String text, String query) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return true;
  final t = normalizeForSearch(text);
  if (t.contains(q)) return true;
  return compactForSearch(t).contains(compactForSearch(q));
}

const int _drop = -1;

bool _isSpace(int ch) =>
    ch == 0x20 || ch == 0x09 || ch == 0x0A || ch == 0x0D || ch == 0xA0;

final Map<int, int> _charMap = {
  // Arabic → Persian letters
  0x064A: 0x06CC, // ي → ی
  0x0649: 0x06CC, // ى → ی
  0x0643: 0x06A9, // ك → ک
  0x0629: 0x0647, // ة → ه
  0x0623: 0x0627, // أ → ا
  0x0625: 0x0627, // إ → ا
  0x0622: 0x0627, // آ → ا
  0x0671: 0x0627, // ٱ → ا
  0x0624: 0x0648, // ؤ → و
  0x0626: 0x06CC, // ئ → ی
  // ZWNJ / ZWJ / other invisible joiners → space
  0x200C: 0x20,
  0x200D: _drop,
  0x200E: _drop, // LRM
  0x200F: _drop, // RLM
  0xFEFF: _drop,
  // tatweel and diacritics (harakat) → removed
  0x0640: _drop,
  for (var c = 0x064B; c <= 0x0652; c++) c: _drop,
  0x0670: _drop,
  // Persian (۰-۹) and Arabic-Indic (٠-٩) digits → Latin
  for (var i = 0; i < 10; i++) 0x06F0 + i: 0x30 + i,
  for (var i = 0; i < 10; i++) 0x0660 + i: 0x30 + i,
};
