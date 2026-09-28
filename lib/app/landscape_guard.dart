import 'package:flutter/material.dart';

/// The game is landscape-only. In portrait, ask the player to rotate the
/// device instead of showing a tiny letterboxed game.
class LandscapeGuard extends StatelessWidget {
  const LandscapeGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isPortrait = size.height > size.width;
    return Stack(
      children: [
        child,
        if (isPortrait)
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
