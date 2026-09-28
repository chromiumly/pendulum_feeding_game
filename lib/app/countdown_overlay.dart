import 'package:flutter/widgets.dart';

import '../ui/text_styles.dart';
import '../ui/widgets/outlined_text.dart';
import '../ui/widgets/stage.dart';

/// 3, 2, 1 over the blurred game, then "START" without the blur
/// (Figma: カウントダウン画面).
class CountdownOverlay extends StatelessWidget {
  const CountdownOverlay({super.key, required this.number});

  /// [GameSession.countdownNumber]: 3, 2, 1, or 0 for "START".
  final int number;

  @override
  Widget build(BuildContext context) {
    final label = Center(
      child: OutlinedText(
        number > 0 ? '$number' : 'START',
        style: GameTextStyles.countdown,
      ),
    );
    return IgnorePointer(
      child: number > 0
          ? BlurOverlay(tint: BlurOverlay.light, child: label)
          : label,
    );
  }
}
