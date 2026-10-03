import 'dart:async';

import 'package:pendulum_feeding_game/audio/sound_controller.dart';

/// A [SoundBackend] that records what it is asked to play.
class FakeSoundBackend implements SoundBackend {
  /// Calls in order: 'unmute', 'mute', the played effect, or 'stop' and the effect's name.
  final calls = <Object>[];

  /// If set, every call throws it.
  Object? failWith;

  /// If set, unmuting the music waits for it.
  Completer<void>? unmuteGate;

  /// How often [unlock] was called. Not in [calls], as it comes before the
  /// music's calls, which wait in line.
  int unlocks = 0;

  /// The effects played, in order.
  List<Sfx> get effects => calls.whereType<Sfx>().toList();

  @override
  void unlock() {
    unlocks++;
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> unmuteBgm() async {
    calls.add('unmute');
    if (failWith != null) throw failWith!;
    await unmuteGate?.future;
  }

  @override
  Future<void> muteBgm() async {
    calls.add('mute');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> playSfx(Sfx sfx) async {
    calls.add(sfx);
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> stopSfx(Sfx sfx) async {
    calls.add('stop ${sfx.name}');
    if (failWith != null) throw failWith!;
  }
}
