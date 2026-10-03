/// The sound backend that plays the game's files with flame_audio.
library;

import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import 'bgm_position.dart';
import 'preloaded_effects.dart';
import 'sound_controller.dart';

/// Plays `assets/audio/bgm/bgm.mp3` as the music and [Sfx] files as the
/// effects, through flame_audio.
///
/// The music is never muted by volume, which iPhones ignore for web audio.
/// It is paused instead, and when sound comes back it jumps to where it
/// would have got to had it played on (see [positionAfterMute]).
///
/// The music also pauses while the app is in the background, and picks up
/// again when it returns, if it was playing.
///
/// The effects are played from pools of players loaded when sound is first
/// turned on, so that they start at once (see [PreloadedEffects]).
class FlameSoundBackend implements SoundBackend {
  /// The music's file under `assets/audio/`.
  static const bgmFile = 'bgm/bgm.mp3';

  /// How loud the music is, from 0 (silent) to 1 (full). Well below the
  /// effects, so that they can be heard over it: measured, the music at this
  /// volume is about 3.5 LU quieter than the effects (see docs/assets.md).
  static const bgmVolume = 0.3;

  /// How loud the effects are, from 0 (silent) to 1 (full).
  static const sfxVolume = 1.0;

  /// Players loaded ahead for each effect, and the most that play at once.
  /// An effect lasts well over a second, and a throw and a meal can follow
  /// each other quickly.
  static const effectPlayersAhead = 2;
  static const effectPlayersMost = 4;

  /// Whether the music has been started.
  bool _started = false;

  /// Runs from when the music was last silenced, to know how far it would
  /// have played on.
  final _silent = Stopwatch();

  /// Where the music was when it was last silenced.
  Duration _positionAtMute = Duration.zero;

  late final _effects = PreloadedEffects(
    volume: sfxVolume,
    createPool: (sfx) async => _FlameEffectPool(
      await FlameAudio.createPool(
        sfx.file,
        minPlayers: effectPlayersAhead,
        maxPlayers: effectPlayersMost,
      ),
    ),
    playOnce: (sfx) async {
      final player = await FlameAudio.play(sfx.file, volume: sfxVolume);
      return player.stop;
    },
  );

  @override
  Future<void> unmuteBgm() async {
    // However often this runs, only what is missing is made.
    unawaited(_effects.prepare());

    final player = FlameAudio.bgm.audioPlayer;
    if (!_started) {
      // Registers once, however often it is called.
      await FlameAudio.bgm.initialize();
      // Loops from the beginning when it reaches the end.
      await FlameAudio.bgm.play(bgmFile, volume: bgmVolume);
      _started = true;
      return;
    }
    final length = await player.getDuration();
    if (length != null && length > Duration.zero) {
      await player.seek(
        positionAfterMute(
          positionAtMute: _positionAtMute,
          mutedFor: _silent.elapsed,
          length: length,
        ),
      );
    }
    await FlameAudio.bgm.resume();
  }

  @override
  Future<void> muteBgm() async {
    if (!_started) return;
    _positionAtMute =
        await FlameAudio.bgm.audioPlayer.getCurrentPosition() ?? Duration.zero;
    _silent
      ..reset()
      ..start();
    await FlameAudio.bgm.pause();
  }

  @override
  Future<void> playSfx(Sfx sfx) => _effects.play(sfx);

  @override
  Future<void> stopSfx(Sfx sfx) => _effects.stop(sfx);
}

/// An [EffectPool] on flame_audio's [AudioPool].
class _FlameEffectPool implements EffectPool {
  _FlameEffectPool(this._pool);

  final AudioPool _pool;

  /// A player goes back to the pool by itself when its effect ends, and
  /// the stop function does nothing after that.
  @override
  Future<StopEffect> start(double volume) => _pool.start(volume: volume);
}
