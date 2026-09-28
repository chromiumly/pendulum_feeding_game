import 'package:flutter/widgets.dart';

import '../ui/assets.dart';
import '../ui/text_styles.dart';
import '../ui/widgets/outlined_text.dart';
import '../ui/widgets/popup_panel.dart';
import '../ui/widgets/round_icon_button.dart';

/// Provisional text; the final version may add illustrations.
const howToPlayText =
    '新婦に食べ物を投げて、上手に食べさせよう！\n'
    '画面を指で引っぱって狙いを決めたら、離して発射。\n'
    '（引っぱった方向と反対向きに飛ぶよ）\n'
    '動いている新婦の口にタイミングよく届けよう！\n'
    '20秒間でハイスコアを目指そう！';

/// The 700x320 how-to-play popup. Positioned by the caller at (72, 35).
class HowToPlayPopup extends StatelessWidget {
  const HowToPlayPopup({super.key, required this.onClose});

  static const size = Size(700, 320);

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return PopupPanel(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          Positioned(
            left: 19,
            top: 20,
            width: 120,
            height: 40,
            child: Center(
              child: OutlinedText(
                '遊び方',
                style: GameTextStyles.popupHeading,
                outlineWidth: 3,
              ),
            ),
          ),
          Positioned(
            left: 632.5,
            top: 14.5,
            child: RoundIconButton(
              icon: GameAssets.closeIcon,
              semanticLabel: '閉じる',
              onPressed: onClose,
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            top: 80,
            bottom: 24,
            child: Align(
              alignment: Alignment.topLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: Text(howToPlayText, style: GameTextStyles.popupBody),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
