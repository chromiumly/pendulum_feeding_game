import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/app/app.dart';
import 'package:pendulum_feeding_game/app/how_to_play_popup.dart';
import 'package:pendulum_feeding_game/app/result_popup.dart';

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

  testWidgets('result popup shows the padded score and buttons', (
    tester,
  ) async {
    var retries = 0;
    var titles = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ResultPopup(
            score: 700,
            onRetry: () => retries++,
            onTitle: () => titles++,
          ),
        ),
      ),
    );
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('00700'), findsOneWidget);
    await tester.tap(find.text('もう一度'));
    await tester.tap(find.text('タイトルへ'));
    await tester.pumpAndSettle();
    expect((retries, titles), (1, 1));
  });
}
