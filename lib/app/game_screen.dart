import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/flame/pendulum_feeding_game.dart';
import '../game/model/game_session.dart';
import '../ui/widgets/stage.dart';
import 'countdown_overlay.dart';
import 'result_popup.dart';
import 'setup_overlay.dart';
import 'title_screen.dart';

/// Hosts one play-through at a time, with Flutter overlays chosen by the
/// session phase on top of the Flame game. Everything is laid out in the
/// 844x390 stage coordinates.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  PendulumFeedingGame _game = _newGame();

  static PendulumFeedingGame _newGame() =>
      PendulumFeedingGame(session: GameSession());

  /// もう一度: a fresh session, starting again from the setup screen.
  void _retry() {
    setState(() => _game = _newGame());
  }

  void _goToTitle() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const TitleScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      body: StageViewport(
        child: Stack(
          children: [
            Positioned.fill(
              child: GameWidget(key: ObjectKey(game), game: game),
            ),
            Positioned.fill(
              child: ValueListenableBuilder(
                valueListenable: game.phase,
                builder: (context, phase, _) => _overlay(game, phase),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overlay(PendulumFeedingGame game, GamePhase phase) {
    switch (phase) {
      case GamePhase.setup:
        return SetupOverlay(onStart: game.startCountdown);
      case GamePhase.countdown:
        return ValueListenableBuilder(
          valueListenable: game.countdownNumber,
          builder: (context, number, _) => CountdownOverlay(number: number),
        );
      case GamePhase.playing:
        return const SizedBox.shrink();
      case GamePhase.finished:
        return Stack(
          children: [
            const Positioned.fill(child: BlurOverlay(tint: BlurOverlay.dark)),
            Positioned(
              left: 185,
              top: 65,
              child: ResultPopup(
                score: game.session.score,
                onRetry: _retry,
                onTitle: _goToTitle,
              ),
            ),
          ],
        );
    }
  }
}
