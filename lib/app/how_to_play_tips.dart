import 'package:flutter/widgets.dart';

import '../game/model/food.dart';
import '../game/model/game_config.dart';
import '../game/model/rules.dart';
import '../ui/assets.dart';
import '../ui/format.dart';
import '../ui/palette.dart';
import '../ui/text_styles.dart';
import '../ui/widgets/bonus_gauge_bar.dart';
import '../ui/widgets/outlined_text.dart';
import 'play_bonus_gauge.dart';

/// The three tip cards of the how-to-play popup, page 2 (Figma: 遊び方画面
/// （2/2） 好物説明, 連続ボーナス説明, プレイ回数ボーナス説明), side by side.
/// The numbers shown are the game's own.
class HowToPlayTips extends StatelessWidget {
  const HowToPlayTips({super.key});

  static const cardSize = Size(163, 159);
  static const cardGap = 7.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardSize.width * 3 + cardGap * 2,
      height: cardSize.height,
      child: Row(
        spacing: cardGap,
        children: const [_FavouritesCard(), _ComboCard(), _PlayBonusCard()],
      ),
    );
  }
}

/// A tip card: a heading, an illustration laid out in card coordinates, and
/// two lines of text at the bottom.
class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.heading,
    required this.body,
    required this.bodyLeft,
    required this.illustration,
  });

  final String heading;
  final String body;
  final double bodyLeft;
  final List<Widget> illustration;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HowToPlayTips.cardSize.width,
      height: HowToPlayTips.cardSize.height,
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 4),
            blurRadius: 4,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 10,
            top: 4,
            height: 25,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _text(heading, GameTextStyles.cardHeading),
            ),
          ),
          ...illustration,
          Positioned(
            left: bodyLeft,
            top: 113,
            height: 38,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _text(body, GameTextStyles.cardBody),
            ),
          ),
        ],
      ),
    );
  }
}

/// Favourites score more: the best, a middle and the last favourite.
class _FavouritesCard extends StatelessWidget {
  const _FavouritesCard();

  @override
  Widget build(BuildContext context) {
    final parfait = _food('parfait');
    final gyoza = _food('gyoza');
    final sweetPotato = _food('sweet_potato');
    return _TipCard(
      heading: '好物は慎重に！',
      body: '新婦が好きな食べ物\nほど高得点',
      bodyLeft: 19,
      illustration: [
        _image(
          GameAssets.food(parfait.id),
          const Rect.fromLTWH(24, 33, 40, 74),
        ),
        _image(GameAssets.food(gyoza.id), const Rect.fromLTWH(83, 42, 37, 27)),
        _image(
          GameAssets.food(sweetPotato.id),
          const Rect.fromLTWH(83, 75, 37, 30),
        ),
        _centredText('+${parfait.points}', GameTextStyles.cardPoints, 43, 74.5),
        _centredText('+${gyoza.points}', GameTextStyles.cardPoints, 124, 59.5),
        _centredText(
          '+${sweetPotato.points}',
          GameTextStyles.cardPoints,
          124,
          94.5,
        ),
      ],
    );
  }
}

/// Foods in a row score more: the bride with the hearts and labels of the
/// game's effect.
class _ComboCard extends StatelessWidget {
  const _ComboCard();

  /// Gyoza eaten as the 4th food in a row: 4 small hearts, ×1.6.
  static const _combo = 4;

  /// Figma's heart positions, one for each food in a row.
  static const _hearts = [
    Offset(30, 40),
    Offset(60, 50),
    Offset(55, 67),
    Offset(28, 82),
  ];

  @override
  Widget build(BuildContext context) {
    final points = comboPoints(
      basePoints: _food('gyoza').points,
      combo: _combo,
    );
    return _TipCard(
      heading: '連続で当てよう！',
      body: '連続回数に応じて\n点数アップ！',
      bodyLeft: 28,
      illustration: [
        _image(GameAssets.bride, const Rect.fromLTWH(32, 46, 42, 64)),
        for (final heart in _hearts.take(_combo))
          _image(GameAssets.heart, heart & const Size(11, 10)),
        Positioned(
          left: 74,
          top: 46,
          height: 17,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _text(
              formatCombo(_combo, comboMultiplier(_combo)),
              GameTextStyles.cardCombo,
            ),
          ),
        ),
        Positioned(
          left: 74,
          top: 55,
          height: 28,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _text('+$points', GameTextStyles.cardPoints),
          ),
        ),
      ],
    );
  }
}

/// Playing more brings favourites more often: the setup screen's gauge, as
/// it is after [_exampleGames] games.
class _PlayBonusCard extends StatelessWidget {
  const _PlayBonusCard();

  /// Shows 13.3%, about Figma's 13.2%.
  static const _exampleGames = 6;

  @override
  Widget build(BuildContext context) {
    const config = GameConfig();
    final bonus = favouriteBonus(
      points: [for (final type in config.foodTypes) type.points],
      gamesPlayed: _exampleGames,
      biasLimit: config.favouriteBiasLimit,
      halfPlays: config.favouriteBiasHalfPlays,
    );
    return _TipCard(
      heading: 'たくさん遊ぼう！',
      body: 'たくさん遊ぶほど\n好物が出やすくなるよ！',
      bodyLeft: 10,
      illustration: [
        Positioned(
          left: 10,
          top: 49,
          child: _text('プレイ回数ボーナス', GameTextStyles.cardGaugeLabel),
        ),
        Positioned(
          left: 10,
          top: 67,
          width: 105,
          height: 13,
          child: BonusGaugeBar(
            fraction: PlayBonusGauge.fraction(bonus.uplift, bonus.maxUplift),
            borderWidth: 2,
          ),
        ),
        Positioned(
          left: 118,
          top: 66,
          height: 15,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _text(
              PlayBonusGauge.percent(bonus.uplift),
              GameTextStyles.cardGaugeLabel,
            ),
          ),
        ),
      ],
    );
  }
}

/// Text with Figma's 2 px light outline, like all text on this page.
Widget _text(
  String text,
  TextStyle style, {
  TextAlign align = TextAlign.left,
}) => OutlinedText(text, style: style, outlineWidth: 2, textAlign: align);

FoodType _food(String id) => defaultFoodTypes.firstWhere((t) => t.id == id);

Widget _image(String asset, Rect rect) => Positioned.fromRect(
  rect: rect,
  child: Image.asset(asset, fit: BoxFit.contain),
);

/// [text] centred on ([x], [y]).
Widget _centredText(String text, TextStyle style, double x, double y) =>
    Positioned(
      left: x - 30,
      top: y - 10,
      width: 60,
      height: 20,
      child: Center(child: _text(text, style, align: TextAlign.center)),
    );
