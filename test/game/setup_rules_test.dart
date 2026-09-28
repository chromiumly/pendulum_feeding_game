import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/model/setup_rules.dart';
import 'package:pendulum_feeding_game/math/vec2.dart';
import 'package:pendulum_feeding_game/physics/double_pendulum.dart';

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
}
