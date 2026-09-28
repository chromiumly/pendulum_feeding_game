import 'dart:math' as math;

import '../../math/vec2.dart';
import '../../physics/double_pendulum.dart';
import 'food.dart';
import 'game_config.dart';
import 'game_event.dart';
import 'rules.dart';
import 'setup_rules.dart';

/// setup: the player places the pendulum; nothing moves.
/// countdown: 3, 2, 1 and "START"; nothing moves and the clock is stopped.
/// playing: physics, food and the time limit run.
/// finished: time is up; the state is frozen.
enum GamePhase { setup, countdown, playing, finished }

/// Drag in progress, in world coordinates.
class Aim {
  const Aim({required this.start, required this.current});

  final Vec2 start;
  final Vec2 current;
}

/// Setup-screen drag in progress. [rawTheta] follows the pointer without
/// the angle limit, so that dragging past a limit and back feels continuous.
class _Placement {
  const _Placement({
    required this.handle,
    required this.pivot,
    required this.pointerAngle,
    required this.rawTheta,
  });

  final SetupHandle handle;
  final Vec2 pivot;
  final double pointerAngle;
  final double rawTheta;
}

/// One play-through of the game: the single owner of all gameplay state.
///
/// Advances only in fixed steps of [GameConfig.fixedDt] via [step]; it knows
/// nothing about Flame, rendering or real time.
class GameSession {
  GameSession({this.config = const GameConfig(), math.Random? random})
    : _random = random ?? math.Random(),
      _pendulum = DoublePendulum(config.pendulumParams),
      _pendulumState = config.pendulumInitialState {
    _pendulumPositions = _pendulum.positions(
      _pendulumState,
      config.pendulumOrigin,
    );
    _food = _spawnFood();
  }

  final GameConfig config;
  final math.Random _random;
  final DoublePendulum _pendulum;

  PendulumState _pendulumState;
  late PendulumPositions _pendulumPositions;
  late Food _food;
  Aim? _aim;
  _Placement? _placement;
  int _score = 0;
  int _countdownElapsedSteps = 0;
  int _elapsedSteps = 0;
  GamePhase _phase = GamePhase.setup;
  final List<GameEvent> _events = [];

  PendulumState get pendulumState => _pendulumState;
  PendulumPositions get pendulumPositions => _pendulumPositions;
  Food get food => _food;
  Aim? get aim => _aim;
  int get score => _score;
  GamePhase get phase => _phase;
  bool get isFinished => _phase == GamePhase.finished;

  /// The handle being dragged on the setup screen, if any.
  SetupHandle? get activeHandle => _placement?.handle;

  /// During the countdown: 3, 2, 1, then 0 while "START" is shown.
  int get countdownNumber {
    final remaining = config.countdownSteps - _countdownElapsedSteps;
    if (remaining <= 0) return 0;
    final stepsPerSecond = (1 / config.fixedDt).round();
    return (remaining + stepsPerSecond - 1) ~/ stepsPerSecond;
  }

  double get remainingSeconds =>
      (config.timeLimitSteps - _elapsedSteps) * config.fixedDt;

  Vec2 get mouthPosition => brideMouthPosition(
    lowerNode: _pendulumPositions.lower,
    lowerTheta: _pendulumState.lowerTheta,
    mouthOffset: config.brideMouthOffset,
  );

  /// Launch velocity the current aim would produce, or null when not aiming.
  Vec2? get aimVelocity {
    final aim = _aim;
    if (aim == null) return null;
    return launchVelocity(
      dragStart: aim.start,
      dragCurrent: aim.current,
      scale: config.launchScale,
      maxSpeed: config.maxLaunchSpeed,
    );
  }

  /// Whether the current aim is long enough to throw on release.
  bool get isAimArmed {
    final aim = _aim;
    return aim != null &&
        aim.start.distanceTo(aim.current) >= config.minDragDistance;
  }

  /// Returns and clears the events produced since the last call.
  List<GameEvent> takeEvents() {
    final events = List<GameEvent>.of(_events);
    _events.clear();
    return events;
  }

  // ---- Setup ---------------------------------------------------------------

  /// Grabs the joint or the bride under [point], if any.
  void beginPlacement(Vec2 point) {
    if (_phase != GamePhase.setup || _placement != null) return;
    final positions = _pendulumPositions;
    final handle = pickSetupHandle(
      point: point,
      joint: positions.upper,
      brideNode: positions.lower,
      brideMouth: mouthPosition,
      jointGrabRadius: config.setupJointGrabRadius,
      brideGrabRadius: config.setupBrideGrabRadius,
    );
    if (handle == null) return;
    final (pivot, theta) = switch (handle) {
      SetupHandle.joint => (config.pendulumOrigin, _pendulumState.upperTheta),
      SetupHandle.bride => (positions.upper, _pendulumState.lowerTheta),
    };
    _placement = _Placement(
      handle: handle,
      pivot: pivot,
      pointerAngle: pendulumAngle(pivot, point),
      rawTheta: theta,
    );
  }

  /// Rotates the grabbed rod by the pointer's angular movement around its
  /// pivot. Both angular velocities stay zero.
  void updatePlacement(Vec2 point) {
    final placement = _placement;
    if (placement == null) return;
    final pointerAngle = pendulumAngle(placement.pivot, point);
    final rawTheta =
        placement.rawTheta + wrapAngle(pointerAngle - placement.pointerAngle);
    _placement = _Placement(
      handle: placement.handle,
      pivot: placement.pivot,
      pointerAngle: pointerAngle,
      rawTheta: rawTheta,
    );

    final limit = config.setupAngleLimit;
    final theta = rawTheta.clamp(-limit, limit);
    final state = _pendulumState;
    _setPendulumState(
      PendulumState(
        upperTheta: placement.handle == SetupHandle.joint
            ? theta
            : state.upperTheta,
        lowerTheta: placement.handle == SetupHandle.bride
            ? theta
            : state.lowerTheta,
        upperOmega: 0,
        lowerOmega: 0,
      ),
    );
  }

  void endPlacement() {
    _placement = null;
  }

  void startCountdown() {
    if (_phase != GamePhase.setup) return;
    _placement = null;
    _phase = GamePhase.countdown;
  }

  // ---- Input ---------------------------------------------------------------

  void beginAim(Vec2 point) {
    if (_phase != GamePhase.playing || _food.isFlying || _aim != null) return;
    _aim = Aim(start: point, current: point);
  }

  void updateAim(Vec2 point) {
    final aim = _aim;
    if (aim == null) return;
    _aim = Aim(start: aim.start, current: point);
  }

  /// Throws the food with the current aim, or cancels a too-short drag.
  void releaseAim() {
    final velocity = aimVelocity;
    final armed = isAimArmed;
    _aim = null;
    if (velocity == null || !armed || _phase != GamePhase.playing) return;
    _food = _food.launched(velocity);
    _events.add(const FoodLaunched());
  }

  void cancelAim() {
    _aim = null;
  }

  // ---- Simulation ----------------------------------------------------------

  void step() {
    switch (_phase) {
      case GamePhase.setup || GamePhase.finished:
        return;
      case GamePhase.countdown:
        _stepCountdown();
      case GamePhase.playing:
        _stepPlaying();
    }
  }

  void _stepCountdown() {
    _countdownElapsedSteps++;
    if (_countdownElapsedSteps >=
        config.countdownSteps + config.startCueSteps) {
      _phase = GamePhase.playing;
    }
  }

  void _stepPlaying() {
    final dt = config.fixedDt;

    _setPendulumState(_pendulum.step(_pendulumState, dt));

    if (_food.isFlying) {
      _stepFood(dt);
    }

    _elapsedSteps++;
    if (_elapsedSteps >= config.timeLimitSteps) {
      _finish();
    }
  }

  void _stepFood(double dt) {
    final previous = _food.position;
    final next = stepProjectile(
      position: _food.position,
      velocity: _food.velocity,
      gravity: config.foodGravity,
      dt: dt,
    );
    _food = _food.moved(next.position, next.velocity);

    final mouth = mouthPosition;
    if (sweptCircleHit(
      from: previous,
      to: _food.position,
      center: mouth,
      radiusSum: _food.type.hitRadius + config.brideMouthRadius,
    )) {
      _score += config.pointsPerFood;
      _events.add(
        FoodEaten(mouthPosition: mouth, points: config.pointsPerFood),
      );
      _food = _spawnFood();
      return;
    }

    if (isOutOfWorld(
      position: _food.position,
      radius: _food.type.hitRadius,
      worldSize: config.worldSize,
    )) {
      _events.add(const FoodMissed());
      _food = _spawnFood();
    }
  }

  void _finish() {
    _phase = GamePhase.finished;
    _aim = null;
    _events.add(GameFinished(score: _score));
  }

  void _setPendulumState(PendulumState state) {
    _pendulumState = state;
    _pendulumPositions = _pendulum.positions(state, config.pendulumOrigin);
  }

  Food _spawnFood() {
    final types = config.foodTypes;
    return Food(
      type: types[_random.nextInt(types.length)],
      position: config.foodSpawnPosition,
    );
  }
}
