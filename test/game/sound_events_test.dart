import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/audio/sound_controller.dart';
import 'package:pendulum_feeding_game/game/flame/pendulum_feeding_game.dart';
import 'package:pendulum_feeding_game/game/model/food.dart';
import 'package:pendulum_feeding_game/game/model/game_config.dart';
import 'package:pendulum_feeding_game/game/model/game_session.dart';
import 'package:pendulum_feeding_game/math/vec2.dart';
import 'package:pendulum_feeding_game/physics/double_pendulum.dart';

import '../audio/fake_sound_backend.dart';

/// One frame at 60 Hz, which is one fixed step.
const _frame = 1 / 60;

const _hanging = PendulumState(
  upperTheta: 0,
  lowerTheta: 0,
  upperOmega: 0,
  lowerOmega: 0,
);

/// A playing game with sound on, over a still pendulum, with the food above
/// the bride's mouth so that a throw straight down is eaten.
({PendulumFeedingGame game, FakeSoundBackend backend}) _playing() {
  final mouth = GameSession(
    config: const GameConfig(
      pendulumInitialState: _hanging,
      startEnergyTopMultiple: 0,
    ),
  ).mouthPosition;
  final backend = FakeSoundBackend();
  final sound = SoundController(backend)..setEnabled(true);
  final game = PendulumFeedingGame(
    session: GameSession(
      config: GameConfig(
        pendulumInitialState: _hanging,
        startEnergyTopMultiple: 0,
        countdownSeconds: 0,
        startCueSeconds: 0,
        foodSpawnPosition: mouth - const Vec2(0, 80),
        foodTypes: const [FoodType(id: 'test', points: 100)],
        foodHitRadius: 10,
      ),
      random: math.Random(1),
    ),
    sound: sound,
  )..startCountdown();
  game.update(_frame);
  expect(game.session.phase, GamePhase.playing);
  return (game: game, backend: backend);
}

/// A game with sound on over a still pendulum that is over after
/// [timeLimitSeconds] of play, with no countdown. The food hangs [drop] px
/// above the bride's mouth, so that a throw straight down is eaten after
/// falling that far.
({PendulumFeedingGame game, FakeSoundBackend backend}) _timed({
  required int timeLimitSeconds,
  double drop = 80,
}) {
  final mouth = GameSession(
    config: const GameConfig(
      pendulumInitialState: _hanging,
      startEnergyTopMultiple: 0,
    ),
  ).mouthPosition;
  final backend = FakeSoundBackend();
  final game = PendulumFeedingGame(
    session: GameSession(
      config: GameConfig(
        pendulumInitialState: _hanging,
        startEnergyTopMultiple: 0,
        countdownSeconds: 0,
        startCueSeconds: 0,
        timeLimitSeconds: timeLimitSeconds,
        foodSpawnPosition: mouth - Vec2(0, drop),
        foodTypes: const [FoodType(id: 'test', points: 100)],
        foodHitRadius: 10,
      ),
      random: math.Random(1),
    ),
    sound: SoundController(backend)..setEnabled(true),
  )..startCountdown();
  game.update(_frame);
  expect(game.session.phase, GamePhase.playing);
  return (game: game, backend: backend);
}

/// Throws the food with [velocity] [px/s], and runs frames until [done].
void _throwAndRun(
  PendulumFeedingGame game,
  Vec2 velocity,
  bool Function() done,
) {
  const start = Vec2(400, 200);
  game.session
    ..beginAim(start)
    ..updateAim(start - velocity * (1 / game.session.config.launchScale))
    ..releaseAim();
  for (var i = 0; i < 120 && !done(); i++) {
    game.update(_frame);
  }
}

void main() {
  test('nothing plays until something happens', () {
    final (:game, :backend) = _playing();
    expect(backend.effects, isEmpty);
    expect(game.session.food.isFlying, isFalse);
  });

  test('throwing plays the throw effect, once, as the food is let go', () {
    final (:game, :backend) = _playing();
    const start = Vec2(400, 200);
    game.session
      ..beginAim(start)
      ..updateAim(const Vec2(430, 240))
      ..releaseAim();
    game.update(_frame);
    expect(game.session.food.isFlying, isTrue);
    expect(backend.effects, [Sfx.throwFood]);
    // Not again while it flies.
    game.update(_frame);
    expect(backend.effects, [Sfx.throwFood]);
  });

  test('a cancelled too-short drag plays nothing', () {
    final (:game, :backend) = _playing();
    game.session
      ..beginAim(const Vec2(400, 200))
      ..updateAim(const Vec2(405, 200))
      ..releaseAim();
    game.update(_frame);
    expect(game.session.food.isFlying, isFalse);
    expect(backend.effects, isEmpty);
  });

  test('eating plays the eating effect after the throw effect', () {
    final (:game, :backend) = _playing();
    _throwAndRun(game, const Vec2(0, 300), () => game.session.score > 0);
    expect(backend.effects, [Sfx.throwFood, Sfx.eat]);
  });

  test('a food that leaves the world makes no sound of its own', () {
    final (:game, :backend) = _playing();
    var missed = false;
    const start = Vec2(400, 200);
    game.session
      ..beginAim(start)
      ..updateAim(start - const Vec2(900, 0) * (1 / 4))
      ..releaseAim();
    for (var i = 0; i < 120 && !missed; i++) {
      game.update(_frame);
      missed = !game.session.food.isFlying;
    }
    expect(missed, isTrue);
    expect(game.session.score, 0);
    expect(backend.effects, [Sfx.throwFood]);
  });

  test('with sound off, or no sound at all, nothing plays', () {
    final (:game, :backend) = _playing();
    game.sound!.setEnabled(false);
    _throwAndRun(game, const Vec2(0, 300), () => game.session.score > 0);
    expect(backend.effects, isEmpty);

    final silent = PendulumFeedingGame(session: GameSession())
      ..startCountdown();
    expect(() => silent.update(_frame), returnsNormally);
  });

  test('the whistle sounds once, as START appears', () {
    final backend = FakeSoundBackend();
    final game = PendulumFeedingGame(
      session: GameSession(
        config: const GameConfig(
          pendulumInitialState: _hanging,
          startEnergyTopMultiple: 0,
        ),
      ),
      sound: SoundController(backend)..setEnabled(true),
    )..startCountdown();

    // Silent through 3, 2 and 1.
    while (game.countdownNumber.value != 0) {
      expect(backend.effects, isEmpty);
      game.update(_frame);
    }
    // Sounded in the very frame START is shown.
    expect(game.phase.value, GamePhase.countdown);
    expect(backend.effects, [Sfx.whistle]);

    // And not again while START shows, or when play begins.
    while (game.phase.value == GamePhase.countdown) {
      game.update(_frame);
    }
    expect(game.phase.value, GamePhase.playing);
    expect(backend.effects, [Sfx.whistle]);
  });

  test('a game without a countdown, like the how-to-play demo, is silent', () {
    final (:game, :backend) = _playing();
    for (var i = 0; i < 30; i++) {
      game.update(_frame);
    }
    expect(backend.effects, isEmpty);
  });

  test('the applause sounds once, as the result comes up', () {
    final (:game, :backend) = _timed(timeLimitSeconds: 1);
    while (game.phase.value == GamePhase.playing) {
      expect(backend.effects, isEmpty);
      game.update(_frame);
    }
    expect(game.phase.value, GamePhase.finished);
    expect(backend.effects, [Sfx.claps]);

    // Not again while the result stays.
    for (var i = 0; i < 30; i++) {
      game.update(_frame);
    }
    expect(backend.effects, [Sfx.claps]);
  });

  test('after a buzzer beater the applause waits for the result', () {
    // The food is thrown 10 steps before time is up and lands after it.
    final (:game, :backend) = _timed(timeLimitSeconds: 1, drop: 150);
    for (var i = 0; i < 20; i++) {
      game.update(_frame);
    }
    const start = Vec2(400, 200);
    game.session
      ..beginAim(start)
      ..updateAim(
        start - const Vec2(0, 300) * (1 / game.session.config.launchScale),
      )
      ..releaseAim();

    while (!game.session.isFinished) {
      game.update(_frame);
    }
    // The game is over and the last food scored, but the result is held back
    // for the score effect: no applause yet.
    expect(game.session.score, 100);
    expect(game.phase.value, GamePhase.playing);
    expect(backend.effects, [Sfx.throwFood, Sfx.eat]);

    while (game.phase.value != GamePhase.finished) {
      game.update(_frame);
    }
    expect(backend.effects, [Sfx.throwFood, Sfx.eat, Sfx.claps]);
  });

  test('with sound off the whistle and the applause are silent', () {
    final (:game, :backend) = _timed(timeLimitSeconds: 1);
    game.sound!.setEnabled(false);
    while (game.phase.value == GamePhase.playing) {
      game.update(_frame);
    }
    expect(backend.effects, isEmpty);
  });
}
