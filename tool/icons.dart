/// The web app's icons, made from the parfait of the game's food art.
///
///   dart run tool/icons.dart
///
/// Makes `web/favicon.png` (the browser tab) and the four icons of
/// `web/icons/` (the home screen, listed in `web/manifest.json`). Run it
/// after changing the art or the colour below.
///
/// The parfait is tall, so its top square is used: the cream, the fruit and
/// the rim of the glass. Each icon is that square on a solid colour, because
/// home screens do not take see-through icons well. The maskable icons get
/// more room around it, since phones cut their corners away to a circle or
/// a rounded square.
library;

import 'dart:io';

import 'package:image/image.dart' as img;

/// The art the icons are made from.
final _source = File('art/food/parfait.png');

/// The colour behind the parfait: the cream of the game's tile buttons.
final _background = img.ColorRgb8(0xFF, 0xF8, 0xE8);

/// How much of the icon's width the parfait fills [0 to 1].
///
/// The maskable icons keep it within the 80% circle that every phone shows;
/// the picture's own corners are empty, so it can be a bit more than that
/// square would allow.
const _plainFill = 0.92;
const _maskableFill = 0.66;

/// The browser tab icon is tiny, so the parfait fills all of it.
const _faviconFill = 1.0;

/// Makes every icon and prints what it made. Run from the project root.
void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run from the project root.');
    exit(1);
  }
  final art = img.decodePng(_source.readAsBytesSync());
  if (art == null) {
    stderr.writeln('${_source.path}: not a PNG');
    exit(1);
  }
  final square = _flatTopSquare(art);

  final icons = {
    'web/favicon.png': (size: 32, fill: _faviconFill),
    'web/icons/Icon-192.png': (size: 192, fill: _plainFill),
    'web/icons/Icon-512.png': (size: 512, fill: _plainFill),
    'web/icons/Icon-maskable-192.png': (size: 192, fill: _maskableFill),
    'web/icons/Icon-maskable-512.png': (size: 512, fill: _maskableFill),
  };
  for (final MapEntry(:key, :value) in icons.entries) {
    final bytes = img.encodePng(_icon(square, value.size, value.fill));
    File(key).writeAsBytesSync(bytes);
    stdout.writeln(
      '${key.padRight(34)} ${value.size}x${value.size}  ${bytes.length} bytes',
    );
  }
}

/// Returns the top square of [art], as wide as it, laid on [_background] so
/// that nothing in it is see-through.
img.Image _flatTopSquare(img.Image art) {
  final top = img.copyCrop(
    art,
    x: 0,
    y: 0,
    width: art.width,
    height: art.width,
  );
  final flat = img.Image(width: top.width, height: top.height, numChannels: 3)
    ..clear(_background);
  return img.compositeImage(flat, top);
}

/// Returns an icon of [size] px square: [square] scaled to [fill] of the
/// width and centred on [_background].
img.Image _icon(img.Image square, int size, double fill) {
  final icon = img.Image(width: size, height: size, numChannels: 3)
    ..clear(_background);
  final width = (size * fill).round();
  final scaled = img.copyResize(
    square,
    width: width,
    // Averaging keeps a shrunk picture smooth; a picture made bigger needs
    // the smooth curve instead.
    interpolation: width < square.width
        ? img.Interpolation.average
        : img.Interpolation.cubic,
  );
  final offset = (size - width) ~/ 2;
  return img.compositeImage(icon, scaled, dstX: offset, dstY: offset);
}
