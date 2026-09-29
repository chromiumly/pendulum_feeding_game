import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../../../math/vec2.dart';
import '../../../ui/assets.dart';
import '../../../ui/palette.dart';
import '../../model/game_session.dart';
import '../stage_style.dart';

Offset _offset(Vec2 v) => Offset(v.x, v.y);

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width;

/// The following components only draw the current [GameSession] state; they
/// hold no gameplay state of their own. World coordinates equal the 844x390
/// stage (Figma) coordinates. Sizes and anchors come from the Figma layout.

/// Rods and the two pivots: the fixed one and the middle joint, which the
/// player drags on the setup screen. The lower node is the bride's swing
/// seat, so it has no pivot.
class PendulumComponent extends Component with HasGameReference<FlameGame> {
  PendulumComponent(this.session);

  final GameSession session;

  /// Displayed pivot diameter. The drag area is independent of it
  /// ([GameConfig.setupJointGrabRadius]).
  static const pivotSize = 18.0;
  static final _pivotSize = Vector2.all(pivotSize);

  /// The pivot is small, so its glow silhouette is enlarged before blurring;
  /// otherwise hardly any glow would show outside it.
  static final _jointGlowSize = Vector2.all(pivotSize * 1.8);

  final _rodPaint = _stroke(Palette.darkBrown, 3)..strokeCap = StrokeCap.round;
  final _jointGlow = _SetupGlow(sigma: 4);
  Sprite? _pivot;

  @override
  Future<void> onLoad() async {
    _pivot = await game.loadSprite(GameAssets.pivot);
  }

  @override
  void update(double dt) {
    _jointGlow.update(dt, active: session.phase == GamePhase.setup);
  }

  @override
  void render(Canvas canvas) {
    final positions = session.pendulumPositions;
    final origin = session.config.pendulumOrigin;
    final pivot = _pivot;
    final joint = Vector2(positions.upper.x, positions.upper.y);

    // Behind the rods, so that they stay crisp.
    if (pivot != null && session.phase == GamePhase.setup) {
      _jointGlow.render(
        canvas,
        pivot,
        position: joint,
        size: _jointGlowSize,
        anchor: Anchor.center,
      );
    }
    canvas
      ..drawLine(_offset(origin), _offset(positions.upper), _rodPaint)
      ..drawLine(_offset(positions.upper), _offset(positions.lower), _rodPaint);
    if (pivot == null) return;
    for (final center in [Vector2(origin.x, origin.y), joint]) {
      pivot.render(
        canvas,
        position: center,
        size: _pivotSize,
        anchor: Anchor.center,
      );
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
  void update(double dt) {
    _follow();
    _glow.update(dt, active: session.phase == GamePhase.setup);
  }

  void _follow() {
    final node = session.pendulumPositions.lower;
    position.setValues(node.x, node.y);
    angle = -session.pendulumState.lowerTheta;
  }

  /// On the setup screen only, shows that she can be dragged.
  final _glow = _SetupGlow(sigma: 7);

  @override
  void render(Canvas canvas) {
    final sprite = this.sprite;
    if (sprite != null && session.phase == GamePhase.setup) {
      _glow.render(canvas, sprite, position: Vector2.zero(), size: size);
    }
    super.render(canvas);
  }
}

/// A soft pale-gold glow that follows a sprite's outline, drawn behind it on the
/// setup screen to show what can be dragged. It is the sprite's own
/// silhouette, tinted and blurred, and it pulses slowly without ever fading
/// out.
class _SetupGlow {
  _SetupGlow({required this.sigma});

  static const _color = Palette.setupGlow;

  /// Blurred silhouettes stacked on top of each other. A single blurred copy
  /// is too faint just outside the outline; each copy strengthens it.
  static const _passes = 3;

  /// Seconds per bright-dim-bright cycle.
  static const _period = 2.4;
  static const _minOpacity = 0.6;
  static const _maxOpacity = 1.0;

  /// Blur radius [px]; the glow spreads about three times as far.
  final double sigma;

  double _time = 0;

  final _silhouettePaint = Paint()
    ..colorFilter = const ColorFilter.mode(_color, BlendMode.srcIn);
  late final _blurPaint = Paint()
    ..imageFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  final _opacityPaint = Paint();

  /// Advances the pulse while [active], and restarts it (bright) otherwise.
  void update(double dt, {required bool active}) {
    _time = active ? _time + dt : 0;
  }

  /// Draws the glow for [sprite] as if it were rendered at [position] with
  /// [size] and [anchor].
  void render(
    Canvas canvas,
    Sprite sprite, {
    required Vector2 position,
    required Vector2 size,
    Anchor anchor = Anchor.topLeft,
  }) {
    // 0 -> 1 -> 0 over one period, starting bright.
    final wave = 0.5 + 0.5 * math.cos(2 * math.pi * _time / _period);
    final opacity = _minOpacity + (_maxOpacity - _minOpacity) * wave;
    _opacityPaint.color = Color.fromRGBO(0, 0, 0, opacity);

    final origin = Offset(
      position.x - anchor.x * size.x,
      position.y - anchor.y * size.y,
    );
    final bounds = (origin & Size(size.x, size.y)).inflate(sigma * 3);
    canvas.saveLayer(bounds, _opacityPaint);
    for (var i = 0; i < _passes; i++) {
      canvas.saveLayer(bounds, _blurPaint);
      sprite.render(
        canvas,
        position: position,
        size: size,
        anchor: anchor,
        overridePaint: _silhouettePaint,
      );
      canvas.restore();
    }
    canvas.restore();
  }
}

enum GroomPose { hold, throwing }

/// The groom stands with his feet at [GameConfig.groomPosition], holding the
/// food. [playThrow] plays the throwing motion once, then he holds again.
/// He is not shown on the setup screen.
///
/// Presentation only: the food is launched by the session when the player
/// releases, independently of this animation.
class GroomComponent extends SpriteAnimationGroupComponent<GroomPose>
    with HasGameReference<FlameGame>, HasVisibility {
  GroomComponent(this.session)
    : super(
        size: spriteSize,
        anchor: feetAnchor,
        position: Vector2(
          session.config.groomPosition.x,
          session.config.groomPosition.y,
        ),
      );

  final GameSession session;

  /// All frames share a 523x943 canvas. They are drawn at the scale of the
  /// Figma layout, where the 864 px tall figure is 128 px tall.
  static const _canvas = Size(523, 943);
  static const _scale = 128 / 864;
  static final spriteSize = Vector2(
    _canvas.width * _scale,
    _canvas.height * _scale,
  );

  /// Centre between the shoes in the frames.
  static final feetAnchor = Anchor(249.5 / 523, 942 / 943);

  static const throwFrameSeconds = 0.08;

  @override
  Future<void> onLoad() async {
    final sprites = await Future.wait([
      game.loadSprite(GameAssets.groomHold),
      for (final path in GameAssets.groomThrow) game.loadSprite(path),
    ]);
    animations = {
      GroomPose.hold: SpriteAnimation.spriteList([sprites.first], stepTime: 1),
      GroomPose.throwing: SpriteAnimation.spriteList(
        sprites.sublist(1),
        stepTime: throwFrameSeconds,
        loop: false,
      ),
    };
    animationTickers![GroomPose.throwing]!.onComplete = () =>
        current = GroomPose.hold;
    current = GroomPose.hold;
    _updateVisibility();
  }

  /// Starts the throwing motion from its first frame.
  void playThrow() {
    if (animations == null) return; // Still loading.
    current = GroomPose.throwing;
    // Restart when a new throw comes before the previous one has finished.
    animationTicker!.reset();
  }

  @override
  void update(double dt) {
    _updateVisibility();
    super.update(dt);
  }

  void _updateVisibility() {
    isVisible = session.phase != GamePhase.setup;
  }
}

/// Dummy food: a 40 px circle coloured by food type. Like the groom who
/// holds it, it is not shown on the setup screen.
class FoodComponent extends Component {
  FoodComponent(this.session);

  final GameSession session;

  static const radius = 20.0;

  final _fillPaint = Paint();
  final _edgePaint = _stroke(const Color(0xFF000000), 1);

  @override
  void render(Canvas canvas) {
    if (session.phase == GamePhase.setup) return;
    final food = session.food;
    final center = _offset(food.position);
    _fillPaint.color = StageStyle.food(food.type.id);
    canvas
      ..drawCircle(center, radius, _fillPaint)
      ..drawCircle(center, radius - 0.5, _edgePaint);
  }
}

/// Debug overlay of the circles the collision rule uses.
class HitCirclesComponent extends Component {
  HitCirclesComponent(this.session);

  final GameSession session;
  final _paint = _stroke(StageStyle.hitCircle, 1);

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      _offset(session.mouthPosition),
      session.config.brideMouthRadius,
      _paint,
    );
    if (session.phase == GamePhase.setup) return; // Food is hidden.
    canvas.drawCircle(
      _offset(session.food.position),
      session.food.type.hitRadius,
      _paint,
    );
  }
}
