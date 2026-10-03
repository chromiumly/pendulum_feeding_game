/// The game's fonts, made from the originals in `art/fonts/`: cut down to the
/// characters the game writes.
///
///   dart run tool/fonts.dart
///
/// The result goes to `assets/fonts/` under the same names, which is where
/// `pubspec.yaml` looks. Run it after adding text to the game, or changing a
/// font in `art/fonts/`. `test/ui/fonts_test.dart` fails if a character of the
/// game is missing from a font here.
///
/// A full Japanese font is several megabytes, and a phone downloads all of it
/// before the first screen. The game writes about a hundred different
/// Japanese characters, which take a few tens of kilobytes.
///
/// Which characters are kept:
///
/// * Every printable ASCII character, in every font: digits, letters and
///   signs, for the score and the like, whatever they are typed as.
/// * In the Japanese font, also every character in a string literal of
///   `lib/` (comments are not read; see [stringLiteralCodePoints]). A
///   character that the original font does not have is an error: it would
///   show as a box, or in another font.
///
/// The Latin font has no Japanese in it: where it is used, the game falls
/// back to the Japanese font (`GameTextStyles.inter`).
///
/// Needs `pyftsubset` of fonttools on the PATH (`pip install fonttools`); or
/// set the `PYFTSUBSET` environment variable to its path.
///
/// Cutting a font down is allowed by its licence (SIL OFL, in `assets/fonts/`)
/// as long as the licence goes with it, and neither font reserves its name.
library;

import 'dart:io';

import 'font_support.dart';

/// Which fonts to make: the file name (in `art/fonts/`, and made into
/// `assets/fonts/`), and whether it also keeps the characters of the game's
/// strings, besides ASCII.
const _fonts = <String, ({bool gameText})>{
  'MPLUSRounded1c-Bold.ttf': (gameText: true),
  'Inter-Bold.ttf': (gameText: false),
  'Inter-ExtraBold.ttf': (gameText: false),
};

/// The printable ASCII characters, space to tilde.
final _ascii = {for (var c = 0x20; c <= 0x7E; c++) c};

/// Makes every font and prints their sizes. Run from the project root.
void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run from the project root.');
    exit(1);
  }
  final text = {
    for (final c in stringLiteralCodePoints(Directory('lib')))
      if (c > 0x7E) c,
  };
  stdout.writeln('${text.length} characters besides ASCII in lib/');

  var failed = false;
  stdout.writeln('font                          original   made');
  for (final MapEntry(key: name, value: font) in _fonts.entries) {
    final source = File('art/fonts/$name');
    final target = File('assets/fonts/$name');
    final has = fontCodePoints(source);

    final wanted = {..._ascii, if (font.gameText) ...text};
    final missing = wanted.where((c) => !has.contains(c)).toList()..sort();
    if (missing.isNotEmpty) {
      failed = true;
      stderr.writeln(
        '$name has no ${_describe(missing)}. Change the text, or use '
        'another font for it.',
      );
      continue;
    }
    _subset(source, target, wanted);
    stdout.writeln(
      '${name.padRight(30)}${_kb(source).padRight(11)}${_kb(target)}',
    );
  }
  if (failed) exit(1);
}

String _kb(File file) => '${(file.lengthSync() / 1024).round()} KB';

String _describe(List<int> codePoints) => codePoints
    .map((c) => '${String.fromCharCode(c)} (U+${c.toRadixString(16)})')
    .join(', ');

/// Writes [target], the font [source] cut down to [codePoints]. Exits with
/// an error if pyftsubset is missing or fails.
void _subset(File source, File target, Set<int> codePoints) {
  final pyftsubset = Platform.environment['PYFTSUBSET'] ?? 'pyftsubset';
  final ProcessResult result;
  try {
    result = Process.runSync(pyftsubset, [
      source.path,
      '--output-file=${target.path}',
      '--unicodes=${(codePoints.toList()..sort()).map((c) => c.toRadixString(16)).join(',')}',
      '--layout-features=*', // Keep the font's kerning and the like.
      '--name-IDs=*', // Keep its name and licence texts.
      '--no-hinting', // Skia does not use TrueType hints; they are large.
    ]);
  } on ProcessException {
    stderr.writeln(
      'pyftsubset not found. Install it (pip install fonttools), or set '
      'PYFTSUBSET to its path.',
    );
    exit(1);
  }
  if (result.exitCode != 0) {
    stderr.writeln('pyftsubset failed on ${source.path}:\n${result.stderr}');
    exit(1);
  }
}
