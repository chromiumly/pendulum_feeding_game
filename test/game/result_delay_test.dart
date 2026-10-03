import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/flame/components/eaten_effect.dart';
import 'package:pendulum_feeding_game/game/flame/pendulum_feeding_game.dart';
import 'package:pendulum_feeding_game/game/model/food.dart';
import 'package:pendulum_feeding_game/game/model/game_config.dart';
import 'package:pendulum_feeding_game/game/model/game_session.dart';
import 'package:pendulum_feeding_game/math/vec2.dart';
import 'package:pendulum_feeding_game/physics/double_pendulum.dart';

const _frame = 1 / 60;

/// A session in play, [stepsLeft] steps before the time limit.
GameSession _playingSession(GameConfig config, {required int stepsLeft}) {
  final session = GameSession(config: config, random: math.Random(1))
    ..startCountdown();
  while (session.phase != GamePhase.playing) {
    session.step();
  }
  for (var i = 0; i < config.timeLimitSteps! - stepsLeft; i++) {
    session.step();
  }
  return session;
}

/// Advances the game until the session has finished; returns the frames.
int _runUntilFinished(PendulumFeedingGame game) {
  var frames = 0;
  while (!game.session.isFinished && frames < 300) {
    game.update(_frame);
    frames++;
  }
  expect(game.session.isFinished, isTrue);
  return frames;
}

void main() {
  test('a buzzer beater shows its score effect before the result', () {
    // As in the session test: a still pendulum, and a food dropped onto the
    // mouth from high enough to land after the time limit.
    const hanging = PendulumState(
      upperTheta: 0,
      lowerTheta: 0,
      upperOmega: 0,
      lowerOmega: 0,
    );
    final mouth = GameSession(
      config: const GameConfig(
        pendulumInitialState: hanging,
        startEnergyTopMultiple: 0,
      ),
    ).mouthPosition;
    final config = GameConfig(
      pendulumInitialState: hanging,
      startEnergyTopMultiple: 0,
      foodSpawnPosition: mouth - const Vec2(0, 150),
      foodTypes: const [FoodType(id: 'test', points: 100)],
      foodHitRadius: 10,
    );
    final session = _playingSession(config, stepsLeft: 10);
    const start = Vec2(400, 200);
    session
      ..beginAim(start)
      ..updateAim(start - const Vec2(0, 300) * (1 / config.launchScale))
      ..releaseAim();

    final game = PendulumFeedingGame(session: session);
    _runUntilFinished(game);
    expect(session.score, 100);
    // The result waits for the effect and a short pause.
    expect(game.phase.value, GamePhase.playing);

    const wait = EatenEffect.duration + PendulumFeedingGame.resultPause;
    var waited = 0.0;
    while (game.phase.value != GamePhase.finished && waited < 3) {
      game.update(_frame);
      waited += _frame;
    }
    expect(game.phase.value, GamePhase.finished);
    expect(waited, closeTo(wait, 2 * _frame));
  });

  test('without a score effect the result shows at once', () {
    final session = _playingSession(const GameConfig(), stepsLeft: 5);
    final game = PendulumFeedingGame(session: session);
    _runUntilFinished(game);
    expect(game.phase.value, GamePhase.finished);
  });
}
