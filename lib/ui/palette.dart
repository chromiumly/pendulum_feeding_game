import 'package:flutter/painting.dart';

/// Colours from the Figma design.
abstract final class Palette {
  /// Title, "TAP TO START", popup headings, icon button fill.
  static const brown = Color(0xFF8B735A);

  /// HUD, scores, button labels, button icons, pendulum.
  static const darkBrown = Color(0xFF522504);

  /// Countdown digits.
  static const countdown = Color(0xFFAC7F5E);

  /// Outline around display text.
  static const textOutline = Color(0xFFF8F5E9);

  static const popup = Color(0xFFC4B396);
  static const tile = Color(0xFFFFF8E8);

  /// Soft pale-gold glow on what can be dragged on the setup screen.
  static const setupGlow = Color(0xFFE8C872);

  /// Setup-screen hints and drag handles.
  static const accentRed = Color(0xFFFF383C);

  /// Area outside the 844x390 stage on screens with another aspect ratio.
  static const letterbox = Color(0xFF202020);
}
