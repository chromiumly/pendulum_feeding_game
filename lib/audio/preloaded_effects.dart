/// Sound effects played from players made ahead of time.
library;

import 'package:flutter/foundation.dart';

import 'sound_controller.dart';

/// Cuts off one play of an effect. Does nothing if that play has ended.
typedef StopEffect = Future<void> Function();

/// One effect, loaded and ready to start at once.
abstract interface class EffectPool {
  /// Starts the effect from its beginning at [volume] (0 to 1), over any run
  /// of it still playing. Returns what cuts this play off.
  Future<StopEffect> start(double volume);
}

/// Plays the [Sfx] effects from pools made ahead of time.
///
/// Loading an effect when it is to be played means fetching and preparing
/// the file after the throw, which is heard as the effect starting late. A
/// "pool" (an [EffectPool]) has it loaded already, so an effect starts at
/// once.
///
/// Until the pools are ready, and for any effect whose pool fails, an
/// effect is played the old way, loaded for that play alone. Sound
/// never fails to play only because the pools did.
class PreloadedEffects {
  /// [createPool] makes the pool of an effect. [playOnce] plays an effect
  /// from a player made for it alone, which is the fallback; both return
  /// what cuts that play off. [volume] is
  /// how loud the effects are, from 0 (silent) to 1 (full).
  PreloadedEffects({
    required this._createPool,
    required this._playOnce,
    required this.volume,
  });

  final Future<EffectPool> Function(Sfx sfx) _createPool;
  final Future<StopEffect> Function(Sfx sfx) _playOnce;

  /// How loud the effects are, from 0 (silent) to 1 (full).
  final double volume;

  /// How many plays of one effect are kept to be cut off. More than can
  /// sound at once; a play that has ended is cut off by doing nothing.
  static const _stopsKept = 8;

  final _pools = <Sfx, EffectPool>{};
  final _stops = <Sfx, List<StopEffect>>{};

  /// How often each effect was asked to stop, so that a play that was
  /// still starting when that happened can be cut off as it starts.
  final _stopRequests = <Sfx, int>{};
  Future<void>? _preparing;

  /// Makes the pool of every effect that has none yet, in turn.
  ///
  /// Meant to be started in the background and left. Calling it while it
  /// runs joins that run; calling it later makes the pools that failed
  /// before, and only those.
  Future<void> prepare() {
    return _preparing ??= _prepare().whenComplete(() => _preparing = null);
  }

  Future<void> _prepare() async {
    for (final sfx in Sfx.values) {
      if (_pools.containsKey(sfx)) continue;
      try {
        _pools[sfx] = await _createPool(sfx);
      } on Object catch (error) {
        debugPrint('Preloading ${sfx.name} failed: $error');
      }
    }
  }

  /// Plays [sfx] from its pool, or if it has none or the pool fails, from a
  /// player made for it alone.
  Future<void> play(Sfx sfx) async {
    final requestsBefore = _stopRequests[sfx] ?? 0;
    final stop = await _start(sfx);
    if ((_stopRequests[sfx] ?? 0) != requestsBefore) {
      // [stop] was asked for while this play was starting.
      await stop();
      return;
    }
    final stops = _stops.putIfAbsent(sfx, () => [])..add(stop);
    if (stops.length > _stopsKept) stops.removeAt(0);
  }

  Future<StopEffect> _start(Sfx sfx) async {
    final pool = _pools[sfx];
    if (pool != null) {
      try {
        return await pool.start(volume);
      } on Object catch (error) {
        debugPrint('Playing ${sfx.name} from its pool failed: $error');
      }
    }
    return _playOnce(sfx);
  }

  /// Cuts off every play of [sfx] that is sounding, and any that is
  /// starting.
  Future<void> stop(Sfx sfx) async {
    _stopRequests[sfx] = (_stopRequests[sfx] ?? 0) + 1;
    final stops = _stops.remove(sfx) ?? const [];
    for (final stop in stops) {
      try {
        await stop();
      } on Object catch (error) {
        debugPrint('Stopping ${sfx.name} failed: $error');
      }
    }
  }
}
