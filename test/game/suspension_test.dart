import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/audio/sound_controller.dart';
import 'package:pendulum_feeding_game/game/flame/pendulum_feeding_game.dart';
import 'package:pendulum_feeding_game/game/model/game_config.dart';
import 'package:pendulum_feeding_game/game/model/game_session.dart';
import 'package:pendulum_feeding_game/math/vec2.dart';

import '../audio/fake_sound_backend.dart';

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

  group('a game that asks to resume', () {
    ({PendulumFeedingGame game, FakeSoundBackend backend}) playing() {
      final backend = FakeSoundBackend();
      final game = PendulumFeedingGame(
        session: GameSession(
          config: const GameConfig(countdownSeconds: 0, startCueSeconds: 0),
        ),
        sound: SoundController(backend)..setEnabled(true),
        asksToResume: true,
      )..startCountdown();
      game.update(_frame);
      expect(game.session.phase, GamePhase.playing);
      return (game: game, backend: backend);
    }

    test('stopped in portrait, waits for resume after rotating back, with '
        'the music held', () async {
      final (:game, :backend) = playing();
      _run(game, 30);
      game.portrait = true;
      expect(game.awaitingResume.value, isTrue);
      final held = _motion(game);

      game.portrait = false;
      expect(game.isSuspended, isTrue);
      _run(game, 120);
      expect(_motion(game), held);
      await pumpEventQueue();
      expect(backend.calls, ['unmute', 'mute', 'hold']);

      game.resume();
      expect(game.awaitingResume.value, isFalse);
      expect(game.isSuspended, isFalse);
      _run(game, 60);
      expect(game.session.remainingSeconds, closeTo(held.$1 - 1, 1e-9));
      await pumpEventQueue();
      expect(backend.calls, ['unmute', 'mute', 'hold', 'release', 'unmute']);
    });

    test('back in front, waits for resume too', () {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        final (:game, backend: _) = playing();
        game.lifecycleStateChange(state);
        game.lifecycleStateChange(AppLifecycleState.resumed);
        expect(game.awaitingResume.value, isTrue, reason: '$state');
        final held = _motion(game);
        _run(game, 60);
        expect(_motion(game), held, reason: '$state');

        game.resume();
        _run(game, 60);
        expect(game.session.remainingSeconds, lessThan(held.$1));
      }
    });

    test('in the countdown as well', () {
      final game = PendulumFeedingGame(
        session: GameSession(),
        asksToResume: true,
      )..startCountdown();
      _run(game, 30);
      game.portrait = true;
      game.portrait = false;
      expect(game.awaitingResume.value, isTrue);
      _run(game, 300);
      expect(game.session.phase, GamePhase.countdown);
    });

    test('but not on the setup screen, where no time runs', () {
      final game = PendulumFeedingGame(
        session: GameSession(),
        asksToResume: true,
      );
      game.portrait = true;
      game.portrait = false;
      expect(game.awaitingResume.value, isFalse);
      expect(game.isSuspended, isFalse);
    });

    test('resuming a game that does not wait does nothing', () async {
      final (:game, :backend) = playing();
      game.resume();
      await pumpEventQueue();
      expect(backend.calls, ['unmute']);
    });
  });

  test('a game that does not ask to resume never waits for it', () {
    final game = _playing();
    game.portrait = true;
    game.portrait = false;
    expect(game.awaitingResume.value, isFalse);
    expect(game.isSuspended, isFalse);
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
