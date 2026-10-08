/// The overlay that waits for the player to carry on with a stopped game.
library;

import 'package:flutter/widgets.dart';

import '../ui/widgets/stage.dart';
import '../ui/widgets/tap_prompt.dart';

/// "TAP TO RESUME" in the middle of the game, blurred as under the result.
/// Covers everything: a tap anywhere resumes, and reaches nothing else.
class ResumeOverlay extends StatelessWidget {
  const ResumeOverlay({super.key, required this.onResume});

  static const text = 'TAP TO RESUME';

  /// Called on a tap anywhere.
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onResume,
      child: const BlurOverlay(
        tint: BlurOverlay.dark,
        child: Center(child: TapPrompt(text)),
      ),
    );
  }
}
