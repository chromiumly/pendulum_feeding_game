/// The presentation: the slides, turned with the keyboard or a clicker.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ranking_board.dart';
import 'roster.dart';
import 'roster_store.dart';
import 'slide_frame.dart';
import 'slide_style.dart';
import 'slides/making_slide.dart';
import 'slides/ranking_slide.dart';
import 'slides/slide_parts.dart';
import 'slides/talk_slides.dart';

/// The pages, in order.
enum PresentationPage { cover, concept, theme, making, award, ranking }

/// Shows one page at a time.
///
/// Keys (a presentation clicker sends PageDown and PageUp): → ↓ PageDown
/// Space Enter for the next page, ← ↑ PageUp Backspace for the one before,
/// Home and End for the first and last, and F to freeze or unfreeze the
/// ranking. Entering the ranking page freezes it (see [RankingBoard]).
///
/// A click or key press also asks for full screen ([onUserGesture]).
///
/// A roster file dropped onto the page ([droppedFiles]), or chosen with the
/// button shown while there is no roster ([pickFile]), names the players;
/// it is kept in [rosterStore] for the next time the page opens.
class PresentationScreen extends StatefulWidget {
  const PresentationScreen({
    super.key,
    required this.board,
    required this.rosterStore,
    this.initialRoster,
    this.droppedFiles = const Stream.empty(),
    this.pickFile,
    this.onUserGesture,
  });

  final RankingBoard board;
  final RosterStore rosterStore;

  /// The roster kept from before, if any.
  final Roster? initialRoster;

  /// The contents of files dropped onto the page.
  final Stream<String> droppedFiles;

  /// Lets the user choose a file and returns its contents, or null; null if
  /// files cannot be chosen.
  final Future<String?> Function()? pickFile;

  /// Called on every click and key press, while it is being handled.
  final VoidCallback? onUserGesture;

  @override
  State<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen> {
  final _focus = FocusNode();
  var _page = PresentationPage.cover;
  late Roster? _roster = widget.initialRoster;
  late final StreamSubscription<String> _drops;

  /// A short message at the bottom, e.g. that the roster was loaded.
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _drops = widget.droppedFiles.listen(
      _loadRoster,
      onError: (Object _) => _showToast(_notARoster),
    );
  }

  @override
  void dispose() {
    unawaited(_drops.cancel());
    _toastTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  static const _notARoster = '名簿ファイルを読み込めませんでした';

  Future<void> _loadRoster(String json) async {
    final Roster roster;
    try {
      roster = Roster.decode(json);
    } on FormatException {
      _showToast(_notARoster);
      return;
    }
    setState(() => _roster = roster);
    _showToast('名簿を読み込みました（${roster.length}人）');
    try {
      await widget.rosterStore.save(roster);
    } on Object catch (error) {
      debugPrint('Roster not kept: $error');
    }
  }

  Future<void> _pickRoster() async {
    final json = await widget.pickFile?.call();
    if (json != null) await _loadRoster(json);
  }

  void _showToast(String message) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _goTo(PresentationPage page) {
    if (page == _page) return;
    setState(() => _page = page);
    if (page == PresentationPage.ranking) widget.board.freezeOnEnter();
  }

  void _step(int by) {
    const pages = PresentationPage.values;
    _goTo(pages[(_page.index + by).clamp(0, pages.length - 1)]);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) widget.onUserGesture?.call();
    final key = event.logicalKey;
    if (_nextKeys.contains(key)) {
      _step(1);
    } else if (_previousKeys.contains(key)) {
      _step(-1);
    } else if (key == LogicalKeyboardKey.home) {
      _goTo(PresentationPage.values.first);
    } else if (key == LogicalKeyboardKey.end) {
      _goTo(PresentationPage.values.last);
    } else if (key == LogicalKeyboardKey.keyF && event is KeyDownEvent) {
      widget.board.toggleFreeze();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static final _nextKeys = {
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.enter,
  };
  static final _previousKeys = {
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.backspace,
  };

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Listener(
        onPointerDown: (_) {
          widget.onUserGesture?.call();
          _focus.requestFocus();
        },
        // Gives the text its default style (no debug underline).
        child: Material(
          type: MaterialType.transparency,
          child: SlideViewport(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: KeyedSubtree(key: ValueKey(_page), child: _slide()),
                ),
                if (_roster == null)
                  Positioned(
                    left: 40,
                    bottom: 32,
                    child: _NoRosterNotice(
                      onPick: widget.pickFile == null ? null : _pickRoster,
                    ),
                  ),
                if (_toast case final toast?)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 120,
                    child: Center(child: _Toast(toast)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slide() {
    final slide = switch (_page) {
      PresentationPage.cover => const CoverSlide(),
      PresentationPage.concept => const ConceptSlide(),
      PresentationPage.theme => const ThemeSlide(),
      PresentationPage.making => const MakingSlide(),
      PresentationPage.award => const AwardSlide(),
      PresentationPage.ranking => RankingSlide(
        board: widget.board,
        roster: _roster,
      ),
    };
    // Every page but the cover is numbered, counting the cover.
    if (_page == PresentationPage.cover) return slide;
    return Stack(
      fit: StackFit.expand,
      children: [
        slide,
        PageNumber(page: _page.index + 1, of: PresentationPage.values.length),
      ],
    );
  }
}

/// Says that there is no roster yet, and how to load one.
class _NoRosterNotice extends StatelessWidget {
  const _NoRosterNotice({required this.onPick});

  /// Chooses a roster file, or null if files cannot be chosen.
  final VoidCallback? onPick;

  static const text = '名簿が読み込まれていません。名簿ファイルをドロップしてください';

  @override
  Widget build(BuildContext context) {
    final onPick = this.onPick;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE65555), width: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: SlideTextStyles.status),
          if (onPick != null) ...[
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onPick,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: SlidePalette.accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'ファイルを選ぶ',
                    style: SlideTextStyles.status.copyWith(
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xE6522504),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        message,
        style: SlideTextStyles.status.copyWith(color: const Color(0xFFFFFFFF)),
      ),
    );
  }
}
