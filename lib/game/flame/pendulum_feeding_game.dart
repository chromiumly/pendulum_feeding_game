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
import '../../ui/palette.dart';
import 'stage_style.dart';

/// Flame host for a [GameSession].
///
/// Responsibilities: drive the session in fixed steps, forward input, render
/// its state, turn session events into effects, and publish the phase for the
/// Flutter overlays.
class PendulumFeedingGame extends FlameGame {
  PendulumFeedingGame({required this.session})
    : _clock = FixedStepClock(stepDt: session.config.fixedDt),
      super(
        camera: CameraComponent.withFixedResolution(
          width: session.config.worldSize.x,
          height: session.config.worldSize.y,
        ),
      );

  final GameSession session;
  final FixedStepClock _clock;

  /// Session phase, for the Flutter overlays. Updated once per frame.
  late final phase = ValueNotifier<GamePhase>(session.phase);

  /// [GameSession.countdownNumber], for the countdown overlay.
  late final countdownNumber = ValueNotifier<int>(session.countdownNumber);

  /// Ends the setup screen (the スタート button).
  void startCountdown() {
    session.startCountdown();
    _publish();
  }

  @override
  Color backgroundColor() => Palette.letterbox;

  @override
  Future<void> onLoad() async {
    // World coordinates == 844x390 logical coordinates, origin at top left.
    camera.viewfinder.anchor = Anchor.topLeft;
    // Asset paths are full paths (GameAssets), not relative to assets/images.
    images.prefix = '';
    // Not awaited: the session runs from the first frame, and each sprite
    // appears once its image has loaded.
    world.addAll([
      BackgroundComponent(session.config.worldSize),
      GroomComponent(session),
      BrideComponent(session),
      PendulumComponent(session),
      FoodComponent(session),
      SetupHighlightComponent(session),
      if (StageStyle.showHitCircles) HitCirclesComponent(session),
      AimGuideComponent(session),
      HudComponent(session),
      InputLayer(session),
    ]);
  }

  @override
  void update(double dt) {
    final steps = _clock.advance(dt);
    for (var i = 0; i < steps; i++) {
      session.step();
    }
    session.takeEvents().forEach(_handleEvent);
    _publish();
    super.update(dt);
  }

  void _publish() {
    phase.value = session.phase;
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
      case FoodLaunched() || FoodMissed() || GameFinished():
        break;
    }
  }
}
