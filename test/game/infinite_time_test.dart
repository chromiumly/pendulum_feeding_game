import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/app/how_to_play_game.dart';
import 'package:pendulum_feeding_game/game/model/game_config.dart';
import 'package:pendulum_feeding_game/game/model/game_session.dart';

void main() {
  group('unlimited time (GameConfig.timeLimitSeconds: null)', () {
    const config = GameConfig(timeLimitSeconds: null);

    test('timeLimitSteps is null', () {
      expect(config.timeLimitSteps, isNull);
    });

    test('a session never times up, however long it plays', () {
      final session = GameSession(config: config)..startCountdown();
      while (session.phase != GamePhase.playing) {
        session.step();
      }
      for (var i = 0; i < 10000; i++) {
        session.step();
      }
      expect(session.isTimeUp, isFalse);
      expect(session.isFinished, isFalse);
      expect(session.remainingSeconds, double.infinity);
    });
  });

  group('howToPlayGameConfig', () {
    test('has no time limit and an instant countdown', () {
      expect(howToPlayGameConfig.timeLimitSeconds, isNull);
      expect(howToPlayGameConfig.countdownSeconds, 0);
      expect(howToPlayGameConfig.startCueSeconds, 0);
    });

    test('starts as a near-straight line, swinging only on its own', () {
      final state = howToPlayGameConfig.pendulumInitialState;
      expect(state.upperTheta, state.lowerTheta);
      expect(state.upperTheta, greaterThan(0));
      expect(state.upperOmega, 0);
      expect(state.lowerOmega, 0);
      // No start speed is added on top of that: the energy bonus is 0.
      expect(howToPlayGameConfig.startEnergyTopMultiple, 0);
    });

    test('reaches playing on the very first step, invisibly', () {
      final session = GameSession(config: howToPlayGameConfig)
        ..startCountdown();
      expect(session.phase, GamePhase.countdown);
      session.step();
      expect(session.phase, GamePhase.playing);
    });
  });
}
