/// The ranking: the top three, live or frozen.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/format.dart';
import '../ranking_board.dart';
import '../roster.dart';
import '../slide_frame.dart';
import '../slide_style.dart';
import '../standings.dart';

/// The top three as a table of rank, score and names, first place large
/// and in gold. Players with the same best share a row.
///
/// Under it: how many players and games, whether the connection is down,
/// and whether the ranks are frozen, which a click (or the F key, see the
/// presentation screen) switches.
class RankingSlide extends StatelessWidget {
  const RankingSlide({super.key, required this.board, required this.roster});

  final RankingBoard board;

  /// Names the players; null shows them all as unknown.
  final Roster? roster;

  /// Shown for a player the roster does not name.
  static const unknownName = '？？？';

  /// Shown in a row no one is at.
  static const empty = '—';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const SlideBackground(festive: true),
        Padding(
          // The bottom stays clear of the page number.
          padding: const EdgeInsets.fromLTRB(128, 40, 128, 100),
          child: ListenableBuilder(
            listenable: board,
            builder: (context, _) {
              final standings = board.shown;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GoldText('ランキング', style: SlideTextStyles.rankingTitle),
                  const SizedBox(height: 24),
                  const _TableHeader(),
                  const SizedBox(height: 8),
                  for (final row in standings?.podium() ?? _emptyPodium)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PodiumRowView(row: row, roster: roster),
                    ),
                  const Spacer(),
                  _StatusLine(board: board),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static const _emptyPodium = [
    PodiumRow(rank: 1),
    PodiumRow(rank: 2),
    PodiumRow(rank: 3),
  ];
}

/// The widths of the rank and score columns; names take the rest.
const _rankWidth = 300.0;
const _scoreWidth = 480.0;
const _rowPadding = EdgeInsets.symmetric(horizontal: 48);

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final style = SlideTextStyles.tableHeader;
    return Padding(
      padding: _rowPadding,
      child: Row(
        children: [
          SizedBox(
            width: _rankWidth,
            child: SlideText('順位', style: style),
          ),
          SizedBox(
            width: _scoreWidth,
            child: SlideText('スコア', style: style),
          ),
          SlideText('名前', style: style),
        ],
      ),
    );
  }
}

class _PodiumRowView extends StatelessWidget {
  const _PodiumRowView({required this.row, required this.roster});

  final PodiumRow row;
  final Roster? roster;

  @override
  Widget build(BuildContext context) {
    final first = row.rank == 1;
    final rankText = '${row.rank}位';
    final score = row.score;
    final names = row.isEmpty
        ? const [RankingSlide.empty]
        : [
            for (final key in row.keys)
              roster?.nameOf(key) ?? RankingSlide.unknownName,
          ];
    return Container(
      height: first ? 300 : 170,
      padding: _rowPadding,
      decoration: BoxDecoration(
        color: SlidePalette.card,
        borderRadius: BorderRadius.circular(first ? 36 : 28),
        border: Border.all(
          color: first ? SlidePalette.gold : const Color(0x33B07A1A),
          width: first ? 6 : 3,
        ),
        boxShadow: [
          BoxShadow(
            color: first ? const Color(0x55D9A93A) : const Color(0x1A522504),
            blurRadius: first ? 40 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: _rankWidth,
            child: first
                ? GoldText(rankText, style: SlideTextStyles.firstRank)
                : SlideText(rankText, style: SlideTextStyles.rank),
          ),
          SizedBox(
            width: _scoreWidth,
            child: SlideText(
              score == null ? RankingSlide.empty : formatScore(score),
              style: first ? SlideTextStyles.firstScore : SlideTextStyles.score,
            ),
          ),
          Expanded(
            child: _Names(
              names,
              style: first ? SlideTextStyles.firstName : SlideTextStyles.name,
            ),
          ),
        ],
      ),
    );
  }
}

/// The names of the players at one rank: down the row first, as many as
/// fit its height, then in more columns; made smaller only if even the
/// columns do not fit.
class _Names extends StatelessWidget {
  const _Names(this.names, {required this.style});

  final List<String> names;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final lineHeight = style.fontSize! * style.height!;
        final perColumn = math.max(1, (box.maxHeight / lineHeight).floor());
        final columns = [
          for (var i = 0; i < names.length; i += perColumn)
            names.sublist(i, math.min(i + perColumn, names.length)),
        ];
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, column) in columns.indexed) ...[
                if (i > 0) const SizedBox(width: 64),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final name in column) _Name(name, style: style),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A player's name, with its honorific (様), if any, at two thirds of its
/// size, on the same baseline.
class _Name extends StatelessWidget {
  const _Name(this.name, {required this.style});

  final String name;
  final TextStyle style;

  /// The roster writes it after the name and a space, e.g. 山田 花子 様.
  static const honorific = '様';

  @override
  Widget build(BuildContext context) {
    if (!name.endsWith(' $honorific')) return SlideText(name, style: style);
    final fontSize = style.fontSize!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SlideText(
          name.substring(0, name.length - honorific.length - 1),
          style: style,
        ),
        SizedBox(width: fontSize / 4),
        SlideText(honorific, style: style.copyWith(fontSize: fontSize * 2 / 3)),
      ],
    );
  }
}

/// Players and games so far, the connection, and the freeze switch.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.board});

  final RankingBoard board;

  @override
  Widget build(BuildContext context) {
    final standings = board.shown;
    final String summary;
    if (standings == null) {
      summary = board.hasError ? 'ランキングを読み込めません。つなぎ直しています…' : 'ランキングを読み込み中…';
    } else {
      summary = [
        '挑戦者 ${standings.playerCount}人・全 ${standings.playCount} プレイ',
        if (standings.isFromCache || board.hasError) '通信が切れています（最後に取れた結果）',
      ].join('　');
    }
    return Row(
      children: [
        Expanded(child: SlideText(summary, style: SlideTextStyles.status)),
        _FreezeSwitch(board: board),
      ],
    );
  }
}

/// Shows whether the ranks are frozen, and switches it on a click.
class _FreezeSwitch extends StatelessWidget {
  const _FreezeSwitch({required this.board});

  final RankingBoard board;

  @override
  Widget build(BuildContext context) {
    final frozenAt = board.frozenAt;
    final label = frozenAt == null ? 'LIVE' : '${_time(frozenAt)} の結果で固定中';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: board.toggleFreeze,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          decoration: BoxDecoration(
            color: SlidePalette.card,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0x33B07A1A), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: frozenAt == null
                      ? const Color(0xFFE65555)
                      : SlidePalette.muted,
                  shape: frozenAt == null
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                ),
              ),
              const SizedBox(width: 16),
              SlideText(label, style: SlideTextStyles.status),
            ],
          ),
        ),
      ),
    );
  }

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}
