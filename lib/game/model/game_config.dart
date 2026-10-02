import 'dart:math' as math;

import '../../math/vec2.dart';
import '../../physics/double_pendulum.dart';
import 'food.dart';

/// The game's pendulum: the prototype's model (see [PendulumParams]) with
///
/// * a longer lower rod, the bride's swing rope in the Figma art, and
/// * 9x gravity, which plays the prototype's motion 3x faster (time scales
///   with 1/sqrt(g)), for a livelier, more chaotic swing.
const gamePendulumParams = PendulumParams(
  lowerLength: 100,
  gravityAcceleration: 9.81 * 3 * 3,
);

/// Where the setup screen starts: a "く", the upper rod down to the left and
/// the lower rod down to the right, so that the bride hangs left of centre
/// under the tree. (The prototype started from [PendulumState.initial], up
/// to the right.) Both at rest; the start speed is added at スタート.
/// Angles are in [0, 2pi) like placed ones: 315 degrees is -45.
const setupStartPendulumState = PendulumState(
  upperTheta: 7 * math.pi / 4,
  lowerTheta: math.pi / 4,
  upperOmega: 0,
  lowerOmega: 0,
);

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
    this.pendulumParams = gamePendulumParams,
    this.physicsSubsteps = 2,
    this.pendulumInitialState = setupStartPendulumState,
    this.pendulumOrigin = const Vec2(237.5, 116.5),
    this.brideMouthOffset = const Vec2(12, -50),
    this.brideMouthRadius = 16,
    this.groomPosition = const Vec2(698, 344),
    this.foodSpawnPosition = const Vec2(727, 216),
    this.foodGravity = const Vec2(0, 700),
    this.foodTypes = defaultFoodTypes,
    this.foodHitRadius = 32,
    this.favouriteBiasLimit = 3,
    this.favouriteBiasHalfPlays = 5,
    this.launchScale = 4.0,
    this.maxLaunchSpeed = 900,
    this.minDragDistance = 12,
    this.countdownSeconds = 3,
    this.startCueSeconds = 0.8,
    this.startEnergyTopMultiple = 2.5,
    this.startCounterSpinRatio = 1.0,
    this.setupJointGrabRadius = 24,
    this.setupBrideGrabRadius = 48,
  });

  final Vec2 worldSize;

  /// Simulation step [s]. The game always advances in steps of this size.
  final double fixedDt;

  final int timeLimitSeconds;

  final PendulumParams pendulumParams;

  /// RK4 steps per [fixedDt] for the pendulum. The faster, more energetic
  /// swing needs a smaller step to stay accurate: with 2, the energy drifts
  /// about 0.1% over a game instead of about 2%.
  final int physicsSubsteps;
  final PendulumState pendulumInitialState;
  final Vec2 pendulumOrigin;

  /// Offset from the lower pendulum node to the bride's mouth, before the
  /// bride is rotated by -lowerTheta. The lower node is where the rope meets
  /// the swing seat; this must match the mouth in the bride sprite.
  final Vec2 brideMouthOffset;

  /// Hit radius around the bride's mouth [px].
  final double brideMouthRadius;

  /// Centre between the groom's shoes, on the ground [px].
  final Vec2 groomPosition;

  final Vec2 foodSpawnPosition;

  /// [px/s²]
  final Vec2 foodGravity;

  final List<FoodType> foodTypes;

  /// Hit radius of every food [px]. A little larger than the food images,
  /// which look like circles of about 53 px across (tool/images.dart),
  /// to be forgiving.
  final double foodHitRadius;

  /// The more games a player has finished, the more often the bride's
  /// favourites come (see `favouriteBias`). The bias approaches this limit,
  /// at which the top 5 of 20 foods come 57% of the time instead of 25%.
  final double favouriteBiasLimit;

  /// Finished games after which the bias is half its limit.
  final double favouriteBiasHalfPlays;

  /// Launch velocity per pixel of drag [1/s].
  final double launchScale;

  /// [px/s]
  final double maxLaunchSpeed;

  /// Shorter drags are treated as cancelled rather than as a throw.
  final double minDragDistance;

  /// Length of the 3, 2, 1 countdown [s].
  final int countdownSeconds;

  /// How long "START" is shown after the countdown before play begins [s].
  final double startCueSeconds;

  /// Mechanical energy at the start of play, as a multiple of the energy the
  /// bride alone needs to swing up to straight above the joint. Placements
  /// with less get the difference as initial speed (see `startOmegas`); at
  /// 2.5 that is every placement.
  ///
  /// 1 is rarely enough, since the joint takes part of the energy. In
  /// simulation at 2.5, the bride reached the top in all but 1 of 300
  /// random placements, from half of them within 1.6 s and from 90% within
  /// 5.3 s.
  final double startEnergyTopMultiple;

  /// At the start of play the joint turns against the bride at this multiple
  /// of her angular speed (see `startOmegas`). In simulation, 1 made the
  /// bride spin around the joint about 5 times per game (1 when only she was
  /// started), and left only 5% of games without such a spin (50% before).
  final double startCounterSpinRatio;

  /// Grab radius around the middle joint on the setup screen [px].
  final double setupJointGrabRadius;

  /// Grab distance from the bride's node-to-mouth segment [px].
  final double setupBrideGrabRadius;

  int get timeLimitSteps => (timeLimitSeconds / fixedDt).round();

  int get countdownSteps => (countdownSeconds / fixedDt).round();

  int get startCueSteps => (startCueSeconds / fixedDt).round();
}

/// In the order of the bride's favourites, best first. The favourite scores
/// 150 points, and each next one 5 fewer: 150 - 5 x (rank - 1).
const defaultFoodTypes = [
  FoodType(id: 'parfait', points: 150), // 1. パフェ
  FoodType(id: 'pino', points: 145), // 2. ピノ
  FoodType(id: 'shrimp_tempura', points: 140), // 3. 海老の天ぷら
  FoodType(id: 'melon_ice_cream', points: 135), // 4. メロンソフトクリーム
  FoodType(id: 'hitsumabushi', points: 130), // 5. ひつまぶし
  FoodType(id: 'mont_blanc', points: 125), // 6. モンブラン
  FoodType(id: 'sushi', points: 120), // 7. お寿司
  FoodType(id: 'chawan_mushi', points: 115), // 8. 茶碗蒸し
  FoodType(id: 'ramen', points: 110), // 9. ラーメン
  FoodType(id: 'gyoza', points: 105), // 10. 津餃子
  FoodType(id: 'tapioka', points: 100), // 11. タピオカミルクティー
  FoodType(id: 'muscat', points: 95), // 12. シャインマスカット
  FoodType(id: 'donut', points: 90), // 13. ポンデリング
  FoodType(id: 'omurice', points: 85), // 14. オムライス
  FoodType(id: 'hamburger', points: 80), // 15. ハンバーガー
  FoodType(id: 'nikuman', points: 75), // 16. 肉まん
  FoodType(id: 'curry', points: 70), // 17. カレーライス
  FoodType(id: 'tea', points: 65), // 18. 紅茶
  FoodType(id: 'jagariko', points: 60), // 19. じゃがりこ
  FoodType(id: 'sweet_potato', points: 55), // 20. 焼き芋
];
