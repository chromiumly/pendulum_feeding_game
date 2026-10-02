import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/model/rules.dart';
import 'package:pendulum_feeding_game/math/vec2.dart';

void main() {
  group('launchVelocity', () {
    test('is the opposite of the drag, scaled', () {
      final v = launchVelocity(
        dragStart: const Vec2(100, 100),
        dragCurrent: const Vec2(130, 140),
        scale: 4,
        maxSpeed: 900,
      );
      expect(v, const Vec2(-120, -160));
    });

    test('is limited to maxSpeed keeping direction', () {
      final v = launchVelocity(
        dragStart: const Vec2(0, 0),
        dragCurrent: const Vec2(300, 400),
        scale: 4,
        maxSpeed: 900,
      );
      expect(v.length, closeTo(900, 1e-9));
      expect(v.x / v.y, closeTo(0.75, 1e-12));
    });
  });

  test('stepProjectile updates velocity before position', () {
    final next = stepProjectile(
      position: const Vec2(0, 0),
      velocity: const Vec2(10, 0),
      gravity: const Vec2(0, 700),
      dt: 0.1,
    );
    expect(next.velocity, const Vec2(10, 70));
    expect(next.position.x, closeTo(1, 1e-12));
    expect(next.position.y, closeTo(7, 1e-12));
  });

  test('predictTrajectory starts one step after the launch point', () {
    final points = predictTrajectory(
      position: const Vec2(0, 0),
      velocity: const Vec2(10, 0),
      gravity: const Vec2(0, 700),
      dt: 0.1,
      count: 3,
    );
    expect(points, hasLength(3));
    expect(points.first.x, closeTo(1, 1e-12));
  });

  group('brideMouthPosition', () {
    test('uses the unrotated offset when hanging straight down', () {
      final mouth = brideMouthPosition(
        lowerNode: const Vec2(200, 300),
        lowerTheta: 0,
        mouthOffset: const Vec2(-3, -40),
      );
      expect(mouth, const Vec2(197, 260));
    });

    test('rotates the offset by -lowerTheta', () {
      // lowerTheta = pi/2: the rod points to +x, the bride is rotated -90°,
      // so "up" in her frame (0,-40) becomes -x on screen.
      final mouth = brideMouthPosition(
        lowerNode: Vec2.zero,
        lowerTheta: math.pi / 2,
        mouthOffset: const Vec2(0, -40),
      );
      expect(mouth.x, closeTo(-40, 1e-9));
      expect(mouth.y, closeTo(0, 1e-9));
    });
  });

  group('sweptCircleHit', () {
    test('detects a hit that a per-step overlap check would miss', () {
      // Moves 100 px in one step straight through the target.
      const from = Vec2(0, 0);
      const to = Vec2(100, 0);
      expect(from.distanceTo(const Vec2(50, 5)), greaterThan(26));
      expect(to.distanceTo(const Vec2(50, 5)), greaterThan(26));
      expect(
        sweptCircleHit(
          from: from,
          to: to,
          center: const Vec2(50, 5),
          radiusSum: 26,
        ),
        isTrue,
      );
    });

    test('treats touching as a hit and misses beyond the radius', () {
      bool hitAt(double y) => sweptCircleHit(
        from: const Vec2(0, 0),
        to: const Vec2(100, 0),
        center: Vec2(50, y),
        radiusSum: 26,
      );
      expect(hitAt(26), isTrue);
      expect(hitAt(26.001), isFalse);
    });

    test('works for a stationary circle', () {
      expect(
        sweptCircleHit(
          from: const Vec2(10, 10),
          to: const Vec2(10, 10),
          center: const Vec2(20, 10),
          radiusSum: 10,
        ),
        isTrue,
      );
    });
  });

  group('isOutOfWorld', () {
    const world = Vec2(844, 390);
    bool out(double x, double y) =>
        isOutOfWorld(position: Vec2(x, y), radius: 10, worldSize: world);

    test('left, right and bottom edges remove the food', () {
      expect(out(-10.1, 100), isTrue);
      expect(out(854.1, 100), isTrue);
      expect(out(100, 400.1), isTrue);
      expect(out(-10, 100), isFalse);
    });

    test('the top edge does not', () {
      expect(out(100, -1000), isFalse);
    });
  });

  group('comboPoints', () {
    test('adds 0.2 x the base points per food in a row, without limit', () {
      int points(int combo) => comboPoints(basePoints: 150, combo: combo);
      expect(points(1), 150);
      expect(points(2), 180);
      expect(points(6), 300);
      expect(points(20), 720);
      expect(points(50), 1620);
    });

    test('applies comboMultiplier', () {
      expect(comboMultiplier(1), 1.0);
      expect(comboMultiplier(2), closeTo(1.2, 1e-12));
      expect(comboMultiplier(20), closeTo(4.8, 1e-12));
      expect(comboMultiplier(2).toStringAsFixed(1), '1.2');
    });

    test('is whole for base points that are multiples of 5', () {
      expect(comboPoints(basePoints: 135, combo: 2), 162);
      for (var base = 5; base <= 150; base += 5) {
        for (var combo = 1; combo <= 30; combo++) {
          // Nothing is lost to the integer division.
          expect(
            comboPoints(basePoints: base, combo: combo) * 5,
            base * (combo + 4),
          );
        }
      }
    });
  });
}
