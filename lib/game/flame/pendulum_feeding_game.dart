import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../fixed_step_clock.dart';
import '../model/game_event.dart';
import '../model/game_session.dart';
import 'components/aim_guide_component.dart';
import 'components/eaten_effect.dart';
import 'components/hud_component.dart';
import 'components/input_layer.dart';
import 'components/stage_components.dart';
import 'stage_style.dart';

/// Flame host for a [GameSession].
///
/// Responsibilities: drive the session in fixed steps, forward input, render
/// its state, turn session events into effects, and publish the phase for the
/// Flutter overlays.
class PendulumFeedingGame extends FlameGame {
  PendulumFeedingGame({required this.session, this.onGameFinished})
    : _clock = FixedStepClock(stepDt: session.config.fixedDt),
      super(
        camera: CameraComponent.withFixedResolution(
          width: session.config.worldSize.x,
          height: session.config.worldSize.y,
        ),
      );

  final GameSession session;

  /// Called with the final score as soon as the game has finished, before
  /// the result is shown (see [phase]), e.g. to start recording it.
  final void Function(int score)? onGameFinished;

  final FixedStepClock _clock;
  late final GroomComponent _groom = GroomComponent(session);

  /// Session phase, for the Flutter overlays. Updated once per frame.
  ///
  /// [GamePhase.finished] is held back (still [GamePhase.playing]) while a
  /// score effect is playing out, e.g. for a buzzer beater, and for
  /// [resultPause] after it, so that the result does not cover it.
  late final phase = ValueNotifier<GamePhase>(session.phase);

  /// Pause between the last score effect and the result [s].
  static const resultPause = 0.3;

  /// Time until the latest score effect has finished [s].
  double _effectTimeLeft = 0;

  /// Time until the result may be shown, once the game has finished [s].
  double _resultDelay = 0;

  /// [GameSession.countdownNumber], for the countdown overlay.
  late final countdownNumber = ValueNotifier<int>(session.countdownNumber);

  /// Ends the setup screen (the スタート button).
  void startCountdown() {
    session.startCountdown();
    _publish();
  }

  /// Transparent: the stage background is drawn by Flutter behind the game,
  /// so that the setup hint can sit between the two.
  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    // World coordinates == 844x390 logical coordinates, origin at top left.
    camera.viewfinder.anchor = Anchor.topLeft;
    // Asset paths are full paths (GameAssets), not relative to assets/images.
    images.prefix = '';
    // Not awaited: the session runs from the first frame, and each sprite
    // appears once its image has loaded.
    world.addAll([
      _groom,
      BrideComponent(session),
      PendulumComponent(session),
      FoodComponent(session),
      if (StageStyle.showHitCircles) HitCirclesComponent(session),
      AimGuideComponent(session),
      HudComponent(session),
      InputLayer(session),
    ]);
  }

  @override
  void update(double dt) {
    _effectTimeLeft = math.max(0, _effectTimeLeft - dt);
    _resultDelay = math.max(0, _resultDelay - dt);
    final steps = _clock.advance(dt);
    for (var i = 0; i < steps; i++) {
      session.step();
    }
    session.takeEvents().forEach(_handleEvent);
    _publish();
    super.update(dt);
  }

  void _publish() {
    final holdResult = session.isFinished && _resultDelay > 0;
    phase.value = holdResult ? GamePhase.playing : session.phase;
    countdownNumber.value = session.countdownNumber;
  }

  void _handleEvent(GameEvent event) {
    switch (event) {
      case FoodEaten(:final mouthPosition, :final points):
        world.add(
          EatenEffect(
            position: Vector2(mouthPosition.x, mouthPosition.y),
            points: points,
          ),
        );
        _effectTimeLeft = EatenEffect.duration;
      case FoodLaunched():
        _groom.playThrow();
      case GameFinished(:final score):
        // Events arrive in order, so a food eaten on the final step has
        // already started its effect.
        _resultDelay = _effectTimeLeft > 0 ? _effectTimeLeft + resultPause : 0;
        onGameFinished?.call(score);
      case FoodMissed():
        break;
    }
  }
}
