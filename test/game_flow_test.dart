import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/app/app.dart';
import 'package:pendulum_feeding_game/app/result_popup.dart';
import 'package:pendulum_feeding_game/app/resume_overlay.dart';
import 'package:pendulum_feeding_game/audio/sound_controller.dart';
import 'package:pendulum_feeding_game/game/flame/components/stage_components.dart';
import 'package:pendulum_feeding_game/game/flame/pendulum_feeding_game.dart';
import 'package:pendulum_feeding_game/game/model/game_session.dart';
import 'package:pendulum_feeding_game/game/model/setup_rules.dart';
import 'package:pendulum_feeding_game/math/vec2.dart';
import 'package:pendulum_feeding_game/ranking/ranking_service.dart';
import 'package:pendulum_feeding_game/ranking/ranking_storage.dart';

import 'audio/fake_sound_backend.dart';
import 'ranking/ranking_service_test.dart' show FakeRankingRepository;

/// Flame mounts components in order, so the input layer is mounted only
/// after the sprites before it. Image decoding needs real async time, and
/// each continuation needs a pump to run in the fake-async zone. Once the
/// input layer is mounted, the game widget registers its drag detector a
/// few frames later.
Future<void> _waitForSprites(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(microseconds: 16667));
  }
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(microseconds: 16667));
  }
}

/// Whether the food component paints anything this frame.
bool _drawsFood(PendulumFeedingGame game) {
  final canvas = _CountingCanvas();
  game.world.children.whereType<FoodComponent>().single.render(canvas);
  return canvas.calls > 0;
}

/// Canvas calls made by the bride component this frame.
int _brideDrawCalls(PendulumFeedingGame game) =>
    _drawCalls<BrideComponent>(game);

/// Canvas calls made by the (single) world component of type [T].
int _drawCalls<T extends Component>(PendulumFeedingGame game) {
  final canvas = _CountingCanvas();
  game.world.children.whereType<T>().single.render(canvas);
  return canvas.calls;
}

/// Counts drawing calls instead of painting.
class _CountingCanvas implements Canvas {
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    return null;
  }
}

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
      expect(find.text('花嫁と支点の位置を決めよう！'), findsOneWidget);
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
      expect(find.text('今回のスコア'), findsOneWidget);
      // No ranking service in this test: a guest.
      expect(find.text(ResultPopup.guestNote), findsOneWidget);
      expect(find.text('もう一度'), findsOneWidget);

      // Retry starts a fresh game from the setup screen.
      await tester.tap(find.text('もう一度'));
      await runSeconds(1);
      expect(find.text('もう一度'), findsNothing);
      expect(find.text('花嫁と支点の位置を決めよう！'), findsOneWidget);
      await tester.tap(find.text('スタート'));
      await runSeconds(24);
      expect(find.text('もう一度'), findsOneWidget);

      await tester.tap(find.text('タイトルへ'));
      await runSeconds(1);
      expect(find.text('TAP TO START'), findsOneWidget);
    },
  );

  testWidgets('the whistle and the applause sound, and the applause is cut '
      'off by leaving the result', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final backend = FakeSoundBackend();
    final sound = SoundController(backend)..setEnabled(true);
    await tester.pumpWidget(PendulumFeedingApp(sound: sound));
    Future<void> runSeconds(int seconds) async {
      for (var i = 0; i < seconds * 60; i++) {
        await tester.pump(const Duration(microseconds: 16667));
      }
    }

    List<Object> sounds() => [
      for (final call in backend.calls)
        if (call is Sfx || (call is String && call.startsWith('stop'))) call,
    ];

    await tester.tap(find.text('TAP TO START'));
    await runSeconds(6);
    await tester.tap(find.text('スタート'));
    await runSeconds(2);
    expect(sounds(), isEmpty); // Still counting down.
    await runSeconds(1);
    expect(find.text('START'), findsOneWidget);
    expect(sounds(), [Sfx.whistle]);

    await runSeconds(23);
    expect(find.text('もう一度'), findsOneWidget);
    expect(sounds(), [Sfx.whistle, Sfx.claps]);

    // もう一度 cuts the applause off, and the next game plays on.
    await tester.tap(find.text('もう一度'));
    await runSeconds(1);
    expect(sounds(), [Sfx.whistle, Sfx.claps, 'stop claps']);
    await tester.tap(find.text('スタート'));
    await runSeconds(26);
    expect(find.text('もう一度'), findsOneWidget);
    expect(sounds(), [
      Sfx.whistle,
      Sfx.claps,
      'stop claps',
      Sfx.whistle,
      Sfx.claps,
    ]);

    // So does タイトルへ.
    await tester.tap(find.text('タイトルへ'));
    await runSeconds(1);
    expect(find.text('TAP TO START'), findsOneWidget);
    expect(sounds().last, 'stop claps');
  });

  testWidgets('a game that fails on a stuck connection shows its ranks once '
      'it is sent again', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = FakeRankingRepository();
    final ranking = RankingService(
      repository: repository,
      storage: MemoryRankingStorage(),
      launchUri: Uri.parse('https://example.com/?id=k7q2xm9pa4c8r3tw'),
    );
    await tester.pumpWidget(PendulumFeedingApp(ranking: ranking));
    Future<void> runSeconds(int seconds) async {
      for (var i = 0; i < seconds * 60; i++) {
        await tester.pump(const Duration(microseconds: 16667));
      }
    }

    await tester.tap(find.text('TAP TO START'));
    await runSeconds(2);
    // The connection gets stuck during the game.
    repository.stuck = true;
    await tester.tap(find.text('スタート'));
    await runSeconds(26);
    expect(find.text('今回のスコア'), findsOneWidget);
    await tester.runAsync(() => ranking.recovered);
    await tester.pump();

    expect(repository.reconnects, 1);
    expect(repository.recorded, hasLength(1));
    expect(find.text(ResultPopup.failedNote), findsNothing);
    expect(find.textContaining('全試行中 1位'), findsOneWidget);
  });

  testWidgets('turning the phone to portrait mid-game holds it still under '
      'the rotate prompt, music included; back to landscape, it waits for '
      'TAP TO RESUME', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final backend = FakeSoundBackend();
    final sound = SoundController(backend)..setEnabled(true);
    await tester.pumpWidget(PendulumFeedingApp(sound: sound));
    Future<void> runSeconds(int seconds) async {
      for (var i = 0; i < seconds * 60; i++) {
        await tester.pump(const Duration(microseconds: 16667));
      }
    }

    List<Object> music() => [
      for (final call in backend.calls)
        if (call is String && !call.startsWith('stop')) call,
    ];

    PendulumFeedingGame game() => tester
        .widget<GameWidget<PendulumFeedingGame>>(
          find.byType(GameWidget<PendulumFeedingGame>),
        )
        .game!;

    await tester.tap(find.text('TAP TO START'));
    await runSeconds(1);
    await tester.tap(find.text('スタート'));
    await runSeconds(6);
    expect(game().session.phase, GamePhase.playing);
    expect(find.text(ResumeOverlay.text), findsNothing);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(find.text('端末を横向きにしてください'), findsOneWidget);
    expect(game().isSuspended, isTrue);
    expect(music(), ['unmute', 'mute', 'hold']);
    final held = game().session.remainingSeconds;
    await runSeconds(3);
    expect(game().session.remainingSeconds, held);

    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    expect(find.text('端末を横向きにしてください'), findsNothing);
    expect(find.text(ResumeOverlay.text), findsOneWidget);
    await runSeconds(2);
    expect(game().session.remainingSeconds, held);
    expect(music(), ['unmute', 'mute', 'hold']);

    // A tap anywhere carries on, and reaches nothing underneath.
    await tester.tapAt(const Offset(30, 25)); // Over the retry button.
    await tester.pump();
    expect(find.text(ResumeOverlay.text), findsNothing);
    expect(music(), ['unmute', 'mute', 'hold', 'release', 'unmute']);
    await runSeconds(2);
    expect(game().session.remainingSeconds, lessThan(held - 1.5));
    expect(game().session.phase, GamePhase.playing);
  });

  testWidgets('back in front mid-game, the game waits for TAP TO RESUME', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PendulumFeedingApp());
    Future<void> runSeconds(int seconds) async {
      for (var i = 0; i < seconds * 60; i++) {
        await tester.pump(const Duration(microseconds: 16667));
      }
    }

    await tester.tap(find.text('TAP TO START'));
    await runSeconds(1);
    await tester.tap(find.text('スタート'));
    await runSeconds(2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await runSeconds(3);
    expect(find.text(ResumeOverlay.text), findsOneWidget);
    expect(find.text('START'), findsNothing); // The countdown stood still.

    // The last second of the countdown, then "START" for a second.
    await tester.tap(find.text(ResumeOverlay.text));
    await runSeconds(1);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    expect(find.text(ResumeOverlay.text), findsNothing);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('on the title, the music is held in portrait and comes back '
      'on rotating', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final backend = FakeSoundBackend();
    final sound = SoundController(backend)..setEnabled(true);
    await tester.pumpWidget(PendulumFeedingApp(sound: sound));

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(sound.isBgmHeld, isTrue);
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    expect(sound.isBgmHeld, isFalse);
    expect(find.text(ResumeOverlay.text), findsNothing);
    await tester.pump();
    expect(backend.calls, ['unmute', 'mute', 'hold', 'release', 'unmute']);
  });

  testWidgets('setup drag reaches the game through the scaled stage', (
    tester,
  ) async {
    // Twice the stage size: stage point p is at 2p on screen.
    tester.view.physicalSize = const Size(1688, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PendulumFeedingApp());
    await tester.tap(find.text('TAP TO START'));
    await _waitForSprites(tester);
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
    // A wrong stage scale would be off by far more. The remaining error is
    // Flame's DragUpdateEvent.localEndPosition, which is one move delta
    // ahead of the pointer (about 0.06 rad here).
    // Angles are normalized into [0, 2pi), so a slight overshoot past 0
    // reads as just under 2pi.
    expect(wrapAngle(session.pendulumState.upperTheta).abs(), lessThan(0.15));
  });

  testWidgets('groom is hidden in setup and throws when the food launches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> frames(int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(microseconds: 16667));
      }
    }

    await tester.pumpWidget(const PendulumFeedingApp());
    await tester.tap(find.text('TAP TO START'));
    await _waitForSprites(tester);
    final game = tester
        .widget<GameWidget<PendulumFeedingGame>>(
          find.byType(GameWidget<PendulumFeedingGame>),
        )
        .game!;
    final groom = game.world.children.whereType<GroomComponent>().single;
    expect(groom.isVisible, isFalse);
    expect(_drawsFood(game), isFalse);
    // The bride glows (extra draws behind her sprite) only during setup.
    final setupBrideDraws = _brideDrawCalls(game);
    // Likewise the middle joint's pivot.
    final setupPendulumDraws = _drawCalls<PendulumComponent>(game);

    await tester.tap(find.text('スタート'));
    await frames(10);
    expect(groom.isVisible, isTrue);
    expect(groom.current, GroomPose.hold);
    expect(_drawsFood(game), isTrue);
    expect(_brideDrawCalls(game), 1);
    expect(setupBrideDraws, greaterThan(1));
    // Two ropes of four layers each and two pivots once the glow is gone.
    expect(_drawCalls<PendulumComponent>(game), 10);
    expect(setupPendulumDraws, greaterThan(10));
    await frames(240); // Rest of the countdown and "START".
    expect(game.session.phase, GamePhase.playing);

    // Pull back and release: the food launches on release, as before.
    final gesture = await tester.startGesture(const Offset(400, 200));
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset(400 + 5.0 * i, 200 + 5.0 * i));
      await frames(1);
    }
    expect(game.session.food.isFlying, isFalse);
    expect(groom.current, GroomPose.hold);
    await gesture.up();
    expect(game.session.food.isFlying, isTrue);

    await frames(1);
    expect(groom.current, GroomPose.throwing);
    await frames(20); // 3 frames x 0.08 s, plus a margin.
    expect(groom.current, GroomPose.hold);
  });

  testWidgets('giving up mid-game returns to setup with the same placement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> frames(int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(microseconds: 16667));
      }
    }

    PendulumFeedingGame currentGame() => tester
        .widget<GameWidget<PendulumFeedingGame>>(
          find.byType(GameWidget<PendulumFeedingGame>),
        )
        .game!;

    await tester.pumpWidget(const PendulumFeedingApp());
    await tester.tap(find.text('TAP TO START'));
    await _waitForSprites(tester);

    // Not on the setup screen.
    expect(find.bySemanticsLabel('やり直す'), findsNothing);
    final first = currentGame();
    final placed = first.session.placedPendulum;

    await tester.tap(find.text('スタート'));
    await frames(300); // Countdown, then a few seconds of play.
    expect(first.session.phase, GamePhase.playing);
    expect(find.text('花嫁と支点の位置を決めよう！'), findsNothing);

    await tester.tap(find.bySemanticsLabel('やり直す'));
    await frames(2);
    final second = currentGame();
    expect(identical(second, first), isFalse);
    expect(second.session.phase, GamePhase.setup);
    expect(second.session.pendulumState.toList(), placed.toList());
    expect(find.text('花嫁と支点の位置を決めよう！'), findsOneWidget);
  });
}
