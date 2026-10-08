/// The sound backend: the music with flame_audio, the effects with Web
/// Audio.
library;

import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import 'bgm_position.dart';
import 'preloaded_effects.dart';
import 'sound_controller.dart';
import 'web_audio_effects.dart';

/// Plays `assets/audio/bgm/bgm.mp3` as the music, through flame_audio, and
/// [Sfx] files as the effects, through Web Audio.
///
/// The music is never muted by volume, which iPhones ignore for web audio.
/// It is paused instead, and when sound comes back it jumps to where it
/// would have got to had it played on (see [positionAfterMute]).
///
/// The music also pauses while the app is in the background, and picks up
/// again when it returns, if it was playing. While held ([holdBgm]), it is
/// paused and does not pick up again by itself.
///
/// The effects are decoded when sound is first turned on, so that they start
/// at once (see [PreloadedEffects]), and played on one Web Audio context
/// ([WebAudioEffects]). Not through flame_audio: on the web it makes a Web
/// Audio context for every player, and Safari on iPhones allows only four,
/// so effects went silent there. The music keeps its own one, two in all.
class FlameSoundBackend implements SoundBackend {
  /// The music's file under `assets/audio/`.
  static const bgmFile = 'bgm/bgm.mp3';

  /// How loud the music is, from 0 (silent) to 1 (full). Well below the
  /// effects, so that they can be heard over it: measured, the music at this
  /// volume is about 3.5 LU quieter than the effects (see docs/assets.md).
  static const bgmVolume = 0.3;

  /// How loud the effects are, from 0 (silent) to 1 (full).
  static const sfxVolume = 1.0;

  /// Whether the music has been started.
  bool _started = false;

  /// Runs from when the music was last silenced, to know how far it would
  /// have played on. Stopped while the music is held.
  final _silent = Stopwatch();

  /// Where the music was when it was last silenced.
  Duration _positionAtMute = Duration.zero;

  final _webAudio = WebAudioEffects();

  late final _effects = PreloadedEffects(
    volume: sfxVolume,
    createPool: _webAudio.load,
    // Before an effect is decoded: decoded on the spot, and played.
    playOnce: (sfx) async => (await _webAudio.load(sfx)).start(sfxVolume),
  );

  @override
  void unlock() => _webAudio.unlock();

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
  Future<void> holdBgm() async => _silent.stop();

  @override
  Future<void> releaseBgm() async {
    if (_started) _silent.start();
  }

  @override
  Future<void> playSfx(Sfx sfx) => _effects.play(sfx);

  @override
  Future<void> stopSfx(Sfx sfx) => _effects.stop(sfx);
}
