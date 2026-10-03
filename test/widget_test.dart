import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/app/app.dart';
import 'package:pendulum_feeding_game/app/how_to_play_game.dart';
import 'package:pendulum_feeding_game/app/how_to_play_popup.dart';
import 'package:pendulum_feeding_game/app/result_popup.dart';
import 'package:pendulum_feeding_game/game/flame/components/stage_components.dart';
import 'package:pendulum_feeding_game/game/flame/pendulum_feeding_game.dart';
import 'package:pendulum_feeding_game/game/model/game_session.dart';
import 'package:pendulum_feeding_game/ranking/ranking_models.dart';

void main() {
  testWidgets('title screen shows the title and TAP TO START', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PendulumFeedingApp());
    expect(find.text('花嫁もぐもぐチャレンジ！'), findsOneWidget);
    expect(find.text('TAP TO START'), findsOneWidget);
    expect(find.text('端末を横向きにしてください'), findsNothing);
  });

  testWidgets('TAP TO START pulses between 50% and 100% opacity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PendulumFeedingApp());
    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('TAP TO START'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    final opacities = <double>[];
    for (var i = 0; i < 60; i++) {
      opacities.add(fade.opacity.value);
      await tester.pump(const Duration(milliseconds: 50));
    }
    final min = opacities.reduce((a, b) => a < b ? a : b);
    final max = opacities.reduce((a, b) => a > b ? a : b);
    expect(min, closeTo(0.5, 0.02));
    expect(max, closeTo(1, 0.02));
  });

  testWidgets('? opens the how-to popup without starting the game', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PendulumFeedingApp());
    await tester.tap(find.bySemanticsLabel('遊び方'));
    await tester.pump();
    const page1 = HowToPlayPopup.page1Heading;
    expect(find.text(page1), findsOneWidget);
    expect(find.text('TAP TO START'), findsNothing);

    // Tapping inside the popup keeps it open.
    await tester.tap(find.text(page1));
    await tester.pump();
    expect(find.text(page1), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('閉じる'));
    await tester.pump();
    expect(find.text(page1), findsNothing);
    expect(find.text('TAP TO START'), findsOneWidget);
  });

  testWidgets('page 1 of the how-to popup has a real, unlimited-time game', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PendulumFeedingApp());
    await tester.tap(find.bySemanticsLabel('遊び方'));
    await tester.pump();

    // Let the demo's sprites load and the session leave its (invisible,
    // instant) countdown.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(microseconds: 16667));
    }

    final game = tester
        .widget<GameWidget<PendulumFeedingGame>>(
          find.byType(GameWidget<PendulumFeedingGame>),
        )
        .game!;
    expect(game.session.phase, GamePhase.playing);
    expect(game.session.config.timeLimitSeconds, isNull);
    // Both the mouth and the food hit circles are shown here, unlike the
    // real game, where they are a debug-only overlay.
    expect(game.world.children.whereType<HitCirclesComponent>(), hasLength(1));

    // The time limit never arrives, however long it plays.
    for (var i = 0; i < 300; i++) {
      game.session.step();
    }
    expect(game.session.isTimeUp, isFalse);
    expect(game.session.isFinished, isFalse);
  });

  testWidgets('the drag hint hides on touch and returns after 5 s idle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PendulumFeedingApp());
    await tester.tap(find.bySemanticsLabel('遊び方'));
    await tester.pump();
    final hint = find.byKey(HowToPlayGame.hintKey);
    expect(hint, findsOneWidget);

    // The demo box, inside the popup at (140, 25).
    const center = Offset(
      140 + HowToPlayGame.left + 211,
      25 + HowToPlayGame.top + 97,
    );
    final gesture = await tester.startGesture(center);
    await tester.pump();
    expect(hint, findsNothing);
    // Still hidden while held, however long.
    await tester.pump(const Duration(seconds: 6));
    expect(hint, findsNothing);

    await gesture.up();
    await tester.pump(const Duration(seconds: 4));
    expect(hint, findsNothing);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(hint, findsOneWidget);
  });

  testWidgets('the how-to popup pages through the tips to the credits and '
      'back', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PendulumFeedingApp());
    await tester.tap(find.bySemanticsLabel('遊び方'));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('次のページ'));
    await tester.pump();
    expect(find.text(HowToPlayPopup.page2Heading), findsOneWidget);
    expect(find.text(HowToPlayPopup.page1Heading), findsNothing);
    expect(find.text(HowToPlayPopup.recordNote), findsNothing);
    // The game's own numbers.
    expect(find.text('+150'), findsOneWidget);
    expect(find.text('+105'), findsOneWidget);
    expect(find.text('+55'), findsOneWidget);
    expect(find.text('4COMBO ×1.6'), findsOneWidget);
    expect(find.text('+168'), findsOneWidget);
    expect(find.text('13.3%'), findsOneWidget);

    // On to the credits, then back the same way.
    await tester.tap(find.bySemanticsLabel('次のページ'));
    await tester.pump();
    expect(find.text(HowToPlayPopup.page3Heading), findsOneWidget);
    expect(find.text(HowToPlayPopup.page2Heading), findsNothing);
    expect(find.text('Jumpei Kurokawa'), findsOneWidget);
    expect(find.text(HowToPlayPopup.recordNote), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('前のページ'));
    await tester.pump();
    expect(find.text(HowToPlayPopup.page2Heading), findsOneWidget);
    // The note belongs to the credits alone.
    expect(find.text(HowToPlayPopup.recordNote), findsNothing);
    await tester.tap(find.bySemanticsLabel('前のページ'));
    await tester.pump();
    expect(find.text(HowToPlayPopup.page1Heading), findsOneWidget);
  });

  testWidgets('the note on the play results is on one line, clear of ◀, at '
      'the height of the tips page closing text', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PendulumFeedingApp());
    await tester.tap(find.bySemanticsLabel('遊び方'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('次のページ'));
    await tester.pump();
    final closing = tester.getRect(
      find.text('ハイスコアを目指して頑張ろう！\n何か良いことがあるかも...？'),
    );
    await tester.tap(find.bySemanticsLabel('次のページ'));
    await tester.pump();

    final note = tester.getRect(find.text(HowToPlayPopup.recordNote));
    // One line of the 16 px body text (a line is 1.2 times the size).
    expect(note.height, closeTo(16 * 1.2, 1));
    // Starts where the other texts do, and stops short of ◀.
    expect(note.left, closeTo(closing.left, 1e-9));
    expect(
      note.right,
      lessThan(tester.getRect(find.bySemanticsLabel('前のページ')).left),
    );
    // Its middle is at the height of the middle of the two-line closing text
    // of the tips page, and of the buttons.
    expect(note.center.dy, closeTo(closing.center.dy, 1));
  });

  testWidgets('the page buttons: ▶ stays put, ◀ sits beside it, and on the '
      'last page stands a little left of where ▶ is', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PendulumFeedingApp());
    await tester.tap(find.bySemanticsLabel('遊び方'));
    await tester.pump();

    final next = find.bySemanticsLabel('次のページ');
    final back = find.bySemanticsLabel('前のページ');
    // Page 1: ▶ only.
    expect(back, findsNothing);
    final nextBox = tester.getRect(next);

    // Page 2: ▶ where it was, ◀ to its left with a gap of 24 between the
    // triangles. The 70 px box holds a triangle 52.5 px long, flush with the
    // right of ▶'s box and the left of ◀'s.
    await tester.tap(next);
    await tester.pump();
    expect(tester.getRect(next), nextBox);
    final backBox = tester.getRect(back);
    expect(backBox.top, nextBox.top);
    final nextTriangleLeft = nextBox.right - 52.5;
    expect(backBox.left + 52.5, closeTo(nextTriangleLeft - 24, 1e-9));

    // Page 3: ◀ only, at the same height, with its triangle a little to the
    // left of where ▶'s was (how far is a matter of taste, so only "a
    // little" is tested: not so far as to reach page 2's ◀).
    await tester.tap(next);
    await tester.pump();
    expect(next, findsNothing);
    final lastBack = tester.getRect(back);
    expect(lastBack.top, nextBox.top);
    expect(nextTriangleLeft - lastBack.left, inInclusiveRange(1, 40));
  });

  testWidgets('portrait shows the rotate prompt', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PendulumFeedingApp());
    expect(find.text('端末を横向きにしてください'), findsOneWidget);
  });

  group('result popup', () {
    Future<void> show(WidgetTester tester, RankingStatus ranking) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ResultPopup(
              score: 700,
              ranking: ranking,
              onRetry: () {},
              onTitle: () {},
            ),
          ),
        ),
      );
    }

    const recorded = RankingRecorded(
      RankingResult(
        score: 700,
        playRank: 35,
        playCount: 210,
        best: 2500,
        isNewBest: false,
        bestRank: 12,
        playerCount: 41,
        gamesPlayed: 6,
      ),
    );

    testWidgets('shows both scores and ranks once recorded', (tester) async {
      await show(tester, recorded);
      expect(find.text('今回のスコア'), findsOneWidget);
      expect(find.text('00700'), findsOneWidget);
      expect(find.text('全試行中 35位 / 210回'), findsOneWidget);
      expect(find.text('自己ベスト'), findsOneWidget);
      expect(find.text('02500'), findsOneWidget);
      expect(find.text('挑戦者中 12位 / 41人'), findsOneWidget);
      expect(find.byType(NewRecordBubble), findsNothing);
    });

    testWidgets('a new best shows the New Record bubble', (tester) async {
      await show(
        tester,
        const RankingRecorded(
          RankingResult(
            score: 2500,
            playRank: 1,
            playCount: 10,
            best: 2500,
            isNewBest: true,
            bestRank: 1,
            playerCount: 5,
            gamesPlayed: 3,
          ),
        ),
      );
      expect(find.text('New Record'), findsOneWidget);
    });

    testWidgets('while recording, and after a failure, bests are unknown', (
      tester,
    ) async {
      await show(tester, const RankingPending());
      expect(find.text('00700'), findsOneWidget);
      expect(find.text(ResultPopup.unknownScore), findsOneWidget);
      expect(find.text(ResultPopup.recordingNote), findsNWidgets(2));

      await show(tester, const RankingFailed());
      expect(find.text('00700'), findsOneWidget);
      expect(find.text(ResultPopup.unknownScore), findsOneWidget);
      expect(find.text(ResultPopup.failedNote), findsNWidgets(2));
      expect(find.byType(NewRecordBubble), findsNothing);
    });

    testWidgets('a guest sees that nothing is recorded', (tester) async {
      await show(tester, const RankingGuest());
      expect(find.text('00700'), findsOneWidget);
      expect(find.text(ResultPopup.guestNote), findsOneWidget);
      expect(find.text(ResultPopup.unknownScore), findsOneWidget);
    });

    testWidgets('notes never wrap on their own', (tester) async {
      for (final ranking in [
        const RankingPending(),
        const RankingFailed(),
        const RankingGuest(),
      ]) {
        await show(tester, ranking);
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          if (text.data == null || !text.data!.contains('\n')) continue;
          expect(text.softWrap, isFalse, reason: text.data);
        }
      }
    });

    testWidgets('buttons call back', (tester) async {
      var retries = 0;
      var titles = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ResultPopup(
              score: 700,
              ranking: recorded,
              onRetry: () => retries++,
              onTitle: () => titles++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('もう一度'));
      await tester.tap(find.text('タイトルへ'));
      await tester.pumpAndSettle();
      expect((retries, titles), (1, 1));
    });
  });
}
