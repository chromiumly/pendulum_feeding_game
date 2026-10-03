/// The sound effects on one Web Audio context.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'preloaded_effects.dart';
import 'sound_controller.dart';

/// Plays the effects through a single Web Audio context, each one decoded
/// once and then played from memory as often as needed.
///
/// One context, because Safari on iPhones allows only four per page and
/// does not take back those left open. A player for each effect (as
/// audioplayers makes on the web, each with a context of its own) runs out
/// of them, and then effects stop sounding.
///
/// Safari also lets a context sound only once the player has touched the
/// page for it. [unlock] is called in the tap that turns sound on; and the
/// context is woken by any later touch, for when the phone has put it to
/// sleep (e.g. the app went to the background).
class WebAudioEffects {
  web.AudioContext? _context;

  /// Makes the context and lets it sound. Call it while handling a tap,
  /// before any `await`, or Safari keeps it silent.
  void unlock() {
    final context = _context ??= _create();
    _wake(context);
    // A sound started in the tap is what Safari wants to see: one silent
    // sample will do.
    final silence = context.createBuffer(1, 1, context.sampleRate);
    final source = context.createBufferSource()..buffer = silence;
    source.connect(context.destination);
    source.start();
  }

  web.AudioContext _create() {
    final context = web.AudioContext();
    // Each touch is a chance to wake it, should the phone have stopped it.
    void wakeOnTouch(web.Event _) => _wake(context);
    web.window.addEventListener('touchend', wakeOnTouch.toJS);
    web.window.addEventListener('pointerup', wakeOnTouch.toJS);
    return context;
  }

  /// Asks [context] to run, if it does not.
  static void _wake(web.AudioContext context) {
    if (context.state == 'running') return;
    unawaited(
      context.resume().toDart.then<void>(
        (_) {},
        onError: (Object error) => debugPrint('Waking audio failed: $error'),
      ),
    );
  }

  /// Fetches and decodes [sfx], ready to start at once. Fails if [unlock]
  /// has not been called yet.
  Future<EffectPool> load(Sfx sfx) async {
    final context = _context;
    if (context == null) throw StateError('Call unlock first.');
    final data = await rootBundle.load('assets/audio/${sfx.file}');
    // A copy of exactly the file's bytes: decoding takes the buffer over.
    final bytes = Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final buffer = await context.decodeAudioData(bytes.buffer.toJS).toDart;
    return _DecodedEffect(context, buffer);
  }
}

/// One decoded effect; every start plays it anew, over any play still on.
class _DecodedEffect implements EffectPool {
  _DecodedEffect(this._context, this._buffer);

  final web.AudioContext _context;
  final web.AudioBuffer _buffer;

  @override
  Future<StopEffect> start(double volume) async {
    WebAudioEffects._wake(_context);
    final source = _context.createBufferSource()..buffer = _buffer;
    final gain = _context.createGain();
    gain.gain.value = volume;
    source.connect(gain);
    gain.connect(_context.destination);
    source.start();
    return () async {
      try {
        source.stop();
      } on Object {
        // It has ended already.
      }
    };
  }
}
