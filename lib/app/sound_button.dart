/// The sound on/off button shown on every screen.
library;

import 'package:flutter/widgets.dart';

import '../ui/assets.dart';
import '../ui/palette.dart';
import '../ui/text_styles.dart';
import '../ui/widgets/stage.dart';
import '../ui/widgets/tile_button.dart';
import 'sound_scope.dart';

/// The one switch for all sound, at the bottom left of the stage.
///
/// Which state it is in shows three ways at once: the icon (a speaker with
/// waves, or a dim one with a red cross), the caption (ON, or OFF in red),
/// and the colour. It is a child of the screen's stage `Stack`, drawn last so
/// that it stays on top, sharp and pressable, also over blurred popups. It
/// shows nothing in an app without sound.
class SoundButton extends StatelessWidget {
  const SoundButton({super.key});

  /// Where it sits [px]: as far from the left and bottom edges as the retry
  /// button at the top left is from the top.
  static const left = 10.0;
  static final top = StageViewport.size.height - 7 - IconTileButton.size;

  /// What screen readers announce for the two states: the action a press
  /// takes.
  static const turnOnLabel = '音を出す';
  static const turnOffLabel = '音を止める';

  @override
  Widget build(BuildContext context) {
    final sound = SoundScope.maybeOf(context);
    if (sound == null) return const SizedBox.shrink();
    return Positioned(
      left: left,
      top: top,
      child: ListenableBuilder(
        listenable: sound,
        builder: (context, _) {
          final on = sound.enabled;
          return IconTileButton(
            icon: on ? GameAssets.soundOnIcon : GameAssets.soundOffIcon,
            iconSize: const Size(42, 32),
            caption: on ? 'ON' : 'OFF',
            captionStyle: GameTextStyles.soundCaption.copyWith(
              color: on ? Palette.brown : Palette.accentRed,
            ),
            semanticLabel: on ? turnOffLabel : turnOnLabel,
            onPressed: sound.toggle,
          );
        },
      ),
    );
  }
}
