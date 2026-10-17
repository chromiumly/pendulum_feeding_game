import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/presentation/standings.dart';

Standings _standings(Map<String, int> bests) => Standings(
  bests: [
    for (final MapEntry(:key, :value) in bests.entries)
      PlayerBest(key: key, best: value),
  ],
  playCount: bests.length,
);

/// Each row as (rank, score, keys joined with spaces).
List<(int, int?, String)> _rows(Standings standings) => [
  for (final row in standings.podium())
    (row.rank, row.score, row.keys.join(' ')),
];

void main() {
  test('the top three, best first', () {
    final standings = _standings({'a': 500, 'b': 900, 'c': 700, 'd': 100});
    expect(_rows(standings), [(1, 900, 'b'), (2, 700, 'c'), (3, 500, 'a')]);
  });

  test('players with the same best share a row, and the rank after them '
      'is empty, as in the game (1, 2, 2, 4)', () {
    final standings = _standings({'a': 900, 'c': 700, 'b': 700, 'd': 500});
    expect(_rows(standings), [(1, 900, 'a'), (2, 700, 'b c'), (3, null, '')]);
  });

  test('everyone tied for third is shown', () {
    final standings = _standings({
      'a': 900,
      'b': 800,
      'c': 700,
      'd': 700,
      'e': 700,
      'f': 600,
    });
    expect(_rows(standings).last, (3, 700, 'c d e'));
  });

  test('with fewer than three players, the rest is empty', () {
    expect(_rows(_standings({'a': 300})), [
      (1, 300, 'a'),
      (2, null, ''),
      (3, null, ''),
    ]);
    expect(_rows(_standings({})).every((row) => row.$2 == null), isTrue);
  });
}
