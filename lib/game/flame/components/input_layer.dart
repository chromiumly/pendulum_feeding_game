/// Pointer input for the game: setup drags and throws.
library;

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
  /// [isActive] says whether input is taken; a held game takes none.
  InputLayer(this.session, {bool Function()? isActive})
    : _isActive = isActive ?? _always,
      super(
        size: Vector2(session.config.worldSize.x, session.config.worldSize.y),
      );

  final GameSession session;
  final bool Function() _isActive;

  static bool _always() => true;

  /// Grabs a handle on the setup screen, or starts aiming while playing.
  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!_isActive()) return;
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

  /// Lets go of the handle, or throws (or cancels a too-short aim).
  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    session
      ..endPlacement()
      ..releaseAim();
  }

  /// Lets go of the handle, or drops the aim without throwing.
  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    session
      ..endPlacement()
      ..cancelAim();
  }

  /// Converts Flame's vector, already in world coordinates, to [Vec2].
  static Vec2 _vec(Vector2 v) => Vec2(v.x, v.y);
}
