import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/app/app.dart';
import 'package:pendulum_feeding_game/app/sound_button.dart';
import 'package:pendulum_feeding_game/audio/sound_controller.dart';
import 'package:pendulum_feeding_game/ui/widgets/tile_button.dart';

import '../audio/fake_sound_backend.dart';

void _stage(WidgetTester tester) {
  tester.view.physicalSize = const Size(844, 390);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Frames at 60 Hz (the game loop never settles, so no pumpAndSettle).
Future<void> _frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(microseconds: 16667));
  }
}

/// Makes the sound inside the test, so that its futures run in the test's
/// fake time, where `pump` moves them on.
(FakeSoundBackend, SoundController) _newSound() {
  final backend = FakeSoundBackend();
  return (backend, SoundController(backend));
}

void main() {
  testWidgets('an app without sound shows no sound button', (tester) async {
    _stage(tester);
    await tester.pumpWidget(const PendulumFeedingApp());
    expect(find.byType(SoundButton), findsOneWidget); // The widget is there,
    expect(find.byType(IconTileButton), findsNothing); // but draws nothing.
  });

  testWidgets('the title screen has it at the bottom left, off at first', (
    tester,
  ) async {
    _stage(tester);
    final (backend, sound) = _newSound();
    await tester.pumpWidget(PendulumFeedingApp(sound: sound));

    final button = find.byType(IconTileButton);
    expect(button, findsOneWidget);
    final rect = tester.getRect(button);
    expect(rect.left, 10);
    expect(rect.bottom, 390 - 7);
    // Off is shown by the caption and by what pressing it would do.
    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('ON'), findsNothing);
    expect(find.bySemanticsLabel(SoundButton.turnOnLabel), findsOneWidget);
  });

  testWidgets('pressing it turns sound on and off, and shows which', (
    tester,
  ) async {
    _stage(tester);
    final (backend, sound) = _newSound();
    await tester.pumpWidget(PendulumFeedingApp(sound: sound));

    await tester.tap(find.byType(IconTileButton));
    await tester.pump();
    expect(sound.enabled, isTrue);
    expect(find.text('ON'), findsOneWidget);
    expect(find.text('OFF'), findsNothing);
    expect(find.bySemanticsLabel(SoundButton.turnOffLabel), findsOneWidget);
    // Still on the title screen: the press did not start the game.
    expect(find.text('TAP TO START'), findsOneWidget);
    await tester.pump();
    expect(backend.calls, ['unmute']);

    await tester.tap(find.byType(IconTileButton));
    await tester.pump();
    expect(sound.enabled, isFalse);
    expect(find.text('OFF'), findsOneWidget);
    expect(backend.calls, ['unmute', 'mute']);
  });

  testWidgets('it is on the how-to-play and the game screens too, and the '
      'music plays on through them', (tester) async {
    _stage(tester);
    final (backend, sound) = _newSound();
    await tester.pumpWidget(PendulumFeedingApp(sound: sound));
    await tester.tap(find.byType(IconTileButton));
    await tester.pump();

    // How-to-play popup.
    await tester.tap(find.bySemanticsLabel('遊び方'));
    await tester.pump();
    expect(find.byType(IconTileButton), findsOneWidget);
    expect(tester.getRect(find.byType(IconTileButton)).left, 10);
    await tester.tap(find.bySemanticsLabel('閉じる'));
    await tester.pump();

    // Setup, countdown, play and result are all one game screen.
    await tester.tap(find.text('TAP TO START'));
    await _frames(tester, 30);
    expect(find.text('スタート'), findsOneWidget);
    expect(find.byType(IconTileButton), findsOneWidget);
    expect(find.text('ON'), findsOneWidget);

    await tester.tap(find.text('スタート'));
    await _frames(tester, 30);
    expect(find.text('3'), findsOneWidget); // Countdown.
    expect(find.text('ON'), findsOneWidget);
    await _frames(tester, 60 * 28); // Countdown, then the whole game.
    expect(find.text('今回のスコア'), findsOneWidget); // Result.
    expect(find.text('ON'), findsOneWidget);
    expect(tester.getRect(find.byType(IconTileButton).last).left, 10);

    // However many screens, the music was brought in once and never silenced.
    expect(backend.calls.where((c) => c == 'unmute'), hasLength(1));
    expect(backend.calls.where((c) => c == 'mute'), isEmpty);
  });

  testWidgets('the demo on the how-to page plays the throw effect too', (
    tester,
  ) async {
    _stage(tester);
    final (backend, sound) = _newSound();
    sound.setEnabled(true);
    await tester.pumpWidget(PendulumFeedingApp(sound: sound));
    await tester.tap(find.bySemanticsLabel('遊び方'));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await _frames(tester, 1);
    }
    // Drag in the demo box (inside the popup at (140, 25)) and let go.
    final gesture = await tester.startGesture(
      const Offset(140 + 30 + 300, 25 + 122 + 100),
    );
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset(470 + 6.0 * i, 247 + 6.0 * i));
      await _frames(tester, 1);
    }
    await gesture.up();
    await _frames(tester, 3);
    expect(backend.effects, [Sfx.throwFood]);
  });
}
