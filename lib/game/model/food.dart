import '../../math/vec2.dart';

/// A kind of food. All kinds share one hit radius (`GameConfig.foodHitRadius`);
/// the image of each is `assets/images/food/<id>.png`.
class FoodType {
  const FoodType({required this.id, required this.points});

  final String id;

  /// Points for eating it, before the combo bonus (see `comboPoints`). A
  /// multiple of 5 keeps the combo points whole.
  final int points;
}

enum FoodPhase { ready, flying }

/// The single food item currently in play.
class Food {
  const Food({
    required this.type,
    required this.position,
    this.velocity = Vec2.zero,
    this.phase = FoodPhase.ready,
  });

  final FoodType type;
  final Vec2 position;
  final Vec2 velocity;
  final FoodPhase phase;

  bool get isFlying => phase == FoodPhase.flying;

  Food launched(Vec2 velocity) => Food(
    type: type,
    position: position,
    velocity: velocity,
    phase: FoodPhase.flying,
  );

  Food moved(Vec2 position, Vec2 velocity) =>
      Food(type: type, position: position, velocity: velocity, phase: phase);
}
