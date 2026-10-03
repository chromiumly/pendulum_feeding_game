import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import '../game/flame/pendulum_feeding_game.dart';
import '../game/model/game_config.dart';
import '../game/model/game_session.dart';
import '../physics/double_pendulum.dart';
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
/// popup (147, 252, 422, 195): a quarter of the full 844x390 stage.
///
/// A fresh [GameSession] each time this widget is built, so that leaving
/// and returning to this page starts over.
class HowToPlayGame extends StatefulWidget {
  const HowToPlayGame({super.key});

  // Measured from the Figma screenshot: its raw node coordinates are for an
  // internal rotated layout the exported React/Tailwind code already
  // resolves per-node, but not consistently enough to trust verbatim here.
  static const left = 30.0;
  static const top = 122.0;
  static const size = Size(422, 195);

  @override
  State<HowToPlayGame> createState() => _HowToPlayGameState();
}

class _HowToPlayGameState extends State<HowToPlayGame> {
  late final _game = PendulumFeedingGame(
    session: GameSession(config: howToPlayGameConfig),
    showHitCircles: true,
  )..startCountdown();

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
          child: Stack(
            children: [
              const StageBackground(),
              GameWidget(game: _game),
            ],
          ),
        ),
      ),
    );
  }
}
