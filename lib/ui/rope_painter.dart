/// The pendulum's rope, as the game draws it.
library;

import 'dart:ui';

import 'palette.dart';

/// Draws the pendulum's rope like the paper-cut art: a soft shadow, a light
/// outline (the art's white edge), the brown rope, and a thin highlight on
/// its upper left side. Shared by the game's stage and the presentation's
/// pendulum, so that both look the same.
///
/// Where the lower rope meets the swing seat (part of the bride's image,
/// drawn below the rope), the shadow, outline and highlight fade out over
/// [_seatFade] just before the seat, and the rope ends square, so that it
/// meets the seat instead of lying on top of it.
class RopePainter {
  static const _ropeWidth = 3.0;
  static const _seatFade = 8.0;
  static const _seatGap = 1.0;
  static const _ropeOutline = 2.0;
  static const _shadowOffset = Offset(1.5, 1.5);
  final _ropeShadowPaint = _round(
    _stroke(const Color(0x40000000), _ropeWidth + 2 * _ropeOutline)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
  );
  final _ropeOutlinePaint = _round(
    _stroke(Palette.textOutline, _ropeWidth + 2 * _ropeOutline),
  );
  final _ropePaint = _round(_stroke(Palette.darkBrown, _ropeWidth));
  final _ropeHighlightPaint = _round(_stroke(const Color(0x59FFFFFF), 1));
  // The joint's pivot covers the other end of the lower rope.
  final _ropeToSeatPaint = _stroke(Palette.darkBrown, _ropeWidth)
    ..strokeCap = StrokeCap.butt;

  // Copies of the light layers that fade out towards the seat.
  final _seatShadowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _ropeWidth + 2 * _ropeOutline
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
  final _seatOutlinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _ropeWidth + 2 * _ropeOutline
    ..strokeCap = StrokeCap.round;
  final _seatHighlightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;

  /// Returns a stroke paint of [color], [width] px wide.
  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  /// Returns [paint] with round line ends.
  static Paint _round(Paint paint) => paint..strokeCap = StrokeCap.round;

  /// Draws the rope from [a] to [b] (world coordinates [px]); [toSeat] is
  /// true when [b] is the swing seat, where the rope must not lie on top.
  void draw(Canvas canvas, Offset a, Offset b, {bool toSeat = false}) {
    final along = b - a;
    final length = along.distance;
    if (length == 0) return;
    // The normal on the upper left, towards the light.
    var normal = Offset(-along.dy, along.dx) / length;
    if (normal.dx + normal.dy > 0) normal = -normal;
    final highlight = normal * (_ropeWidth / 4);

    if (!toSeat) {
      canvas
        ..drawLine(a + _shadowOffset, b + _shadowOffset, _ropeShadowPaint)
        ..drawLine(a, b, _ropeOutlinePaint)
        ..drawLine(a, b, _ropePaint)
        ..drawLine(a + highlight, b + highlight, _ropeHighlightPaint);
      return;
    }

    // Fully drawn up to the fade, then gone [_seatGap] before the seat.
    final fadeEnd = ((length - _seatGap) / length).clamp(0.0, 1.0);
    final fadeStart = ((length - _seatGap - _seatFade) / length).clamp(
      0.0,
      fadeEnd,
    );
    Shader fading(Offset from, Offset to, Color color) => Gradient.linear(
      from,
      to,
      [color, color, color.withValues(alpha: 0)],
      [0, fadeStart, fadeEnd],
    );
    _seatShadowPaint.shader = fading(
      a + _shadowOffset,
      b + _shadowOffset,
      const Color(0x40000000),
    );
    _seatOutlinePaint.shader = fading(a, b, Palette.textOutline);
    _seatHighlightPaint.shader = fading(
      a + highlight,
      b + highlight,
      const Color(0x59FFFFFF),
    );
    canvas
      ..drawLine(a + _shadowOffset, b + _shadowOffset, _seatShadowPaint)
      ..drawLine(a, b, _seatOutlinePaint)
      ..drawLine(a, b, _ropeToSeatPaint)
      ..drawLine(a + highlight, b + highlight, _seatHighlightPaint);
  }
}
