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
/// playing: physics, food and the time limit run. After the time limit,
///   play goes on only while a food thrown before it is in the air (a
///   buzzer beater): it still scores if it reaches the bride.
/// finished: time is up; the state is frozen.
enum GamePhase { setup, countdown, playing, finished }

/// Drag in progress, in world coordinates.
class Aim {
  const Aim({required this.start, required this.current});

  final Vec2 start;
  final Vec2 current;
}

/// Setup-screen drag in progress.
class _Placement {
  const _Placement({
    required this.handle,
    required this.pivot,
    required this.pointerAngle,
  });

  final SetupHandle handle;
  final Vec2 pivot;

  /// Pointer angle around [pivot] at the previous drag position.
  final double pointerAngle;
}

/// One play-through of the game: the single owner of all gameplay state.
///
/// Advances only in fixed steps of [GameConfig.fixedDt] via [step]; it knows
/// nothing about Flame, rendering or real time.
class GameSession {
  /// [placedPendulum] starts the setup screen from an earlier placement
  /// instead of [GameConfig.pendulumInitialState].
  ///
  /// [gamesPlayed] is the number of games the player has finished before; it
  /// favours the bride's favourites in the food draw for the whole game.
  GameSession({
    this.config = const GameConfig(),
    math.Random? random,
    PendulumState? placedPendulum,
    int gamesPlayed = 0,
  }) : _random = random ?? math.Random(),
       foodTypeProbabilities = foodProbabilities(
         count: config.foodTypes.length,
         bias: favouriteBias(
           gamesPlayed: gamesPlayed,
           limit: config.favouriteBiasLimit,
           halfPlays: config.favouriteBiasHalfPlays,
         ),
       ),
       _pendulum = DoublePendulum(config.pendulumParams),
       _pendulumState = placedPendulum ?? config.pendulumInitialState {
    _pendulumPositions = _pendulum.positions(
      _pendulumState,
      config.pendulumOrigin,
    );
    _food = _spawnFood();
  }

  final GameConfig config;
  final math.Random _random;

  /// Probability of each of [GameConfig.foodTypes] in this game.
  final List<double> foodTypeProbabilities;
  final DoublePendulum _pendulum;

  PendulumState _pendulumState;
  late PendulumPositions _pendulumPositions;
  late Food _food;
  Aim? _aim;
  _Placement? _placement;
  PendulumState? _placedPendulum;
  int _score = 0;
  int _combo = 0;
  int _countdownElapsedSteps = 0;
  int _elapsedSteps = 0;
  GamePhase _phase = GamePhase.setup;
  final List<GameEvent> _events = [];

  PendulumState get pendulumState => _pendulumState;

  /// The pendulum as placed on the setup screen, at rest (without the start
  /// speed), e.g. to place it the same way again on a retry. Fixed once the
  /// countdown starts.
  PendulumState get placedPendulum =>
      _placedPendulum ??
      PendulumState(
        upperTheta: _pendulumState.upperTheta,
        lowerTheta: _pendulumState.lowerTheta,
        upperOmega: 0,
        lowerOmega: 0,
      );
  PendulumPositions get pendulumPositions => _pendulumPositions;
  Food get food => _food;
  Aim? get aim => _aim;
  int get score => _score;

  /// Foods eaten in a row; a food that leaves the world breaks the run.
  int get combo => _combo;
  GamePhase get phase => _phase;
  bool get isFinished => _phase == GamePhase.finished;

  /// The time limit has been reached; no more throws. The game may still be
  /// playing out a buzzer beater.
  bool get isTimeUp => _elapsedSteps >= config.timeLimitSteps;

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
    final pivot = switch (handle) {
      SetupHandle.joint => config.pendulumOrigin,
      SetupHandle.bride => positions.upper,
    };
    _placement = _Placement(
      handle: handle,
      pivot: pivot,
      pointerAngle: pendulumAngle(pivot, point),
    );
  }

  /// Rotates the grabbed rod by the pointer's angular movement around its
  /// pivot, all the way round if the player likes. The angle is normalized
  /// into [0, 2pi) (0 to 360 degrees). Both angular velocities stay zero.
  void updatePlacement(Vec2 point) {
    final placement = _placement;
    if (placement == null) return;
    final pointerAngle = pendulumAngle(placement.pivot, point);
    _placement = _Placement(
      handle: placement.handle,
      pivot: placement.pivot,
      pointerAngle: pointerAngle,
    );

    final state = _pendulumState;
    final current = placement.handle == SetupHandle.joint
        ? state.upperTheta
        : state.lowerTheta;
    final theta = normalizeAngle(
      current + wrapAngle(pointerAngle - placement.pointerAngle),
    );
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

  /// Ends setup (the スタート button). The pendulum gets its initial speed
  /// now (see [startOmegas]); it starts moving when play begins.
  void startCountdown() {
    if (_phase != GamePhase.setup) return;
    _placement = null;
    _placedPendulum = placedPendulum;
    final params = config.pendulumParams;
    final state = _pendulumState;
    final omegas = startOmegas(
      params: params,
      state: state,
      targetEnergy: config.startEnergyTopMultiple * brideTopEnergy(params),
      counterSpinRatio: config.startCounterSpinRatio,
    );
    _setPendulumState(
      PendulumState(
        upperTheta: state.upperTheta,
        lowerTheta: state.lowerTheta,
        upperOmega: omegas.upperOmega,
        lowerOmega: omegas.lowerOmega,
      ),
    );
    _phase = GamePhase.countdown;
  }

  // ---- Input ---------------------------------------------------------------

  void beginAim(Vec2 point) {
    if (_phase != GamePhase.playing ||
        isTimeUp ||
        _food.isFlying ||
        _aim != null) {
      return;
    }
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
    if (velocity == null || !armed || _phase != GamePhase.playing || isTimeUp) {
      return;
    }
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

    final substepDt = dt / config.physicsSubsteps;
    var pendulum = _pendulumState;
    for (var i = 0; i < config.physicsSubsteps; i++) {
      pendulum = _pendulum.step(pendulum, substepDt);
    }
    _setPendulumState(pendulum);

    if (_food.isFlying) {
      _stepFood(dt);
    }

    if (!isTimeUp) _elapsedSteps++;
    // Buzzer beater: a food still in the air at the time limit is played
    // out; the game ends once it has been eaten or has left the world.
    if (isTimeUp && !_food.isFlying) {
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
      radiusSum: config.foodHitRadius + config.brideMouthRadius,
    )) {
      _combo++;
      final points = comboPoints(basePoints: _food.type.points, combo: _combo);
      _score += points;
      _events.add(
        FoodEaten(mouthPosition: mouth, points: points, combo: _combo),
      );
      _food = _spawnFood();
      return;
    }

    if (isOutOfWorld(
      position: _food.position,
      radius: config.foodHitRadius,
      worldSize: config.worldSize,
    )) {
      _combo = 0;
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
      type: types[drawIndex(foodTypeProbabilities, _random)],
      position: config.foodSpawnPosition,
    );
  }
}
