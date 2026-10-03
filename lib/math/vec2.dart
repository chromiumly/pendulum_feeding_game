/// The 2D vector type shared by physics, rules and rendering.
library;

import 'dart:math' as math;

/// Immutable 2D vector in the game's logical coordinate system
/// (x to the right, y downward).
class Vec2 {
  const Vec2(this.x, this.y);

  static const zero = Vec2(0, 0);

  /// Horizontal component, positive to the right [px].
  final double x;

  /// Vertical component, positive downward [px].
  final double y;

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);

  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);

  Vec2 operator *(double scale) => Vec2(x * scale, y * scale);

  /// Euclidean length [px].
  double get length => math.sqrt(x * x + y * y);

  /// Returns the distance to [other] [px].
  double distanceTo(Vec2 other) => (this - other).length;

  /// Returns the dot product with [other].
  double dot(Vec2 other) => x * other.x + y * other.y;

  /// Rotates by [angle] radians (clockwise on screen, since y points down).
  Vec2 rotated(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Vec2(cos * x - sin * y, sin * x + cos * y);
  }

  /// Returns this vector scaled down so that its length does not exceed
  /// [max]; unchanged if it is already short enough.
  ///
  /// [max] must not be negative.
  Vec2 limited(double max) {
    final len = length;
    if (len > max) {
      return this * (max / len);
    }
    return this;
  }

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}
