/// The how-to-play popup: controls, tips, and credits.
library;

import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../ui/assets.dart';
import '../ui/text_styles.dart';
import '../ui/widgets/outlined_text.dart';
import '../ui/widgets/popup_panel.dart';
import '../ui/widgets/round_icon_button.dart';
import 'how_to_play_credits.dart';
import 'how_to_play_game.dart';
import 'how_to_play_tips.dart';

/// The pages of the popup, in the order of the ▶ button.
enum _Page { controls, tips, credits }

/// The 563x340 how-to-play popup (Figma: 遊び方画面（1/2）and（2/2）), in
/// three pages: how to play, tips for a high score, and credits. Positioned
/// by the caller at (140, 25).
///
/// ▶ goes to the next page and ◀ to the previous one. ▶ is always in the
/// same place; ◀ is beside it, except on the last page, where it stands
/// alone a little to the left of where ▶ is.
class HowToPlayPopup extends StatefulWidget {
  const HowToPlayPopup({super.key, required this.onClose});

  static const size = Size(563, 340);

  static const page1Heading = '遊び方①（操作方法）';
  static const page2Heading = '遊び方②（高得点をとるコツ）';
  static const page3Heading = 'クレジット';

  /// The note at the bottom of the credits: what is done with the play
  /// results. It also stands in the LICENSE and the README.
  static const recordNote = 'プレイ結果は、ランキングのために記録されます';

  /// Called when the × button is pressed.
  final VoidCallback onClose;

  @override
  State<HowToPlayPopup> createState() => _HowToPlayPopupState();
}

class _HowToPlayPopupState extends State<HowToPlayPopup> {
  /// The page shown.
  _Page _page = _Page.controls;

  /// Shows [page].
  void _show(_Page page) => setState(() => _page = page);

  /// Where the buttons' boxes sit [px]: the top, and the left of ▶, which
  /// is the same on every page that has one.
  static const _arrowTop = 254.0;
  static const _nextLeft = 477.0;

  /// Space between ◀ and ▶ where they sit side by side, between the
  /// triangles themselves [px].
  static const _arrowGap = 24.0;

  /// How far to the left of ▶'s place the ◀ of the last page sits [px]. In
  /// the very place of ▶ it looked too far to the right.
  static const _lastBackShift = 10.0;

  /// The left of the last page's ◀: its triangle where ▶'s is on the other
  /// pages, but [_lastBackShift] further left.
  static final _lastBackLeft =
      _PageArrowButton.boxLeft(
        next: false,
        visibleLeft: _PageArrowButton.visibleLeft(
          next: true,
          boxLeft: _nextLeft,
        ),
      ) -
      _lastBackShift;

  /// The left of ◀ so that it sits to the left of ▶, [_arrowGap] apart.
  static final _backBesideNextLeft = _PageArrowButton.boxLeft(
    next: false,
    visibleLeft:
        _PageArrowButton.visibleLeft(next: true, boxLeft: _nextLeft) -
        _arrowGap -
        _PageArrowButton.triangleLength,
  );

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
                switch (_page) {
                  _Page.controls => HowToPlayPopup.page1Heading,
                  _Page.tips => HowToPlayPopup.page2Heading,
                  _Page.credits => HowToPlayPopup.page3Heading,
                },
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
          ...switch (_page) {
            _Page.controls => _controlsPage(),
            _Page.tips => _tipsPage(),
            _Page.credits => _creditsPage(),
          },
        ],
      ),
    );
  }

  /// Page 1/2: the lead text and the playable demo (Figma: ゲーム画面). Real
  /// play replaces Figma's static mockup and its drag-hint icon: the lead
  /// text and the game's own aim guide (dots and arrow while dragging)
  /// explain the controls instead.
  List<Widget> _controlsPage() => [
    _lead(top: 70, 'ドラッグして食べ物を投げよう！\n新婦の口元にあたると得点が入るよ'),
    const HowToPlayGame(),
    _nextButton(_Page.tips),
  ];

  /// Page 2/3: the tips, with ◀ to the controls beside ▶ to the credits.
  List<Widget> _tipsPage() => [
    const Positioned(left: 30, top: 85, child: HowToPlayTips()),
    _lead(top: 269, 'ハイスコアを目指して頑張ろう！\n何か良いことがあるかも...？'),
    _backButton(_Page.controls, left: _backBesideNextLeft),
    _nextButton(_Page.credits),
  ];

  /// Page 3/3: the credits and the note on the play results, with ◀ to the
  /// tips, near where ▶ is on the other pages.
  List<Widget> _creditsPage() => [
    const Positioned(left: 30, top: 78, child: CreditsTable()),
    // At the height of the tips page's closing text, on one line, short of
    // ◀.
    _lead(top: 269, width: 400, HowToPlayPopup.recordNote),
    _backButton(_Page.tips, left: _lastBackLeft),
  ];

  /// Returns the ▶ button that goes to [page].
  Widget _nextButton(_Page page) => Positioned(
    left: _nextLeft,
    top: _arrowTop,
    child: _PageArrowButton(
      semanticLabel: '次のページ',
      next: true,
      onPressed: () => _show(page),
    ),
  );

  /// Returns the ◀ button that goes to [page], its box [left] px from the
  /// popup's left.
  Widget _backButton(_Page page, {required double left}) => Positioned(
    left: left,
    top: _arrowTop,
    child: _PageArrowButton(
      semanticLabel: '前のページ',
      next: false,
      onPressed: () => _show(page),
    ),
  );

  /// Returns the outlined lead [text] of a page, [top] px from the popup's
  /// top, in a box [width] px wide (enough for two short lines by default).
  static Widget _lead(String text, {required double top, double width = 276}) =>
      Positioned(
        left: 30,
        top: top,
        width: width,
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedText(
            text,
            style: GameTextStyles.howToLead,
            outlineWidth: 2,
            textAlign: TextAlign.left,
          ),
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

  /// What screen readers announce.
  final String semanticLabel;

  /// True for ▶ (next page), false for ◀ (previous page).
  final bool next;

  final VoidCallback onPressed;

  static const _box = 70.0;

  /// How far the triangle reaches along the button's axis once turned: the
  /// SVG's height [px]. It leaves the rest of the box empty on the side it
  /// points away from.
  static const triangleLength = 52.5;

  /// Returns the left edge of the visible triangle for a box at [boxLeft].
  /// The turned ▶ is flush with the right of its box, the ◀ with the left.
  static double visibleLeft({required bool next, required double boxLeft}) =>
      next ? boxLeft + _box - triangleLength : boxLeft;

  /// Returns the left of the box that puts the triangle's left edge at
  /// [visibleLeft]: the inverse of [visibleLeft].
  static double boxLeft({required bool next, required double visibleLeft}) =>
      next ? visibleLeft - (_box - triangleLength) : visibleLeft;

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
