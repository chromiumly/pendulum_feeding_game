import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/presentation/dummy_names.dart';
import 'package:pendulum_feeding_game/presentation/roster.dart';
import 'package:pendulum_feeding_game/ranking/firestore_ranking_repository.dart';

void main() {
  test('a player key is the bests/ document ID of the player', () {
    const id = 'k7q2xm9pa4c8r3tw';
    expect(Roster.keyOf(id), FirestoreRankingRepository.bestKey(id));
  });

  test('a roster file reads back as written, without the IDs', () {
    final roster = Roster({
      Roster.keyOf('aaaaaaaaaaaaaaaa'): '佐藤 花子',
      Roster.keyOf('bbbbbbbbbbbbbbbb'): '鈴木 健',
    });
    final file = roster.encode();
    expect(file, isNot(contains('aaaaaaaaaaaaaaaa')));

    final read = Roster.decode(file);
    expect(read.length, 2);
    expect(read.nameOf(Roster.keyOf('aaaaaaaaaaaaaaaa')), '佐藤 花子');
    expect(read.nameOf(Roster.keyOf('cccccccccccccccc')), isNull);
  });

  test('other files are turned away', () {
    for (final file in [
      'not json',
      '[]',
      '{"names": {}}',
      '{"format": "something-else", "names": {}}',
      '{"format": "${Roster.format}", "names": {"not-a-key": "名前"}}',
      '{"format": "${Roster.format}", "names": {"${'a' * 64}": 1}}',
    ]) {
      expect(() => Roster.decode(file), throwsFormatException, reason: file);
    }
  });

  test('the first 60 made-up names are all different', () {
    final names = {for (var i = 0; i < 60; i++) dummyName(i)};
    expect(names, hasLength(60));
  });
}
