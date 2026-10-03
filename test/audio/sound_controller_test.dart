import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/audio/bgm_position.dart';
import 'package:pendulum_feeding_game/audio/sound_controller.dart';

import 'fake_sound_backend.dart';

void main() {
  late FakeSoundBackend backend;
  late SoundController sound;

  setUp(() {
    backend = FakeSoundBackend();
    sound = SoundController(backend);
  });

  test('sound is off at first, and plays nothing', () async {
    expect(sound.enabled, isFalse);
    sound.playSfx(Sfx.eat);
    await pumpEventQueue();
    expect(backend.calls, isEmpty);
  });

  test('turning it on brings in the music, and off silences it', () async {
    sound.toggle();
    expect(sound.enabled, isTrue);
    await pumpEventQueue();
    expect(backend.calls, ['unmute']);

    sound.toggle();
    expect(sound.enabled, isFalse);
    await pumpEventQueue();
    expect(backend.calls, ['unmute', 'mute']);
  });

  test('every switch on is an unmute, never a new start', () async {
    // What makes the music play on in the background is up to the backend
    // (see FlameSoundBackend); the controller only ever mutes and unmutes.
    for (var i = 0; i < 3; i++) {
      sound.setEnabled(true);
      sound.setEnabled(false);
    }
    await pumpEventQueue();
    expect(backend.calls, [
      'unmute',
      'mute',
      'unmute',
      'mute',
      'unmute',
      'mute',
    ]);
  });

  test('setting the state it already has does nothing', () async {
    sound.setEnabled(false);
    sound.setEnabled(true);
    sound.setEnabled(true);
    await pumpEventQueue();
    expect(backend.calls, ['unmute']);
  });

  test('tells its listeners when it is switched', () {
    var notified = 0;
    sound.addListener(() => notified++);
    sound.toggle();
    sound.toggle();
    expect(notified, 2);
  });

  test('effects play only while sound is on', () async {
    sound.setEnabled(true);
    sound.playSfx(Sfx.throwFood);
    sound.playSfx(Sfx.eat);
    sound.setEnabled(false);
    sound.playSfx(Sfx.throwFood);
    await pumpEventQueue();
    expect(backend.effects, [Sfx.throwFood, Sfx.eat]);
  });

  test(
    'switching on and off quickly leaves the music in the last state',
    () async {
      // Unmuting takes a while; the mute must wait for it, not overtake it.
      backend.unmuteGate = Completer<void>();
      sound.setEnabled(true);
      sound.setEnabled(false);
      await pumpEventQueue();
      expect(backend.calls, ['unmute']);

      backend.unmuteGate!.complete();
      await pumpEventQueue();
      expect(backend.calls, ['unmute', 'mute']);
    },
  );

  test('a failing backend does not break the game', () async {
    backend.failWith = StateError('autoplay blocked');
    expect(() => sound.setEnabled(true), returnsNormally);
    expect(() => sound.playSfx(Sfx.eat), returnsNormally);
    await pumpEventQueue();
    expect(sound.enabled, isTrue);
    // And it works again once the backend does.
    backend.failWith = null;
    sound.playSfx(Sfx.throwFood);
    await pumpEventQueue();
    expect(backend.effects, contains(Sfx.throwFood));
  });

  test('an effect can be cut off, with sound on or off', () async {
    sound.setEnabled(true);
    sound.playSfx(Sfx.claps);
    sound.stopSfx(Sfx.claps);
    sound.setEnabled(false);
    sound.stopSfx(Sfx.claps);
    await pumpEventQueue();
    // The music's calls wait in line behind each other; the effects' do not.
    expect(
      backend.calls.where((call) => call == Sfx.claps || call == 'stop claps'),
      [Sfx.claps, 'stop claps', 'stop claps'],
    );
  });

  test('a failing backend does not break stopping an effect', () async {
    backend.failWith = StateError('gone');
    expect(() => sound.stopSfx(Sfx.claps), returnsNormally);
    await pumpEventQueue();
  });

  test('every effect has its file under assets/audio/', () {
    expect(
      {for (final s in Sfx.values) s.file},
      {'sfx/throw.mp3', 'sfx/eat.mp3', 'sfx/whistle.mp3', 'sfx/claps.mp3'},
    );
  });

  group('positionAfterMute', () {
    const length = Duration(seconds: 172);

    Duration after(int atMute, int mutedFor) => positionAfterMute(
      positionAtMute: Duration(seconds: atMute),
      mutedFor: Duration(seconds: mutedFor),
      length: length,
    );

    test('is where the music has got to, had it played on', () {
      expect(after(10, 5), const Duration(seconds: 15));
      expect(after(0, 0), Duration.zero);
    });

    test('wraps round, as the music loops', () {
      expect(after(170, 5), const Duration(seconds: 3));
      expect(after(10, 172 * 3), const Duration(seconds: 10));
      expect(after(0, 172), Duration.zero); // Never as long as the music.
    });

    test('keeps the sub-second part', () {
      expect(
        positionAfterMute(
          positionAtMute: const Duration(milliseconds: 1500),
          mutedFor: const Duration(milliseconds: 750),
          length: length,
        ),
        const Duration(milliseconds: 2250),
      );
    });
  });
}
