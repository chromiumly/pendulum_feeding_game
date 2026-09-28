import '../../math/vec2.dart';

/// Things that happened during a step, for presentation (effects, sounds,
/// screen transitions). The session state stays the source of truth.
sealed class GameEvent {
  const GameEvent();
}

class FoodLaunched extends GameEvent {
  const FoodLaunched();
}

class FoodEaten extends GameEvent {
  const FoodEaten({required this.mouthPosition, required this.points});

  final Vec2 mouthPosition;
  final int points;
}

class FoodMissed extends GameEvent {
  const FoodMissed();
}

class GameFinished extends GameEvent {
  const GameFinished({required this.score});

  final int score;
}
