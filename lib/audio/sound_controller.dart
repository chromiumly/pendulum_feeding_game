/// The game's sound: one switch for the background music and the effects.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// The sound effects, each a file under `assets/audio/`.
enum Sfx {
  /// The player throws a food.
  throwFood('sfx/throw.mp3'),

  /// The bride eats a food.
  eat('sfx/eat.mp3'),

  /// "START" is shown, and play begins.
  whistle('sfx/whistle.mp3'),

  /// The result is shown.
  claps('sfx/claps.mp3');

  const Sfx(this.file);

  /// The file's path under `assets/audio/`.
  final String file;
}

/// What actually makes the sound, so that tests can stand in for it.
abstract interface class SoundBackend {
  /// Called in the tap that turns sound on or off, at once and before
  /// anything else: the moment browsers allow sound to be started. Must not
  /// wait for anything.
  void unlock();

  /// Makes the music audible. The first time it also starts it, from its
  /// beginning, looping from then on. After that the music has played on
  /// silently since [muteBgm], so this brings in the part it has reached
  /// now, not where it was left.
  Future<void> unmuteBgm();

  /// Silences the music, which plays on unheard.
  Future<void> muteBgm();

  /// Stops the music playing on unheard: from now until [releaseBgm], it
  /// gets no further. Comes after [muteBgm] if the music was audible.
  Future<void> holdBgm();

  /// Lets the music play on unheard again, from where [holdBgm] stopped it.
  Future<void> releaseBgm();

  /// Plays [sfx] once, over anything already playing.
  Future<void> playSfx(Sfx sfx);

  /// Cuts off every play of [sfx] that is still sounding, or about to.
  Future<void> stopSfx(Sfx sfx);
}

/// Owns whether sound is on, and plays the music and effects while it is.
///
/// Sound is off until the player turns it on. Browsers do not allow sound
/// before the player touches the page, so the music starts only when the
/// player first turns sound on. It then never stops: turning sound off
/// only silences it, and turning it on again brings in wherever the music
/// has got to. It lives as long as the app, so the music plays on without a
/// break across screens. A failure of the [SoundBackend] never reaches the
/// game: sound just stays quiet.
///
/// The music can also be held, e.g. while the phone is in portrait: it then
/// stops where it is, and once nothing holds it any more it carries on from
/// there, if sound is on (see [holdBgm]).
class SoundController extends ChangeNotifier {
  /// Creates a controller with sound off, playing through [backend].
  SoundController(this._backend);

  final SoundBackend _backend;

  bool _enabled = false;

  /// What holds the music still; it plays only while this is empty.
  final _holds = <Object>{};

  /// Music changes run one after another, so that quickly switching sound
  /// on and off cannot leave the music in the wrong state.
  Future<void> _music = Future.value();

  /// Whether sound is on.
  bool get enabled => _enabled;

  /// Turns sound on if it is off, and off if it is on.
  void toggle() => setEnabled(!_enabled);

  /// Turns sound on or off, with the music following it.
  /// While the music is held, it only takes note: the music follows once
  /// it is released.
  void setEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    _unlock();
    if (_holds.isEmpty) {
      _queueMusic(enabled ? _backend.unmuteBgm : _backend.muteBgm);
    }
    notifyListeners();
  }

  /// Whether anything holds the music still.
  bool get isBgmHeld => _holds.isNotEmpty;

  /// Holds the music still for [reason], until [releaseBgm] with the same
  /// [reason]. It stops where it is, even with sound off (where it plays on
  /// unheard otherwise). Holding it again for the same [reason] does
  /// nothing.
  void holdBgm(Object reason) {
    final wasHeld = isBgmHeld;
    if (!_holds.add(reason) || wasHeld) return;
    if (_enabled) _queueMusic(_backend.muteBgm);
    _queueMusic(_backend.holdBgm);
  }

  /// Releases the hold for [reason]. Once nothing holds the music, it
  /// carries on from where it was held: audibly if sound is on. Call it in a
  /// tap if possible, which is when browsers allow sound to start.
  void releaseBgm(Object reason) {
    if (!_holds.remove(reason) || isBgmHeld) return;
    _queueMusic(_backend.releaseBgm);
    if (_enabled) {
      _unlock();
      _queueMusic(_backend.unmuteBgm);
    }
  }

  /// Lets the backend start sound, at once.
  void _unlock() {
    try {
      _backend.unlock();
    } on Object catch (error) {
      debugPrint('Sound failed: $error');
    }
  }

  /// Runs [change] to the music after those before it.
  void _queueMusic(Future<void> Function() change) {
    _music = _music.then((_) => _quietly(change));
  }

  /// Plays [sfx] if sound is on.
  void playSfx(Sfx sfx) {
    if (!_enabled) return;
    unawaited(_quietly(() => _backend.playSfx(sfx)));
  }

  /// Cuts off [sfx] if it is sounding, e.g. the applause when the player
  /// leaves the result. Works with sound on or off.
  void stopSfx(Sfx sfx) {
    unawaited(_quietly(() => _backend.stopSfx(sfx)));
  }

  /// Runs [action], ignoring any error it throws or completes with.
  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      debugPrint('Sound failed: $error');
    }
  }
}
