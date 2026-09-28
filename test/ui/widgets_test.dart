import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/ui/assets.dart';
import 'package:pendulum_feeding_game/ui/text_styles.dart';
import 'package:pendulum_feeding_game/ui/widgets/outlined_text.dart';
import 'package:pendulum_feeding_game/ui/widgets/stage.dart';
import 'package:pendulum_feeding_game/ui/widgets/tile_button.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('OutlinedText is found once by its text', (tester) async {
    await tester.pumpWidget(
      _wrap(OutlinedText('TAP TO START', style: GameTextStyles.tapToStart)),
    );
    expect(find.text('TAP TO START'), findsOneWidget);
  });

  testWidgets('TileButton calls onPressed when tapped', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _wrap(
        TileButton(
          icon: GameAssets.startIcon,
          label: 'スタート',
          onPressed: () => pressed++,
        ),
      ),
    );
    await tester.tap(find.text('スタート'));
    await tester.pumpAndSettle();
    expect(pressed, 1);
    expect(tester.getSize(find.byType(TileButton)), const Size(110, 110));
  });

  testWidgets('StageViewport scales the 844x390 stage to fit', (tester) async {
    tester.view.physicalSize = const Size(1688, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const key = Key('stage');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: StageViewport(child: SizedBox.expand(key: key)),
      ),
    );
    final rect = tester.getRect(find.byKey(key));
    // Width-limited: scale 2, centred vertically.
    expect(rect.size, const Size(1688, 780));
    expect(rect.top, 60);
  });
}
