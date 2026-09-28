import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../../../math/vec2.dart';
import '../../../ui/assets.dart';
import '../../../ui/palette.dart';
import '../../model/game_session.dart';
import '../stage_style.dart';

Offset _offset(Vec2 v) => Offset(v.x, v.y);

Paint _fill(Color color) => Paint()..color = color;

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width;

/// The following components only draw the current [GameSession] state; they
/// hold no gameplay state of their own. World coordinates equal the 844x390
/// stage (Figma) coordinates. Sizes and anchors come from the Figma layout.

class BackgroundComponent extends SpriteComponent
    with HasGameReference<FlameGame> {
  BackgroundComponent(Vec2 size) : super(size: Vector2(size.x, size.y));

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite(GameAssets.background);
  }
}

/// Rods and the two upper dots (pivot and middle joint). The lower node is
/// the bride's swing seat, so it has no dot.
class PendulumComponent extends Component {
  PendulumComponent(this.session);

  final GameSession session;

  static const dotRadius = 7.5;

  final _rodPaint = _stroke(Palette.darkBrown, 3)..strokeCap = StrokeCap.round;
  final _dotPaint = _fill(Palette.darkBrown);
  final _dotEdgePaint = _stroke(const Color(0xFF000000), 1);

  @override
  void render(Canvas canvas) {
    final origin = _offset(session.config.pendulumOrigin);
    final positions = session.pendulumPositions;
    final upper = _offset(positions.upper);
    final lower = _offset(positions.lower);
    canvas
      ..drawLine(origin, upper, _rodPaint)
      ..drawLine(upper, lower, _rodPaint);
    for (final dot in [origin, upper]) {
      canvas
        ..drawCircle(dot, dotRadius, _dotPaint)
        ..drawCircle(dot, dotRadius - 0.5, _dotEdgePaint);
    }
  }
}

/// The bride hangs from the lower node by her swing seat and is rotated by
/// -lowerTheta, like the mouth position in the rules.
class BrideComponent extends SpriteComponent with HasGameReference<FlameGame> {
  BrideComponent(this.session) : super(size: spriteSize, anchor: seatAnchor);

  final GameSession session;

  static final spriteSize = Vector2(84, 128);

  /// Where the rope meets the swing seat in the sprite.
  static const seat = Offset(30.5, 84);
  static final seatAnchor = Anchor(seat.dx / 84, seat.dy / 128);

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite(GameAssets.bride);
    _follow();
  }

  @override
  void update(double dt) => _follow();

  void _follow() {
    final node = session.pendulumPositions.lower;
    position.setValues(node.x, node.y);
    angle = -session.pendulumState.lowerTheta;
  }
}

/// The groom stands with his feet at [GameConfig.groomPosition].
class GroomComponent extends SpriteComponent with HasGameReference<FlameGame> {
  GroomComponent(GameSession session)
    : super(
        size: Vector2(64, 128),
        anchor: Anchor.bottomCenter,
        position: Vector2(
          session.config.groomPosition.x,
          session.config.groomPosition.y,
        ),
      );

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite(GameAssets.groom);
  }
}

/// Dummy food: a 40 px circle coloured by food type.
class FoodComponent extends Component {
  FoodComponent(this.session);

  final GameSession session;

  static const radius = 20.0;

  final _fillPaint = Paint();
  final _edgePaint = _stroke(const Color(0xFF000000), 1);

  @override
  void render(Canvas canvas) {
    final food = session.food;
    final center = _offset(food.position);
    _fillPaint.color = StageStyle.food(food.type.id);
    canvas
      ..drawCircle(center, radius, _fillPaint)
      ..drawCircle(center, radius - 0.5, _edgePaint);
  }
}

/// Red markers on the draggable joint and bride during setup
/// (Figma: 5 px strokes outside the joint dot and the bride's frame).
class SetupHighlightComponent extends Component {
  SetupHighlightComponent(this.session);

  final GameSession session;
  final _paint = _stroke(Palette.accentRed, 5);

  static final _brideFrame = Rect.fromLTWH(
    -BrideComponent.seat.dx,
    -BrideComponent.seat.dy,
    BrideComponent.spriteSize.x,
    BrideComponent.spriteSize.y,
  ).inflate(2.5);

  @override
  void render(Canvas canvas) {
    if (session.phase != GamePhase.setup) return;
    final positions = session.pendulumPositions;
    canvas.drawCircle(
      _offset(positions.upper),
      PendulumComponent.dotRadius + 2.5,
      _paint,
    );
    canvas
      ..save()
      ..translate(positions.lower.x, positions.lower.y)
      ..rotate(-session.pendulumState.lowerTheta)
      ..drawRect(_brideFrame, _paint)
      ..restore();
  }
}

/// Debug overlay of the circles the collision rule uses.
class HitCirclesComponent extends Component {
  HitCirclesComponent(this.session);

  final GameSession session;
  final _paint = _stroke(StageStyle.hitCircle, 1);

  @override
  void render(Canvas canvas) {
    canvas
      ..drawCircle(
        _offset(session.mouthPosition),
        session.config.brideMouthRadius,
        _paint,
      )
      ..drawCircle(
        _offset(session.food.position),
        session.food.type.hitRadius,
        _paint,
      );
  }
}
