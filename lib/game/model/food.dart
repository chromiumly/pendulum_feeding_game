import '../../math/vec2.dart';

class FoodType {
  const FoodType({required this.id, required this.hitRadius});

  final String id;

  /// [px]
  final double hitRadius;
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
