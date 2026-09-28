import 'dart:math' as math;

import '../../math/vec2.dart';
import '../../physics/double_pendulum.dart';
import 'food.dart';

/// Tunable game rules and layout, in the 844x390 logical coordinate system.
///
/// Rules and physics reproduce the TypeScript prototype. Screen positions
/// (pivot, bride's mouth, groom, food spawn) follow the Figma design, whose
/// art replaced the prototype's.
class GameConfig {
  const GameConfig({
    this.worldSize = const Vec2(844, 390),
    this.fixedDt = 1 / 60,
    this.timeLimitSeconds = 20,
    this.pendulumParams = const PendulumParams(),
    this.pendulumInitialState = PendulumState.initial,
    this.pendulumOrigin = const Vec2(237.5, 116.5),
    this.brideMouthOffset = const Vec2(12, -50),
    this.brideMouthRadius = 16,
    this.groomPosition = const Vec2(707, 344),
    this.foodSpawnPosition = const Vec2(727, 216),
    this.foodGravity = const Vec2(0, 700),
    this.foodTypes = defaultFoodTypes,
    this.launchScale = 4.0,
    this.maxLaunchSpeed = 900,
    this.minDragDistance = 12,
    this.pointsPerFood = 100,
    this.countdownSeconds = 3,
    this.startCueSeconds = 0.8,
    this.setupAngleLimit = 3 * math.pi / 4,
    this.setupJointGrabRadius = 24,
    this.setupBrideGrabRadius = 48,
  });

  final Vec2 worldSize;

  /// Simulation step [s]. The game always advances in steps of this size.
  final double fixedDt;

  final int timeLimitSeconds;

  final PendulumParams pendulumParams;
  final PendulumState pendulumInitialState;
  final Vec2 pendulumOrigin;

  /// Offset from the lower pendulum node to the bride's mouth, before the
  /// bride is rotated by -lowerTheta. The lower node is where the rope meets
  /// the swing seat; this must match the mouth in the bride sprite.
  final Vec2 brideMouthOffset;

  /// Hit radius around the bride's mouth [px].
  final double brideMouthRadius;

  final Vec2 groomPosition;

  final Vec2 foodSpawnPosition;

  /// [px/s²]
  final Vec2 foodGravity;

  final List<FoodType> foodTypes;

  /// Launch velocity per pixel of drag [1/s].
  final double launchScale;

  /// [px/s]
  final double maxLaunchSpeed;

  /// Shorter drags are treated as cancelled rather than as a throw.
  final double minDragDistance;

  final int pointsPerFood;

  /// Length of the 3, 2, 1 countdown [s].
  final int countdownSeconds;

  /// How long "START" is shown after the countdown before play begins [s].
  final double startCueSeconds;

  /// Placed angles are limited to [-limit, limit] [rad]. This keeps the
  /// pendulum from starting (nearly) upside down, and keeps angles away from
  /// the ±pi wrap so that a dragged handle never jumps.
  final double setupAngleLimit;

  /// Grab radius around the middle joint on the setup screen [px].
  final double setupJointGrabRadius;

  /// Grab distance from the bride's node-to-mouth segment [px].
  final double setupBrideGrabRadius;

  int get timeLimitSteps => (timeLimitSeconds / fixedDt).round();

  int get countdownSteps => (countdownSeconds / fixedDt).round();

  int get startCueSteps => (startCueSeconds / fixedDt).round();
}

/// Hit radii are the prototype's values and are expected to be retuned.
const defaultFoodTypes = [
  FoodType(id: 'apple', hitRadius: 50),
  FoodType(id: 'cake', hitRadius: 24),
  FoodType(id: 'grape', hitRadius: 50),
  FoodType(id: 'hamburger', hitRadius: 50),
  FoodType(id: 'mont_blanc', hitRadius: 50),
  FoodType(id: 'omelette_rice', hitRadius: 50),
  FoodType(id: 'peach', hitRadius: 50),
  FoodType(id: 'ramen', hitRadius: 50),
  FoodType(id: 'sushi', hitRadius: 10),
  FoodType(id: 'takoyaki', hitRadius: 50),
];
