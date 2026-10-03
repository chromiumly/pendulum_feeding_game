/// The play-count bonus gauge on the setup screen.
library;

import 'package:flutter/widgets.dart';

import '../ui/text_styles.dart';
import '../ui/widgets/bonus_gauge_bar.dart';

/// The play-count bonus at the top right of the setup screen (Figma:
/// 初期位置決め画面 プレイ回数ボーナスゲージ): how much more an average food
/// is worth this game, as a percentage and as a gauge that fills up towards
/// the most it can ever be.
///
/// Laid out at its Figma position in the 844x390 stage.
class PlayBonusGauge extends StatelessWidget {
  const PlayBonusGauge({
    super.key,
    required this.uplift,
    required this.maxUplift,
  });

  /// How much more an average food is worth this game: 0.123 for +12.3%.
  final double uplift;

  /// The most [uplift] can ever be, which fills the gauge.
  final double maxUplift;

  /// Returns the gauge fill, 0 (empty) to 1 (full), for [uplift] out of
  /// [maxUplift]; 0 when [maxUplift] is not positive.
  static double fraction(double uplift, double maxUplift) =>
      maxUplift > 0 ? (uplift / maxUplift).clamp(0.0, 1.0) : 0.0;

  /// Returns [uplift] as a percentage label: "12.3%" for 0.123.
  static String percent(double uplift) =>
      '${(uplift * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 518,
            top: 10,
            width: 185,
            height: 25,
            child: Text('プレイ回数ボーナス', style: GameTextStyles.gaugeLabel),
          ),
          Positioned(
            left: 520,
            top: 37,
            width: 241,
            height: 30,
            child: BonusGaugeBar(
              fraction: fraction(uplift, maxUplift),
              borderWidth: 3,
            ),
          ),
          Positioned(
            left: 769,
            top: 39,
            width: 70,
            height: 25,
            child: Text(percent(uplift), style: GameTextStyles.gaugeLabel),
          ),
        ],
      ),
    );
  }
}
