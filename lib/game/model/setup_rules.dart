import 'dart:math' as math;

import '../../math/vec2.dart';

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
