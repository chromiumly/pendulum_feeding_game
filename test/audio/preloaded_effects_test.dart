import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/audio/preloaded_effects.dart';
import 'package:pendulum_feeding_game/audio/sound_controller.dart';

/// A pool that records its starts.
class _FakePool implements EffectPool {
  _FakePool(this.sfx, this.log);

  final Sfx sfx;
  final List<String> log;

  /// If set, starting throws it.
  Object? failWith;

  @override
  Future<void> start(double volume) async {
    log.add('pool ${sfx.name} @$volume');
    if (failWith != null) throw failWith!;
  }
}

void main() {
  late List<String> log;
  late Map<Sfx, _FakePool> pools;
  late Set<Sfx> failToCreate;
  late PreloadedEffects effects;

  setUp(() {
    log = [];
    pools = {};
    failToCreate = {};
    effects = PreloadedEffects(
      volume: 0.8,
      createPool: (sfx) async {
        log.add('create ${sfx.name}');
        if (failToCreate.contains(sfx)) throw StateError('no pool for $sfx');
        return pools[sfx] = _FakePool(sfx, log);
      },
      playOnce: (sfx) async => log.add('once ${sfx.name}'),
    );
  });

  test('before the pools are ready, an effect plays the old way', () async {
    await effects.play(Sfx.throwFood);
    expect(log, ['once throwFood']);
  });

  test('prepare makes a pool for every effect, once', () async {
    await effects.prepare();
    expect(log, [for (final sfx in Sfx.values) 'create ${sfx.name}']);

    await effects.prepare(); // Nothing left to make.
    expect(log, hasLength(Sfx.values.length));
  });

  test('once ready, an effect starts from its pool at the volume', () async {
    await effects.prepare();
    log.clear();
    await effects.play(Sfx.eat);
    await effects.play(Sfx.throwFood);
    expect(log, ['pool eat @0.8', 'pool throwFood @0.8']);
  });

  test('a pool that fails to start falls back to the old way', () async {
    await effects.prepare();
    log.clear();
    pools[Sfx.eat]!.failWith = StateError('blocked');
    await effects.play(Sfx.eat);
    expect(log, ['pool eat @0.8', 'once eat']);
    // The other effects are not affected.
    await effects.play(Sfx.throwFood);
    expect(log.last, 'pool throwFood @0.8');
  });

  test('an effect whose pool failed to make plays the old way, and is '
      'made again by the next prepare, alone', () async {
    failToCreate = {Sfx.eat};
    await effects.prepare();
    expect(pools.keys, [Sfx.throwFood]);

    log.clear();
    await effects.play(Sfx.eat);
    await effects.play(Sfx.throwFood);
    expect(log, ['once eat', 'pool throwFood @0.8']);

    failToCreate = {};
    log.clear();
    await effects.prepare();
    expect(log, ['create eat']); // Only the one that was missing.
    log.clear();
    await effects.play(Sfx.eat);
    expect(log, ['pool eat @0.8']);
  });

  test('prepare calls that overlap share one run', () async {
    final first = effects.prepare();
    final second = effects.prepare();
    await Future.wait([first, second]);
    expect(log, [for (final sfx in Sfx.values) 'create ${sfx.name}']);
  });
}
