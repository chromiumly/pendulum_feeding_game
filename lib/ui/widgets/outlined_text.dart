import 'package:flutter/widgets.dart';

import '../palette.dart';

/// Text with an outline outside the glyphs (Figma: stroke, align outside).
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    required this.style,
    this.outlineWidth = 5,
    this.outlineColor = Palette.textOutline,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final TextStyle style;

  /// Visible outline width outside the glyphs [px].
  final double outlineWidth;
  final Color outlineColor;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final fillStyle = DefaultTextStyle.of(context).style.merge(style);
    // A centred stroke of twice the width leaves [outlineWidth] outside the
    // glyphs once the fill is painted on top.
    final outlineStyle = fillStyle.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth * 2
        ..strokeJoin = StrokeJoin.round
        ..color = outlineColor,
      shadows: const [],
    );
    return Stack(
      children: [
        // Decorative layer: a RichText so that it is neither announced nor
        // matched by `find.text` a second time.
        ExcludeSemantics(
          child: RichText(
            text: TextSpan(text: text, style: outlineStyle),
            textAlign: textAlign,
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
        Text(text, style: fillStyle, textAlign: textAlign),
      ],
    );
  }
}
