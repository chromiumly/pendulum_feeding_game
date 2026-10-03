/// The gauge bar shared by the play-count bonus displays.
library;

import 'package:flutter/widgets.dart';

import '../palette.dart';

/// The play-count bonus gauge bar (Figma: ゲージ枠 and ゲージ): a framed
/// gradient fill, [fraction] of the way across, with a highlight sweeping
/// across the fill. Fills the size its parent gives it.
class BonusGaugeBar extends StatefulWidget {
  const BonusGaugeBar({
    super.key,
    required this.fraction,
    required this.borderWidth,
  });

  /// 0 (empty) to 1 (full); values outside are clamped.
  final double fraction;

  /// Width of the frame [px].
  final double borderWidth;

  @override
  State<BonusGaugeBar> createState() => _BonusGaugeBarState();
}

class _BonusGaugeBarState extends State<BonusGaugeBar>
    with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        border: Border.all(color: Palette.brown, width: widget.borderWidth),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final fillWidth = box.maxWidth * widget.fraction.clamp(0.0, 1.0);
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: fillWidth,
              height: box.maxHeight,
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
                    if (fillWidth > 0) _highlight(fillWidth, box.maxHeight),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Returns a soft white band, about three times as wide as the bar is
  /// tall, that moves from left to right across the fill during the first
  /// 60% of each cycle, and waits outside it for the rest. [fillWidth] and
  /// [height] are the fill's size [px].
  Widget _highlight(double fillWidth, double height) {
    final width = height * 3;
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(
          (_sweep.value / 0.6).clamp(0.0, 1.0),
        );
        return Positioned(
          left: -width + (fillWidth + width) * t,
          top: 0,
          width: width,
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
