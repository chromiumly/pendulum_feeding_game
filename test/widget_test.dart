import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/app/app.dart';
import 'package:pendulum_feeding_game/app/how_to_play_popup.dart';
import 'package:pendulum_feeding_game/app/result_popup.dart';
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
    expect(find.text(howToPlayText), findsOneWidget);
    expect(find.text('TAP TO START'), findsNothing);

    // Tapping inside the popup keeps it open.
    await tester.tap(find.text(howToPlayText));
    await tester.pump();
    expect(find.text(howToPlayText), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('閉じる'));
    await tester.pump();
    expect(find.text(howToPlayText), findsNothing);
    expect(find.text('TAP TO START'), findsOneWidget);
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
