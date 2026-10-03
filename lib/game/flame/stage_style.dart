/// Placeholder colours for what Figma does not design.
library;

import 'package:flutter/painting.dart';

/// Colours drawn by the Flame components that are not (yet) part of the
/// Figma design. Design colours live in `Palette`.
abstract final class StageStyle {
  /// The aim guide while the drag is too short to throw.
  static const guideDisarmed = Color(0xFF9E9E9E);

  /// The hit circles, when shown.
  static const hitCircle = Color(0xAAFF0000);

  /// Draw the hit circles used by the rules, for gameplay verification:
  /// `flutter run --dart-define=SHOW_HIT_CIRCLES=true`.
  static const showHitCircles = bool.fromEnvironment('SHOW_HIT_CIRCLES');
}
