/// Pages of QR code stickers to print at home on A4 sticker paper and cut
/// out by hand: one per player in players.csv, with the player's name in the
/// middle of the code.
///
///   flutter test tool/ranking/qr_stickers.dart
///
/// Writes, in tool/ranking/out/qr_stickers/, 54 stickers to a page, side by
/// side so that one cut along a grey line parts two of them:
///
/// * qr_stickers.pdf, to print at actual size (100%);
/// * qr_stickers.html with page_N.png, the same pages for a browser.
///
/// It runs under `flutter test` because it draws Japanese text with the
/// presentation page's font; `flutter test` alone (test/) does not run it.
///
/// Each sticker is 29 mm square, to fit the box on the paper items, and its
/// code 22.6 mm across, like the Google Photos code beside it. The code is error correction level Q (about 25% may be
/// lost), version 6 (41x41 modules) for the game's URL, and the name covers
/// the middle 13x13 modules (about 10%), clear of the code's finder and
/// alignment patterns. The QR codes encode the same URLs as qr.html, so
/// cards printed from it still work.
///
/// The 100 mm rule at the bottom of each page should measure 100 mm. Before
/// printing them all, print one page and check that phones read the codes.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';

const _csv = 'tool/ranking/out/players.csv';
const _outDir = 'tool/ranking/out/qr_stickers';
const _font = 'art/fonts/MPLUSRounded1c-Bold.ttf';
const _family = 'StickerRounded';

/// 600 dpi: pixels per millimetre.
const _pxPerMm = 600 / 25.4;
double _mm(double mm) => mm * _pxPerMm;

/// A4, portrait [mm].
const _pageMm = Size(210, 297);
final _page = Size(
  _mm(_pageMm.width).roundToDouble(),
  _mm(_pageMm.height).roundToDouble(),
);

/// A sticker: 686 px = 29.0 mm square, the box on the paper items.
const _sticker = 686.0;

/// The code in it: 41 modules of 13 px (0.55 mm), 22.6 mm across like the
/// Google Photos code beside it on the paper items, in the middle of the
/// sticker; the white around it (3.2 mm) is more than the 4-module quiet
/// zone a reader needs.
const _modules = 41;
const _module = 13.0;

/// (686 - 41 x 13) / 2, to whole pixels so that the modules stay sharp.
const _margin = 76.0;

/// The name's box: the middle 13x13 modules.
const _box = 13;

/// The grid: 6 columns and 9 rows of stickers side by side, at least 10 mm
/// from the edges of the page.
const _columns = 6;
const _rows = 9;

const _ink = Color(0xFF000000);
const _nameInk = Color(0xFF222222);
const _guide = Color(0xFFBBBBBB);

/// A row of players.csv.
typedef _Player = ({int number, String url, String name});

List<_Player> _players() => [
  for (final line in File(_csv).readAsLinesSync().skip(1))
    if (line.trim().isNotEmpty)
      () {
        final cells = line.split(',');
        final name = cells.skip(3).join(',').trim();
        if (name.isEmpty) {
          throw StateError('No.${cells[0]} has no name in $_csv.');
        }
        return (number: int.parse(cells[0]), url: cells[2], name: name);
      }(),
];

/// The lines in the middle of a sticker: family name, given name and 様
/// (smaller), as the roster writes them ("姓 名 様"); a single word (ゲスト46)
/// is split before its digits.
List<(String, double)> _nameLines(String name) {
  final words = name.split(' ');
  if (words.length == 1) {
    final m = RegExp(r'^(\D+)(\d+)$').firstMatch(name);
    return m == null ? [(name, 1)] : [(m[1]!, 1), (m[2]!, 1)];
  }
  return [for (final word in words) (word, word == '様' ? 2 / 3 : 1)];
}

void _text(
  Canvas canvas,
  String text, {
  required Offset centre,
  required double size,
  double? maxWidth,
  Color color = _nameInk,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: _family, fontSize: size, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final scale = maxWidth == null
      ? 1.0
      : math.min(1.0, maxWidth / painter.width);
  canvas
    ..save()
    ..translate(centre.dx, centre.dy)
    ..scale(scale)
    ..translate(-painter.width / 2, -painter.height / 2);
  painter.paint(canvas, Offset.zero);
  canvas.restore();
}

/// Draws [player]'s sticker with its top left at [origin].
void _drawSticker(Canvas canvas, Offset origin, _Player player) {
  final code = QrCode(
    payload: QrPayload.fromString(player.url),
    errorCorrectLevel: QrErrorCorrectLevel.quartile,
  );
  if (code.moduleCount != _modules) {
    throw StateError(
      'The code has ${code.moduleCount} modules, not $_modules.',
    );
  }
  final image = QrImage(code);
  final sticker = origin & const Size(_sticker, _sticker);
  canvas
    ..drawRect(sticker, Paint()..color = const Color(0xFFFFFFFF))
    ..drawRect(
      sticker,
      Paint()
        ..color = _guide
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

  const first = (_modules - _box) ~/ 2;
  const last = first + _box - 1;
  final dark = Paint()..color = _ink;
  for (var row = 0; row < _modules; row++) {
    for (var col = 0; col < _modules; col++) {
      final inBox = row >= first && row <= last && col >= first && col <= last;
      if (inBox || !image.isDark(row, col)) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          origin.dx + _margin + col * _module,
          origin.dy + _margin + row * _module,
          _module,
          _module,
        ),
        dark,
      );
    }
  }

  // The name, in the box.
  final box = Rect.fromLTWH(
    origin.dx + _margin + first * _module,
    origin.dy + _margin + first * _module,
    _box * _module,
    _box * _module,
  );
  final lines = _nameLines(player.name);
  final inner = box.deflate(_module * 0.6);
  final units = lines.fold(0.0, (sum, line) => sum + line.$2);
  final unit = math.min(inner.height / units, inner.width / 2.4);
  var y = inner.center.dy - unit * units / 2;
  for (final (text, weight) in lines) {
    final size = unit * weight;
    _text(
      canvas,
      text,
      centre: Offset(inner.center.dx, y + size / 2),
      size: size * 0.92,
      maxWidth: inner.width,
    );
    y += size;
  }
}

/// Returns page [index] of [count] with [players] on it, as an image.
Future<ui.Image> _drawPage(int index, int count, List<_Player> players) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(Offset.zero & _page, Paint()..color = const Color(0xFFFFFFFF));

  const width = _columns * _sticker;
  const height = _rows * _sticker;
  // On whole pixels, so that the modules stay sharp.
  final left = ((_page.width - width) / 2).roundToDouble();
  final top = ((_page.height - height) / 2).roundToDouble();
  for (final (i, player) in players.indexed) {
    final origin = Offset(
      left + (i % _columns) * _sticker,
      top + (i ~/ _columns) * _sticker,
    );
    _drawSticker(canvas, origin, player);
  }

  // The title, and a 100 mm rule to check the print is at actual size.
  const grey = Color(0xFF888888);
  _text(
    canvas,
    '花嫁もぐもぐチャレンジ QRシール $index/$count'
    '（No.${players.first.number}〜${players.last.number}）',
    centre: Offset(_page.width / 2, top / 2),
    size: _mm(3),
    color: grey,
  );
  final ruleY = top + height + (_page.height - top - height) / 2;
  final rule = Paint()
    ..color = grey
    ..strokeWidth = 4;
  canvas.drawLine(Offset(left, ruleY), Offset(left + _mm(100), ruleY), rule);
  for (var mm = 0; mm <= 100; mm += 10) {
    final x = left + _mm(mm.toDouble());
    canvas.drawLine(Offset(x, ruleY - _mm(1.5)), Offset(x, ruleY), rule);
  }
  _text(
    canvas,
    '← 100mm（等倍で印刷できていればこの長さ）',
    centre: Offset(left + _mm(100) + _mm(38), ruleY - _mm(0.75)),
    size: _mm(2.5),
    color: grey,
  );

  return recorder.endRecording().toImage(
    _page.width.toInt(),
    _page.height.toInt(),
  );
}

/// Returns [image]'s grey levels, a byte per pixel (it is drawn in greys).
Future<Uint8List> _grey(ui.Image image) async {
  final rgba = (await image.toByteData())!.buffer.asUint8List();
  final grey = Uint8List(image.width * image.height);
  for (var i = 0; i < grey.length; i++) {
    grey[i] = rgba[i * 4];
  }
  return grey;
}

/// Returns a PDF of A4 pages, each showing one image of [pages] (grey
/// levels, [_page] in size) over the whole page.
List<int> _pdf(List<Uint8List> pages) {
  final out = BytesBuilder();
  final offsets = <int>[];
  void write(String text) => out.add(latin1.encode(text));
  void object(int id, String dictionary, [List<int>? stream]) {
    offsets.add(out.length);
    write('$id 0 obj\n$dictionary\n');
    if (stream != null) {
      write('stream\n');
      out.add(stream);
      write('\nendstream\n');
    }
    write('endobj\n');
  }

  // The page in points.
  final w = (_pageMm.width / 25.4 * 72).toStringAsFixed(2);
  final h = (_pageMm.height / 25.4 * 72).toStringAsFixed(2);
  final pageIds = [for (var i = 0; i < pages.length; i++) 3 + i * 3];
  write('%PDF-1.4\n');
  object(1, '<< /Type /Catalog /Pages 2 0 R >>');
  object(
    2,
    '<< /Type /Pages /Kids [${pageIds.map((id) => '$id 0 R').join(' ')}] '
    '/Count ${pages.length} >>',
  );
  for (final (i, grey) in pages.indexed) {
    final id = pageIds[i];
    final content = latin1.encode('q $w 0 0 $h 0 0 cm /Im Do Q');
    final data = zlib.encode(grey);
    object(
      id,
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $w $h] '
      '/Resources << /XObject << /Im ${id + 2} 0 R >> >> '
      '/Contents ${id + 1} 0 R >>',
    );
    object(id + 1, '<< /Length ${content.length} >>', content);
    object(
      id + 2,
      '<< /Type /XObject /Subtype /Image /Width ${_page.width.toInt()} '
      '/Height ${_page.height.toInt()} /ColorSpace /DeviceGray '
      '/BitsPerComponent 8 /Filter /FlateDecode /Length ${data.length} >>',
      data,
    );
  }
  final xref = out.length;
  write('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets) {
    write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  write(
    'trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return out.takeBytes();
}

/// Returns a page showing [count] page images at A4 size, to print with no
/// margins.
String _html(int count) {
  final images = [
    for (var i = 1; i <= count; i++) '<img src="page_$i.png" alt="$iページ目">',
  ].join('\n');
  return '''
<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<title>花嫁もぐもぐチャレンジ QRシール（A4）</title>
<style>
  @page { size: A4; margin: 0; }
  body { margin: 0; background: #ddd; }
  img { display: block; width: 210mm; height: 297mm; margin: 0 auto 8mm;
        background: #fff; break-after: page; }
  @media print { body { background: none; } img { margin: 0; } }
</style>
</head>
<body>
$images
</body>
</html>
''';
}

void main() {
  test('write the QR sticker pages', () async {
    await (FontLoader(_family)..addFont(
          Future.value(ByteData.sublistView(File(_font).readAsBytesSync())),
        ))
        .load();
    final players = _players();
    final dir = Directory(_outDir)..createSync(recursive: true);
    const perPage = _columns * _rows;
    final count = (players.length / perPage).ceil();
    final greys = <Uint8List>[];
    for (var i = 0; i < count; i++) {
      final image = await _drawPage(
        i + 1,
        count,
        players.sublist(
          i * perPage,
          math.min((i + 1) * perPage, players.length),
        ),
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/page_${i + 1}.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
      greys.add(await _grey(image));
    }
    File('${dir.path}/qr_stickers.pdf').writeAsBytesSync(_pdf(greys));
    File('${dir.path}/qr_stickers.html').writeAsStringSync(_html(count));
    // ignore: avoid_print
    print('Wrote $count A4 pages of ${players.length} stickers to $_outDir');
  });
}
