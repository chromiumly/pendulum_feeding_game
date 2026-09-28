import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/painting.dart';

import '../stage_style.dart';

/// Expanding ring plus a rising "+points" label at the bride's mouth.
class EatenEffect extends Component {
  EatenEffect({required this.position, required this.points});

  final Vector2 position;
  final int points;

  static const _duration = 0.8;

  @override
  Future<void> onLoad() async {
    final ring = CircleComponent(
      radius: 16,
      position: position,
      anchor: Anchor.center,
      paint: Paint()
        ..color = StageStyle.effect
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    ring.addAll([
      ScaleEffect.to(Vector2.all(2.5), EffectController(duration: _duration)),
      OpacityEffect.fadeOut(EffectController(duration: _duration)),
    ]);

    final label = TextComponent(
      text: '+$points',
      position: position - Vector2(0, 20),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: StageStyle.effect,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    label.add(
      MoveByEffect(Vector2(0, -40), EffectController(duration: _duration)),
    );

    addAll([ring, label]);
    add(RemoveEffect(delay: _duration));
  }
}
