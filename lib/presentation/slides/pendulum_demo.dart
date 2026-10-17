/// The game's double pendulum, swinging on its own on a slide.
library;

import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../game/fixed_step_clock.dart';
import '../../game/model/game_config.dart';
import '../../game/model/setup_rules.dart';
import '../../math/vec2.dart';
import '../../physics/double_pendulum.dart';
import '../../ui/assets.dart';
import '../../ui/palette.dart';
import '../../ui/rope_painter.dart';

/// Swings the game's double pendulum as a game starts: from the setup
/// screen's starting pose with the speed スタート gives it, with the same
/// parameters, step and integrator as the game. Drawn like the game (the
/// rope, the pivots and the bride on her swing), with the path of the swing
/// seat fading out behind her.
///
/// It starts over each time it is built anew, e.g. on coming back to its
/// slide.
class PendulumDemo extends StatefulWidget {
  const PendulumDemo({super.key});

  /// The setup screen's starting pose, given the speed the game gives it at
  /// スタート (see GameSession.startCountdown).
  static PendulumState startState() {
    const config = GameConfig();
    final params = config.pendulumParams;
    final state = config.pendulumInitialState;
    final omegas = startOmegas(
      params: params,
      state: state,
      targetEnergy: config.startEnergyTopMultiple * brideTopEnergy(params),
      counterSpinRatio: config.startCounterSpinRatio,
    );
    return PendulumState(
      upperTheta: state.upperTheta,
      lowerTheta: state.lowerTheta,
      upperOmega: omegas.upperOmega,
      lowerOmega: omegas.lowerOmega,
    );
  }

  @override
  State<PendulumDemo> createState() => _PendulumDemoState();
}

class _PendulumDemoState extends State<PendulumDemo>
    with SingleTickerProviderStateMixin {
  static const _config = GameConfig();
  final _pendulum = DoublePendulum(_config.pendulumParams);
  final _clock = FixedStepClock(stepDt: _config.fixedDt);

  var _state = PendulumDemo.startState();

  /// The swing seat's recent positions, oldest first, relative to the pivot
  /// [px of the game]: the last few seconds.
  final _trail = ListQueue<Vec2>();
  static const _trailLength = 300;

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  ui.Image? _bride;
  ui.Image? _pivot;
  final _streams = <(ImageStream, ImageStreamListener)>[];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _load(GameAssets.bride, (image) => _bride = image);
    _load(GameAssets.pivot, (image) => _pivot = image);
  }

  void _load(String asset, void Function(ui.Image) loaded) {
    final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      if (mounted) setState(() => loaded(info.image));
    });
    stream.addListener(listener);
    _streams.add((stream, listener));
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final steps = _clock.advance(dt);
    if (steps == 0) return;
    final substepDt = _config.fixedDt / _config.physicsSubsteps;
    for (var i = 0; i < steps; i++) {
      for (var j = 0; j < _config.physicsSubsteps; j++) {
        _state = _pendulum.step(_state, substepDt);
      }
      _trail.add(_pendulum.positions(_state, Vec2.zero).lower);
      if (_trail.length > _trailLength) _trail.removeFirst();
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final (stream, listener) in _streams) {
      stream.removeListener(listener);
    }
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PendulumPainter(
        state: _state,
        positions: _pendulum.positions(_state, Vec2.zero),
        trail: _trail.toList(),
        bride: _bride,
        pivot: _pivot,
      ),
      size: Size.infinite,
    );
  }
}

class _PendulumPainter extends CustomPainter {
  _PendulumPainter({
    required this.state,
    required this.positions,
    required this.trail,
    required this.bride,
    required this.pivot,
  });

  final PendulumState state;

  /// Relative to the pivot [px of the game].
  final PendulumPositions positions;
  final List<Vec2> trail;

  /// The game's images, or null until they are loaded.
  final ui.Image? bride;
  final ui.Image? pivot;

  /// As the game draws them (BrideComponent, PendulumComponent) [px of the
  /// game].
  static const _brideSize = Size(84, 128);
  static const _seat = Offset(30.5, 84);
  static const _pivotSize = 18.0;

  /// How far from the pivot fits in the card: both rods and half of the
  /// bride's image beyond the seat [px of the game]. Fitting all of her
  /// would leave the card mostly empty; her head may be cut off at the edge
  /// only for a moment, when the rods point straight at it.
  static final _reach =
      const GameConfig().pendulumParams.upperLength +
      const GameConfig().pendulumParams.lowerLength +
      Offset(_brideSize.width - _seat.dx, _seat.dy).distance / 2;

  static final _rope = RopePainter();
  static final _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.shortestSide / 2 - 12) / _reach;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale);
    Offset at(Vec2 p) => Offset(p.x, p.y);

    // The seat's path, behind everything, fading out towards its tail.
    for (var i = 1; i < trail.length; i++) {
      final fade = i / trail.length;
      canvas.drawLine(
        at(trail[i - 1]),
        at(trail[i]),
        Paint()
          ..color = Palette.scorePink.withValues(alpha: 0.5 * fade * fade)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }

    final upper = at(positions.upper);
    final lower = at(positions.lower);
    final bride = this.bride;
    if (bride != null) {
      canvas
        ..save()
        ..translate(lower.dx, lower.dy)
        ..rotate(-state.lowerTheta)
        ..drawImageRect(
          bride,
          Rect.fromLTWH(0, 0, bride.width.toDouble(), bride.height.toDouble()),
          -_seat & _brideSize,
          _imagePaint,
        )
        ..restore();
    }
    _rope.draw(canvas, Offset.zero, upper);
    _rope.draw(canvas, upper, lower, toSeat: true);
    final pivot = this.pivot;
    if (pivot != null) {
      for (final centre in [Offset.zero, upper]) {
        canvas.drawImageRect(
          pivot,
          Rect.fromLTWH(0, 0, pivot.width.toDouble(), pivot.height.toDouble()),
          Rect.fromCenter(
            center: centre,
            width: _pivotSize,
            height: _pivotSize,
          ),
          _imagePaint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PendulumPainter oldDelegate) => true;
}
