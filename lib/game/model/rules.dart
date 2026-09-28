import '../../math/vec2.dart';

/// Pure game-rule functions. They are independent of Flame so that they can be
/// unit tested and reused by the trajectory guide.

/// One semi-implicit Euler step (velocity first, then position).
({Vec2 position, Vec2 velocity}) stepProjectile({
  required Vec2 position,
  required Vec2 velocity,
  required Vec2 gravity,
  required double dt,
}) {
  final nextVelocity = velocity + gravity * dt;
  return (position: position + nextVelocity * dt, velocity: nextVelocity);
}

/// Predicted positions of a launched food, one per [dt], for the aim guide.
List<Vec2> predictTrajectory({
  required Vec2 position,
  required Vec2 velocity,
  required Vec2 gravity,
  required double dt,
  required int count,
}) {
  final points = <Vec2>[];
  var p = position;
  var v = velocity;
  for (var i = 0; i < count; i++) {
    final next = stepProjectile(
      position: p,
      velocity: v,
      gravity: gravity,
      dt: dt,
    );
    p = next.position;
    v = next.velocity;
    points.add(p);
  }
  return points;
}

/// Slingshot launch: pulling back from [dragStart] to [dragCurrent] throws
/// the food in the opposite direction.
Vec2 launchVelocity({
  required Vec2 dragStart,
  required Vec2 dragCurrent,
  required double scale,
  required double maxSpeed,
}) {
  return ((dragStart - dragCurrent) * scale).limited(maxSpeed);
}

/// World position of the bride's mouth. The bride hangs from the lower
/// pendulum node and is drawn rotated by -lowerTheta.
Vec2 brideMouthPosition({
  required Vec2 lowerNode,
  required double lowerTheta,
  required Vec2 mouthOffset,
}) {
  return lowerNode + mouthOffset.rotated(-lowerTheta);
}

/// Whether a circle moving from [from] to [to] touched a circle at [center]
/// during the step. Sweeping the segment prevents fast food from tunnelling
/// through the mouth between two steps.
bool sweptCircleHit({
  required Vec2 from,
  required Vec2 to,
  required Vec2 center,
  required double radiusSum,
}) {
  final segment = to - from;
  final lengthSquared = segment.dot(segment);
  var t = 0.0;
  if (lengthSquared > 0) {
    t = ((center - from).dot(segment) / lengthSquared).clamp(0.0, 1.0);
  }
  final closest = from + segment * t;
  return closest.distanceTo(center) <= radiusSum;
}

/// The food is gone once it leaves the left, right or bottom edge. Leaving
/// through the top is allowed because gravity brings it back.
bool isOutOfWorld({
  required Vec2 position,
  required double radius,
  required Vec2 worldSize,
}) {
  return position.x + radius < 0 ||
      position.x - radius > worldSize.x ||
      position.y - radius > worldSize.y;
}
