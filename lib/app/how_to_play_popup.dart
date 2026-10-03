import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../ui/assets.dart';
import '../ui/text_styles.dart';
import '../ui/widgets/outlined_text.dart';
import '../ui/widgets/popup_panel.dart';
import '../ui/widgets/round_icon_button.dart';
import 'how_to_play_tips.dart';

/// The 563x340 how-to-play popup (Figma: 遊び方画面（1/2）and（2/2）), in two
/// pages: how to play, then tips for a high score. Positioned by the caller
/// at (140, 25).
class HowToPlayPopup extends StatefulWidget {
  const HowToPlayPopup({super.key, required this.onClose});

  static const size = Size(563, 340);

  static const page1Heading = '遊び方①（操作方法）';
  static const page2Heading = '遊び方②（高得点をとるコツ）';

  final VoidCallback onClose;

  @override
  State<HowToPlayPopup> createState() => _HowToPlayPopupState();
}

class _HowToPlayPopupState extends State<HowToPlayPopup> {
  bool _onTips = false;

  void _showTips(bool tips) => setState(() => _onTips = tips);

  @override
  Widget build(BuildContext context) {
    final size = HowToPlayPopup.size;
    return PopupPanel(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          Positioned(
            left: 30,
            top: 17,
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedText(
                _onTips
                    ? HowToPlayPopup.page2Heading
                    : HowToPlayPopup.page1Heading,
                style: GameTextStyles.popupHeading,
                outlineWidth: 3,
                textAlign: TextAlign.left,
              ),
            ),
          ),
          Positioned(
            left: 497 - 1.5,
            top: 12 - 1.5,
            child: RoundIconButton(
              icon: GameAssets.closeIcon,
              semanticLabel: '閉じる',
              onPressed: widget.onClose,
            ),
          ),
          if (_onTips) ..._tipsPage() else ..._controlsPage(),
        ],
      ),
    );
  }

  /// Page 1/2. The playable game below the lead text comes next.
  List<Widget> _controlsPage() => [
    _lead(top: 70, 'ドラッグして食べ物を投げよう！\n新婦の口元にあたると得点が入るよ'),
    Positioned(
      left: 477,
      top: 254,
      child: _PageArrowButton(
        semanticLabel: '次のページ',
        next: true,
        onPressed: () => _showTips(true),
      ),
    ),
  ];

  /// Page 2/2.
  List<Widget> _tipsPage() => [
    const Positioned(left: 30, top: 85, child: HowToPlayTips()),
    _lead(top: 269, 'ハイスコアを目指して頑張ろう！\n何か良いことがあるかも...？', outlined: true),
    Positioned(
      left: 487,
      top: 254,
      child: _PageArrowButton(
        semanticLabel: '前のページ',
        next: false,
        onPressed: () => _showTips(false),
      ),
    ),
  ];

  /// [outlined] adds Figma's 2 px light outline, as on page 2.
  static Widget _lead(
    String text, {
    required double top,
    bool outlined = false,
  }) => Positioned(
    left: 30,
    top: top,
    width: 276,
    height: 40,
    child: Align(
      alignment: Alignment.centerLeft,
      child: outlined
          ? OutlinedText(
              text,
              style: GameTextStyles.howToLead,
              outlineWidth: 2,
              textAlign: TextAlign.left,
            )
          : Text(text, style: GameTextStyles.howToLead),
    ),
  );
}

/// The ▶ / ◀ page button: Figma's triangle, exported pointing up inside a
/// 70x70 box, turned to point right (next) or left (back).
class _PageArrowButton extends StatelessWidget {
  const _PageArrowButton({
    required this.semanticLabel,
    required this.next,
    required this.onPressed,
  });

  final String semanticLabel;
  final bool next;
  final VoidCallback onPressed;

  static const _box = 70.0;

  /// Where the SVG sits in the box, and Figma's drop shadow (4, 4, blur 4,
  /// 25%), both before turning. flutter_svg ignores SVG filters, so the
  /// shadow is painted here.
  static const _svgLeft = 4.69;
  static const _shadowOffset = Offset(4, 4);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: _box,
          child: RotatedBox(
            quarterTurns: next ? 1 : 3,
            child: Stack(
              children: [
                Positioned(
                  left: _svgLeft + _shadowOffset.dx,
                  top: _shadowOffset.dy,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: SvgPicture.asset(
                      GameAssets.pageArrow,
                      colorFilter: const ColorFilter.mode(
                        Color(0x40000000),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _svgLeft,
                  top: 0,
                  child: SvgPicture.asset(GameAssets.pageArrow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
