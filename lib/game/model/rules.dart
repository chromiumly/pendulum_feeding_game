import 'dart:math' as math;

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

/// Points for eating a food worth [basePoints] as the [combo]th food in a
/// row (1 for the first): basePoints x (1 + 0.2 x (combo - 1)), without an
/// upper limit. Whole when [basePoints] is a multiple of 5.
int comboPoints({required int basePoints, required int combo}) =>
    basePoints * (combo + 4) ~/ 5;

/// The multiplier [comboPoints] applies to the [combo]th food in a row.
double comboMultiplier(int combo) => (combo + 4) / 5;

/// How strongly the draw favours the bride's favourites after [gamesPlayed]
/// finished games: 0 at first, rising smoothly towards [limit], half way
/// after [halfPlays] games.
double favouriteBias({
  required int gamesPlayed,
  required double limit,
  required double halfPlays,
}) => limit * gamesPlayed / (gamesPlayed + halfPlays);

/// Probability of each of [count] foods, listed best favourite first:
/// proportional to exp(bias x f), where f goes from 1 for the favourite down
/// to 0 for the last. A [bias] of 0 draws them all alike; every food stays
/// possible at any bias.
List<double> foodProbabilities({required int count, required double bias}) {
  final weights = [
    for (var i = 0; i < count; i++)
      math.exp(bias * (count > 1 ? (count - 1 - i) / (count - 1) : 0)),
  ];
  final total = weights.fold(0.0, (sum, w) => sum + w);
  return [for (final w in weights) w / total];
}

/// How much more an average drawn food is worth after [gamesPlayed] games
/// than in a first game (0.12 for 12%), and the most it can ever be, as the
/// bias approaches [biasLimit]. [points] are the foods' points, listed best
/// favourite first.
({double uplift, double maxUplift}) favouriteBonus({
  required List<int> points,
  required int gamesPlayed,
  required double biasLimit,
  required double halfPlays,
}) {
  double averageAt(double bias) {
    final p = foodProbabilities(count: points.length, bias: bias);
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      sum += p[i] * points[i];
    }
    return sum;
  }

  final first = averageAt(0);
  final bias = favouriteBias(
    gamesPlayed: gamesPlayed,
    limit: biasLimit,
    halfPlays: halfPlays,
  );
  return (
    uplift: averageAt(bias) / first - 1,
    maxUplift: averageAt(biasLimit) / first - 1,
  );
}

/// Draws an index with the given [probabilities], which add up to 1.
int drawIndex(List<double> probabilities, math.Random random) {
  var r = random.nextDouble();
  for (var i = 0; i < probabilities.length - 1; i++) {
    r -= probabilities[i];
    if (r < 0) return i;
  }
  // The last one, also when rounding leaves a little over.
  return probabilities.length - 1;
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
