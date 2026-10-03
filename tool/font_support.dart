/// What `tool/fonts.dart` and `test/ui/fonts_test.dart` share: finding the
/// characters the game writes, and the characters a font file has.
library;

import 'dart:io';
import 'dart:typed_data';

/// The code points of every character in the string literals of the Dart
/// files under [dir], including `\u` escapes and the strings inside `${}`.
///
/// Comments are not read, so that a note such as `// 1. パフェ` does not put
/// its characters into the font. Everything else a Dart file writes as text
/// is a string literal.
Set<int> stringLiteralCodePoints(Directory dir) {
  final found = <int>{};
  for (final file in dir.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    _Scanner(file.readAsStringSync().runes.toList(), found).code(0);
  }
  return found;
}

/// Reads Dart source: skips the code and the comments, and collects the
/// characters of the strings into [found].
class _Scanner {
  _Scanner(this._src, this._found);

  final List<int> _src;
  final Set<int> _found;

  static const _slash = 0x2F, _star = 0x2A, _backslash = 0x5C;
  static const _dollar = 0x24, _openBrace = 0x7B, _closeBrace = 0x7D;
  static const _single = 0x27, _double = 0x22, _newline = 0x0A, _r = 0x72;

  int _at(int i) => i < _src.length ? _src[i] : -1;

  bool _isIdentifierChar(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      c == 0x5F ||
      c == _dollar;

  /// Scans code from [i]; to the end of the file, or, when [inBraces], to
  /// the `}` that closes the `${` before it. Returns the index after that.
  int code(int i, {bool inBraces = false}) {
    var depth = 1;
    while (i < _src.length) {
      final c = _src[i];
      if (c == _slash && _at(i + 1) == _slash) {
        while (i < _src.length && _src[i] != _newline) {
          i++;
        }
      } else if (c == _slash && _at(i + 1) == _star) {
        i = _blockComment(i + 2);
      } else if (c == _single || c == _double) {
        final raw = _at(i - 1) == _r && !_isIdentifierChar(_at(i - 2));
        i = _string(i, raw: raw);
      } else if (inBraces && c == _openBrace) {
        depth++;
        i++;
      } else if (inBraces && c == _closeBrace) {
        if (--depth == 0) return i + 1;
        i++;
      } else {
        i++;
      }
    }
    return i;
  }

  /// Skips a block comment whose text starts at [i]; they nest in Dart.
  int _blockComment(int i) {
    var depth = 1;
    while (i < _src.length && depth > 0) {
      if (_src[i] == _slash && _at(i + 1) == _star) {
        depth++;
        i += 2;
      } else if (_src[i] == _star && _at(i + 1) == _slash) {
        depth--;
        i += 2;
      } else {
        i++;
      }
    }
    return i;
  }

  /// Reads the string whose opening quote is at [i]; returns the index after
  /// its closing quote.
  int _string(int i, {required bool raw}) {
    final quote = _src[i];
    final triple = _at(i + 1) == quote && _at(i + 2) == quote;
    i += triple ? 3 : 1;
    while (i < _src.length) {
      final c = _src[i];
      if (c == quote &&
          (!triple || (_at(i + 1) == quote && _at(i + 2) == quote))) {
        return i + (triple ? 3 : 1);
      }
      if (!triple && c == _newline) return i; // Not a string after all.
      if (!raw && c == _backslash) {
        i = _escape(i + 1);
      } else if (!raw && c == _dollar && _at(i + 1) == _openBrace) {
        i = code(i + 2, inBraces: true);
      } else {
        _found.add(c);
        i++;
      }
    }
    return i;
  }

  /// Reads the escape whose letter is at [i] (after the backslash): adds the
  /// character of a `\u` or `\x` escape, and returns the index after it.
  int _escape(int i) {
    final letter = _at(i);
    if (letter == 0x75 /* u */ && _at(i + 1) == _openBrace) {
      var end = i + 2;
      while (end < _src.length && _src[end] != _closeBrace) {
        end++;
      }
      _addHex(_src.sublist(i + 2, end));
      return end + 1;
    }
    final digits = switch (letter) {
      0x75 /* u */ => 4,
      0x78 /* x */ => 2,
      _ => 0,
    };
    if (digits > 0) {
      _addHex(_src.sublist(i + 1, i + 1 + digits));
      return i + 1 + digits;
    }
    return i + 1; // \n, \', \$ and the like: nothing a font needs to draw.
  }

  void _addHex(List<int> digits) {
    final value = int.tryParse(String.fromCharCodes(digits), radix: 16);
    if (value != null) _found.add(value);
  }
}

/// The code points that [font] (a TrueType file) has a glyph for.
///
/// Reads the `cmap` table (formats 4 and 12, the ones fonts use for Unicode).
Set<int> fontCodePoints(File font) {
  final bytes = font.readAsBytesSync();
  final data = ByteData.sublistView(bytes);

  int? cmapOffset;
  final tableCount = data.getUint16(4);
  for (var i = 0; i < tableCount; i++) {
    final record = 12 + 16 * i;
    if (String.fromCharCodes(bytes.sublist(record, record + 4)) == 'cmap') {
      cmapOffset = data.getUint32(record + 8);
    }
  }
  if (cmapOffset == null) throw FormatException('${font.path}: no cmap');

  final found = <int>{};
  final subtables = data.getUint16(cmapOffset + 2);
  for (var i = 0; i < subtables; i++) {
    final platform = data.getUint16(cmapOffset + 4 + 8 * i);
    final encoding = data.getUint16(cmapOffset + 6 + 8 * i);
    final unicode =
        platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
    if (!unicode) continue;
    final table = cmapOffset + data.getUint32(cmapOffset + 8 + 8 * i);
    switch (data.getUint16(table)) {
      case 4:
        _readFormat4(data, table, found);
      case 12:
        _readFormat12(data, table, found);
    }
  }
  return found;
}

void _readFormat4(ByteData data, int table, Set<int> found) {
  final segments = data.getUint16(table + 6) ~/ 2;
  final ends = table + 14;
  final starts = ends + 2 * segments + 2;
  final deltas = starts + 2 * segments;
  final rangeOffsets = deltas + 2 * segments;
  for (var s = 0; s < segments; s++) {
    final end = data.getUint16(ends + 2 * s);
    final start = data.getUint16(starts + 2 * s);
    final delta = data.getUint16(deltas + 2 * s);
    final rangeOffset = data.getUint16(rangeOffsets + 2 * s);
    for (var c = start; c <= end && c < 0xFFFF; c++) {
      final int glyph;
      if (rangeOffset == 0) {
        glyph = (c + delta) & 0xFFFF;
      } else {
        final at = rangeOffsets + 2 * s + rangeOffset + 2 * (c - start);
        final raw = data.getUint16(at);
        glyph = raw == 0 ? 0 : (raw + delta) & 0xFFFF;
      }
      if (glyph != 0) found.add(c);
    }
  }
}

void _readFormat12(ByteData data, int table, Set<int> found) {
  final groups = data.getUint32(table + 12);
  for (var g = 0; g < groups; g++) {
    final at = table + 16 + 12 * g;
    final start = data.getUint32(at);
    final end = data.getUint32(at + 4);
    final firstGlyph = data.getUint32(at + 8);
    for (var c = start; c <= end; c++) {
      if (firstGlyph + (c - start) != 0) found.add(c);
    }
  }
}
