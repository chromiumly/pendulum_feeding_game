import 'dart:math' as math;

/// Immutable 2D vector in the game's logical coordinate system
/// (x to the right, y downward).
class Vec2 {
  const Vec2(this.x, this.y);

  static const zero = Vec2(0, 0);

  final double x;
  final double y;

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);

  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);

  Vec2 operator *(double scale) => Vec2(x * scale, y * scale);

  double get length => math.sqrt(x * x + y * y);

  double distanceTo(Vec2 other) => (this - other).length;

  double dot(Vec2 other) => x * other.x + y * other.y;

  /// Rotates by [angle] radians (clockwise on screen, since y points down).
  Vec2 rotated(double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Vec2(cos * x - sin * y, sin * x + cos * y);
  }

  /// Scales the vector down so that its length does not exceed [max].
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
