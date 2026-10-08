/// The game screen: one play-through with its Flutter layers.
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/sound_controller.dart';
import '../game/flame/pendulum_feeding_game.dart';
import '../game/model/game_session.dart';
import '../physics/double_pendulum.dart';
import '../ranking/ranking_models.dart';
import '../ranking/ranking_service.dart';
import '../ui/assets.dart';
import '../ui/widgets/stage.dart';
import '../ui/widgets/tile_button.dart';
import 'countdown_overlay.dart';
import 'landscape_guard.dart';
import 'play_bonus_gauge.dart';
import 'result_popup.dart';
import 'resume_overlay.dart';
import 'setup_overlay.dart';
import 'sound_button.dart';
import 'sound_scope.dart';
import 'title_screen.dart';

/// Hosts one play-through at a time, with Flutter layers chosen by the
/// session phase around the Flame game. Everything is laid out in the
/// 844x390 stage coordinates.
///
/// From back to front: the stage background, the setup hint and play-count
/// bonus gauge, the game (transparent), the overlays (buttons, countdown,
/// result), then "TAP TO RESUME" over everything while the game waits for
/// it.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.ranking});

  /// Records finished games; without it the player is a guest.
  final RankingService? ranking;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late PendulumFeedingGame _game = _newGame();

  /// The ranking of the current game, for the result popup.
  final _ranking = ValueNotifier<RankingStatus>(const RankingPending());

  /// Returns a new game for the player's current play count, starting the
  /// setup screen from [placedPendulum] if given (a retry), and recording
  /// the game when it finishes.
  PendulumFeedingGame _newGame([PendulumState? placedPendulum]) {
    late final PendulumFeedingGame game;
    game = PendulumFeedingGame(
      session: GameSession(
        placedPendulum: placedPendulum,
        gamesPlayed: widget.ranking?.gamesPlayed ?? 0,
      ),
      onGameFinished: (score) => _record(game, score),
      sound: SoundScope.maybeOf(context),
      asksToResume: true,
    )..portrait = _isPortrait;
    return game;
  }

  /// Records a finished game. Only the current game's answer is shown; a
  /// game left for a new one is still recorded. A game that failed to record
  /// but was recorded on a second try in the background shows its ranks
  /// then, if its result is still up.
  Future<void> _record(PendulumFeedingGame game, int score) async {
    final ranking = widget.ranking;
    _ranking.value = ranking == null
        ? const RankingGuest()
        : const RankingPending();
    if (ranking == null) return;

    void show(RankingStatus status) {
      if (mounted && identical(game, _game)) _ranking.value = status;
    }

    // Kept, so that the failure, which may be reported after it, does not
    // replace it.
    RankingStatus? late;
    RankingStatus status;
    try {
      status = await ranking.recordGame(
        score,
        onLateResult: (status) => show(late = status),
      );
    } on Object {
      status = const RankingFailed();
    }
    show(late ?? status);
  }

  /// もう一度, or giving up mid-game: a fresh session from the setup screen,
  /// with the pendulum placed as last time. An abandoned game is not
  /// recorded.
  void _retry() {
    _stopApplause();
    setState(() {
      _game = _newGame(_game.session.placedPendulum);
      _ranking.value = const RankingPending();
    });
  }

  /// Whether the screen is in portrait, where the game holds still under
  /// the prompt to rotate the device.
  bool get _isPortrait => LandscapeGuard.isPortrait(MediaQuery.sizeOf(context));

  /// Holds the game still while in portrait; picked up again on rotating.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.portrait = _isPortrait;
  }

  @override
  void dispose() {
    _ranking.dispose();
    super.dispose();
  }

  /// Cuts off the applause of the result, which is still sounding if the
  /// player leaves it at once.
  void _stopApplause() => SoundScope.maybeOf(context)?.stopSfx(Sfx.claps);

  /// Leaves for the title screen.
  void _goToTitle() {
    _stopApplause();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TitleScreen(ranking: widget.ranking),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      body: StageViewport(
        child: Stack(
          children: [
            const Positioned.fill(child: StageBackground()),
            Positioned.fill(
              child: ValueListenableBuilder(
                valueListenable: game.phase,
                builder: (context, phase, _) => phase == GamePhase.setup
                    ? Stack(
                        children: [
                          const SetupHint(),
                          PlayBonusGauge(
                            uplift: game.session.playBonus.uplift,
                            maxUplift: game.session.playBonus.maxUplift,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Positioned.fill(
              child: GameWidget(key: ObjectKey(game), game: game),
            ),
            Positioned.fill(
              child: ValueListenableBuilder(
                valueListenable: game.phase,
                builder: (context, phase, _) => _overlay(game, phase),
              ),
            ),
            const SoundButton(),
            Positioned.fill(
              child: ValueListenableBuilder(
                valueListenable: game.awaitingResume,
                builder: (context, awaiting, _) => awaiting
                    ? ResumeOverlay(onResume: game.resume)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the Flutter layers in front of [game] for [phase]: the スタート
  /// button, the countdown, the retry button, or the result.
  Widget _overlay(PendulumFeedingGame game, GamePhase phase) {
    switch (phase) {
      case GamePhase.setup:
        return SetupOverlay(onStart: game.startCountdown);
      case GamePhase.countdown:
        return Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder(
                valueListenable: game.countdownNumber,
                builder: (context, number, _) =>
                    CountdownOverlay(number: number),
              ),
            ),
            _retryButton(),
          ],
        );
      case GamePhase.playing:
        return Stack(children: [_retryButton()]);
      case GamePhase.finished:
        return Stack(
          children: [
            const Positioned.fill(child: BlurOverlay(tint: BlurOverlay.dark)),
            Positioned(
              left: 172,
              top: 45,
              child: ValueListenableBuilder(
                valueListenable: _ranking,
                builder: (context, ranking, _) => ResultPopup(
                  score: game.session.score,
                  ranking: ranking,
                  onRetry: _retry,
                  onTitle: _goToTitle,
                ),
              ),
            ),
          ],
        );
    }
  }

  /// Figma: ゲーム画面 リトライボタン, at (10, 7).
  Widget _retryButton() => Positioned(
    left: 10,
    top: 7,
    child: IconTileButton(
      icon: GameAssets.retryIcon,
      // The 55x50 icon (63x58 with its stroke) scaled to Figma's 36x33.
      iconSize: const Size(63 * 36 / 55, 58 * 36 / 55),
      semanticLabel: 'やり直す',
      onPressed: _retry,
    ),
  );
}
