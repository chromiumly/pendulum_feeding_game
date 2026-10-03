/// The cream tile buttons.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../palette.dart';
import '../text_styles.dart';

/// 110x110 cream tile with an icon above a label (スタート, もう一度, タイトルへ).
class TileButton extends StatefulWidget {
  const TileButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  static const size = 110.0;

  /// SVG asset path. It is drawn at its own size, centred on the icon slot.
  final String icon;

  /// Text under the icon.
  final String label;

  final VoidCallback onPressed;

  @override
  State<TileButton> createState() => _TileButtonState();
}

class _TileButtonState extends State<TileButton> {
  /// Whether a finger is down on the button, which shows it pressed.
  bool _pressed = false;

  /// Shows the button pressed or released.
  void _setPressed(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: TileButton.size,
            height: TileButton.size,
            decoration: BoxDecoration(
              color: Palette.tile,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 5),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            // Figma: icons are centred at y=42, labels at y=89.
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 84,
                  child: Center(child: SvgPicture.asset(widget.icon)),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 75,
                  height: 28,
                  child: Center(
                    child: Text(
                      widget.label,
                      style: GameTextStyles.buttonLabel,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small cream tile with only an icon: the in-game retry (Figma: ゲーム画面).
class IconTileButton extends StatefulWidget {
  const IconTileButton({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.semanticLabel,
    required this.onPressed,
    this.caption,
    this.captionStyle,
  });

  static const size = 60.0;

  /// SVG asset path, drawn at [iconSize] in the centre.
  final String icon;
  final Size iconSize;

  /// Small text under the icon, e.g. the state of a switch; null for none.
  final String? caption;

  /// How [caption] looks.
  final TextStyle? captionStyle;

  /// What screen readers announce.
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  State<IconTileButton> createState() => _IconTileButtonState();
}

class _IconTileButtonState extends State<IconTileButton> {
  /// Whether a finger is down on the button, which shows it pressed.
  bool _pressed = false;

  /// Shows the button pressed or released.
  void _setPressed(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: IconTileButton.size,
            height: IconTileButton.size,
            decoration: BoxDecoration(
              color: Palette.tile,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  offset: Offset(0, 5),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: _content(),
          ),
        ),
      ),
    );
  }

  /// Returns the icon, with the caption under it if there is one.
  Widget _content() {
    final icon = SvgPicture.asset(
      widget.icon,
      width: widget.iconSize.width,
      height: widget.iconSize.height,
    );
    final caption = widget.caption;
    if (caption == null) return icon;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 1),
        Text(caption, style: widget.captionStyle),
      ],
    );
  }
}
