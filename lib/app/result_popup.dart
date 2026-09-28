import 'package:flutter/widgets.dart';

import '../ui/assets.dart';
import '../ui/format.dart';
import '../ui/text_styles.dart';
import '../ui/widgets/popup_panel.dart';
import '../ui/widgets/tile_button.dart';

/// The 474x259 result popup (Figma: リザルト画面). Positioned by the caller at
/// (185, 65) over the blurred game.
class ResultPopup extends StatelessWidget {
  const ResultPopup({
    super.key,
    required this.score,
    required this.onRetry,
    required this.onTitle,
  });

  static const size = Size(474, 259);

  final int score;
  final VoidCallback onRetry;
  final VoidCallback onTitle;

  @override
  Widget build(BuildContext context) {
    return PopupPanel(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          Positioned(
            left: 2,
            top: 36,
            width: 237,
            height: 68,
            child: Center(
              child: Text('SCORE', style: GameTextStyles.resultLabel),
            ),
          ),
          Positioned(
            left: 205,
            top: 33,
            width: 237,
            height: 68,
            child: Center(
              child: Text(
                formatScore(score),
                style: GameTextStyles.resultScore,
              ),
            ),
          ),
          Positioned(
            left: 100,
            top: 122,
            child: TileButton(
              icon: GameAssets.retryIcon,
              label: 'もう一度',
              onPressed: onRetry,
            ),
          ),
          Positioned(
            left: 264,
            top: 122,
            child: TileButton(
              icon: GameAssets.homeIcon,
              label: 'タイトルへ',
              onPressed: onTitle,
            ),
          ),
        ],
      ),
    );
  }
}
