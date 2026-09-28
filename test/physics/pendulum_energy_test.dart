import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/model/game_config.dart';
import 'package:pendulum_feeding_game/physics/double_pendulum.dart';
import 'package:pendulum_feeding_game/physics/pendulum_energy.dart';

void main() {
  // The game's parameters, simulated at the game's RK4 step.
  const params = gamePendulumParams;
  const pendulum = DoublePendulum(params);
  const config = GameConfig();
  final stepsPerSecond = config.physicsSubsteps * (1 / config.fixedDt).round();
  final energyScale =
      params.lowerMass * params.gravityAcceleration * params.lowerLength;

  test('hanging straight down at rest has zero energy', () {
    const state = PendulumState(
      upperTheta: 0,
      lowerTheta: 0,
      upperOmega: 0,
      lowerOmega: 0,
    );
    expect(totalEnergy(params, state), 0);
  });

  // The energy model must match the equations of motion. If it does, the
  // simulation conserves it up to RK4's error, which shrinks ~16x when the
  // step is halved (4th order). A wrong model would drift regardless of dt.
  double maxRelativeDrift(PendulumState start, int stepsPerSecond) {
    final initial = totalEnergy(params, start);
    var state = start;
    var maxDrift = 0.0;
    for (var i = 0; i < 20 * stepsPerSecond; i++) {
      state = pendulum.step(state, 1 / stepsPerSecond);
      maxDrift = math.max(
        maxDrift,
        (totalEnergy(params, state) - initial).abs(),
      );
    }
    // Relative to the energy scale lowerMass * g * lowerLength.
    return maxDrift / energyScale;
  }

  for (final (name, start) in [
    ('the game start', PendulumState.initial),
    (
      'a kicked bride',
      const PendulumState(
        upperTheta: 0,
        lowerTheta: 0,
        upperOmega: 0,
        lowerOmega: 0.45,
      ),
    ),
    (
      // The start speed for hanging straight down: 2.5x the energy to reach
      // the top, so the bride spins.
      'a spinning bride',
      PendulumState(
        upperTheta: 0,
        lowerTheta: 0,
        upperOmega: 0,
        lowerOmega: math.sqrt(
          2 *
              config.startEnergyTopMultiple *
              2 *
              params.lowerMass *
              params.gravityAcceleration *
              params.lowerLength /
              (params.lowerMass * params.lowerLength * params.lowerLength),
        ),
      ),
    ),
    (
      'both rods moving',
      const PendulumState(
        upperTheta: 1.1,
        lowerTheta: -2.0,
        upperOmega: 0.3,
        lowerOmega: -0.6,
      ),
    ),
  ]) {
    test('energy is conserved by the simulation from $name', () {
      final drift = maxRelativeDrift(start, stepsPerSecond);
      final finer = maxRelativeDrift(start, stepsPerSecond * 2);
      expect(drift, lessThan(1e-2));
      expect(finer, lessThan(drift / 8 + 1e-12));
    });
  }
}
