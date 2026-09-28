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

  final double upperMass;
  final double lowerMass;
  final double upperLength;
  final double lowerLength;
  final double gravityAcceleration;
}

/// Angles are measured from the downward vertical; positive angles swing the
/// node toward +x.
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

  factory PendulumState.fromList(List<double> values) => PendulumState(
    upperTheta: values[0],
    lowerTheta: values[1],
    upperOmega: values[2],
    lowerOmega: values[3],
  );

  /// Angles [rad]
  final double upperTheta;
  final double lowerTheta;

  /// Angular velocities [rad/s]
  final double upperOmega;
  final double lowerOmega;

  List<double> toList() => [upperTheta, lowerTheta, upperOmega, lowerOmega];
}

class PendulumPositions {
  const PendulumPositions({required this.upper, required this.lower});

  final Vec2 upper;
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

  PendulumState step(PendulumState state, double dt) {
    return PendulumState.fromList(rk4Step(state.toList(), dt, derivatives));
  }

  /// Returns [upperOmega, lowerOmega, upperAcceleration, lowerAcceleration].
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
