/// The double-pendulum physics: parameters, state and equations of motion.
library;

import 'dart:math' as math;

import '../math/vec2.dart';
import 'rk4.dart';

/// Physical parameters of the double pendulum.
///
/// Lengths are in logical pixels and gravity is 9.81 in px/s², exactly as in
/// the TypeScript prototype; this gives the slow swing the game is tuned for.
class PendulumParams {
  const PendulumParams({
    this.upperMass = 1,
    this.lowerMass = 5,
    this.upperLength = 70,
    this.lowerLength = 80,
    this.gravityAcceleration = 9.81,
  });

  /// Point mass at the middle joint, relative to [lowerMass] (no unit).
  final double upperMass;

  /// Point mass at the lower node: the bride on the swing.
  final double lowerMass;

  /// From the fixed pivot to the middle joint [px].
  final double upperLength;

  /// From the middle joint to the lower node [px].
  final double lowerLength;

  /// Downward acceleration [px/s²].
  final double gravityAcceleration;
}

/// The double pendulum's state at one instant: both rod angles and their
/// angular velocities.
///
/// Angles are measured from the downward vertical; positive angles swing the
/// node toward +x (to the right on screen). They are not normalized: any
/// real number is valid.
class PendulumState {
  const PendulumState({
    required this.upperTheta,
    required this.lowerTheta,
    required this.upperOmega,
    required this.lowerOmega,
  });

  /// Initial condition of the game (upper rod pointing up-right, lower rod
  /// horizontal, at rest).
  static const initial = PendulumState(
    upperTheta: 3 * math.pi / 4,
    lowerTheta: math.pi / 2,
    upperOmega: 0,
    lowerOmega: 0,
  );

  /// Creates a state from [values] in the order of [toList].
  factory PendulumState.fromList(List<double> values) => PendulumState(
    upperTheta: values[0],
    lowerTheta: values[1],
    upperOmega: values[2],
    lowerOmega: values[3],
  );

  /// Angle of the upper rod, pivot to joint [rad].
  final double upperTheta;

  /// Angle of the lower rod, joint to lower node [rad]. Absolute, not
  /// relative to the upper rod.
  final double lowerTheta;

  /// Angular velocity of the upper rod [rad/s].
  final double upperOmega;

  /// Angular velocity of the lower rod [rad/s].
  final double lowerOmega;

  /// Returns [upperTheta, lowerTheta, upperOmega, lowerOmega], the state
  /// vector the integrator works on.
  List<double> toList() => [upperTheta, lowerTheta, upperOmega, lowerOmega];
}

/// Where the pendulum's two moving points are, in world coordinates [px].
class PendulumPositions {
  const PendulumPositions({required this.upper, required this.lower});

  /// The middle joint.
  final Vec2 upper;

  /// The lower node, where the rope meets the bride's swing seat.
  final Vec2 lower;
}

/// Double-pendulum equations of motion and RK4 integration.
///
/// Numerical reference: `PendulumDynamics.ts`, `RK4.ts` and `Pendulum.ts` of
/// the TypeScript prototype. Keep the order of operations unchanged; it is
/// verified against golden data in `test/physics/pendulum_golden_test.dart`.
class DoublePendulum {
  const DoublePendulum([this.params = const PendulumParams()]);

  final PendulumParams params;

  /// Returns [state] advanced by one RK4 step of [dt] seconds.
  PendulumState step(PendulumState state, double dt) {
    return PendulumState.fromList(rk4Step(state.toList(), dt, derivatives));
  }

  /// Returns the time derivative of [state], a list in the order of
  /// [PendulumState.toList]: [upperOmega, lowerOmega, upperAcceleration,
  /// lowerAcceleration], angular accelerations in rad/s².
  List<double> derivatives(List<double> state) {
    final upperMass = params.upperMass;
    final lowerMass = params.lowerMass;
    final upperLength = params.upperLength;
    final lowerLength = params.lowerLength;
    final gravityAcceleration = params.gravityAcceleration;
    final upperTheta = state[0];
    final lowerTheta = state[1];
    final upperOmega = state[2];
    final lowerOmega = state[3];

    final deltaTheta = upperTheta - lowerTheta;
    final denom =
        2 * upperMass + lowerMass - lowerMass * math.cos(2 * deltaTheta);
    final upperSin = math.sin(upperTheta);
    final upperCos = math.cos(upperTheta);
    final upperLowerSin = math.sin(upperTheta - 2 * lowerTheta);
    final deltaSin = math.sin(deltaTheta);
    final deltaCos = math.cos(deltaTheta);

    // Guard against a vanishing denominator (unreachable while upperMass > 0).
    const eps = 1e-6;
    var safeDenom = denom;
    if (denom.abs() < eps) {
      safeDenom = denom >= 0 ? eps : -eps;
    }

    final upperGravity =
        -(2 * upperMass + lowerMass) * gravityAcceleration * upperSin;
    final upperCouplingGravity =
        -lowerMass * gravityAcceleration * upperLowerSin;
    final upperCentrifugal =
        -2 *
        lowerMass *
        deltaSin *
        (lowerOmega * lowerOmega * lowerLength +
            upperOmega * upperOmega * upperLength * deltaCos);
    final upperAcceleration =
        (upperGravity + upperCouplingGravity + upperCentrifugal) /
        (upperLength * safeDenom);

    final kineticTransfer =
        upperOmega * upperOmega * upperLength * (upperMass + lowerMass);
    final gravityTransfer =
        (upperMass + lowerMass) * gravityAcceleration * upperCos;
    final lowerCentrifugal =
        lowerMass * deltaCos * lowerOmega * lowerOmega * lowerLength;
    final lowerAcceleration =
        2 *
        deltaSin *
        (kineticTransfer + gravityTransfer + lowerCentrifugal) /
        (lowerLength * safeDenom);

    return [upperOmega, lowerOmega, upperAcceleration, lowerAcceleration];
  }

  /// Returns the joint and lower node positions for [state], with the fixed
  /// pivot at [origin] (world coordinates, y downward) [px].
  PendulumPositions positions(PendulumState state, Vec2 origin) {
    final upper = Vec2(
      origin.x + params.upperLength * math.sin(state.upperTheta),
      origin.y + params.upperLength * math.cos(state.upperTheta),
    );
    final lower = Vec2(
      upper.x + params.lowerLength * math.sin(state.lowerTheta),
      upper.y + params.lowerLength * math.cos(state.lowerTheta),
    );
    return PendulumPositions(upper: upper, lower: lower);
  }
}
