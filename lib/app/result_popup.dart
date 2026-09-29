import 'package:flutter/widgets.dart';

import '../ranking/ranking_models.dart';
import '../ui/assets.dart';
import '../ui/format.dart';
import '../ui/palette.dart';
import '../ui/text_styles.dart';
import '../ui/widgets/popup_panel.dart';
import '../ui/widgets/tile_button.dart';

/// The 500x300 result popup (Figma: リザルト画面). Positioned by the caller at
/// (172, 45) over the blurred game.
///
/// Left: this game's score and its rank among all games. Right: the
/// player's best and its rank among all players' bests, with a "New Record"
/// bubble when this game set it. What the ranking cannot tell (guest,
/// recording, failed) is said in place of the ranks.
class ResultPopup extends StatelessWidget {
  const ResultPopup({
    super.key,
    required this.score,
    required this.ranking,
    required this.onRetry,
    required this.onTitle,
  });

  static const size = Size(500, 300);

  /// Shown in place of an unknown score.
  static const unknownScore = '-----';

  static const recordingNote = '集計中…';
  static const failedNote = '通信失敗のため\n次回更新します';
  static const guestNote = 'ゲストのため\n記録されません';

  final int score;
  final RankingStatus ranking;
  final VoidCallback onRetry;
  final VoidCallback onTitle;

  @override
  Widget build(BuildContext context) {
    final (
      String playRank,
      String best,
      String bestRank,
      bool newRecord,
    ) = switch (ranking) {
      RankingRecorded(:final result) => (
        '全試行中 ${result.playRank}位 / ${result.playCount}回',
        formatScore(result.best),
        '挑戦者中 ${result.bestRank}位 / ${result.playerCount}人',
        result.isNewBest,
      ),
      RankingPending() => (recordingNote, unknownScore, recordingNote, false),
      RankingFailed() => (failedNote, unknownScore, failedNote, false),
      RankingGuest() => (guestNote, unknownScore, '', false),
    };

    return PopupPanel(
      width: size.width,
      height: size.height,
      child: Stack(
        // The New Record bubble sticks out above the popup.
        clipBehavior: Clip.none,
        children: [
          ..._column(
            left: 37,
            heading: '今回のスコア',
            value: formatScore(score),
            rank: playRank,
            rankWidth: 210,
          ),
          ..._column(
            left: 283,
            heading: '自己ベスト',
            value: best,
            rank: bestRank,
            rankWidth: 197,
          ),
          if (newRecord)
            const Positioned(left: 282, top: -25, child: NewRecordBubble()),
          Positioned(
            left: 113,
            top: 164,
            child: TileButton(
              icon: GameAssets.retryIcon,
              label: 'もう一度',
              onPressed: onRetry,
            ),
          ),
          Positioned(
            left: 277,
            top: 164,
            child: TileButton(
              icon: GameAssets.homeIcon,
              label: 'タイトルへ',
              onPressed: onTitle,
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _column({
    required double left,
    required String heading,
    required String value,
    required String rank,
    required double rankWidth,
  }) => [
    Positioned(
      left: left,
      top: 17,
      child: Text(heading, style: GameTextStyles.resultHeading),
    ),
    Positioned(
      left: left,
      top: 50,
      child: Text(value, style: GameTextStyles.resultValue),
    ),
    Positioned(
      left: left,
      top: 106,
      width: rankWidth,
      height: 46,
      child: _RankLine(rank),
    ),
  ];
}

/// A rank ("全試行中 35位 / 210回") or a two-line note. Never wraps on its
/// own: notes break where written, and anything too wide is scaled down.
class _RankLine extends StatelessWidget {
  const _RankLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isNote = text.contains('\n') || text == ResultPopup.recordingNote;
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: isNote ? GameTextStyles.resultNote : GameTextStyles.resultRank,
          softWrap: false,
          maxLines: 2,
        ),
      ),
    );
  }
}

/// Figma: New Record 吹き出し, 164x52 with the tail pointing down.
class NewRecordBubble extends StatelessWidget {
  const NewRecordBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      height: 52,
      child: Stack(
        children: [
          Container(
            width: 164,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Palette.accentRed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('New Record', style: GameTextStyles.newRecord),
          ),
          const Positioned(
            left: 42,
            top: 36,
            child: CustomPaint(size: Size(20, 16), painter: _TailPainter()),
          ),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = Palette.accentRed,
    );
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) => false;
}
