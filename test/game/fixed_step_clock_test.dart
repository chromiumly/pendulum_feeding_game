import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/fixed_step_clock.dart';

void main() {
  test('runs one step per 60 Hz frame', () {
    final clock = FixedStepClock(stepDt: 1 / 60);
    var total = 0;
    for (var i = 0; i < 60; i++) {
      total += clock.advance(1 / 60);
    }
    expect(total, 60);
  });

  test('runs one step every other 120 Hz frame', () {
    final clock = FixedStepClock(stepDt: 1 / 60);
    var total = 0;
    for (var i = 0; i < 120; i++) {
      total += clock.advance(1 / 120);
    }
    expect(total, closeTo(60, 1));
  });

  test('caps the steps after a long stall and drops the backlog', () {
    final clock = FixedStepClock(stepDt: 1 / 60, maxStepsPerFrame: 5);
    expect(clock.advance(2.0), 5);
    expect(clock.advance(1 / 60), 1);
  });
}
