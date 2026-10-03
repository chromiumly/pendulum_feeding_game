/// The round icon buttons: "?" and "×".
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A circular icon exported from Figma as an SVG (the "?" and "×" buttons).
///
/// The SVG is drawn at its own size, which includes the stroke overhang
/// around the 50x50 circle; position it by its top-left corner.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.circleOffset = const Offset(1.5, 1.5),
    this.shadow = false,
  });

  static const circleDiameter = 50.0;

  /// SVG asset path.
  final String icon;

  /// What screen readers announce.
  final String semanticLabel;

  final VoidCallback onPressed;

  /// Top-left of the 50x50 circle inside the SVG [px].
  final Offset circleOffset;

  /// Figma drop shadow (0, 2, blur 2, 25%). flutter_svg ignores SVG filters,
  /// so the shadow is painted here instead.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Stack(
          children: [
            if (shadow)
              Positioned(
                left: circleOffset.dx,
                top: circleOffset.dy,
                width: circleDiameter,
                height: circleDiameter,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x40000000),
                        offset: Offset(0, 2),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            SvgPicture.asset(icon),
          ],
        ),
      ),
    );
  }
}
