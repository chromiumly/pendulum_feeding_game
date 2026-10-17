/// The presentation's colours and text, in the game's style.
library;

import 'package:flutter/painting.dart';

import '../ui/palette.dart';
import '../ui/text_styles.dart';
import 'presentation_fonts.dart';

/// Colours of the slides, from the Figma design: the game's cream, browns
/// and orange, the accents of the cards, and gold for the award.
abstract final class SlidePalette {
  /// Laid over the blurred stage background, to make the text readable.
  static const veil = Color(0xCCFFFAE9);

  static const heading = Palette.darkBrown;
  static const body = Palette.cardText;
  static const muted = Palette.brown;

  /// The ranking's highlights.
  static const accent = Palette.gaugeEnd;

  /// The bullets (Figma: マーカー), in orange gold.
  static const bullet = Color(0xFFD3911F);

  /// The underline under the titles, from its left along it: the award's
  /// gold (it was orange gold, 0xFFD98A1C to 0xFFEBB445).
  static const ruleDeep = goldDeep;
  static const ruleLight = goldLight;

  /// Gold, from deep to light, for the award pages.
  static const goldDeep = Color(0xFFB07A1A);
  static const gold = Color(0xFFD9A93A);
  static const goldMid = Color(0xFFE6BF5C);
  static const goldLight = Color(0xFFFFE7A3);

  /// The gold sheen of large text: deep, light, gold, light, deep.
  static const goldSheen = [goldDeep, goldLight, gold, goldLight, goldDeep];

  /// Cards on the slides, e.g. the ranking rows and the tool cards.
  static const card = Color(0xFFFFFDF6);

  /// The edges of the cards: gold for the making, teal for running it, pink
  /// for the game itself.
  static const cardGold = Color(0xFFDAAD4D);
  static const cardTeal = Color(0xFF5FA8B8);
  static const cardPink = Palette.scorePink;

  /// Inside the pendulum's card: the card's cream with a touch of its teal
  /// edge, a little lighter than [playingFill].
  static const pendulumFill = Color(0xFFF3F7F2);

  /// Inside the dashed frames of making (これまで) and playing (本日).
  static const makingFill = Color(0xFFFFEFDB);
  static const playingFill = Color(0xFFF4F2E5);

  /// The AI balloons.
  static const aiBalloon = Palette.accentRed;

  /// The lines between the cards.
  static const connector = Palette.brown;
}

/// Text styles of the slides, sized for the 1920x1080 slide. Japanese is in
/// the whole font ([PresentationFonts]), numbers and Latin in Inter.
abstract final class SlideTextStyles {
  /// The talk's text, as in Figma: the rounded font at its own line height.
  static const _rounded = TextStyle(
    fontFamily: PresentationFonts.rounded,
    fontFamilyFallback: [GameTextStyles.rounded],
    fontWeight: FontWeight.w700,
    color: SlidePalette.heading,
  );

  /// The ranking's text, a little tighter.
  static final _base = _rounded.copyWith(height: 1.35);

  static const _numbers = TextStyle(
    fontFamily: GameTextStyles.inter,
    fontFamilyFallback: [PresentationFonts.rounded, GameTextStyles.rounded],
    fontWeight: FontWeight.w800,
    height: 1.1,
  );

  /// "Lightning Talk" on the cover.
  static final kicker = _rounded.copyWith(
    fontSize: 64,
    color: SlidePalette.muted,
  );
  static final coverTitle = _rounded.copyWith(fontSize: 96);

  /// The date and the presenter on the cover.
  static final coverByline = _rounded.copyWith(
    fontSize: 64,
    color: SlidePalette.muted,
  );

  /// A slide's title (e.g. コンセプト), its message under it, its points
  /// and the points under a point.
  static final title = _rounded.copyWith(fontSize: 64);
  static final message = _rounded.copyWith(fontSize: 64);
  static final bullet = _rounded.copyWith(fontSize: 64);
  static final subBullet = _rounded.copyWith(fontSize: 58);

  /// "2 / 6" at the bottom right.
  static final pageNumber = _rounded.copyWith(
    fontSize: 40,
    color: SlidePalette.muted,
  );

  /// The diagram of how the game was made: the frames' titles, the cards'
  /// names and roles, and the small labels on the lines.
  static final section = _rounded.copyWith(
    fontSize: 48,
    color: SlidePalette.muted,
  );
  static final cardName = _rounded.copyWith(fontSize: 32, height: 1);
  static final cardRole = _rounded.copyWith(
    fontSize: 32,
    color: SlidePalette.muted,
  );
  static final phoneLabel = _rounded.copyWith(fontSize: 28, height: 32 / 28);
  static final connectorLabel = _rounded.copyWith(
    fontSize: 16,
    color: SlidePalette.muted,
  );

  /// "AI" in the balloons. One line of the font's size, its spare room
  /// shared above and below, puts the capitals in the middle.
  static const aiBalloon = TextStyle(
    fontFamily: GameTextStyles.inter,
    fontFamilyFallback: [PresentationFonts.rounded],
    fontWeight: FontWeight.w800,
    fontSize: 24,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
    color: Color(0xFFFFFFFF),
    shadows: [
      Shadow(color: Color(0x40000000), offset: Offset(0, 4), blurRadius: 4),
    ],
  );

  /// The talk's title above 表彰式.
  static final awardTalkTitle = _base.copyWith(
    fontSize: 40,
    color: SlidePalette.muted,
  );

  /// 表彰式.
  static final award = _base.copyWith(fontSize: 240, letterSpacing: 24);

  /// ランキング.
  static final rankingTitle = _base.copyWith(fontSize: 72);

  /// Ranking table: the first row, the others, and the header.
  static final firstRank = _base.copyWith(fontSize: 120);
  static final firstScore = _numbers.copyWith(
    fontSize: 128,
    color: SlidePalette.heading,
  );
  static final firstName = _base.copyWith(fontSize: 88);
  static final rank = _base.copyWith(fontSize: 64);
  static final score = _numbers.copyWith(
    fontSize: 72,
    color: SlidePalette.heading,
  );
  static final name = _base.copyWith(fontSize: 56);
  static final tableHeader = _base.copyWith(
    fontSize: 32,
    color: SlidePalette.muted,
  );

  /// The small status line under the ranking.
  static final status = _base.copyWith(fontSize: 30, color: SlidePalette.muted);
}
