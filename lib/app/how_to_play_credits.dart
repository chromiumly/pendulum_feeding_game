/// The credits page of the how-to-play popup: who made the game, and where
/// its assets come from.
library;

import 'package:flutter/widgets.dart';

import '../ui/text_styles.dart';
import '../ui/widgets/outlined_text.dart';

/// One line of the credits: an item and its value, e.g. 効果音 and OtoLogic.
typedef CreditLine = ({String label, String value});

/// The credits, in groups that are set apart: who made the game and who
/// watched over it, then where its assets come from. Keep the wording of the sources in line with what
/// their terms ask for, and with docs/assets.md.
const creditGroups = <List<CreditLine>>[
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
];

/// The credits laid out like a table: the items in one column, their values
/// in the next, one line per row. The groups of [creditGroups] are set apart
/// by a little more space.
///
/// Values look like the body text of the other how-to pages; the items are
/// in the darker brown of the tip cards' headings, to set them apart.
class CreditsTable extends StatelessWidget {
  const CreditsTable({super.key});

  /// Distance from one row to the next within a group [px].
  static const rowHeight = 30.0;

  /// Extra space between two groups [px].
  static const groupGap = 14.0;

  /// Width of the items column, which is where the values begin [px]. Wide
  /// enough for the longest item, with room to spare.
  static const labelWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, group) in creditGroups.indexed) ...[
          if (i > 0) const SizedBox(height: groupGap),
          for (final line in group) _row(line),
        ],
      ],
    );
  }

  /// Returns the row for [line].
  static Widget _row(CreditLine line) => SizedBox(
    height: rowHeight,
    child: Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: OutlinedText(
            line.label,
            style: GameTextStyles.cardHeading,
            outlineWidth: 2,
            textAlign: TextAlign.left,
          ),
        ),
        OutlinedText(
          line.value,
          style: GameTextStyles.howToLead,
          outlineWidth: 2,
          textAlign: TextAlign.left,
        ),
      ],
    ),
  );
}
