/// The prompt to rotate the device to landscape.
library;

import 'package:flutter/material.dart';

import '../audio/sound_controller.dart';
import 'sound_scope.dart';

/// The game is landscape-only. In portrait, ask the player to rotate the
/// device instead of showing a tiny letterboxed game. The music is held
/// meanwhile, on any screen, and the game itself holds still (`GameScreen`
/// tells it, with [isPortrait]).
class LandscapeGuard extends StatefulWidget {
  const LandscapeGuard({super.key, required this.child});

  /// The app, shown underneath in any orientation.
  final Widget child;

  /// Whether a screen of [size] is in portrait.
  static bool isPortrait(Size size) => size.height > size.width;

  @override
  State<LandscapeGuard> createState() => _LandscapeGuardState();
}

class _LandscapeGuardState extends State<LandscapeGuard> {
  /// The app's sound, held by this while in portrait.
  SoundController? _sound;

  /// Holds the music while in portrait; released on rotating back.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sound = SoundScope.maybeOf(context);
    if (sound != _sound) _sound?.releaseBgm(this);
    _sound = sound;
    if (LandscapeGuard.isPortrait(MediaQuery.sizeOf(context))) {
      sound?.holdBgm(this);
    } else {
      sound?.releaseBgm(this);
    }
  }

  @override
  void dispose() {
    _sound?.releaseBgm(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final portrait = LandscapeGuard.isPortrait(MediaQuery.sizeOf(context));
    return Stack(
      children: [
        widget.child,
        if (portrait)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.screen_rotation, color: Colors.white, size: 64),
                    SizedBox(height: 16),
                    Text(
                      '端末を横向きにしてください',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
