/// Mechanical energy of the double pendulum, for the same point-mass model
/// as `DoublePendulum`: `PendulumParams.upperMass` at the middle joint and
/// `PendulumParams.lowerMass` at the lower node. Heights are measured from
/// hanging straight down, so a pendulum at rest there has zero energy.
///
/// Used to choose start conditions only; the simulation itself does not
/// use it.
library;

import 'dart:math' as math;

import 'double_pendulum.dart';

/// Returns the potential energy of [state], zero when both rods hang
/// straight down.
///
/// Like all energies here, it is in the model's own units: mass units x
/// px²/s², since lengths are in px and gravity in px/s².
double potentialEnergy(PendulumParams params, PendulumState state) {
  final g = params.gravityAcceleration;
  return (params.upperMass + params.lowerMass) *
          g *
          params.upperLength *
          (1 - math.cos(state.upperTheta)) +
      params.lowerMass *
          g *
          params.lowerLength *
          (1 - math.cos(state.lowerTheta));
}

/// Returns the kinetic energy of [state], from its angular velocities (rad/s).
double kineticEnergy(PendulumParams params, PendulumState state) {
  final l1 = params.upperLength;
  final l2 = params.lowerLength;
  final w1 = state.upperOmega;
  final w2 = state.lowerOmega;
  return 0.5 * (params.upperMass + params.lowerMass) * l1 * l1 * w1 * w1 +
      0.5 * params.lowerMass * l2 * l2 * w2 * w2 +
      params.lowerMass *
          l1 *
          l2 *
          w1 *
          w2 *
          math.cos(state.upperTheta - state.lowerTheta);
}

/// Returns the mechanical energy of [state]: potential plus kinetic.
double totalEnergy(PendulumParams params, PendulumState state) =>
    potentialEnergy(params, state) + kineticEnergy(params, state);
