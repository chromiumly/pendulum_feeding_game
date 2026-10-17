import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/model/game_config.dart';
import 'package:pendulum_feeding_game/game/model/game_session.dart';
import 'package:pendulum_feeding_game/presentation/slides/pendulum_demo.dart';

void main() {
  test('the slide\'s pendulum starts as a game does after スタート', () {
    final session = GameSession(
      config: const GameConfig(),
      random: math.Random(1),
    )..startCountdown();
    final game = session.pendulumState;
    final demo = PendulumDemo.startState();

    expect(demo.upperTheta, game.upperTheta);
    expect(demo.lowerTheta, game.lowerTheta);
    expect(demo.upperOmega, game.upperOmega);
    expect(demo.lowerOmega, game.lowerOmega);
    expect(demo.upperOmega, isNot(0)); // It is given its speed.
  });
}
