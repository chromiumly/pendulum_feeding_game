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
import 'package:pendulum_feeding_game/physics/pendulum_energy.dart';

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

/// [actual] is a placed angle: in [0, 2pi) and equal to [expected] modulo
/// 2pi.
void _expectAngle(double actual, double expected) {
  expect(actual, inInclusiveRange(0, 2 * math.pi));
  expect(actual < 2 * math.pi, isTrue);
  expect(wrapAngle(actual - expected).abs(), lessThan(1e-9));
}

/// One game step of the pendulum with the physics core alone: RK4 at
/// fixedDt / physicsSubsteps, physicsSubsteps times.
PendulumState _physicsStep(GameConfig config, PendulumState state) {
  final pendulum = DoublePendulum(config.pendulumParams);
  var next = state;
  for (var i = 0; i < config.physicsSubsteps; i++) {
    next = pendulum.step(next, config.fixedDt / config.physicsSubsteps);
  }
  return next;
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
    var expected = session.pendulumState;
    for (var i = 0; i < 120; i++) {
      session.step();
      expected = _physicsStep(session.config, expected);
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
      expect(
        session.pendulumState.toList(),
        const GameConfig().pendulumInitialState.toList(),
      );
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
        // Still where it was placed; only the start speed was set.
        final state = session.pendulumState;
        expect(
          state.upperTheta,
          const GameConfig().pendulumInitialState.upperTheta,
        );
        expect(
          state.lowerTheta,
          const GameConfig().pendulumInitialState.lowerTheta,
        );
        expect(state.lowerOmega, greaterThan(0));
        expect(state.upperOmega, closeTo(-state.lowerOmega, 1e-12));
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
      _expectAngle(session.pendulumState.upperTheta, 0);
      expect(
        session.pendulumState.lowerTheta,
        const GameConfig().pendulumInitialState.lowerTheta,
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
      // -90 degrees, normalized to 270.
      _expectAngle(session.pendulumState.lowerTheta, 3 * math.pi / 2);
      expect(
        session.pendulumState.upperTheta,
        const GameConfig().pendulumInitialState.upperTheta,
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
        _expectAngle(
          session.pendulumState.lowerTheta,
          const GameConfig().pendulumInitialState.lowerTheta - 0.3,
        );
      },
    );

    test('the joint can go all the way round, straight up included', () {
      final session = _setupSession();
      final origin = session.config.pendulumOrigin;
      Vec2 at(double theta) =>
          origin + Vec2(math.sin(theta), math.cos(theta)) * 70;

      final start = session.pendulumState.upperTheta;
      session.beginPlacement(session.pendulumPositions.upper);
      // From where it starts, over the top and once all the way round.
      for (var theta = start; theta <= start + 2 * math.pi; theta += 0.2) {
        session.updatePlacement(at(theta));
        _expectAngle(session.pendulumState.upperTheta, theta);
      }

      session.updatePlacement(at(math.pi));
      _expectAngle(session.pendulumState.upperTheta, math.pi);
      expect(
        session.pendulumPositions.upper.distanceTo(origin - const Vec2(0, 70)),
        closeTo(0, 1e-9),
      );
    });

    test('the other way round, angles below 0 wrap to just under 360', () {
      final session = _setupSession();
      final origin = session.config.pendulumOrigin;
      Vec2 at(double theta) =>
          origin + Vec2(math.sin(theta), math.cos(theta)) * 70;

      // Up to +0.5 from where it starts (-45 degrees), then back past 0.
      final start = wrapAngle(session.pendulumState.upperTheta);
      session.beginPlacement(session.pendulumPositions.upper);
      for (var theta = start; theta <= 0.5; theta += 0.1) {
        session.updatePlacement(at(theta));
      }
      for (var theta = 0.5; theta >= -0.5; theta -= 0.1) {
        session.updatePlacement(at(theta));
      }
      session.updatePlacement(at(-0.5));
      expect(
        session.pendulumState.upperTheta,
        closeTo(2 * math.pi - 0.5, 1e-9),
      );
    });

    test(
      'hanging straight down, the pendulum gets its start speed at スタート',
      () {
        final session = _setupSession();
        final origin = session.config.pendulumOrigin;
        // Both rods turned in small moves from where they start to 0.
        final upperStart = wrapAngle(session.pendulumState.upperTheta);
        final lowerStart = wrapAngle(session.pendulumState.lowerTheta);
        session.beginPlacement(session.pendulumPositions.upper);
        for (var i = 1; i < 20; i++) {
          final theta = upperStart * (1 - i / 20);
          session.updatePlacement(
            origin + Vec2(math.sin(theta), math.cos(theta)) * 70,
          );
        }
        session
          ..updatePlacement(origin + const Vec2(0, 70))
          ..endPlacement();
        final joint = session.pendulumPositions.upper;
        session.beginPlacement(session.pendulumPositions.lower);
        for (var i = 1; i < 20; i++) {
          final theta = lowerStart * (1 - i / 20);
          session.updatePlacement(
            joint + Vec2(math.sin(theta), math.cos(theta)) * 100,
          );
        }
        session
          ..updatePlacement(joint + const Vec2(0, 100))
          ..endPlacement();
        expect(session.pendulumState.lowerOmega, 0);

        session.startCountdown();
        final started = session.pendulumState;
        final params = session.config.pendulumParams;
        expect(started.lowerOmega, greaterThan(0)); // toward the groom
        expect(started.upperOmega, closeTo(-started.lowerOmega, 1e-12));
        expect(
          totalEnergy(params, started),
          closeTo(
            session.config.startEnergyTopMultiple * brideTopEnergy(params),
            1e-6,
          ),
        );

        // Frozen through the countdown, then play starts from that state.
        _runCountdown(session);
        expect(session.pendulumState.toList(), started.toList());
        session.step();
        expect(
          session.pendulumState.toList(),
          _physicsStep(session.config, started).toList(),
        );
      },
    );

    test('grabbing empty space or dragging outside setup does nothing', () {
      final session = _setupSession()
        ..beginPlacement(const Vec2(800, 20))
        ..updatePlacement(const Vec2(700, 300));
      expect(session.activeHandle, isNull);
      expect(
        session.pendulumState.toList(),
        const GameConfig().pendulumInitialState.toList(),
      );

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
      final started = session.pendulumState;
      expect(started.upperTheta, placed.upperTheta);
      expect(started.lowerTheta, placed.lowerTheta);
      final omegas = startOmegas(
        params: session.config.pendulumParams,
        state: placed,
        targetEnergy:
            session.config.startEnergyTopMultiple *
            brideTopEnergy(session.config.pendulumParams),
        counterSpinRatio: session.config.startCounterSpinRatio,
      );
      expect(started.upperOmega, omegas.upperOmega);
      expect(started.lowerOmega, omegas.lowerOmega);

      _runCountdown(session);
      var expected = started;
      for (var i = 0; i < 60; i++) {
        session.step();
        expected = _physicsStep(session.config, expected);
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
      foodTypes: const [FoodType(id: 'test', points: 100)],
      foodHitRadius: 10,
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

  group('combo', () {
    // A still pendulum, so that every food dropped from the spawn point
    // lands in the mouth.
    const hanging = PendulumState(
      upperTheta: 0,
      lowerTheta: 0,
      upperOmega: 0,
      lowerOmega: 0,
    );

    GameSession comboSession() {
      final probe = _session(
        const GameConfig(
          pendulumInitialState: hanging,
          startEnergyTopMultiple: 0,
        ),
      );
      return _session(
        GameConfig(
          pendulumInitialState: hanging,
          startEnergyTopMultiple: 0,
          foodSpawnPosition: probe.mouthPosition - const Vec2(0, 80),
          foodTypes: const [FoodType(id: 'test', points: 100)],
          foodHitRadius: 10,
        ),
      );
    }

    /// Throws [velocity] and steps until the food is eaten or missed.
    GameEvent throwFood(GameSession session, Vec2 velocity) {
      _throw(session, velocity);
      for (var i = 0; i < 120; i++) {
        session.step();
        final events = session.takeEvents().where(
          (e) => e is FoodEaten || e is FoodMissed,
        );
        if (events.isNotEmpty) return events.single;
      }
      fail('The food was neither eaten nor missed.');
    }

    FoodEaten eat(GameSession session) =>
        throwFood(session, const Vec2(0, 300)) as FoodEaten;

    void miss(GameSession session) =>
        expect(throwFood(session, const Vec2(900, 0)), isA<FoodMissed>());

    test('each food in a row is worth 0.2 x its points more', () {
      final session = comboSession();
      expect(session.combo, 0);
      final eaten = [for (var i = 0; i < 3; i++) eat(session)];
      expect([for (final e in eaten) e.combo], [1, 2, 3]);
      expect([for (final e in eaten) e.points], [100, 120, 140]);
      expect(session.combo, 3);
      expect(session.score, 360);
    });

    test('a miss breaks the run', () {
      final session = comboSession();
      eat(session);
      eat(session);
      miss(session);
      expect(session.combo, 0);
      final next = eat(session);
      expect(next.combo, 1);
      expect(next.points, 100);
      expect(session.score, 100 + 120 + 100);
    });
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

  group('buzzer beater', () {
    void runSteps(GameSession session, int count) {
      for (var i = 0; i < count; i++) {
        session.step();
      }
    }

    test('a food eaten after the time limit still scores', () {
      // A still pendulum, hanging straight down, so the mouth does not move;
      // the food is dropped onto it from high enough to land after time up.
      const hanging = PendulumState(
        upperTheta: 0,
        lowerTheta: 0,
        upperOmega: 0,
        lowerOmega: 0,
      );
      final probe = _session(
        const GameConfig(
          pendulumInitialState: hanging,
          startEnergyTopMultiple: 0,
        ),
      );
      final config = GameConfig(
        pendulumInitialState: hanging,
        startEnergyTopMultiple: 0,
        foodSpawnPosition: probe.mouthPosition - const Vec2(0, 150),
        foodTypes: const [FoodType(id: 'test', points: 100)],
        foodHitRadius: 10,
      );
      final session = _session(config);
      final limit = config.timeLimitSteps;
      runSteps(session, limit - 10);
      _throw(session, const Vec2(0, 300));
      session.takeEvents();

      runSteps(session, 10);
      expect(session.isTimeUp, isTrue);
      expect(session.isFinished, isFalse); // Still in the air.
      expect(session.remainingSeconds, 0);
      expect(session.food.isFlying, isTrue);

      var extra = 0;
      while (!session.isFinished && extra < 120) {
        session.step();
        extra++;
      }
      expect(extra, greaterThan(0));
      expect(session.isFinished, isTrue);
      expect(session.score, 100);
      expect(session.remainingSeconds, 0);
      final events = session.takeEvents();
      expect(events.whereType<FoodEaten>(), hasLength(1));
      expect(events.whereType<GameFinished>().single.score, 100);
    });

    test('a food that misses after the time limit ends the game', () {
      final session = _session();
      final limit = session.config.timeLimitSteps;
      runSteps(session, limit - 5);
      // Straight right, out of the world after about 10 steps.
      _throw(session, const Vec2(900, 0));
      session.takeEvents();

      runSteps(session, 5);
      expect(session.isTimeUp, isTrue);
      expect(session.isFinished, isFalse);

      var extra = 0;
      while (!session.isFinished && extra < 120) {
        session.step();
        extra++;
      }
      expect(extra, greaterThan(0));
      expect(session.score, 0);
      final events = session.takeEvents();
      expect(events.whereType<FoodMissed>(), hasLength(1));
      expect(events.whereType<GameFinished>(), hasLength(1));
    });

    test(
      'while a buzzer beater flies, the pendulum moves and no one throws',
      () {
        final session = _session();
        final limit = session.config.timeLimitSteps;
        runSteps(session, limit - 1);
        _throw(session, const Vec2(0, -600)); // Up, so it flies a while.
        runSteps(session, 1);
        expect(session.isTimeUp, isTrue);
        expect(session.isFinished, isFalse);

        final before = session.pendulumState.toList();
        session.step();
        expect(session.pendulumState.toList(), isNot(before));

        // The food is in the air, so no aim; and once time is up there would
        // be no new throw even with a ready food.
        session.beginAim(const Vec2(400, 200));
        expect(session.aim, isNull);
      },
    );
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
