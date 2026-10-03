/// Sound effects played from players made ahead of time.
library;

import 'package:flutter/foundation.dart';

import 'sound_controller.dart';

/// The players of one effect, loaded and ready to start at once.
abstract interface class EffectPool {
  /// Starts the effect from its beginning at [volume] (0 to 1), over any run
  /// of it still playing.
  Future<void> start(double volume);
}

/// Plays the [Sfx] effects from pools made ahead of time.
///
/// Playing from a new player each time means fetching and preparing the
/// file after the throw, which is heard as the effect starting late. A pool
/// has its players loaded already, so an effect starts at once.
///
/// Until the pools are ready, and for any effect whose pool fails, an
/// effect is played the old way, from a player made for it alone. Sound
/// never fails to play only because the pools did.
class PreloadedEffects {
  /// [createPool] makes the pool of an effect. [playOnce] plays an effect
  /// from a player made for it alone, which is the fallback. [volume] is
  /// how loud the effects are, from 0 (silent) to 1 (full).
  PreloadedEffects({
    required this._createPool,
    required this._playOnce,
    required this.volume,
  });

  final Future<EffectPool> Function(Sfx sfx) _createPool;
  final Future<void> Function(Sfx sfx) _playOnce;

  /// How loud the effects are, from 0 (silent) to 1 (full).
  final double volume;

  final _pools = <Sfx, EffectPool>{};
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
    final pool = _pools[sfx];
    if (pool != null) {
      try {
        await pool.start(volume);
        return;
      } on Object catch (error) {
        debugPrint('Playing ${sfx.name} from its pool failed: $error');
      }
    }
    await _playOnce(sfx);
  }
}
