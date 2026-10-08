/// The pulsing "TAP TO ..." prompt.
library;

import 'package:flutter/widgets.dart';

import '../text_styles.dart';
import 'outlined_text.dart';

/// [text] in the "TAP TO START" style, fading between 50% and 100% opacity,
/// never fully out.
class TapPrompt extends StatefulWidget {
  const TapPrompt(this.text, {super.key});

  final String text;

  @override
  State<TapPrompt> createState() => _TapPromptState();
}

class _TapPromptState extends State<TapPrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0.5,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: OutlinedText(widget.text, style: GameTextStyles.tapToStart),
    );
  }
}
