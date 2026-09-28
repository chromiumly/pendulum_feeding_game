import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/model/game_config.dart';
import 'package:pendulum_feeding_game/game/model/setup_rules.dart';
import 'package:pendulum_feeding_game/math/vec2.dart';
import 'package:pendulum_feeding_game/physics/double_pendulum.dart';
import 'package:pendulum_feeding_game/physics/pendulum_energy.dart';

void main() {
  test('pendulumAngle inverts DoublePendulum.positions', () {
    const pendulum = DoublePendulum();
    const origin = Vec2(237.5, 116.5);
    for (final (upper, lower) in [(0.0, 0.0), (2.3, -1.1), (-0.7, 2.9)]) {
      final positions = pendulum.positions(
        PendulumState(
          upperTheta: upper,
          lowerTheta: lower,
          upperOmega: 0,
          lowerOmega: 0,
        ),
        origin,
      );
      expect(pendulumAngle(origin, positions.upper), closeTo(upper, 1e-12));
      expect(
        pendulumAngle(positions.upper, positions.lower),
        closeTo(lower, 1e-12),
      );
    }
  });

  test('normalizeAngle maps into [0, 2pi)', () {
    expect(normalizeAngle(0), 0);
    expect(normalizeAngle(math.pi), closeTo(math.pi, 1e-12));
    expect(normalizeAngle(2 * math.pi), closeTo(0, 1e-12));
    expect(normalizeAngle(-0.5), closeTo(2 * math.pi - 0.5, 1e-12));
    expect(normalizeAngle(7), closeTo(7 - 2 * math.pi, 1e-12));
  });

  test('wrapAngle maps into (-pi, pi]', () {
    expect(wrapAngle(0), 0);
    expect(wrapAngle(math.pi), closeTo(math.pi, 1e-12));
    expect(wrapAngle(-math.pi), closeTo(math.pi, 1e-12));
    expect(wrapAngle(1.5 * math.pi), closeTo(-0.5 * math.pi, 1e-12));
    expect(wrapAngle(-1.5 * math.pi), closeTo(0.5 * math.pi, 1e-12));
  });

  test('distanceToSegment', () {
    const a = Vec2(0, 0);
    const b = Vec2(10, 0);
    expect(distanceToSegment(const Vec2(5, 3), a, b), 3);
    expect(distanceToSegment(const Vec2(-4, 3), a, b), 5);
    expect(distanceToSegment(const Vec2(1, 1), a, a), math.sqrt2);
  });

  group('pickSetupHandle', () {
    SetupHandle? pick(Vec2 point) => pickSetupHandle(
      point: point,
      joint: const Vec2(100, 100),
      brideNode: const Vec2(100, 180),
      brideMouth: const Vec2(110, 130),
      jointGrabRadius: 24,
      brideGrabRadius: 48,
    );

    test('joint within its radius, winning over the bride', () {
      expect(pick(const Vec2(110, 110)), SetupHandle.joint);
    });

    test('bride near her node-to-mouth segment', () {
      expect(pick(const Vec2(100, 180)), SetupHandle.bride);
      expect(pick(const Vec2(150, 150)), SetupHandle.bride);
    });

    test('nothing elsewhere', () {
      expect(pick(const Vec2(300, 100)), isNull);
    });
  });

  group('start speed', () {
    const params = gamePendulumParams;
    final top = brideTopEnergy(params);
    final target = const GameConfig().startEnergyTopMultiple * top;

    PendulumState placed(double upper, double lower) => PendulumState(
      upperTheta: upper,
      lowerTheta: lower,
      upperOmega: 0,
      lowerOmega: 0,
    );

    test('the top energy lifts the bride 2 * lowerLength', () {
      expect(
        top,
        closeTo(
          params.lowerMass *
              params.gravityAcceleration *
              2 *
              params.lowerLength,
          1e-9,
        ),
      );
      // With the joint still, that is the potential energy of the bride
      // straight above it.
      expect(potentialEnergy(params, placed(0, math.pi)), closeTo(top, 1e-9));
    });

    ({double upperOmega, double lowerOmega}) omegasFor(
      PendulumState state, {
      double? targetEnergy,
      double ratio = 1.0,
    }) => startOmegas(
      params: params,
      state: state,
      targetEnergy: targetEnergy ?? target,
      counterSpinRatio: ratio,
    );

    PendulumState withOmegas(
      PendulumState state,
      ({double upperOmega, double lowerOmega}) omegas,
    ) => PendulumState(
      upperTheta: state.upperTheta,
      lowerTheta: state.lowerTheta,
      upperOmega: omegas.upperOmega,
      lowerOmega: omegas.lowerOmega,
    );

    test('the bride turns toward the groom and the joint against her', () {
      final omegas = omegasFor(placed(0, 0));
      expect(omegas.lowerOmega, greaterThan(0)); // toward the groom
      expect(omegas.upperOmega, closeTo(-omegas.lowerOmega, 1e-12));

      final half = omegasFor(placed(0, 0), ratio: 0.5);
      expect(half.upperOmega, closeTo(-0.5 * half.lowerOmega, 1e-12));
    });

    test('with ratio 0 only the bride moves, as m2 L2^2 w^2 / 2', () {
      final omegas = omegasFor(placed(0, 0), ratio: 0);
      expect(omegas.upperOmega, 0);
      expect(
        omegas.lowerOmega,
        closeTo(
          math.sqrt(
            2 * target / (params.lowerMass * math.pow(params.lowerLength, 2)),
          ),
          1e-12,
        ),
      );
    });

    test('every placement is topped up to exactly the target', () {
      for (final (upper, lower) in [
        (0.0, 0.0),
        (0.3, -0.4),
        (3 * math.pi / 4, math.pi / 2), // the default
        (math.pi, math.pi), // straight up: the highest placement
        (1.0, 2.5), // rods bent, where the cross term matters
      ]) {
        final state = placed(upper, lower);
        expect(potentialEnergy(params, state), lessThan(target));
        final started = withOmegas(state, omegasFor(state));
        expect(totalEnergy(params, started), closeTo(target, 1e-6));
      }
    });

    test('a placement with more energy than the target starts at rest', () {
      final state = placed(math.pi, math.pi);
      expect(potentialEnergy(params, state), greaterThan(top));
      final omegas = omegasFor(state, targetEnergy: top);
      expect(omegas.upperOmega, 0);
      expect(omegas.lowerOmega, 0);
    });
  });
}
