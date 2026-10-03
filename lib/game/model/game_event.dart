/// The events a game session reports to its presentation.
library;

import '../../math/vec2.dart';

/// Things that happened during a step, for presentation (effects, sounds,
/// screen transitions). The session state stays the source of truth.
sealed class GameEvent {
  const GameEvent();
}

/// The player released a drag and the food was thrown.
class FoodLaunched extends GameEvent {
  const FoodLaunched();
}

/// The food reached the bride's mouth and scored.
class FoodEaten extends GameEvent {
  const FoodEaten({
    required this.mouthPosition,
    required this.points,
    required this.combo,
  });

  /// Centre of the bride's hit circle at the moment she ate, in world
  /// coordinates [px]; effects are placed around it.
  final Vec2 mouthPosition;

  /// Including the combo bonus.
  final int points;

  /// Foods eaten in a row, this one included.
  final int combo;
}

/// The food left the world without being eaten; the combo is broken.
class FoodMissed extends GameEvent {
  const FoodMissed();
}

/// Time is up and no food is in the air: the game is over.
class GameFinished extends GameEvent {
  const GameFinished({required this.score});

  /// The final score.
  final int score;
}
