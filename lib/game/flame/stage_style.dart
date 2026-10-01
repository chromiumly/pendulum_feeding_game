import 'package:flutter/painting.dart';

/// Colours drawn by the Flame components that are not (yet) part of the
/// Figma design. Design colours live in `Palette`.
abstract final class StageStyle {
  static const guide = Color(0xFF000000);
  static const arrowArmed = Color(0xFF2E7D32);
  static const arrowDisarmed = Color(0xFF9E9E9E);

  static const effect = Color(0xFFE91E63);

  static const hitCircle = Color(0xAAFF0000);

  /// Draw the hit circles used by the rules, for gameplay verification:
  /// `flutter run --dart-define=SHOW_HIT_CIRCLES=true`.
  static const showHitCircles = bool.fromEnvironment('SHOW_HIT_CIRCLES');
}
