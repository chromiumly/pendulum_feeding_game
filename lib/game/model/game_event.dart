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
  const FoodEaten({
    required this.mouthPosition,
    required this.points,
    required this.combo,
  });

  final Vec2 mouthPosition;

  /// Including the combo bonus.
  final int points;

  /// Foods eaten in a row, this one included.
  final int combo;
}

class FoodMissed extends GameEvent {
  const FoodMissed();
}

class GameFinished extends GameEvent {
  const GameFinished({required this.score});

  final int score;
}
