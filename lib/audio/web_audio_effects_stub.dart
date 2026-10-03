/// [WebAudioEffects] where there is no Web Audio (tests on the Dart VM).
library;

import 'preloaded_effects.dart';
import 'sound_controller.dart';

/// Stands in for the web's [WebAudioEffects]: plays nothing.
class WebAudioEffects {
  /// Does nothing.
  void unlock() {}

  /// Fails: there is nothing to play effects with.
  Future<EffectPool> load(Sfx sfx) =>
      Future.error(UnsupportedError('Sound effects need Web Audio.'));
}
