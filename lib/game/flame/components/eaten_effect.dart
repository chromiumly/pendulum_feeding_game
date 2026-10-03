import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../../ui/assets.dart';
import '../../../ui/format.dart';
import '../../../ui/text_styles.dart';
import '../../model/rules.dart';

/// When the bride eats (Figma: ゲーム画面（得点シーン）): a heart for each
/// food in a row pops up around her mouth, with the points gained and, from
/// the second food in a row, the combo multiplier. Everything drifts up and
/// fades out.
///
/// Like birthday candles, every [heartsPerBigHeart] foods in a row show as
/// one big heart, so that long combos do not crowd the bride.
///
/// Placed relative to the mouth at the moment of eating, as in the Figma
/// layout with the bride hanging straight down; it does not follow her.
class EatenEffect extends Component with HasGameReference<FlameGame> {
  EatenEffect({
    required Vector2 position,
    required this.points,
    required this.combo,
  }) : _mouth = position.clone();

  final Vector2 _mouth;
  final int points;
  final int combo;

  static const duration = 1.0;

  static const heartsPerBigHeart = 5;

  /// Figma's heart, and the big one standing for [heartsPerBigHeart].
  static final heartSize = Vector2(22, 20);
  static final bigHeartSize = Vector2(36, 36 * 20 / 22);

  /// Big and small hearts for the [combo]th food in a row.
  static ({int big, int small}) heartCount(int combo) =>
      (big: combo ~/ heartsPerBigHeart, small: combo % heartsPerBigHeart);

  /// Hearts lie on an arc around the mouth, from its left round below it to
  /// its lower right, big ones first. Two land about where Figma has them.
  static const _arcFrom = 200 * math.pi / 180;
  static const _arcTo = 20 * math.pi / 180;

  /// Each heart pops in this much after the one before [s].
  static const _popStagger = 0.05;

  /// Centre offsets from the mouth and sizes of the hearts for [combo].
  static List<({Vector2 offset, Vector2 size})> heartLayout(int combo) {
    final count = heartCount(combo);
    final sizes = [
      for (var i = 0; i < count.big; i++) bigHeartSize,
      for (var i = 0; i < count.small; i++) heartSize,
    ];
    // Wider apart when big hearts need the room.
    final radius = count.big > 0 ? 58.0 : 48.0;
    return [
      for (var i = 0; i < sizes.length; i++)
        (
          offset: _arcPoint(
            sizes.length == 1 ? 0 : i / (sizes.length - 1),
            radius,
          ),
          size: sizes[i],
        ),
    ];
  }

  static Vector2 _arcPoint(double t, double radius) {
    final angle = _arcFrom + (_arcTo - _arcFrom) * t;
    return Vector2(math.cos(angle), math.sin(angle)) * radius;
  }

  /// Left ends and vertical centres of the labels, from the mouth.
  static final _comboOffset = Vector2(14, -53.5);
  static final _pointsOffset = Vector2(14, -31.5);

  /// How far everything drifts up over [duration] [px].
  static const _rise = 24.0;

  /// The hearts pop in over this long [s].
  static const _popTime = 0.2;

  /// Everything fades out over the last part [s].
  static const _fadeTime = 0.35;

  Sprite? _heart;
  double _time = 0;
  final _heartPaint = Paint()..filterQuality = FilterQuality.medium;

  late final _hearts = heartLayout(combo);
  late final String _pointsText = '+$points';
  late final String? _comboText = combo >= 2
      ? formatCombo(combo, comboMultiplier(combo))
      : null;

  @override
  void onLoad() {
    // Not awaited, so that the labels show at once; the hearts appear once
    // their image has loaded (it is cached after the first time).
    game.loadSprite(GameAssets.heart).then((sprite) => _heart = sprite);
    add(RemoveEffect(delay: duration));
  }

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final t = math.min(_time, duration);
    final opacity = (duration - t).clamp(0.0, _fadeTime) / _fadeTime;
    final lift = Vector2(0, -_rise * Curves.easeOut.transform(t / duration));

    final heart = _heart;
    if (heart != null) {
      _heartPaint.color = Color.fromRGBO(0, 0, 0, opacity);
      for (final (i, h) in _hearts.indexed) {
        final popT = (t - i * _popStagger) / _popTime;
        if (popT <= 0) continue;
        final pop = Curves.easeOutBack.transform(math.min(popT, 1));
        heart.render(
          canvas,
          position: _mouth + h.offset + lift,
          size: h.size * pop,
          anchor: Anchor.center,
          overridePaint: _heartPaint,
        );
      }
    }

    final comboText = _comboText;
    if (comboText != null) {
      _label(GameTextStyles.eatenCombo, opacity).render(
        canvas,
        comboText,
        _mouth + _comboOffset + lift,
        anchor: Anchor.centerLeft,
      );
    }
    _label(GameTextStyles.eatenPoints, opacity).render(
      canvas,
      _pointsText,
      _mouth + _pointsOffset + lift,
      anchor: Anchor.centerLeft,
    );
  }

  static TextPaint _label(TextStyle style, double opacity) => TextPaint(
    style: style.copyWith(color: style.color!.withValues(alpha: opacity)),
  );
}
