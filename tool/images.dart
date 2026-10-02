// Images for the game, made from the original art in art/: trimmed and
// scaled down to what the game needs.
//
//   dart run tool/images.dart
//
// Foods (art/food/ -> assets/images/food/) are sized to look about the same
// size: each image is trimmed to its visible pixels and scaled so that
// sqrt(equivalent diameter x long side) is [_visualSize] display px. The
// equivalent diameter is that of a circle with the image's visible area.
// Matching the area alone would make tall or wide foods (parfait, sushi)
// very long; matching the long side alone would make them look small. The
// geometric mean of the two is in between.
//
// The output is [_density] times the display size, for sharp drawing on
// high-density phone screens. The game draws every food image at
// 1 / [_density] (GameAssets.foodImageDensity), so the sizes chosen here are
// the sizes on the stage.
//
// Effects (art/effects/ -> assets/images/effects/) are scaled to [_density]
// times the largest size the game draws them at.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Display px. About a 53 px circle's worth of visible area per food.
const _visualSize = 58.0;

/// Must equal GameAssets.foodImageDensity.
const _density = 4;

/// Pixels at least this opaque count as visible area.
const _visibleAlpha = 0.5;

/// Largest display width of each effect image [px]; must match where the
/// game draws it.
const _effectWidths = {
  'heart.png': 36.0, // EatenEffect.bigHeartSize
};

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run from the project root.');
    exit(1);
  }
  _foods();
  _effects();
}

void _foods() {
  final output = Directory('assets/images/food')..createSync(recursive: true);
  stdout.writeln('food                 display    eq.diam  bytes');
  for (final source in _pngs(Directory('art/food'))) {
    final name = source.uri.pathSegments.last;
    final image = _load(source);
    final diameter = 2 * math.sqrt(_visibleArea(image) / math.pi);
    final longSide = math.max(image.width, image.height);
    final displayScale = _visualSize / math.sqrt(diameter * longSide);

    final resized = _resize(image, displayScale * _density);
    final bytes = img.encodePng(
      resized.convert(format: img.Format.uint8),
      level: 9,
    );
    File('${output.path}/$name').writeAsBytesSync(bytes);

    final display =
        '${(resized.width / _density).toStringAsFixed(0)}x'
        '${(resized.height / _density).toStringAsFixed(0)}';
    stdout.writeln(
      '${name.padRight(21)}${display.padRight(11)}'
      '${(diameter * displayScale).toStringAsFixed(1).padRight(9)}'
      '${bytes.length}',
    );
  }
}

void _effects() {
  final output = Directory('assets/images/effects')
    ..createSync(recursive: true);
  stdout.writeln('\neffect               display    bytes');
  for (final source in _pngs(Directory('art/effects'))) {
    final name = source.uri.pathSegments.last;
    final width = _effectWidths[name];
    if (width == null) {
      stderr.writeln('$name: add its display width to _effectWidths.');
      exit(1);
    }
    final image = _load(source);
    final resized = _resize(image, width * _density / image.width);
    final bytes = img.encodePng(
      resized.convert(format: img.Format.uint8),
      level: 9,
    );
    File('${output.path}/$name').writeAsBytesSync(bytes);
    final display =
        '${(resized.width / _density).toStringAsFixed(0)}x'
        '${(resized.height / _density).toStringAsFixed(0)}';
    stdout.writeln(
      '${name.padRight(21)}${display.padRight(11)}${bytes.length}',
    );
  }
}

List<File> _pngs(Directory dir) =>
    dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.png'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// [source] decoded and trimmed to its visible pixels, in floating point.
img.Image _load(File source) {
  final original = img.decodePng(source.readAsBytesSync());
  if (original == null) {
    stderr.writeln('${source.path}: not a PNG');
    exit(1);
  }
  return _trim(original.convert(format: img.Format.float32, numChannels: 4));
}

/// [image] cropped to its non-transparent pixels.
img.Image _trim(img.Image image) {
  var left = image.width, top = image.height, right = -1, bottom = -1;
  for (final pixel in image) {
    if (pixel.aNormalized <= 0) continue;
    left = math.min(left, pixel.x);
    top = math.min(top, pixel.y);
    right = math.max(right, pixel.x);
    bottom = math.max(bottom, pixel.y);
  }
  return img.copyCrop(
    image,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}

int _visibleArea(img.Image image) {
  var area = 0;
  for (final pixel in image) {
    if (pixel.aNormalized >= _visibleAlpha) area++;
  }
  return area;
}

/// Scales [image] by [scale] with premultiplied alpha, so that the colour of
/// fully transparent pixels (often black) does not darken the edges.
img.Image _resize(img.Image image, double scale) {
  for (final pixel in image) {
    final a = pixel.aNormalized;
    pixel
      ..r = pixel.r * a
      ..g = pixel.g * a
      ..b = pixel.b * a;
  }
  final resized = img.copyResize(
    image,
    width: math.max(1, (image.width * scale).round()),
    height: math.max(1, (image.height * scale).round()),
    interpolation: img.Interpolation.average,
  );
  for (final pixel in resized) {
    final a = pixel.aNormalized;
    if (a <= 0) {
      pixel
        ..r = 0
        ..g = 0
        ..b = 0;
      continue;
    }
    pixel
      ..r = math.min(pixel.r / a, 1)
      ..g = math.min(pixel.g / a, 1)
      ..b = math.min(pixel.b / a, 1);
  }
  return resized;
}
