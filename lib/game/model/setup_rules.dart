import 'dart:math' as math;

import '../../math/vec2.dart';
import '../../physics/double_pendulum.dart';
import '../../physics/pendulum_energy.dart';

/// Pure rules for placing the pendulum before the countdown. Like rules.dart
/// they are independent of Flame so that they can be unit tested.

/// What the player grabbed on the setup screen.
enum SetupHandle {
  /// The middle joint; dragging it sets upperTheta around the pivot.
  joint,

  /// The bride; dragging her sets lowerTheta around the middle joint.
  bride,
}

/// Pendulum angle of [point] around [pivot]: measured from the downward
/// vertical, positive toward +x, as in `PendulumState`.
double pendulumAngle(Vec2 pivot, Vec2 point) =>
    math.atan2(point.x - pivot.x, point.y - pivot.y);

/// Normalizes [angle] into [0, 2pi), i.e. 0 to 360 degrees. The physics only
/// uses sin/cos of the angles, so this does not change the motion.
double normalizeAngle(double angle) => angle % (2 * math.pi);

/// Wraps [angle] into (-pi, pi].
double wrapAngle(double angle) {
  var a = angle % (2 * math.pi);
  if (a > math.pi) a -= 2 * math.pi;
  return a;
}

/// Shortest distance from [point] to the segment [a]-[b].
double distanceToSegment(Vec2 point, Vec2 a, Vec2 b) {
  final ab = b - a;
  final lengthSquared = ab.dot(ab);
  var t = 0.0;
  if (lengthSquared > 0) {
    t = ((point - a).dot(ab) / lengthSquared).clamp(0.0, 1.0);
  }
  return point.distanceTo(a + ab * t);
}

/// The handle under [point], or null. The joint wins where both overlap,
/// since it is the smaller target.
SetupHandle? pickSetupHandle({
  required Vec2 point,
  required Vec2 joint,
  required Vec2 brideNode,
  required Vec2 brideMouth,
  required double jointGrabRadius,
  required double brideGrabRadius,
}) {
  if (point.distanceTo(joint) <= jointGrabRadius) return SetupHandle.joint;
  if (distanceToSegment(point, brideNode, brideMouth) <= brideGrabRadius) {
    return SetupHandle.bride;
  }
  return null;
}

/// Energy that the bride alone would need to swing up from hanging straight
/// down to straight above the joint, with the joint held still.
double brideTopEnergy(PendulumParams params) =>
    2 * params.lowerMass * params.gravityAcceleration * params.lowerLength;

/// Angular velocities to start play with, from the placed [state] (both
/// zero), as (upperOmega, lowerOmega).
///
/// They top the total mechanical energy up to [targetEnergy], so that every
/// placement swings at least that much; hanging straight down would not
/// move at all otherwise. Placements that already have more energy start at
/// rest.
///
/// The bride turns toward the groom (positive, +x while she is below the
/// joint) and the joint the opposite way at [counterSpinRatio] times her
/// angular speed. Bending the rods against each other sets the bride
/// spinning around the joint; starting only the bride makes the heavy
/// bride pull both rods straight, and the pair then swings like a single
/// pendulum.
({double upperOmega, double lowerOmega}) startOmegas({
  required PendulumParams params,
  required PendulumState state,
  required double targetEnergy,
  required double counterSpinRatio,
}) {
  final kinetic = targetEnergy - potentialEnergy(params, state);
  if (kinetic <= 0) return (upperOmega: 0, lowerOmega: 0);
  // Kinetic energy is quadratic in the angular velocities, so scale the
  // direction (-ratio, 1) until it carries [kinetic].
  final unit = kineticEnergy(
    params,
    PendulumState(
      upperTheta: state.upperTheta,
      lowerTheta: state.lowerTheta,
      upperOmega: -counterSpinRatio,
      lowerOmega: 1,
    ),
  );
  final lowerOmega = math.sqrt(kinetic / unit);
  return (upperOmega: -counterSpinRatio * lowerOmega, lowerOmega: lowerOmega);
}
