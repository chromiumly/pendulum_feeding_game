import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/app/how_to_play_credits.dart';
import 'package:pendulum_feeding_game/ui/palette.dart';
import 'package:pendulum_feeding_game/ui/text_styles.dart';
import 'package:pendulum_feeding_game/ui/widgets/outlined_text.dart';

/// The credits table, alone, at the top left of a wide box.
Widget _table() => const Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: CreditsTable()),
);

/// The style of the [OutlinedText] showing [text].
TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<OutlinedText>(find.widgetWithText(OutlinedText, text)).style;

void main() {
  test('the credits are the maker and the one who watched over, then where the assets come from', () {
    expect(creditGroups, [
      [
        (label: '制作', value: 'Jumpei Kurokawa'),
        (label: '見守り', value: 'Yuria Otsuka'),
      ],
      [
        (label: '効果音', value: 'OtoLogic（https://otologic.jp/）'),
        (label: 'BGM', value: 'Google Flow Music'),
        (label: '画像', value: 'Google Flow'),
        (label: 'フォント', value: 'M PLUS Rounded 1c / Inter'),
      ],
    ]);
  });

  testWidgets('every line is there, items in one column, values in another', (
    tester,
  ) async {
    await tester.pumpWidget(_table());
    final lines = [for (final group in creditGroups) ...group];
    expect(lines, hasLength(6));

    final labelLefts = <double>{};
    final valueLefts = <double>{};
    for (final line in lines) {
      expect(find.text(line.label), findsOneWidget);
      expect(find.text(line.value), findsOneWidget);
      labelLefts.add(tester.getTopLeft(find.text(line.label)).dx);
      valueLefts.add(tester.getTopLeft(find.text(line.value)).dx);
    }
    // One left edge for all the items, and one for all the values: a table.
    expect(labelLefts, hasLength(1));
    expect(valueLefts, hasLength(1));
    expect(valueLefts.single - labelLefts.single, CreditsTable.labelWidth);
  });

  testWidgets('the rows are evenly spaced, with more space between groups', (
    tester,
  ) async {
    await tester.pumpWidget(_table());
    final tops = [
      for (final group in creditGroups)
        for (final line in group) tester.getTopLeft(find.text(line.label)).dy,
    ];
    // Maker, watcher | source, source, source, source.
    final steps = [for (var i = 1; i < tops.length; i++) tops[i] - tops[i - 1]];
    expect(steps, [
      CreditsTable.rowHeight,
      CreditsTable.rowHeight + CreditsTable.groupGap,
      CreditsTable.rowHeight,
      CreditsTable.rowHeight,
      CreditsTable.rowHeight,
    ]);
  });

  testWidgets('values look like the how-to body text; items are darker', (
    tester,
  ) async {
    await tester.pumpWidget(_table());
    for (final group in creditGroups) {
      for (final line in group) {
        final value = _styleOf(tester, line.value);
        expect(value.fontSize, GameTextStyles.howToLead.fontSize);
        expect(value.color, Palette.brown);
        expect(value.color, GameTextStyles.howToLead.color);

        final label = _styleOf(tester, line.label);
        expect(label.fontSize, GameTextStyles.howToLead.fontSize);
        expect(label.color, Palette.darkBrown);
      }
    }
  });
}
