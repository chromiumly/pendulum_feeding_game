import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/audio/flame_sound_backend.dart';
import 'package:pendulum_feeding_game/audio/sound_controller.dart';

Set<String> _mp3s(String dir) => {
  for (final file in Directory(dir).listSync(recursive: true))
    if (file is File && file.path.endsWith('.mp3'))
      file.path.substring(dir.length + 1),
};

void main() {
  test('the game has the music and every effect it plays', () {
    final made = _mp3s('assets/audio');
    expect(made, contains(FlameSoundBackend.bgmFile));
    for (final sfx in Sfx.values) {
      expect(made, contains(sfx.file), reason: sfx.name);
    }
  });

  test('every audio file is made from its original', () {
    // Run `dart run tool/audio.dart` after changing art/audio/.
    expect(_mp3s('assets/audio'), _mp3s('art/audio'));
  });

  test('heavy audio is not shipped as it is', () {
    // The BGM's original is 3.5 MB; made by tool/audio.dart it is half that.
    final bgm = File('assets/audio/${FlameSoundBackend.bgmFile}');
    expect(bgm.lengthSync(), lessThan(2 * 1024 * 1024));
  });
}
