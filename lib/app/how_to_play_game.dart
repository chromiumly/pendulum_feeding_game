/// The playable demo on page 1 of the how-to-play popup, with its drag hint.
library;

import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import '../game/flame/pendulum_feeding_game.dart';
import '../game/model/game_config.dart';
import '../game/model/game_session.dart';
import '../physics/double_pendulum.dart';
import '../ui/assets.dart';
import '../ui/widgets/stage.dart';

/// Where the how-to-play demo starts, and stays near: both rods at the same
/// small angle, so the pendulum hangs as a near-straight line, swinging only
/// as far as this little potential energy carries it (no start speed is
/// added, see [howToPlayGameConfig]). The physics has no damping, so this
/// gentle sway never dies down or grows.
const _almostStraight = PendulumState(
  upperTheta: 0.1,
  lowerTheta: 0.1,
  upperOmega: 0,
  lowerOmega: 0,
);

/// The how-to-play popup's playable demo (Figma: 遊び方画面（1/2） ゲーム画
/// 面): the real game, so that trying the controls here is exactly like
/// playing for real, except that it never ends.
final howToPlayGameConfig = GameConfig(
  pendulumInitialState: _almostStraight,
  // No start speed on top of the above: startOmegas only adds energy up to
  // this multiple of the bride's own, and she already has more than none.
  startEnergyTopMultiple: 0,
  // Playing starts the moment the demo is built; see HowToPlayGame.
  countdownSeconds: 0,
  startCueSeconds: 0,
  timeLimitSeconds: null,
);

/// Plays the demo at its Figma position and size inside the how-to-play
/// popup (30, 122, 422, 195): the full 844x390 stage at half size.
///
/// A fresh [GameSession] each time this widget is built, so that leaving
/// and returning to this page starts over.
///
/// A hand shows how to drag until the player touches the game, and again
/// after [hintIdle] without a touch.
class HowToPlayGame extends StatefulWidget {
  const HowToPlayGame({super.key});

  // Measured from the Figma screenshot: its raw node coordinates are for an
  // internal rotated layout the exported React/Tailwind code already
  // resolves per-node, but not consistently enough to trust verbatim here.
  static const left = 30.0;
  static const top = 122.0;
  static const size = Size(422, 195);

  static const hintIdle = Duration(seconds: 5);

  /// The drag hint, while it is shown.
  static const hintKey = Key('howToPlayDragHint');

  @override
  State<HowToPlayGame> createState() => _HowToPlayGameState();
}

class _HowToPlayGameState extends State<HowToPlayGame> {
  late final _game = PendulumFeedingGame(
    session: GameSession(config: howToPlayGameConfig),
    showHitCircles: true,
  )..startCountdown();

  bool _showHint = true;

  /// Brings the hint back after [HowToPlayGame.hintIdle] without a touch.
  Timer? _idle;

  /// Hides the hint while the player touches the game.
  void _onTouch() {
    _idle?.cancel();
    if (_showHint) setState(() => _showHint = false);
  }

  /// Starts the wait to bring the hint back once the finger is lifted.
  void _onRelease() {
    _idle?.cancel();
    _idle = Timer(HowToPlayGame.hintIdle, () {
      if (mounted) setState(() => _showHint = true);
    });
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: HowToPlayGame.left,
      top: HowToPlayGame.top,
      width: HowToPlayGame.size.width,
      height: HowToPlayGame.size.height,
      // The 844x390 world (background included, as in StageViewport) at this
      // quarter size, the same way StageViewport scales the whole app to
      // fit the screen.
      child: FittedBox(
        child: SizedBox(
          width: howToPlayGameConfig.worldSize.x,
          height: howToPlayGameConfig.worldSize.y,
          // Listener does not take part in the gesture arena, so the game
          // still gets every drag.
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _onTouch(),
            onPointerUp: (_) => _onRelease(),
            onPointerCancel: (_) => _onRelease(),
            child: Stack(
              children: [
                const StageBackground(),
                GameWidget(game: _game),
                if (_showHint) const _DragHint(key: HowToPlayGame.hintKey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A hand that presses beside the groom and drags to the lower right, over
/// and over, in world coordinates. Drawing only: it does not throw.
class _DragHint extends StatefulWidget {
  const _DragHint({super.key});

  @override
  State<_DragHint> createState() => _DragHintState();
}

class _DragHintState extends State<_DragHint>
    with SingleTickerProviderStateMixin {
  /// Figma: ドラッグ, 25x37 at (614, 226) / 2 in the half-size demo.
  static const _size = Size(50, 74);
  static const _start = Offset(614, 226);
  static const _drag = Offset(100, 70);

  /// One press, drag and release, starting afresh each time it is shown.
  late final _cycle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  /// Returns [t] from [from] to [to] as 0 to 1, clamped; all are fractions
  /// of the animation cycle.
  static double _part(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _cycle,
        builder: (context, child) {
          final t = _cycle.value;
          // Fade in, press, drag, release, fade out.
          final opacity = t < 0.8 ? _part(t, 0, 0.12) : 1 - _part(t, 0.8, 1);
          final press = _part(t, 0.12, 0.22) - _part(t, 0.7, 0.8);
          final move = Curves.easeInOut.transform(_part(t, 0.22, 0.7));
          final topLeft = _start + _drag * move;
          return Stack(
            children: [
              Positioned(
                left: topLeft.dx,
                top: topLeft.dy,
                width: _size.width,
                height: _size.height,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(scale: 1 - 0.1 * press, child: child),
                ),
              ),
            ],
          );
        },
        child: Image.asset(GameAssets.dragHand),
      ),
    );
  }
}
