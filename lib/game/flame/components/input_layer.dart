import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../../math/vec2.dart';
import '../../model/game_session.dart';

/// Full-screen drag target that forwards input to the session.
///
/// Setup: dragging the joint or the bride places the pendulum.
/// Playing: a drag may start anywhere; pulling back and releasing throws the
/// food.
class InputLayer extends PositionComponent with DragCallbacks {
  InputLayer(this.session)
    : super(
        size: Vector2(session.config.worldSize.x, session.config.worldSize.y),
      );

  final GameSession session;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final point = _vec(event.localPosition);
    switch (session.phase) {
      case GamePhase.setup:
        session.beginPlacement(point);
      case GamePhase.playing:
        session.beginAim(point);
      case GamePhase.countdown || GamePhase.finished:
        break;
    }
  }

  // At most one of placement and aim is active; the other call is a no-op.

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final point = _vec(event.localEndPosition);
    session
      ..updatePlacement(point)
      ..updateAim(point);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    session
      ..endPlacement()
      ..releaseAim();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    session
      ..endPlacement()
      ..cancelAim();
  }

  static Vec2 _vec(Vector2 v) => Vec2(v.x, v.y);
}
