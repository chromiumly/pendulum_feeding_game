/// The slide on how the game was made: from the tools to the guests'
/// phones, as a diagram.
library;

import 'package:flutter/material.dart';

import '../presentation_assets.dart';
import '../slide_frame.dart';
import '../slide_style.dart';
import '../talk_content.dart';
import 'slide_parts.dart';

/// Two dashed frames, making (これまで) and playing (本日): the tools for the
/// images, music and sounds lead to the design, the code and the game,
/// which GitHub Pages hands to the guests' phones; the game on the phone
/// records to Firebase.
class MakingSlide extends StatelessWidget {
  const MakingSlide({super.key});

  /// The top of the tall cards, and their height.
  static const _cardTop = 570.0;
  static const _cardHeight = 297.0;

  /// The tall cards' middle, where the lines between the cards run.
  static const _lineY = _cardTop + _cardHeight / 2;

  /// The wide cards: their height, and from one top to the next. The middle
  /// one (Google Flow Music) is level with the tall cards.
  static const _materialHeight = 126.0;
  static const _materialStep = 158.0;
  static const _materialTop = _lineY - _materialHeight / 2 - _materialStep;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const SlideBackground(),
        const SlideHeader(title: TalkMaking.title, message: TalkMaking.message),

        // Playing (本日), under the making frame where GitHub Pages crosses.
        const Positioned(
          left: 1338,
          top: 374,
          width: 528,
          height: 613,
          child: DashedFrame(
            color: SlidePalette.cardTeal,
            fill: SlidePalette.playingFill,
          ),
        ),
        _section(TalkMaking.playing, left: 1376),
        ..._phone(),
        _toolCard(
          left: 1663,
          icon: PresentationAssets.firebase,
          name: 'Firebase',
          role: '記録',
          edge: SlidePalette.cardTeal,
        ),

        // Making (これまで).
        const Positioned(
          left: 53,
          top: 374,
          width: 1261,
          height: 613,
          child: DashedFrame(
            color: SlidePalette.cardGold,
            fill: SlidePalette.makingFill,
          ),
        ),
        _section(TalkMaking.making, left: 95),
        for (final (i, (icon, name, role)) in const [
          (PresentationAssets.googleFlow, 'Google Flow', '画像'),
          (PresentationAssets.googleFlowMusic, 'Google Flow Music', '音楽'),
          (PresentationAssets.otologic, 'Otologic', '効果音'),
        ].indexed)
          _materialCard(
            top: _materialTop + _materialStep * i,
            icon: icon,
            name: name,
            role: role,
          ),
        _toolCard(
          left: 565,
          icon: PresentationAssets.figma,
          name: 'Figma',
          role: 'デザイン',
          edge: SlidePalette.cardGold,
        ),
        _toolCard(
          left: 790,
          icon: PresentationAssets.claude,
          name: 'Claude\nCode',
          role: '実装',
          edge: SlidePalette.cardGold,
        ),
        _toolCard(
          left: 1015,
          icon: PresentationAssets.flutter,
          name: 'Flutter',
          role: 'ゲーム',
          edge: SlidePalette.cardPink,
        ),
        _toolCard(
          left: 1240,
          icon: PresentationAssets.github,
          name: 'GitHub\nPages',
          role: '置き場',
          edge: SlidePalette.cardTeal,
        ),
        // Made with AI: Google Flow, Google Flow Music and Claude Code.
        const Positioned(left: 95, top: _materialTop - 26, child: _AiBalloon()),
        const Positioned(
          left: 95,
          top: _materialTop + _materialStep - 26,
          child: _AiBalloon(),
        ),
        const Positioned(left: 790, top: 544, child: _AiBalloon()),

        const Positioned.fill(child: CustomPaint(painter: _ConnectorPainter())),
        _connectorLabel('MCP', centreX: 766, centreY: _lineY - 14),
        _connectorLabel('公開', centreX: 1215, centreY: _lineY - 14),
        _connectorLabel('通信', centreX: 1637, centreY: _lineY - 14),
      ],
    );
  }

  static Widget _section(String text, {required double left}) => Positioned(
    left: left,
    top: 388,
    height: 78,
    child: Center(child: SlideText(text, style: SlideTextStyles.section)),
  );

  /// A wide card of a tool for the material: its icon, name and role.
  static Widget _materialCard({
    required double top,
    required String icon,
    required String name,
    required String role,
  }) {
    return Positioned(
      left: 95,
      top: top,
      width: 421,
      height: _materialHeight,
      child: Container(
        decoration: accentCard(SlidePalette.cardGold),
        padding: const EdgeInsets.only(left: 13, right: 8),
        child: Row(
          children: [
            ShadowedIcon(icon, size: 80),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Google Flow Music only just fits: shrunk if it does not.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SlideText(name, style: SlideTextStyles.cardName),
                  ),
                  const SizedBox(height: 12),
                  SlideText(
                    role,
                    style: SlideTextStyles.cardRole.copyWith(height: 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A tall card of a tool: its icon, its name (one or two lines) and its
  /// role.
  static Widget _toolCard({
    required double left,
    required String icon,
    required String name,
    required String role,
    required Color edge,
  }) {
    return Positioned(
      left: left,
      top: _cardTop,
      width: 176,
      height: _cardHeight,
      child: Container(
        decoration: accentCard(edge),
        child: Stack(
          children: [
            Positioned(left: 23, top: 21, child: ShadowedIcon(icon, size: 120)),
            // The name's middle at 194 from the top, the role's at 257.
            Positioned(
              left: 0,
              right: 0,
              top: 194 - 5 - 40,
              height: 80,
              child: Center(
                child: SlideText(
                  name,
                  style: SlideTextStyles.cardName,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 257 - 5 - 25,
              height: 50,
              child: Center(
                child: SlideText(role, style: SlideTextStyles.cardRole),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The phone image's drawn size over its pixel size.
  static const _phoneScaleX = 157 / 520;
  static const _phoneScaleY = 295 / 980;

  /// The phone: the game running on it, in a pink card with the Flutter
  /// icon.
  static List<Widget> _phone() => [
    Positioned(
      left: 1385,
      top: 515,
      width: 302,
      height: 68,
      child: Center(
        child: SlideText('みなさんのスマホ', style: SlideTextStyles.phoneLabel),
      ),
    ),
    Positioned(
      left: 1457,
      top: 572,
      width: 157,
      height: 295,
      child: Image.asset(PresentationAssets.smartphone, fit: BoxFit.fill),
    ),
    // On the phone's screen exactly: the image's screen is at (50, 105) to
    // (470, 910) of 520x980, radius 40.
    Positioned(
      left: 1457 + 50 * _phoneScaleX,
      top: 572 + 105 * _phoneScaleY,
      width: 420 * _phoneScaleX,
      height: 805 * _phoneScaleY,
      child: Container(
        decoration: accentCard(
          SlidePalette.cardPink,
          radius: 40 * _phoneScaleX,
          shadow: false,
        ),
      ),
    ),
    const Positioned(
      left: 1486,
      top: 631,
      child: ShadowedIcon(PresentationAssets.flutter, size: 100),
    ),
    Positioned(
      left: 1462,
      top: 749,
      width: 146,
      height: 68,
      child: Center(
        child: SlideText(
          'ゲームが\n動く',
          style: SlideTextStyles.phoneLabel,
          textAlign: TextAlign.center,
        ),
      ),
    ),
  ];

  static Widget _connectorLabel(
    String text, {
    required double centreX,
    required double centreY,
  }) {
    return Positioned(
      left: centreX - 29,
      top: centreY - 15.5,
      width: 58,
      height: 31,
      child: Center(
        child: SlideText(text, style: SlideTextStyles.connectorLabel),
      ),
    );
  }
}

/// "AI" in a red balloon pointing down at the card it is on.
class _AiBalloon extends StatelessWidget {
  const _AiBalloon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 51,
      height: 52,
      child: CustomPaint(
        painter: const _BalloonPainter(),
        // In the middle of the box, not of the box and its point.
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 42,
            child: Center(child: Text('AI', style: SlideTextStyles.aiBalloon)),
          ),
        ),
      ),
    );
  }
}

class _BalloonPainter extends CustomPainter {
  const _BalloonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = SlidePalette.aiBalloon;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 51, 42),
          const Radius.circular(10),
        ),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(26 - 8.66, 40)
          ..lineTo(26 + 8.66, 40)
          ..lineTo(26, 52)
          ..close(),
        paint,
      );
  }

  @override
  bool shouldRepaint(_BalloonPainter oldDelegate) => false;
}

/// The lines between the cards: from the three materials to Figma, and on
/// from card to card.
class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter();

  /// The wide cards' right edge and their middles, and the tall cards'
  /// left edge.
  static const _materialsRight = 516.0;
  static const _figmaLeft = 565.0;
  static const _y = MakingSlide._lineY;
  static const _step = MakingSlide._materialStep;

  static const _lines = [
    // The three materials to Figma: the middle one straight across.
    (Offset(_materialsRight, _y - _step), Offset(_figmaLeft, _y)),
    (Offset(_materialsRight, _y), Offset(_figmaLeft, _y)),
    (Offset(_materialsRight, _y + _step), Offset(_figmaLeft, _y)),
    // On from card to card, through their middles.
    (Offset(741, _y), Offset(790, _y)),
    (Offset(966, _y), Offset(1015, _y)),
    (Offset(1190, _y), Offset(1240, _y)),
    (Offset(1416, _y), Offset(1461, _y)),
    (Offset(1611, _y), Offset(1663, _y)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SlidePalette.connector
      ..strokeWidth = 3;
    for (final (a, b) in _lines) {
      canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) => false;
}
