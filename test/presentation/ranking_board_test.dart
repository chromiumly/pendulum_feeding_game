import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/presentation/ranking_board.dart';
import 'package:pendulum_feeding_game/presentation/standings.dart';

Standings _withPlays(int plays) => Standings(bests: const [], playCount: plays);

void main() {
  late StreamController<Standings> source;
  late RankingBoard board;

  setUp(() {
    source = StreamController<Standings>();
    board = RankingBoard(
      source.stream,
      clock: () => DateTime(2026, 11, 23, 15),
    );
  });

  tearDown(() async {
    board.dispose();
    await source.close();
  });

  Future<void> receive(int plays) async {
    source.add(_withPlays(plays));
    await pumpEventQueue();
  }

  test('live, it shows the latest standings', () async {
    expect(board.shown, isNull);
    await receive(1);
    await receive(2);
    expect(board.isFrozen, isFalse);
    expect(board.shown?.playCount, 2);
  });

  test('entering the ranking freezes it there; it stays frozen on entering '
      'again', () async {
    await receive(1);
    board.freezeOnEnter();
    expect(board.isFrozen, isTrue);
    expect(board.frozenAt, DateTime(2026, 11, 23, 15));
    await receive(2);
    expect(board.shown?.playCount, 1);
    expect(board.live?.playCount, 2);

    board.freezeOnEnter();
    expect(board.shown?.playCount, 1);
  });

  test(
    'the switch lets it follow again, and freezes it at the latest',
    () async {
      await receive(1);
      board.freezeOnEnter();
      await receive(2);

      board.toggleFreeze();
      expect(board.isFrozen, isFalse);
      expect(board.frozenAt, isNull);
      expect(board.shown?.playCount, 2);
      await receive(3);
      expect(board.shown?.playCount, 3);

      board.toggleFreeze();
      await receive(4);
      expect(board.shown?.playCount, 3);
    },
  );

  test('entering again after unfreezing freezes it at the latest', () async {
    await receive(1);
    board
      ..freezeOnEnter()
      ..toggleFreeze();
    await receive(2);
    board.freezeOnEnter();
    await receive(3);
    expect(board.shown?.playCount, 2);
  });

  test('frozen before any standings came, it freezes at the first', () async {
    board.freezeOnEnter();
    expect(board.shown, isNull);
    await receive(1);
    await receive(2);
    expect(board.shown?.playCount, 1);
  });

  test('a failure is shown until the next standings', () async {
    source.addError(Exception('offline'));
    await pumpEventQueue();
    expect(board.hasError, isTrue);
    await receive(1);
    expect(board.hasError, isFalse);
  });
}
