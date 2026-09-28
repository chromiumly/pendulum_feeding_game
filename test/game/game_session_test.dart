import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/model/food.dart';
import 'package:pendulum_feeding_game/game/model/game_config.dart';
import 'package:pendulum_feeding_game/game/model/game_event.dart';
import 'package:pendulum_feeding_game/game/model/game_session.dart';
import 'package:pendulum_feeding_game/game/model/rules.dart';
import 'package:pendulum_feeding_game/game/model/setup_rules.dart';
import 'package:pendulum_feeding_game/math/vec2.dart';
import 'package:pendulum_feeding_game/physics/double_pendulum.dart';

GameSession _setupSession([GameConfig config = const GameConfig()]) =>
    GameSession(config: config, random: math.Random(1));

void _runCountdown(GameSession session) {
  final steps = session.config.countdownSteps + session.config.startCueSteps;
  for (var i = 0; i < steps; i++) {
    session.step();
  }
}

/// A session that went through setup untouched and the whole countdown.
GameSession _session([GameConfig config = const GameConfig()]) {
  final session = _setupSession(config)..startCountdown();
  _runCountdown(session);
  expect(session.phase, GamePhase.playing);
  return session;
}

/// Drags so that the launch velocity equals [velocity] exactly.
void _throw(GameSession session, Vec2 velocity) {
  const start = Vec2(400, 200);
  session
    ..beginAim(start)
    ..updateAim(start - velocity * (1 / session.config.launchScale))
    ..releaseAim();
}

void main() {
  test('starts playing with the full time and a ready food', () {
    final session = _session();
    expect(session.remainingSeconds, 20);
    expect(session.score, 0);
    expect(session.food.phase, FoodPhase.ready);
    expect(session.food.position, session.config.foodSpawnPosition);
  });

  test('pendulum follows the physics core step by step', () {
    final session = _session();
    const pendulum = DoublePendulum();
    var expected = PendulumState.initial;
    for (var i = 0; i < 120; i++) {
      session.step();
      expected = pendulum.step(expected, 1 / 60);
    }
    expect(session.pendulumState.toList(), expected.toList());
  });

  group('phases', () {
    test('a session starts in setup, where nothing moves', () {
      final session = _setupSession();
      expect(session.phase, GamePhase.setup);
      for (var i = 0; i < 120; i++) {
        session.step();
      }
      expect(session.pendulumState.toList(), PendulumState.initial.toList());
      expect(session.remainingSeconds, 20);
      session.beginAim(const Vec2(400, 200));
      expect(session.aim, isNull);
    });

    test(
      'countdown shows 3, 2, 1, START and then plays, frozen until then',
      () {
        final session = _setupSession()..startCountdown();
        expect(session.phase, GamePhase.countdown);

        final numbers = <int>[];
        final steps =
            session.config.countdownSteps + session.config.startCueSteps;
        for (var i = 0; i < steps; i++) {
          numbers.add(session.countdownNumber);
          expect(session.phase, GamePhase.countdown);
          session.beginAim(const Vec2(400, 200));
          expect(session.aim, isNull);
          session.step();
        }
        expect(numbers.sublist(0, 60), everyElement(3));
        expect(numbers.sublist(60, 120), everyElement(2));
        expect(numbers.sublist(120, 180), everyElement(1));
        expect(numbers.sublist(180), everyElement(0));
        expect(numbers.sublist(180), hasLength(48)); // 0.8 s of "START"

        expect(session.phase, GamePhase.playing);
        expect(session.pendulumState.toList(), PendulumState.initial.toList());
        expect(session.remainingSeconds, 20);
        expect(session.takeEvents(), isEmpty);
      },
    );

    test('the countdown can only be started from setup', () {
      final session = _session()..startCountdown();
      expect(session.phase, GamePhase.playing);
    });
  });

  group('placement', () {
    test('dragging the joint sets upperTheta around the pivot', () {
      final session = _setupSession();
      final origin = session.config.pendulumOrigin;
      session
        ..beginPlacement(session.pendulumPositions.upper)
        ..updatePlacement(origin + const Vec2(0, 70));
      expect(session.activeHandle, SetupHandle.joint);
      expect(session.pendulumState.upperTheta, closeTo(0, 1e-12));
      expect(
        session.pendulumState.lowerTheta,
        PendulumState.initial.lowerTheta,
      );
      expect(session.pendulumState.upperOmega, 0);
      expect(session.pendulumState.lowerOmega, 0);
      expect(
        session.pendulumPositions.upper.distanceTo(origin + const Vec2(0, 70)),
        closeTo(0, 1e-9),
      );
      session.endPlacement();
      expect(session.activeHandle, isNull);
    });

    test('dragging the bride sets lowerTheta around the joint', () {
      final session = _setupSession();
      final joint = session.pendulumPositions.upper;
      session
        ..beginPlacement(session.pendulumPositions.lower)
        // Via straight down: a drag moves in small increments.
        ..updatePlacement(joint + const Vec2(0, 80))
        ..updatePlacement(joint + const Vec2(-80, 0));
      expect(session.activeHandle, SetupHandle.bride);
      expect(session.pendulumState.lowerTheta, closeTo(-math.pi / 2, 1e-12));
      expect(
        session.pendulumState.upperTheta,
        PendulumState.initial.upperTheta,
      );
      expect(session.pendulumState.upperOmega, 0);
      expect(session.pendulumState.lowerOmega, 0);
    });

    test(
      'a drag moves the rod by the pointer rotation, not to the pointer',
      () {
        final session = _setupSession();
        final joint = session.pendulumPositions.upper;
        final start = session.mouthPosition;
        // Rotate the grab point by -0.3 rad around the joint.
        session
          ..beginPlacement(start)
          ..updatePlacement(joint + (start - joint).rotated(0.3));
        expect(
          session.pendulumState.lowerTheta,
          closeTo(PendulumState.initial.lowerTheta - 0.3, 1e-9),
        );
      },
    );

    test(
      'angles are limited, and dragging back past the limit is continuous',
      () {
        final session = _setupSession();
        final limit = session.config.setupAngleLimit;
        final origin = session.config.pendulumOrigin;
        Vec2 at(double theta) =>
            origin + Vec2(math.sin(theta), math.cos(theta)) * 70;

        session.beginPlacement(session.pendulumPositions.upper);
        // Over the top and down the other side: stays at +limit, no jump.
        for (final theta in [2.6, 3.0, 3.3, 3.8]) {
          session.updatePlacement(at(theta));
          expect(session.pendulumState.upperTheta, closeTo(limit, 1e-12));
        }
        // Back again: follows once inside the range.
        session.updatePlacement(at(2.0));
        expect(session.pendulumState.upperTheta, closeTo(2.0, 1e-9));
      },
    );

    test('grabbing empty space or dragging outside setup does nothing', () {
      final session = _setupSession()
        ..beginPlacement(const Vec2(800, 20))
        ..updatePlacement(const Vec2(700, 300));
      expect(session.activeHandle, isNull);
      expect(session.pendulumState.toList(), PendulumState.initial.toList());

      session
        ..startCountdown()
        ..beginPlacement(session.pendulumPositions.upper);
      expect(session.activeHandle, isNull);
    });

    test('play starts from the placed state with the unchanged physics', () {
      final session = _setupSession();
      session
        ..beginPlacement(session.pendulumPositions.upper)
        ..updatePlacement(session.config.pendulumOrigin + const Vec2(70, 0))
        ..endPlacement();
      final placed = session.pendulumState;
      expect(placed.upperTheta, closeTo(math.pi / 2, 1e-12));

      session.startCountdown();
      _runCountdown(session);
      const pendulum = DoublePendulum();
      var expected = placed;
      for (var i = 0; i < 60; i++) {
        session.step();
        expected = pendulum.step(expected, 1 / 60);
      }
      expect(session.pendulumState.toList(), expected.toList());
    });
  });

  group('aiming', () {
    test('a drag throws the food with the slingshot velocity', () {
      final session = _session();
      session
        ..beginAim(const Vec2(400, 200))
        ..updateAim(const Vec2(430, 240))
        ..releaseAim();
      expect(session.food.isFlying, isTrue);
      expect(session.food.velocity, const Vec2(-120, -160));
      expect(session.takeEvents(), [isA<FoodLaunched>()]);
    });

    test('a drag shorter than minDragDistance is cancelled', () {
      final session = _session();
      session
        ..beginAim(const Vec2(400, 200))
        ..updateAim(const Vec2(405, 200))
        ..releaseAim();
      expect(session.food.isFlying, isFalse);
      expect(session.aim, isNull);
      expect(session.takeEvents(), isEmpty);
    });

    test('cannot aim while the food is flying', () {
      final session = _session();
      _throw(session, const Vec2(-100, -100));
      session.beginAim(const Vec2(10, 10));
      expect(session.aim, isNull);
    });
  });

  test('eating the food scores and respawns a ready food', () {
    // Put the spawn point next to the mouth and drop the food onto it.
    final probe = _session();
    final mouth = probe.mouthPosition;
    final config = GameConfig(
      foodSpawnPosition: mouth - const Vec2(0, 80),
      foodTypes: const [FoodType(id: 'test', hitRadius: 10)],
    );
    final session = _session(config);
    _throw(session, const Vec2(0, 300));

    var steps = 0;
    while (session.score == 0 && steps < 60) {
      session.step();
      steps++;
    }
    expect(session.score, 100);
    expect(session.food.phase, FoodPhase.ready);
    expect(session.food.position, config.foodSpawnPosition);
    final events = session.takeEvents();
    expect(events.whereType<FoodEaten>(), hasLength(1));
  });

  test('food leaving the world is a miss and respawns', () {
    final session = _session();
    _throw(session, const Vec2(900, 0));
    for (
      var i = 0;
      i < 60 && !session.takeEvents().any((e) => e is FoodMissed);
      i++
    ) {
      session.step();
    }
    expect(session.score, 0);
    expect(session.food.phase, FoodPhase.ready);
  });

  group('time limit', () {
    test('finishes after exactly 20 s of fixed steps', () {
      final session = _session();
      for (var i = 0; i < 1199; i++) {
        session.step();
      }
      expect(session.isFinished, isFalse);
      expect(session.remainingSeconds.ceil(), 1);

      session.step();
      expect(session.isFinished, isTrue);
      expect(session.remainingSeconds, 0);
      expect(
        session.takeEvents().whereType<GameFinished>().single.score,
        session.score,
      );
    });

    test('stops simulation and input after finishing', () {
      final session = _session();
      for (var i = 0; i < 1200; i++) {
        session.step();
      }
      final frozen = session.pendulumState.toList();
      session
        ..step()
        ..beginAim(const Vec2(400, 200));
      expect(session.pendulumState.toList(), frozen);
      expect(session.aim, isNull);
    });

    test('an aim in progress is dropped at time up', () {
      final session = _session();
      session.beginAim(const Vec2(400, 200));
      for (var i = 0; i < 1200; i++) {
        session.step();
      }
      session
        ..updateAim(const Vec2(500, 300))
        ..releaseAim();
      expect(session.food.isFlying, isFalse);
    });
  });

  test('guide prediction matches the in-game flight at the same dt', () {
    final session = _session();
    const velocity = Vec2(-500, -300);
    final predicted = predictTrajectory(
      position: session.food.position,
      velocity: velocity,
      gravity: session.config.foodGravity,
      dt: session.config.fixedDt,
      count: 10,
    );
    _throw(session, velocity);
    for (var i = 0; i < 10; i++) {
      session.step();
    }
    expect(session.food.position.x, closeTo(predicted.last.x, 1e-9));
    expect(session.food.position.y, closeTo(predicted.last.y, 1e-9));
  });
}
