import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/ranking/ranking_models.dart';
import 'package:pendulum_feeding_game/ranking/ranking_repository.dart';
import 'package:pendulum_feeding_game/ranking/ranking_service.dart';
import 'package:pendulum_feeding_game/ranking/ranking_storage.dart';

const _id = 'k7q2xm9pa4c8r3tw';

/// Records in memory; can be made to fail or reject.
class FakeRankingRepository implements RankingRepository {
  final registered = <String>{_id};
  final recorded = <String, PlayRecord>{};

  /// Games recorded per player before [recorded], e.g. from another device.
  final earlierGames = <String, int>{};
  bool offline = false;

  /// Fails every call like [offline], until [reconnect] makes it work.
  bool stuck = false;

  /// How often [reconnect] was called, and whether it fails.
  int reconnects = 0;
  bool reconnectFails = false;

  int _games(String playerId) =>
      (earlierGames[playerId] ?? 0) +
      recorded.values.where((r) => r.playerId == playerId).length;

  @override
  Future<int?> recordedGames(String playerId) async {
    if (offline || stuck) throw Exception('offline');
    return registered.contains(playerId) ? _games(playerId) : null;
  }

  @override
  Future<RankingResult> record(PlayRecord record) async {
    if (offline || stuck) throw Exception('offline');
    if (!registered.contains(record.playerId)) {
      throw const RecordRejectedException();
    }
    recorded[record.playId] = record;
    return RankingResult(
      score: record.score,
      playRank: 1,
      playCount: recorded.length,
      best: record.score,
      isNewBest: true,
      bestRank: 1,
      playerCount: 1,
      gamesPlayed: _games(record.playerId),
    );
  }

  @override
  Future<void> reconnect() async {
    reconnects++;
    if (reconnectFails) throw Exception('cannot reconnect');
    stuck = false;
  }
}

void main() {
  late FakeRankingRepository repository;
  late MemoryRankingStorage storage;

  RankingService service([String url = 'https://example.com/?id=$_id']) =>
      RankingService(
        repository: repository,
        storage: storage,
        launchUri: Uri.parse(url),
      );

  setUp(() {
    repository = FakeRankingRepository();
    storage = MemoryRankingStorage();
  });

  test('a registered ID from the URL is recorded', () async {
    final ranking = service();
    await ranking.start();
    expect(ranking.hasPlayer, isTrue);

    final status = await ranking.recordGame(1200);
    expect(status, isA<RankingRecorded>());
    expect(repository.recorded.values.single.score, 1200);
    expect(repository.recorded.values.single.playerId, _id);
    expect(storage.pending, isEmpty);
  });

  test('a launch without the ID plays as a guest, after one with it', () async {
    await service().recordGame(800);
    final ranking = service('https://example.com/');
    expect(await ranking.recordGame(700), isA<RankingGuest>());
    expect(ranking.gamesPlayed, 0);
    expect(repository.recorded, hasLength(1));
  });

  test('no ID, or a malformed one, plays as a guest', () async {
    for (final url in [
      'https://example.com/',
      'https://example.com/?id=short',
      'https://example.com/?id=../../players/x',
    ]) {
      storage = MemoryRankingStorage();
      final ranking = service(url);
      expect(await ranking.recordGame(800), isA<RankingGuest>(), reason: url);
      expect(repository.recorded, isEmpty);
    }
  });

  test('an unregistered ID plays as a guest', () async {
    repository.registered.clear();
    final ranking = service();
    await ranking.start();
    expect(ranking.hasPlayer, isFalse);
    expect(await ranking.recordGame(800), isA<RankingGuest>());
    expect(storage.pending, isEmpty);
  });

  test('a failed game is kept and sent with the next one', () async {
    final ranking = service();
    await ranking.start();
    repository.offline = true;
    expect(await ranking.recordGame(700), isA<RankingFailed>());
    expect(storage.pending.single.score, 700);

    repository.offline = false;
    expect(await ranking.recordGame(900), isA<RankingRecorded>());
    expect(
      repository.recorded.values.map((r) => r.score),
      unorderedEquals([700, 900]),
    );
    expect(storage.pending, isEmpty);
  });

  test('games left from before are sent at start', () async {
    storage.pending = [
      const PlayRecord(playId: 'old-play-1', playerId: _id, score: 500),
    ];
    await service().start();
    expect(repository.recorded.keys, ['old-play-1']);
    expect(storage.pending, isEmpty);
  });

  test('offline at start keeps the ID and records later', () async {
    repository.offline = true;
    final ranking = service();
    await ranking.start();
    expect(ranking.hasPlayer, isTrue);
    repository.offline = false;
    expect(await ranking.recordGame(600), isA<RankingRecorded>());
  });

  test(
    'a rejected game is dropped; an unregistered player turns guest',
    () async {
      final ranking = service();
      await ranking.start();
      repository.registered.clear(); // e.g. the ID was removed
      expect(await ranking.recordGame(600), isA<RankingGuest>());
      expect(storage.pending, isEmpty);
      expect(ranking.hasPlayer, isFalse);
    },
  );

  test('every game gets its own random play ID', () async {
    final ranking = service();
    for (var i = 0; i < 5; i++) {
      await ranking.recordGame(100 * i);
    }
    expect(repository.recorded.keys.toSet(), hasLength(5));
    for (final id in repository.recorded.keys) {
      expect(id, matches(r'^[A-Za-z0-9]{20}$'));
    }
  });

  group('gamesPlayed', () {
    test('is 0 for a guest', () async {
      final ranking = service('https://example.com/');
      await ranking.start();
      await ranking.recordGame(500);
      expect(ranking.gamesPlayed, 0);
    });

    test('comes from the storage at start, and is remembered', () async {
      repository.earlierGames[_id] = 4;
      final ranking = service();
      await ranking.start();
      expect(ranking.gamesPlayed, 4);
      expect(storage.recordedGames[_id], 4);
    });

    test('offline at start, is what was recorded when last heard', () async {
      storage.recordedGames[_id] = 4;
      repository.offline = true;
      final ranking = service();
      await ranking.start();
      expect(ranking.gamesPlayed, 4);
    });

    test('counts a game as soon as it is being recorded', () async {
      final ranking = service();
      await ranking.start();
      final recording = ranking.recordGame(800);
      expect(ranking.gamesPlayed, 1);
      await recording;
      expect(ranking.gamesPlayed, 1);
      await ranking.recordGame(900);
      expect(ranking.gamesPlayed, 2);
    });

    test('counts games kept on the device, but not twice once sent', () async {
      repository.earlierGames[_id] = 2;
      final ranking = service();
      await ranking.start();
      repository.offline = true;
      await ranking.recordGame(700);
      await ranking.recordGame(600);
      expect(storage.pending, hasLength(2));
      expect(ranking.gamesPlayed, 4);

      repository.offline = false;
      await ranking.recordGame(900);
      expect(storage.pending, isEmpty);
      expect(ranking.gamesPlayed, 5);
      expect(storage.recordedGames[_id], 5);
    });

    test('counts games left from before at start', () async {
      storage.recordedGames[_id] = 1;
      storage.pending = [
        const PlayRecord(playId: 'old-play-1', playerId: _id, score: 500),
      ];
      repository.offline = true;
      final ranking = service();
      await ranking.start();
      expect(ranking.gamesPlayed, 2);
    });

    test('does not count another player\'s games left on the device', () async {
      storage.pending = [
        const PlayRecord(
          playId: 'old-play-1',
          playerId: 'z9y8x7w6v5u4t3s2',
          score: 500,
        ),
      ];
      repository.offline = true;
      final ranking = service();
      await ranking.start();
      expect(ranking.gamesPlayed, 0);
    });
  });

  group('after a failure', () {
    test('a stuck connection is made anew, and the game is sent again at '
        'once, its ranks reported late', () async {
      final ranking = service();
      await ranking.start();
      repository.stuck = true;
      final late = <RankingStatus>[];

      expect(
        await ranking.recordGame(700, onLateResult: late.add),
        isA<RankingFailed>(),
      );
      await ranking.recovered;

      expect(repository.reconnects, 1);
      expect(repository.recorded.values.single.score, 700);
      expect(storage.pending, isEmpty);
      expect(late, [isA<RankingRecorded>()]);
      expect((late.single as RankingRecorded).result.score, 700);
      expect(ranking.gamesPlayed, 1);
    });

    test('with the network down the game stays kept, and is sent with the '
        'next one', () async {
      final ranking = service();
      await ranking.start();
      repository.offline = true;
      final late = <RankingStatus>[];

      expect(
        await ranking.recordGame(700, onLateResult: late.add),
        isA<RankingFailed>(),
      );
      await ranking.recovered;
      expect(repository.reconnects, 1);
      expect(storage.pending.single.score, 700);
      expect(late, isEmpty);

      repository.offline = false;
      expect(await ranking.recordGame(900), isA<RankingRecorded>());
      expect(
        repository.recorded.values.map((r) => r.score),
        unorderedEquals([700, 900]),
      );
      // Its result came at last, for whoever still shows that game.
      expect(late, [isA<RankingRecorded>()]);
    });

    test('a failed reconnect still sends the games again', () async {
      final ranking = service();
      await ranking.start();
      repository.offline = true;
      repository.reconnectFails = true;
      final status = ranking.recordGame(700);
      // The network comes back while the game is failing.
      expect(await status, isA<RankingFailed>());
      repository.offline = false;
      await ranking.recovered;
      expect(repository.recorded.values.single.score, 700);
      expect(storage.pending, isEmpty);
    });

    test('a refused game is not a stuck connection: no reconnect', () async {
      final ranking = service();
      await ranking.start();
      repository.registered.clear();
      expect(await ranking.recordGame(700), isA<RankingGuest>());
      await ranking.recovered;
      expect(repository.reconnects, 0);
    });

    test('a game recorded at once reports no late result', () async {
      final ranking = service();
      await ranking.start();
      final late = <RankingStatus>[];
      expect(
        await ranking.recordGame(700, onLateResult: late.add),
        isA<RankingRecorded>(),
      );
      await ranking.recovered;
      expect(late, isEmpty);
      expect(repository.reconnects, 0);
    });
  });
}
