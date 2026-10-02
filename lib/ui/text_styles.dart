import 'package:flutter/painting.dart';

import 'palette.dart';

/// Text styles from the Figma design.
///
/// Rounded display text is drawn with an outline (see `OutlinedText`); Inter
/// text uses a drop shadow. Japanese glyphs in Inter styles fall back to
/// M PLUS Rounded 1c, since Inter has no Japanese glyphs.
abstract final class GameTextStyles {
  static const rounded = 'MPLUSRounded1c';
  static const inter = 'Inter';

  static const _shadow = [
    Shadow(color: Color(0x40000000), offset: Offset(0, 4), blurRadius: 4),
  ];

  static const _roundedBase = TextStyle(
    fontFamily: rounded,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const _interBase = TextStyle(
    fontFamily: inter,
    fontFamilyFallback: [rounded],
    color: Palette.darkBrown,
    shadows: _shadow,
    height: 1.2,
  );

  static final title = _roundedBase.copyWith(
    fontSize: 64,
    color: Palette.brown,
  );
  static final tapToStart = _roundedBase.copyWith(
    fontSize: 32,
    color: Palette.brown,
  );
  static final popupHeading = _roundedBase.copyWith(
    fontSize: 32,
    color: Palette.brown,
  );
  static final popupBody = _roundedBase.copyWith(
    fontSize: 20,
    color: Palette.darkBrown,
    height: 1.6,
  );
  static final hint = _roundedBase.copyWith(
    fontSize: 32,
    color: Palette.accentRed,
  );

  /// Play-count bonus heading and percentage.
  static final gaugeLabel = _roundedBase.copyWith(
    fontSize: 20,
    color: Palette.brown,
  );

  /// Shown at the bride's mouth when she eats. A little larger than Figma's
  /// 20 and 15 px, to read at a glance.
  static final eatenPoints = _roundedBase.copyWith(
    fontSize: 24,
    color: Palette.scorePink,
  );
  static final eatenCombo = _roundedBase.copyWith(
    fontSize: 18,
    color: Palette.scorePink,
  );

  static final countdown = _roundedBase.copyWith(
    fontSize: 128,
    color: Palette.countdown,
  );

  static final hud = _interBase.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w800,
  );
  static final resultHeading = _interBase.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w800,
  );
  static final resultValue = _interBase.copyWith(
    fontSize: 48,
    fontWeight: FontWeight.w800,
  );
  static final resultRank = _interBase.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w800,
  );

  /// Two-line notes in place of a rank (guest, failed); smaller than ranks.
  static final resultNote = _interBase.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.25,
  );
  static final newRecord = _interBase.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: const Color(0xFFFFFFFF),
  );
  static final buttonLabel = _interBase.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
  );
}
