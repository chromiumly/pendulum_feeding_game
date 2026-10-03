/// The panel behind popups.
library;

import 'package:flutter/widgets.dart';

import '../palette.dart';

/// Rounded panel used by the how-to-play and result popups.
class PopupPanel extends StatelessWidget {
  const PopupPanel({
    super.key,
    required this.width,
    required this.height,
    required this.child,
  });

  /// Size of the panel [px].
  final double width;
  final double height;

  /// The contents, laid out inside the panel.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Palette.popup,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 4),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: child,
    );
  }
}
