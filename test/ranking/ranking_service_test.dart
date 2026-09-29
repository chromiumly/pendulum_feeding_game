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
  bool offline = false;

  @override
  Future<bool> isRegistered(String playerId) async {
    if (offline) throw Exception('offline');
    return registered.contains(playerId);
  }

  @override
  Future<RankingResult> record(PlayRecord record) async {
    if (offline) throw Exception('offline');
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
    );
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

  test('a registered ID from the URL is remembered and recorded', () async {
    final ranking = service();
    await ranking.start();
    expect(ranking.hasPlayer, isTrue);
    expect(storage.playerId, _id);

    final status = await ranking.recordGame(1200);
    expect(status, isA<RankingRecorded>());
    expect(repository.recorded.values.single.score, 1200);
    expect(repository.recorded.values.single.playerId, _id);
    expect(storage.pending, isEmpty);
  });

  test(
    'a later launch without the ID in the URL uses the remembered one',
    () async {
      storage.playerId = _id;
      final ranking = service('https://example.com/');
      expect(await ranking.recordGame(800), isA<RankingRecorded>());
    },
  );

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
}
