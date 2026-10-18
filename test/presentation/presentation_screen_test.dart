import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/presentation/presentation_screen.dart';
import 'package:pendulum_feeding_game/presentation/ranking_board.dart';
import 'package:pendulum_feeding_game/presentation/roster.dart';
import 'package:pendulum_feeding_game/presentation/roster_store.dart';
import 'package:pendulum_feeding_game/presentation/slides/ranking_slide.dart';
import 'package:pendulum_feeding_game/presentation/standings.dart';
import 'package:pendulum_feeding_game/presentation/talk_content.dart';

final _hanako = Roster.keyOf('hanako0000000000');
final _ken = Roster.keyOf('ken0000000000000');
final _misaki = Roster.keyOf('misaki0000000000');

final _roster = Roster({_hanako: '佐藤 花子', _ken: '鈴木 健', _misaki: '高橋 美咲'});

Standings _standings(Map<String, int> bests) => Standings(
  bests: [
    for (final MapEntry(:key, :value) in bests.entries)
      PlayerBest(key: key, best: value),
  ],
  playCount: 10,
);

void main() {
  late StreamController<Standings> source;
  late StreamController<String> drops;
  late RankingBoard board;
  late MemoryRosterStore store;
  late int gestures;

  setUp(() {
    source = StreamController<Standings>();
    drops = StreamController<String>();
    board = RankingBoard(source.stream);
    store = MemoryRosterStore();
    gestures = 0;
  });

  tearDown(() async {
    board.dispose();
    await source.close();
    await drops.close();
  });

  Future<void> show(WidgetTester tester, {Roster? roster}) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PresentationScreen(
          board: board,
          rosterStore: store,
          initialRoster: roster,
          droppedFiles: drops.stream,
          onUserGesture: () => gestures++,
        ),
      ),
    );
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    // The fade starts on the next frame; the page before is gone on the
    // frame after it ends.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  Future<void> receive(WidgetTester tester, Map<String, int> bests) async {
    source.add(_standings(bests));
    await tester.pump();
  }

  testWidgets('the pages turn with a clicker\'s keys and the arrows', (
    tester,
  ) async {
    await show(tester, roster: _roster);
    expect(find.text(TalkCover.title), findsOneWidget);
    expect(find.text(TalkCover.kicker), findsOneWidget);
    expect(find.textContaining(' / 6'), findsNothing); // No number.

    await press(tester, LogicalKeyboardKey.pageDown);
    expect(find.text(TalkConcept.message), findsOneWidget);
    expect(find.text('2 / 6'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text(TalkTheme.message), findsOneWidget);
    expect(find.text('3 / 6'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text(TalkMaking.message), findsOneWidget);
    expect(find.text('4 / 6'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.pageUp);
    expect(find.text(TalkTheme.message), findsOneWidget);

    await press(tester, LogicalKeyboardKey.end);
    expect(find.text('ランキング'), findsWidgets); // Gold: drawn twice.
    expect(find.text('6 / 6'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.pageDown); // Stays on the last.
    expect(find.text('ランキング'), findsWidgets); // Gold: drawn twice.
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(find.text('表彰式'), findsWidgets);
    expect(find.text('5 / 6'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.home);
    expect(find.text(TalkCover.title), findsOneWidget);

    expect(gestures, greaterThan(0)); // For full screen.
  });

  testWidgets('the ranking shows the top three by name, frozen on entering, '
      'until F lets it follow again', (tester) async {
    await show(tester, roster: _roster);
    await receive(tester, {_hanako: 8200, _ken: 7600, _misaki: 7600});

    await press(tester, LogicalKeyboardKey.end);
    expect(find.text('08200'), findsOneWidget);
    expect(find.text('佐藤 花子'), findsOneWidget);
    // Tied: one under the other in the same row.
    expect(find.text('鈴木 健'), findsOneWidget);
    expect(find.text('高橋 美咲'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('高橋 美咲')).dy,
      greaterThan(tester.getTopLeft(find.text('鈴木 健')).dy),
    );
    expect(find.text(RankingSlide.empty), findsNWidgets(2)); // No 3rd.
    expect(find.textContaining('の結果で固定中'), findsOneWidget);

    // A new best comes in while the ranks are announced.
    await receive(tester, {_hanako: 8200, _ken: 8500, _misaki: 7600});
    expect(find.text('08500'), findsNothing);

    // Leaving and coming back keeps them frozen.
    await press(tester, LogicalKeyboardKey.pageUp);
    await press(tester, LogicalKeyboardKey.pageDown);
    expect(find.text('08500'), findsNothing);

    await press(tester, LogicalKeyboardKey.keyF);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('08500'), findsOneWidget);
    expect(find.text('鈴木 健'), findsOneWidget);

    // A click on the switch freezes them again.
    await tester.tap(find.text('LIVE'));
    await tester.pump();
    expect(find.textContaining('の結果で固定中'), findsOneWidget);
  });

  testWidgets('the honorific 様 after a name is two thirds of its size', (
    tester,
  ) async {
    final guest = Roster.keyOf('guest00000000000');
    await show(tester, roster: Roster({_hanako: '佐藤 花子', guest: '山田 花子 様'}));
    await receive(tester, {guest: 9000, _hanako: 8200});
    await press(tester, LogicalKeyboardKey.end);

    final name = tester.widget<Text>(find.text('山田 花子'));
    final honorific = tester.widget<Text>(find.text('様'));
    expect(honorific.style!.fontSize, name.style!.fontSize! * 2 / 3);
    expect(find.text('佐藤 花子'), findsOneWidget); // No honorific: as it is.
  });

  testWidgets('without a roster, names are unknown until a roster file is '
      'dropped, and it is kept', (tester) async {
    await show(tester);
    expect(find.textContaining('名簿が読み込まれていません'), findsOneWidget);
    await receive(tester, {_hanako: 8200});
    await press(tester, LogicalKeyboardKey.end);
    expect(find.text(RankingSlide.unknownName), findsOneWidget);

    drops.add('{"not": "a roster"}');
    await tester.pump();
    expect(find.text('名簿ファイルを読み込めませんでした'), findsOneWidget);

    drops.add(_roster.encode());
    await tester.pump();
    await tester.pump();
    expect(find.text('名簿を読み込みました（3人）'), findsOneWidget);
    expect(find.text('佐藤 花子'), findsOneWidget);
    expect(find.textContaining('名簿が読み込まれていません'), findsNothing);
    expect(store.roster?.nameOf(_hanako), '佐藤 花子');

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('名簿を読み込みました（3人）'), findsNothing);
  });

  testWidgets('before the standings come, the ranking says it is loading', (
    tester,
  ) async {
    await show(tester, roster: _roster);
    await press(tester, LogicalKeyboardKey.end);
    expect(find.text('ランキングを読み込み中…'), findsOneWidget);
    expect(find.text(RankingSlide.empty), findsNWidgets(6));

    await receive(tester, {_hanako: 8200});
    expect(find.text('佐藤 花子'), findsOneWidget);
    expect(find.text('挑戦者 1人・全 10 プレイ'), findsOneWidget);
  });
}
