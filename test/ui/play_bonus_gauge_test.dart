import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/app/play_bonus_gauge.dart';

Future<void> _show(WidgetTester tester, double uplift) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(children: [PlayBonusGauge(uplift: uplift, maxUplift: 0.2)]),
  ),
);

/// Width of the gauge fill: the clipped box inside the frame.
double _fillWidth(WidgetTester tester) =>
    tester.getSize(find.byType(ClipRect)).width;

void main() {
  testWidgets('shows the uplift and fills in proportion to the most', (
    tester,
  ) async {
    await _show(tester, 0.123);
    expect(find.text('プレイ回数ボーナス'), findsOneWidget);
    expect(find.text('12.3%'), findsOneWidget);
    // 235 px inside the 3 px border, filled 0.123 / 0.2.
    expect(_fillWidth(tester), closeTo(235 * 0.615, 1e-9));
  });

  testWidgets('is empty for a first game, or a guest', (tester) async {
    await _show(tester, 0);
    expect(find.text('0.0%'), findsOneWidget);
    expect(_fillWidth(tester), 0);
  });
}
