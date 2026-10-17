/// The presentation page's Japanese font.
library;

import 'package:flutter/services.dart';

/// The whole of the game's Japanese font, M PLUS Rounded 1c Bold, not cut
/// down as the game's is (see tool/fonts.dart): the roster's names can have
/// any character. It is an asset, not one of the app's fonts, so that the
/// game does not download it; the presentation page [load]s it at launch.
abstract final class PresentationFonts {
  static const rounded = 'PresentationRounded';

  /// The font file, also checked by test/ui/fonts_test.dart.
  static const roundedAsset = 'art/fonts/MPLUSRounded1c-Bold.ttf';

  /// Loads [rounded], so that text in it is drawn as soon as it is shown.
  static Future<void> load() =>
      (FontLoader(rounded)..addFont(rootBundle.load(roundedAsset))).load();
}
