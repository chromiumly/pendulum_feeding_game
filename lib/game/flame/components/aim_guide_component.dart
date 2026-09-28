import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../model/game_session.dart';
import '../../model/rules.dart';
import '../stage_style.dart';

/// Draws the predicted trajectory and a launch arrow while aiming.
class AimGuideComponent extends Component {
  AimGuideComponent(this.session);

  final GameSession session;

  static const _guideDt = 0.05;
  static const _guidePoints = 50;

  /// Arrow length at maximum launch speed [px].
  static const _maxArrowLength = 90.0;

  final _dotPaint = Paint();
  final _arrowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas canvas) {
    final velocity = session.aimVelocity;
    if (velocity == null) return;
    final armed = session.isAimArmed;
    final origin = session.food.position;

    if (armed) {
      final points = predictTrajectory(
        position: origin,
        velocity: velocity,
        gravity: session.config.foodGravity,
        dt: _guideDt,
        count: _guidePoints,
      );
      for (var i = 0; i < points.length; i++) {
        _dotPaint.color = StageStyle.guide.withValues(
          alpha: 1 - i / points.length,
        );
        canvas.drawCircle(Offset(points[i].x, points[i].y), 2, _dotPaint);
      }
    }

    final speed = velocity.length;
    if (speed == 0) return;
    _arrowPaint.color = armed
        ? StageStyle.arrowArmed
        : StageStyle.arrowDisarmed;
    final length = speed / session.config.maxLaunchSpeed * _maxArrowLength;
    final angle = math.atan2(velocity.y, velocity.x);
    final start = Offset(origin.x, origin.y);
    final tip = start + Offset.fromDirection(angle, length);
    canvas
      ..drawLine(start, tip, _arrowPaint)
      ..drawLine(tip, tip + Offset.fromDirection(angle + 2.6, 12), _arrowPaint)
      ..drawLine(tip, tip + Offset.fromDirection(angle - 2.6, 12), _arrowPaint);
  }
}
