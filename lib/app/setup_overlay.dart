/// The setup screen's Flutter layers: the スタート button and the hint.
library;

import 'package:flutter/widgets.dart';

import '../ui/assets.dart';
import '../ui/text_styles.dart';
import '../ui/widgets/outlined_text.dart';
import '../ui/widgets/tile_button.dart';

/// The スタート button over the game (Figma: 初期位置決め画面).
///
/// Only the button takes input; drags elsewhere reach the game, where the
/// player moves the joint and the bride.
class SetupOverlay extends StatelessWidget {
  const SetupOverlay({super.key, required this.onStart});

  /// Called when スタート is pressed, to start the countdown.
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 718,
          top: 262,
          child: TileButton(
            icon: GameAssets.startIcon,
            label: 'スタート',
            onPressed: onStart,
          ),
        ),
      ],
    );
  }
}

/// The setup-screen hint. It is laid out behind the game, so that the
/// pendulum swings in front of it.
class SetupHint extends StatelessWidget {
  const SetupHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 5,
          top: 0,
          width: 465,
          height: 46,
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedText(
                '花嫁と支点の位置を決めよう！',
                style: GameTextStyles.hint,
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
