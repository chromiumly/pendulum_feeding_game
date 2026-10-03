import 'dart:ui';

import 'package:flame/components.dart';

import '../../../ui/format.dart';
import '../../../ui/text_styles.dart';
import '../../model/game_session.dart';

/// Score and remaining time at the top right (Figma: ゲーム画面), shown
/// while playing and on the result screen.
class HudComponent extends Component {
  HudComponent(this.session);

  final GameSession session;

  final _textPaint = TextPaint(style: GameTextStyles.hud);

  @override
  void render(Canvas canvas) {
    if (session.phase case GamePhase.setup || GamePhase.countdown) return;
    final remaining = session.remainingSeconds;
    final time = remaining.isInfinite ? '∞' : remaining.ceil().toString();
    _textPaint
      ..render(canvas, 'SCORE ${formatScore(session.score)}', Vector2(555, 3))
      ..render(canvas, 'TIME $time', Vector2(739, 3));
  }
}
