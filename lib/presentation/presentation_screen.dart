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
/// With no keys (a phone), a tap or click on the left or right sixth of the
/// screen turns back or on; that edge glows under the mouse and flashes when
/// tapped, except where there is no page that way.
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

class _PresentationScreenState extends State<PresentationScreen>
    with SingleTickerProviderStateMixin {
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
    _flash.dispose();
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

  /// Whether there is a page that way: -1 back, 1 on.
  bool _canStep(int by) {
    final index = _page.index + by;
    return index >= 0 && index < PresentationPage.values.length;
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
        // A tap or click on the left or right edge turns the page, for phones
        // and tablets with no keys; the buttons on the slides take their own.
        // The edge glows while the mouse is over it, and flashes when tapped.
        child: LayoutBuilder(
          builder: (context, box) {
            int? sideAt(double x) {
              final at = x / box.maxWidth;
              if (at < _edge) return -1;
              if (at > 1 - _edge) return 1;
              return null;
            }

            return MouseRegion(
              cursor: _lit(_hovered)
                  ? SystemMouseCursors.click
                  : MouseCursor.defer,
              onHover: (event) => _hover(sideAt(event.localPosition.dx)),
              onExit: (_) => _hover(null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final side = sideAt(details.localPosition.dx);
                  if (side == null || !_canStep(side)) return;
                  _step(side);
                  _flashSide = side;
                  unawaited(_flash.forward(from: 0));
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _slides(),
                    for (final side in const [-1, 1])
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: side < 0 ? 0 : null,
                        right: side > 0 ? 0 : null,
                        width: box.maxWidth * _edge,
                        child: _glow(side),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// How much of the screen's width on each side turns the page when tapped.
  static const _edge = 1 / 6;

  /// The edge under the mouse: -1 left, 1 right, or null.
  int? _hovered;

  /// The edge last tapped, and its flash, fading from full to nothing.
  var _flashSide = 1;
  late final _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: 1,
  );

  /// Whether the edge on [side] glows under the mouse: not on the first
  /// page's left nor the last page's right, where there is no page to go.
  bool _lit(int? side) => side != null && _canStep(side);

  void _hover(int? side) {
    if (side != _hovered) setState(() => _hovered = side);
  }

  /// The glow on one edge: while hovered, and the flash over it (the two
  /// add up, so a click lights the hovered edge a little more).
  Widget _glow(int side) {
    final glow = CustomPaint(painter: _EdgeGlowPainter(side: side));
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: _hovered == side && _lit(side) ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: glow,
          ),
          AnimatedBuilder(
            animation: _flash,
            builder: (context, child) => Opacity(
              opacity: side == _flashSide ? 1 - _flash.value : 0,
              child: child,
            ),
            child: glow,
          ),
        ],
      ),
    );
  }

  Widget _slides() {
    // Gives the text its default style (no debug underline).
    return Material(
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

/// A soft white glow on a screen edge, like the outer rim of a fan: a round
/// bulge out of the edge, brightest along the edge and fading to its rim.
class _EdgeGlowPainter extends CustomPainter {
  const _EdgeGlowPainter({required this.side});

  /// -1 for the left edge, 1 for the right.
  final int side;

  static const _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    // The bulge reaches most of the way across, along most of the height.
    final depth = size.width * 0.8;
    final half = size.height * 0.4;
    final radius = (half * half + depth * depth) / (2 * depth);
    final edgeX = side < 0 ? 0.0 : size.width;
    final center = Offset(edgeX + side * (radius - depth), size.height / 2);
    final inner = (radius - depth) / radius;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          _white.withValues(alpha: 0.65),
          _white.withValues(alpha: 0.3),
          _white.withValues(alpha: 0),
        ],
        stops: [inner, inner + (1 - inner) * 0.6, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas
      ..clipRect(Offset.zero & size)
      ..drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_EdgeGlowPainter oldDelegate) => side != oldDelegate.side;
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
