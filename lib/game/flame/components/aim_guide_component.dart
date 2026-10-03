import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../../ui/palette.dart';
import '../../model/game_session.dart';
import '../../model/rules.dart';
import '../stage_style.dart';

/// While aiming, the predicted flight: an orange band with a light outline,
/// like the play-count bonus gauge, that thins and fades out along the way,
/// with a highlight running along it. A drag too short to throw shows it
/// grey and without the highlight.
class AimGuideComponent extends Component {
  AimGuideComponent(this.session);

  final GameSession session;

  /// Opacity of the whole guide (band, outline, shadow and highlight), so
  /// that it does not stand out too much: 1 is fully opaque.
  static const opacity = 0.6;

  static const _guideDt = 0.05;
  static const _guidePoints = 50;

  /// Half the band's width at the start and at the end [px].
  static const _startHalfWidth = 3.5;
  static const _endHalfWidth = 1.2;

  /// The light outline around the band, like the art's white edges [px].
  static const _outline = 2.0;

  /// The highlight runs from start to end in [_sweepTime] and then waits, as
  /// on the gauge.
  static const _sweepTime = 1.0;
  static const _sweepPeriod = 1.4;

  /// Points on each side of the highlight's centre that it covers.
  static const _highlightSpan = 4;

  double _time = 0;
  bool _wasAiming = false;

  final _outlinePaint = Paint()..color = Palette.textOutline;
  final _shadowPaint = Paint()
    ..color = const Color(0x33000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
  final _bandPaint = Paint();
  final _highlightPaint = Paint();
  final _fadePaint = Paint()..blendMode = BlendMode.dstIn;

  @override
  void update(double dt) {
    final aiming = session.aim != null;
    // Each new aim starts its highlight from the food.
    _time = aiming && _wasAiming ? _time + dt : 0;
    _wasAiming = aiming;
  }

  @override
  void render(Canvas canvas) {
    final velocity = session.aimVelocity;
    if (velocity == null || velocity.length == 0) return;
    final armed = session.isAimArmed;
    final origin = session.food.position;
    final points = [
      origin,
      ...predictTrajectory(
        position: origin,
        velocity: velocity,
        gravity: session.config.foodGravity,
        dt: _guideDt,
        count: _guidePoints,
      ),
    ].map((p) => Offset(p.x, p.y)).toList();

    final bounds = _bounds(points).inflate(_startHalfWidth + _outline + 4);
    canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));

    final outline = _band(points, (t) => _halfWidth(t) + _outline);
    canvas
      ..drawPath(outline.shift(const Offset(0, 1.5)), _shadowPaint)
      ..drawPath(outline, _outlinePaint);

    _bandPaint.shader = Gradient.linear(
      points.first,
      points.last,
      armed
          ? const [Palette.gaugeEnd, Palette.gaugeStart]
          : const [StageStyle.guideDisarmed, StageStyle.guideDisarmed],
    );
    canvas.drawPath(_band(points, _halfWidth), _bandPaint);

    if (armed) _drawHighlight(canvas, points);

    // Fade out along the way, whichever way the path turns.
    canvas
      ..drawVertices(
        _fadeMask(points, armed ? 1 : 0.6),
        BlendMode.dstIn,
        _fadePaint,
      )
      ..restore();
  }

  static double _halfWidth(double t) =>
      _startHalfWidth + (_endHalfWidth - _startHalfWidth) * t;

  /// A short light patch on the band around the point the highlight has
  /// reached, fading towards both of its ends.
  void _drawHighlight(Canvas canvas, List<Offset> points) {
    final phase = _time % _sweepPeriod;
    if (phase > _sweepTime) return;
    final centre = (phase / _sweepTime * (points.length - 1)).round();
    final from = math.max(0, centre - _highlightSpan);
    final to = math.min(points.length - 1, centre + _highlightSpan);
    if (to - from < 2) return;
    final part = points.sublist(from, to + 1);
    _highlightPaint.shader = Gradient.linear(
      part.first,
      part.last,
      const [Color(0x00FFFFFF), Color(0xB3FFFFFF), Color(0x00FFFFFF)],
      const [0, 0.5, 1],
    );
    canvas.drawPath(
      _band(
        part,
        (t) =>
            _halfWidth((from + t * (part.length - 1)) / (points.length - 1)) *
            0.6,
      ),
      _highlightPaint,
    );
  }

  /// A closed band along [points], [halfWidth] (of 0 to 1 along the points)
  /// on each side, as one path so that it has no seams.
  static Path _band(List<Offset> points, double Function(double t) halfWidth) {
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final normal = _normal(points, i);
      final w = halfWidth(i / (points.length - 1));
      left.add(points[i] + normal * w);
      right.add(points[i] - normal * w);
    }
    return Path()..addPolygon([...left, ...right.reversed], true);
  }

  /// White, from opaque at the start to transparent at the end, over a band
  /// wider than everything drawn: multiplying by it fades the guide.
  static Vertices _fadeMask(List<Offset> points, double startAlpha) {
    final positions = <Offset>[];
    final colors = <Color>[];
    const halfWidth = _startHalfWidth + _outline + 4;
    for (var i = 0; i < points.length; i++) {
      final normal = _normal(points, i);
      final t = i / (points.length - 1);
      final color = Color.fromRGBO(255, 255, 255, startAlpha * (1 - t));
      positions
        ..add(points[i] + normal * halfWidth)
        ..add(points[i] - normal * halfWidth);
      colors
        ..add(color)
        ..add(color);
    }
    return Vertices(VertexMode.triangleStrip, positions, colors: colors);
  }

  /// The unit normal of the path at point [i].
  static Offset _normal(List<Offset> points, int i) {
    final a = points[math.max(0, i - 1)];
    final b = points[math.min(points.length - 1, i + 1)];
    final along = b - a;
    if (along.distance == 0) return const Offset(0, -1);
    return Offset(-along.dy, along.dx) / along.distance;
  }

  static Rect _bounds(List<Offset> points) {
    var left = points.first.dx, right = left;
    var top = points.first.dy, bottom = top;
    for (final p in points) {
      left = math.min(left, p.dx);
      right = math.max(right, p.dx);
      top = math.min(top, p.dy);
      bottom = math.max(bottom, p.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}
