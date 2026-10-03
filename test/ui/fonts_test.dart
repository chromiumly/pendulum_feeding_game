import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/font_support.dart';

/// The printable ASCII characters, space to tilde.
final _ascii = {for (var c = 0x20; c <= 0x7E; c++) c};

String _show(Iterable<int> codePoints) => (codePoints.toList()..sort())
    .map((c) => '${String.fromCharCode(c)} (U+${c.toRadixString(16)})')
    .join(', ');

Directory _scratch(String source) {
  final dir = Directory.systemTemp.createTempSync('font_text_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  File('${dir.path}/a.dart').writeAsStringSync(source);
  return dir;
}

void main() {
  // A character that a font does not have is drawn as a box (or from another
  // font). The fonts in assets/ are cut down to the characters of the game,
  // so these tests are the guard against a new text that needs `dart run
  // tool/fonts.dart`.
  group('no missing characters (no boxes)', () {
    final text = stringLiteralCodePoints(Directory('lib'))
        .where((c) => c >= 0x20)
        .toSet();
    final rounded = fontCodePoints(
      File('assets/fonts/MPLUSRounded1c-Bold.ttf'),
    );

    test('the Japanese font has every character of the game\'s texts', () {
      final missing = text.difference(rounded);
      expect(
        missing,
        isEmpty,
        reason:
            '${_show(missing)} are not in '
            'assets/fonts/MPLUSRounded1c-Bold.ttf. Run `dart run '
            'tool/fonts.dart` (it says so if the original font has no such '
            'character either).',
      );
    });

    test('every font has all of ASCII (the score, times and signs)', () {
      for (final name in [
        'MPLUSRounded1c-Bold',
        'Inter-Bold',
        'Inter-ExtraBold',
      ]) {
        final has = fontCodePoints(File('assets/fonts/$name.ttf'));
        expect(_ascii.difference(has), isEmpty, reason: name);
      }
    });

    test('the texts are found at all', () {
      // If the scan found nothing, the tests above would pass by being
      // empty.
      expect(text, containsAll('遊び方'.runes));
      expect(text.length, greaterThan(100));
    });
  });

  test('the fonts in assets/ are the cut-down ones', () {
    // A full font is several megabytes; the game's own is far below this.
    for (final name in [
      'MPLUSRounded1c-Bold',
      'Inter-Bold',
      'Inter-ExtraBold',
    ]) {
      expect(
        File('assets/fonts/$name.ttf').lengthSync(),
        lessThan(300 * 1024),
        reason: '$name is not cut down: run `dart run tool/fonts.dart`',
      );
      expect(File('art/fonts/$name.ttf').existsSync(), isTrue, reason: name);
    }
  });

  group('fontCodePoints', () {
    test('reads what the original fonts have, and what they do not', () {
      final rounded = fontCodePoints(File('art/fonts/MPLUSRounded1c-Bold.ttf'));
      expect(rounded, containsAll('あア漢A9！'.runes));
      expect(rounded, isNot(contains(0x1F600))); // An emoji.

      final inter = fontCodePoints(File('art/fonts/Inter-Bold.ttf'));
      expect(inter, containsAll('Az09'.runes));
      expect(inter, isNot(contains('あ'.runes.first)));
    });

    test('the cut-down font keeps only what it was asked for', () {
      final rounded = fontCodePoints(
        File('assets/fonts/MPLUSRounded1c-Bold.ttf'),
      );
      expect(rounded, contains('遊'.runes.first));
      expect(rounded, isNot(contains('鬱'.runes.first)));
    });
  });

  group('stringLiteralCodePoints', () {
    Set<int> scan(String source) => stringLiteralCodePoints(_scratch(source));

    test('reads the characters of strings, and not of comments', () {
      final found = scan('''
// 注釈
/* ブロック /* 入れ子 */ まだ注釈 */
/// 文書コメント
final a = 'あ"い';
final b = "う'え";
// 'お'
''');
      expect(String.fromCharCodes(found.toList()..sort()), '"\'あいうえ');
    });

    test('reads raw, triple-quoted and interpolated strings', () {
      final found = scan(r'''
final a = r'か$\';
final b = """き
く""";
final c = 'け${'こ' + "さ"}し$name';
''');
      for (final c in 'かきくけこさし'.runes) {
        expect(found, contains(c), reason: String.fromCharCode(c));
      }
      expect(found, isNot(contains('名'.runes.first)));
    });

    test('reads \\u escapes', () {
      final found = scan(r"final a = 'あ\u{3044}\x41\n';");
      expect(found, containsAll([0x3042, 0x3044, 0x41]));
    });

    test('a // inside a string is not a comment', () {
      final found = scan("final a = 'https://example.com/ あ';");
      expect(found, contains('あ'.runes.first));
    });
  });
}
