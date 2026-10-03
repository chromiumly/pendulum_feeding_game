/// The fixed 844x390 stage and what is drawn on and over it.
library;

import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../game/model/game_config.dart';
import '../assets.dart';
import '../palette.dart';

/// Lays out [child] in the fixed 844x390 stage coordinate system, scaled to
/// fit and letterboxed exactly like the Flame camera. Figma coordinates can
/// therefore be used directly inside it, and Flutter overlays line up with
/// the game world.
class StageViewport extends StatelessWidget {
  const StageViewport({super.key, required this.child});

  static final size = Size(
    const GameConfig().worldSize.x,
    const GameConfig().worldSize.y,
  );

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.letterbox,
      // FittedBox must be given tight constraints, or it would not scale up.
      child: SizedBox.expand(
        child: FittedBox(
          child: SizedBox.fromSize(size: size, child: child),
        ),
      ),
    );
  }
}

/// The stage background illustration, filling its parent.
class StageBackground extends StatelessWidget {
  const StageBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(GameAssets.background, fit: BoxFit.cover);
  }
}

/// Blurs whatever is painted behind it and tints it, as on the title,
/// countdown and result screens.
class BlurOverlay extends StatelessWidget {
  const BlurOverlay({super.key, required this.tint, this.child});

  /// Figma: 20% white (title, how-to, countdown) or 20% black (result).
  static const light = Color(0x33FFFFFF);
  static const dark = Color(0x33000000);

  /// Colour laid over the blur, e.g. [light] or [dark].
  final Color tint;

  /// Shown on top of the tint, sharp.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        // Figma layer blur 24 ≈ Gaussian sigma 12.
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: ColoredBox(color: tint, child: child ?? const SizedBox.expand()),
      ),
    );
  }
}
