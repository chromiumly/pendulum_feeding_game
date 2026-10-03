/// The title screen and its how-to-play popup.
library;

import 'package:flutter/material.dart';

import '../ranking/ranking_service.dart';
import '../ui/assets.dart';
import '../ui/text_styles.dart';
import '../ui/widgets/outlined_text.dart';
import '../ui/widgets/round_icon_button.dart';
import '../ui/widgets/stage.dart';
import 'game_screen.dart';
import 'how_to_play_popup.dart';
import 'sound_button.dart';

/// The title screen: tap to start, or "?" for how to play.
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key, this.ranking});

  /// Passed on to the game; null plays as a guest.
  final RankingService? ranking;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with SingleTickerProviderStateMixin {
  /// Whether the how-to-play popup is shown instead of the title.
  bool _showHowToPlay = false;

  /// "TAP TO START" fades between 50% and 100% opacity, never fully out.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  late final Animation<double> _pulseOpacity = Tween<double>(
    begin: 1,
    end: 0.5,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Leaves for the game screen.
  void _start() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(ranking: widget.ranking),
      ),
    );
  }

  void _setHowToPlay(bool show) => setState(() => _showHowToPlay = show);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StageViewport(
        child: Stack(
          children: [
            const Positioned.fill(child: StageBackground()),
            const Positioned.fill(child: BlurOverlay(tint: BlurOverlay.light)),
            if (_showHowToPlay) ..._howToPlay() else ..._title(),
            const SoundButton(),
          ],
        ),
      ),
    );
  }

  /// Figma: タイトル画面. Tapping anywhere except the "?" button starts.
  List<Widget> _title() => [
    Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _start,
        child: Stack(
          children: [
            Positioned(
              left: 34,
              top: 104,
              width: 775,
              height: 103,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: OutlinedText(
                    '花嫁もぐもぐチャレンジ！',
                    style: GameTextStyles.title,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 272,
              top: 244,
              width: 300,
              height: 60,
              child: Center(
                child: FadeTransition(
                  opacity: _pulseOpacity,
                  child: OutlinedText(
                    'TAP TO START',
                    style: GameTextStyles.tapToStart,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    Positioned(
      left: 775.5,
      top: 10.5,
      child: RoundIconButton(
        icon: GameAssets.helpIcon,
        semanticLabel: '遊び方',
        circleOffset: const Offset(3.5, 1.5),
        shadow: true,
        onPressed: () => _setHowToPlay(true),
      ),
    ),
  ];

  /// Figma: 遊び方画面. Tapping outside the popup also closes it.
  List<Widget> _howToPlay() => [
    Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setHowToPlay(false),
      ),
    ),
    Positioned(
      left: 140,
      top: 25,
      child: GestureDetector(
        // Swallow taps on the popup so they do not close it.
        onTap: () {},
        child: HowToPlayPopup(onClose: () => _setHowToPlay(false)),
      ),
    ),
  ];
}
