import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The width and height of the PNG at [path], from its header.
({int width, int height}) _pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  final header = ByteData.sublistView(bytes, 16, 24);
  return (width: header.getUint32(0), height: header.getUint32(4));
}

void main() {
  final manifest = jsonDecode(
    File('web/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final index = File('web/index.html').readAsStringSync();
  final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

  test('the manifest is for a landscape game', () {
    // Installed to the home screen, a portrait lock would trap the game
    // behind its rotate prompt.
    expect(manifest['orientation'], 'landscape');
  });

  test('every icon in the manifest exists, at the size it says', () {
    final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();
    expect(icons, isNotEmpty);
    for (final icon in icons) {
      final size = _pngSize('web/${icon['src']}');
      expect(
        '${size.width}x${size.height}',
        icon['sizes'],
        reason: '${icon['src']}',
      );
    }
  });

  test('the favicon is 32 px square, and the touch icon the page names', () {
    final favicon = _pngSize('web/favicon.png');
    expect((favicon.width, favicon.height), (32, 32));
    expect(index, contains('href="icons/Icon-192.png"'));
  });

  test('the colours are the game\'s, not Flutter\'s blue', () {
    expect(manifest['background_color'], '#FFF8E8'); // The tile buttons.
    expect(manifest['theme_color'], '#C4B396'); // The popup frames.
    expect(manifest['theme_color'], isNot('#0175C2'));
    // The page's own bar colour says the same.
    expect(
      index,
      contains('name="theme-color" content="${manifest['theme_color']}"'),
    );
  });

  test('the loading screen and the script that moves it agree', () {
    for (final id in ['loading', 'loading-bar', 'loading-label']) {
      expect(index, contains('id="$id"'), reason: id);
      expect(bootstrap, contains("getElementById('$id')"), reason: id);
    }
    // It goes away on the game's first frame, and the Flutter parts of the
    // start-up script are still there.
    expect(bootstrap, contains("'flutter-first-frame'"));
    expect(bootstrap, contains('{{flutter_js}}'));
    expect(bootstrap, contains('{{flutter_build_config}}'));
    expect(bootstrap, contains('_flutter.loader.load('));
  });
}
