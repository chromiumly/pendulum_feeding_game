/// The food the groom throws: its kinds and the one in play.
library;

import '../../math/vec2.dart';

/// A kind of food. All kinds share one hit radius (`GameConfig.foodHitRadius`);
/// the image of each is `assets/images/food/<id>.webp`.
class FoodType {
  const FoodType({required this.id, required this.points});

  /// Identifies the kind, e.g. `parfait`; also names its image.
  final String id;

  /// Points for eating it, before the combo bonus (see `comboPoints`). A
  /// multiple of 5 keeps the combo points whole.
  final int points;
}

/// Whether a food waits in the groom's hand or has been thrown.
enum FoodPhase {
  /// Held at the spawn point, ready to be thrown.
  ready,

  /// In the air, moving under gravity.
  flying,
}

/// The single food item currently in play.
class Food {
  const Food({
    required this.type,
    required this.position,
    this.velocity = Vec2.zero,
    this.phase = FoodPhase.ready,
  });

  final FoodType type;

  /// Centre of the food in world coordinates [px].
  final Vec2 position;

  /// [px/s], y downward. Zero while ready.
  final Vec2 velocity;

  final FoodPhase phase;

  bool get isFlying => phase == FoodPhase.flying;

  /// Returns this food thrown with [velocity] [px/s] from where it is.
  Food launched(Vec2 velocity) => Food(
    type: type,
    position: position,
    velocity: velocity,
    phase: FoodPhase.flying,
  );

  /// Returns this food at [position] [px] with [velocity] [px/s], for one
  /// step of its flight.
  Food moved(Vec2 position, Vec2 velocity) =>
      Food(type: type, position: position, velocity: velocity, phase: phase);
}
