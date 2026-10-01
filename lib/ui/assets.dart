/// Asset paths. Images and icons are exported from the Figma design.
abstract final class GameAssets {
  static const background = 'assets/images/background/background.png';
  static const bride = 'assets/images/bride/bride.png';

  /// Both pendulum pivots: the fixed one and the middle joint.
  static const pivot = 'assets/images/pendulum/pivot.png';

  /// The groom's idle pose, holding the next food.
  static const groomHold = 'assets/images/groom/hold.png';

  /// The throwing motion, in order. Same canvas and feet position as
  /// [groomHold].
  static const groomThrow = [
    'assets/images/groom/throw_1.png',
    'assets/images/groom/throw_2.png',
    'assets/images/groom/throw_3.png',
  ];

  /// Made by tool/food_images.dart from the art in art/food/.
  static String food(String id) => 'assets/images/food/$id.png';

  /// Food images are this many pixels per stage px; drawn at 1 / this, every
  /// food has the size that tool/food_images.dart chose for it.
  static const foodImageDensity = 4;

  static const helpIcon = 'assets/icons/help.svg';
  static const closeIcon = 'assets/icons/close.svg';
  static const startIcon = 'assets/icons/start.svg';
  static const retryIcon = 'assets/icons/retry.svg';
  static const homeIcon = 'assets/icons/home.svg';
}
