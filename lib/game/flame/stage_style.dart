import 'package:flutter/painting.dart';

/// Colours drawn by the Flame components that are not (yet) part of the
/// Figma design. Design colours live in `Palette`.
abstract final class StageStyle {
  static const guide = Color(0xFF000000);
  static const arrowArmed = Color(0xFF2E7D32);
  static const arrowDisarmed = Color(0xFF9E9E9E);

  static const effect = Color(0xFFE91E63);

  static const hitCircle = Color(0xAAFF0000);

  /// Dummy food: a coloured circle per food type until food art exists.
  static const foodColors = <String, Color>{
    'apple': Color(0xFFD32F2F),
    'cake': Color(0xFFFFCC80),
    'grape': Color(0xFF7B1FA2),
    'hamburger': Color(0xFF8D6E63),
    'mont_blanc': Color(0xFFBCAAA4),
    'omelette_rice': Color(0xFFFBC02D),
    'peach': Color(0xFFF8BBD0),
    'ramen': Color(0xFFFFB74D),
    'sushi': Color(0xFFEF5350),
    'takoyaki': Color(0xFF6D4C41),
  };

  static Color food(String id) => foodColors[id] ?? const Color(0xFF14AE5C);

  /// Draw the hit circles used by the rules, for gameplay verification:
  /// `flutter run --dart-define=SHOW_HIT_CIRCLES=true`.
  static const showHitCircles = bool.fromEnvironment('SHOW_HIT_CIRCLES');
}
