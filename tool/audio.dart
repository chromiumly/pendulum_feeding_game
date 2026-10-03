/// Audio for the game, made from the originals in `art/audio/`: the heavy
/// ones re-encoded smaller, the effects with their leading silence cut, and
/// the rest copied.
///
///   dart run tool/audio.dart
///
/// The result goes to `assets/audio/` with the same paths, which is where
/// flame_audio looks. Run it after changing anything in `art/audio/`.
///
/// Needs ffmpeg (with MP3 support) on the PATH, e.g. `sudo apt install
/// ffmpeg` or `brew install ffmpeg`; or set the `FFMPEG` environment
/// variable to its path.
///
/// Re-encoding drops what the game does not play: the album art and tags
/// that music files often carry (the art of the BGM was about a quarter of
/// its size), and trims the bitrate to what a phone speaker needs.
///
/// Sound effects are also cut at the start, up to just before the sound
/// begins. Many carry a tenth of a second of silence there, which the player
/// would hear as the effect starting late. How much is cut is set for each
/// one in [_recipes].
library;

import 'dart:io';

/// How to make one file: the MP3 bitrate to re-encode at (e.g. `80k`), or
/// null to copy it as it is because it is small already; and how loud the
/// sound must get to count as begun, so that everything before it is cut
/// (e.g. `-60dB`), or null to cut nothing. Cutting needs re-encoding.
typedef _Recipe = ({String? bitrate, String? trimBelow});

/// The recipe of each file under `art/audio/`, by its path under it. A file
/// missing here is an error, so that no heavy file is shipped by accident.
///
/// Levels are relative to the loudest possible sample: -60 dB is 0.1%, far
/// below anything heard.
const _recipes = <String, _Recipe>{
  'bgm/bgm.mp3': (bitrate: '80k', trimBelow: null),
  // At 128 kbps the effects are about 27 KB each, and the cut does not wear
  // their quality further.
  'sfx/eat.mp3': (bitrate: '128k', trimBelow: '-60dB'),
  // The throw opens with about 50 ms of faint rustle (around -40 dB) before
  // its body, which comes in at about -17 dB. The rustle only makes it feel
  // late after the release that throws it, so it is cut too.
  'sfx/throw.mp3': (bitrate: '128k', trimBelow: '-26dB'),
};

/// How much is kept before the sound reaches the level that counts as begun
/// [s], so that it does not start with a click.
const _keptLead = 0.005;

/// How long the start fades in [s], whatever the cut left there.
const _fadeIn = 0.003;

/// Sample rate of re-encoded files [Hz]. Browsers play 44.1 kHz everywhere.
const _sampleRate = 44100;

final _source = Directory('art/audio');
final _output = Directory('assets/audio');

/// Makes every audio file in `assets/audio/` and prints their sizes. Run
/// from the project root.
void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run from the project root.');
    exit(1);
  }
  final sources = [
    for (final file in _source.listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.mp3')) file,
  ]..sort((a, b) => a.path.compareTo(b.path));

  stdout.writeln('audio                          original      made');
  for (final source in sources) {
    final path = source.path.substring('${_source.path}/'.length);
    final recipe = _recipes[path];
    if (recipe == null) {
      stderr.writeln('art/audio/$path: add it to _recipes.');
      exit(1);
    }
    final target = File('${_output.path}/$path')
      ..parent.createSync(recursive: true);
    final bitrate = recipe.bitrate;
    if (bitrate == null) {
      source.copySync(target.path);
    } else {
      _encode(source, target, bitrate, trimBelow: recipe.trimBelow);
    }
    stdout.writeln(
      '${path.padRight(28)}${_kb(source.lengthSync()).padLeft(10)}'
      '${_kb(target.lengthSync()).padLeft(10)}',
    );
  }
}

/// Re-encodes [source] to [target] as MP3 at [bitrate] (e.g. `80k`) without
/// pictures or tags. Unless [trimBelow] is null, also cuts everything before
/// the sound first gets louder than that (e.g. `-60dB`), and fades the new
/// start in. Exits with an error if ffmpeg is missing or fails.
void _encode(
  File source,
  File target,
  String bitrate, {
  required String? trimBelow,
}) {
  final ffmpeg = Platform.environment['FFMPEG'] ?? 'ffmpeg';
  final ProcessResult result;
  try {
    result = Process.runSync(ffmpeg, [
      '-y',
      '-v', 'error',
      '-i', source.path,
      '-vn', // No album art.
      '-map_metadata', '-1', // No tags.
      if (trimBelow != null) ...[
        '-af',
        'silenceremove=start_periods=1:start_threshold=$trimBelow'
            ':start_silence=$_keptLead:detection=peak,'
            'afade=t=in:d=$_fadeIn',
      ],
      '-ar', '$_sampleRate',
      '-codec:a', 'libmp3lame',
      '-b:a', bitrate,
      target.path,
    ]);
  } on ProcessException {
    stderr.writeln(
      'ffmpeg not found. Install it (sudo apt install ffmpeg, '
      'brew install ffmpeg), or set FFMPEG to its path.',
    );
    exit(1);
  }
  if (result.exitCode != 0) {
    stderr.writeln('ffmpeg failed on ${source.path}:\n${result.stderr}');
    exit(1);
  }
}

/// Returns [bytes] as kilobytes, e.g. `1763 KB`.
String _kb(int bytes) => '${(bytes / 1024).round()} KB';
