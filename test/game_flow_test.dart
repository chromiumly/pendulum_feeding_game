import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/app/app.dart';
import 'package:pendulum_feeding_game/game/flame/pendulum_feeding_game.dart';
import 'package:pendulum_feeding_game/game/model/game_session.dart';
import 'package:pendulum_feeding_game/math/vec2.dart';

void main() {
  testWidgets(
    'title -> setup -> countdown -> 20 s play -> result -> retry -> title',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const PendulumFeedingApp());
      // Drive the Flame game loop at 60 Hz. (pumpAndSettle never returns while
      // the game widget is shown, since the game loop never settles.)
      Future<void> runSeconds(int seconds) async {
        for (var i = 0; i < seconds * 60; i++) {
          await tester.pump(const Duration(microseconds: 16667));
        }
      }

      await tester.tap(find.text('TAP TO START'));
      await runSeconds(1);
      expect(find.text('TAP TO START'), findsNothing);

      // Setup waits for the スタート button.
      expect(find.text('位置を決めたらスタート！'), findsOneWidget);
      await runSeconds(5);
      await tester.tap(find.text('スタート'));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      await runSeconds(1);
      expect(find.text('2'), findsOneWidget);
      await runSeconds(2);
      expect(find.text('START'), findsOneWidget);
      await runSeconds(1);
      expect(find.text('START'), findsNothing);

      await runSeconds(18);
      expect(find.text('もう一度'), findsNothing);
      await runSeconds(2);
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('もう一度'), findsOneWidget);

      // Retry starts a fresh game from the setup screen.
      await tester.tap(find.text('もう一度'));
      await runSeconds(1);
      expect(find.text('もう一度'), findsNothing);
      expect(find.text('位置を決めたらスタート！'), findsOneWidget);
      await tester.tap(find.text('スタート'));
      await runSeconds(24);
      expect(find.text('もう一度'), findsOneWidget);

      await tester.tap(find.text('タイトルへ'));
      await runSeconds(1);
      expect(find.text('TAP TO START'), findsOneWidget);
    },
  );

  testWidgets('setup drag reaches the game through the scaled stage', (
    tester,
  ) async {
    // Twice the stage size: stage point p is at 2p on screen.
    tester.view.physicalSize = const Size(1688, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PendulumFeedingApp());
    await tester.tap(find.text('TAP TO START'));
    await tester.pump();
    // Flame mounts components in order, so the input layer is mounted only
    // after the sprites before it; image decoding needs real async time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final game = tester
        .widget<GameWidget<PendulumFeedingGame>>(
          find.byType(GameWidget<PendulumFeedingGame>),
        )
        .game!;
    final session = game.session;
    final joint = session.pendulumPositions.upper;
    final origin = session.config.pendulumOrigin;
    Offset screen(Vec2 p) => Offset(p.x * 2, p.y * 2);

    // Drag the joint to straight below the pivot, in small moves.
    final gesture = await tester.startGesture(screen(joint));
    const moves = 20;
    final target = origin + const Vec2(0, 70);
    for (var i = 1; i <= moves; i++) {
      await gesture.moveTo(screen(joint + (target - joint) * (i / moves)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();

    expect(session.phase, GamePhase.setup);
    expect(session.pendulumState.upperTheta.abs(), lessThan(0.05));
  });
}
