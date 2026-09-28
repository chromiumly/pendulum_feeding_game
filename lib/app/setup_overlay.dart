import 'package:flutter/widgets.dart';

import '../ui/assets.dart';
import '../ui/text_styles.dart';
import '../ui/widgets/outlined_text.dart';
import '../ui/widgets/tile_button.dart';

/// Hints and the スタート button over the game (Figma: 初期位置決め画面).
///
/// Only the button takes input; drags elsewhere reach the game, where the
/// player moves the joint and the bride.
class SetupOverlay extends StatelessWidget {
  const SetupOverlay({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _hint(left: 42, top: 347, text: '新婦を好きな位置に動かそう！'),
        _hint(left: 558, top: 219, text: '位置を決めたらスタート！'),
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

  static Widget _hint({
    required double left,
    required double top,
    required String text,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: 300,
      height: 42,
      child: IgnorePointer(
        child: Center(child: OutlinedText(text, style: GameTextStyles.hint)),
      ),
    );
  }
}
