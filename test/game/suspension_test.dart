import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/flame/pendulum_feeding_game.dart';
import 'package:pendulum_feeding_game/game/model/game_config.dart';
import 'package:pendulum_feeding_game/game/model/game_session.dart';
import 'package:pendulum_feeding_game/math/vec2.dart';

/// One frame at 60 Hz, which is one fixed step.
const _frame = 1 / 60;

/// A game in play, with the pendulum swinging.
PendulumFeedingGame _playing() {
  final game = PendulumFeedingGame(
    session: GameSession(
      config: const GameConfig(countdownSeconds: 0, startCueSeconds: 0),
    ),
  )..startCountdown();
  game.update(_frame);
  expect(game.session.phase, GamePhase.playing);
  return game;
}

void _run(PendulumFeedingGame game, int frames) {
  for (var i = 0; i < frames; i++) {
    game.update(_frame);
  }
}

/// What moves in a game: the clock and the pendulum.
(double, double, double) _motion(PendulumFeedingGame game) => (
  game.session.remainingSeconds,
  game.session.pendulumState.upperTheta,
  game.session.pendulumState.lowerTheta,
);

void main() {
  test('in portrait the clock and the pendulum stand still, and carry on '
      'from there on rotating back', () {
    final game = _playing();
    _run(game, 30);
    game.portrait = true;
    expect(game.isSuspended, isTrue);
    final held = _motion(game);

    _run(game, 120);
    expect(_motion(game), held);

    game.portrait = false;
    expect(game.isSuspended, isFalse);
    _run(game, 60);
    expect(game.session.remainingSeconds, closeTo(held.$1 - 1, 1e-9));
    expect(game.session.pendulumState.upperTheta, isNot(held.$2));
  });

  test('the countdown stands still too', () {
    final game = PendulumFeedingGame(session: GameSession())..startCountdown();
    _run(game, 30);
    game.portrait = true;
    _run(game, 300);
    expect(game.session.phase, GamePhase.countdown);
    expect(game.countdownNumber.value, 3);

    game.portrait = false;
    _run(game, 300);
    expect(game.session.phase, GamePhase.playing);
  });

  test('an aim under way is dropped, and throws nothing on coming back', () {
    final game = _playing();
    game.session
      ..beginAim(const Vec2(400, 200))
      ..updateAim(const Vec2(300, 260));
    expect(game.session.aim, isNotNull);

    game.portrait = true;
    expect(game.session.aim, isNull);

    game.portrait = false;
    game.session.releaseAim(); // The finger, if it comes up after all.
    _run(game, 5);
    expect(game.session.food.isFlying, isFalse);
  });

  test('in the background, or with something else in front, the game '
      'stands still', () {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      final game = _playing();
      game.lifecycleStateChange(state);
      expect(game.isSuspended, isTrue, reason: '$state');
      final held = _motion(game);
      _run(game, 120);
      expect(_motion(game), held, reason: '$state');

      game.lifecycleStateChange(AppLifecycleState.resumed);
      expect(game.isSuspended, isFalse, reason: '$state');
      _run(game, 60);
      expect(
        game.session.remainingSeconds,
        lessThan(held.$1),
        reason: '$state',
      );
    }
  });

  test('back in front while still in portrait, it stays held', () {
    final game = _playing();
    game.lifecycleStateChange(AppLifecycleState.hidden);
    game.portrait = true;
    game.lifecycleStateChange(AppLifecycleState.resumed);
    expect(game.isSuspended, isTrue);
    final held = _motion(game);
    _run(game, 60);
    expect(_motion(game), held);

    game.portrait = false;
    _run(game, 60);
    expect(game.session.remainingSeconds, lessThan(held.$1));
  });
}
