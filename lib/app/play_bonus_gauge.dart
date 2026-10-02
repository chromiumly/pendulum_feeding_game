import 'package:flutter/widgets.dart';

import '../ui/palette.dart';
import '../ui/text_styles.dart';

/// The play-count bonus at the top right of the setup screen (Figma:
/// 初期位置決め画面 プレイ回数ボーナスゲージ): how much more an average food
/// is worth this game, as a percentage and as a gauge that fills up towards
/// the most it can ever be. A highlight sweeps across the fill.
///
/// Laid out at its Figma position in the 844x390 stage.
class PlayBonusGauge extends StatefulWidget {
  const PlayBonusGauge({
    super.key,
    required this.uplift,
    required this.maxUplift,
  });

  /// 0.123 for +12.3%.
  final double uplift;
  final double maxUplift;

  @override
  State<PlayBonusGauge> createState() => _PlayBonusGaugeState();
}

class _PlayBonusGaugeState extends State<PlayBonusGauge>
    with SingleTickerProviderStateMixin {
  static const _frame = Rect.fromLTWH(520, 37, 241, 30);
  static const _border = 3.0;

  /// Width of the sweeping highlight [px].
  static const _highlightWidth = 70.0;

  /// One sweep across the fill, then a pause before the next.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  double get _fraction => widget.maxUplift > 0
      ? (widget.uplift / widget.maxUplift).clamp(0.0, 1.0)
      : 0.0;

  @override
  Widget build(BuildContext context) {
    final inner = Size(_frame.width - 2 * _border, _frame.height - 2 * _border);
    final fillWidth = inner.width * _fraction;
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
          Positioned.fromRect(
            rect: _frame,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xCCFFFFFF),
                border: Border.all(color: Palette.brown, width: _border),
              ),
            ),
          ),
          Positioned(
            left: _frame.left + _border,
            top: _frame.top + _border,
            width: fillWidth,
            height: inner.height,
            child: ClipRect(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Palette.gaugeStart, Palette.gaugeEnd],
                        ),
                      ),
                    ),
                  ),
                  if (fillWidth > 0) _highlight(fillWidth, inner.height),
                ],
              ),
            ),
          ),
          Positioned(
            left: 769,
            top: 39,
            width: 70,
            height: 25,
            child: Text(
              '${(widget.uplift * 100).toStringAsFixed(1)}%',
              style: GameTextStyles.gaugeLabel,
            ),
          ),
        ],
      ),
    );
  }

  /// A soft white band that moves from left to right across the fill during
  /// the first 60% of each cycle, and waits outside it for the rest.
  Widget _highlight(double fillWidth, double height) {
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(
          (_sweep.value / 0.6).clamp(0.0, 1.0),
        );
        final travel = fillWidth + _highlightWidth;
        return Positioned(
          left: -_highlightWidth + travel * t,
          top: 0,
          width: _highlightWidth,
          height: height,
          child: child!,
        );
      },
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x00FFFFFF), Color(0x80FFFFFF), Color(0x00FFFFFF)],
          ),
        ),
      ),
    );
  }
}
