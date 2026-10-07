/// The Flame game that hosts a session and draws the stage.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../../audio/sound_controller.dart';
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
///
/// It holds still while the screen is in portrait (see [portrait]) or the
/// app is not in front (anything but [AppLifecycleState.resumed]), and
/// carries on from where it was as soon as neither holds. Flame pauses the
/// engine in the background too, but its own resume would also start a game
/// that is still in portrait.
class PendulumFeedingGame extends FlameGame {
  /// [session] is the game to host; its config sets the world size.
  /// [onGameFinished] is called with the final score once it ends.
  /// [showHitCircles] forces the debug hit circles on (true) or off (false)
  /// regardless of the compile-time flag; null follows the flag. The
  /// how-to-play demo turns them on. [sound] plays the effects; null is
  /// silent.
  PendulumFeedingGame({
    required this.session,
    this.onGameFinished,
    bool? showHitCircles,
    this.sound,
  }) : _showHitCircles = showHitCircles ?? StageStyle.showHitCircles,
       _clock = FixedStepClock(stepDt: session.config.fixedDt),
       super(
         camera: CameraComponent.withFixedResolution(
           width: session.config.worldSize.x,
           height: session.config.worldSize.y,
         ),
       );

  final GameSession session;

  /// Plays the effects for what happens in the game, or null for none.
  final SoundController? sound;

  /// Called with the final score as soon as the game has finished, before
  /// the result is shown (see [phase]), e.g. to start recording it.
  final void Function(int score)? onGameFinished;

  final bool _showHitCircles;
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

  /// Whether the screen is in portrait, where the game is covered by the
  /// prompt to rotate the device: set by the screen that shows it.
  bool get portrait => _portrait;
  set portrait(bool value) => _holdIf(() => _portrait = value);
  bool _portrait = false;

  /// Whether the app is not in front (in the background, or another thing
  /// such as the notification centre has the focus).
  bool _inBackground = false;

  /// Whether the game is held still: nothing moves, the clock included.
  bool get isSuspended => _portrait || _inBackground;

  /// Runs [change] to the reasons for holding still. A drag under way when
  /// the game stops is dropped: its finger may never come back up here.
  void _holdIf(void Function() change) {
    final wasSuspended = isSuspended;
    change();
    if (isSuspended && !wasSuspended) {
      session
        ..cancelAim()
        ..endPlacement();
    }
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    _holdIf(() => _inBackground = state != AppLifecycleState.resumed);
  }

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

  /// Adds the stage's components, drawn in this order (back to front).
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
      if (_showHitCircles) HitCirclesComponent(session),
      AimGuideComponent(session),
      HudComponent(session),
      InputLayer(session, isActive: () => !isSuspended),
    ]);
  }

  /// Runs as many fixed session steps as [dt] (the frame time [s]) calls
  /// for, turns their events into effects, and publishes the phase. Does
  /// nothing at all while [isSuspended].
  @override
  void update(double dt) {
    if (isSuspended) return;
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

  /// Copies the session's phase and countdown to the overlays' notifiers.
  ///
  /// The applause is played here, as the result comes up: that is after the
  /// last score effect, not when the game finishes ([GameFinished]).
  void _publish() {
    final holdResult = session.isFinished && _resultDelay > 0;
    final shown = holdResult ? GamePhase.playing : session.phase;
    if (shown == GamePhase.finished && phase.value != GamePhase.finished) {
      sound?.playSfx(Sfx.claps);
    }
    phase.value = shown;
    countdownNumber.value = session.countdownNumber;
  }

  /// Plays the effect for [event]: score hearts and the eating sound, the
  /// groom's throw and its sound, the whistle at the start, or the end of the
  /// game.
  void _handleEvent(GameEvent event) {
    switch (event) {
      case FoodEaten(:final mouthPosition, :final points, :final combo):
        world.add(
          EatenEffect(
            position: Vector2(mouthPosition.x, mouthPosition.y),
            points: points,
            combo: combo,
          ),
        );
        _effectTimeLeft = EatenEffect.duration;
        sound?.playSfx(Sfx.eat);
      case FoodLaunched():
        _groom.playThrow();
        sound?.playSfx(Sfx.throwFood);
      case StartCueShown():
        sound?.playSfx(Sfx.whistle);
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
