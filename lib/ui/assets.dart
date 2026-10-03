/// Where the game's images, icons and fonts are.
library;

/// Asset paths. Images and icons are exported from the Figma design; images
/// are made by tool/images.dart from the originals in art/.
abstract final class GameAssets {
  static const background = 'assets/images/background/background.webp';
  static const bride = 'assets/images/bride/bride.webp';

  /// Both pendulum pivots: the fixed one and the middle joint.
  static const pivot = 'assets/images/pendulum/pivot.webp';

  /// The groom's idle pose, holding the next food.
  static const groomHold = 'assets/images/groom/hold.webp';

  /// The throwing motion, in order. Same canvas and feet position as
  /// [groomHold].
  static const groomThrow = [
    'assets/images/groom/throw_1.webp',
    'assets/images/groom/throw_2.webp',
    'assets/images/groom/throw_3.webp',
  ];

  /// Shown around the bride when she eats. Made by tool/images.dart from
  /// art/effects/.
  static const heart = 'assets/images/effects/heart.webp';

  /// The hand that shows how to drag in the how-to-play demo.
  static const dragHand = 'assets/images/effects/drag_hand.webp';

  /// Returns the image path of the food [id] (see `FoodType.id`). Made by
  /// tool/images.dart from the art in art/food/.
  static String food(String id) => 'assets/images/food/$id.webp';

  /// Food images are this many pixels per stage px; drawn at 1 / this, every
  /// food has the size that tool/images.dart chose for it.
  static const foodImageDensity = 4;

  static const helpIcon = 'assets/icons/help.svg';
  static const closeIcon = 'assets/icons/close.svg';
  static const startIcon = 'assets/icons/start.svg';
  static const retryIcon = 'assets/icons/retry.svg';
  static const homeIcon = 'assets/icons/home.svg';

  /// The sound button: a speaker with waves (sound on), and a dim speaker
  /// with a cross (sound off). Drawn in the dark brown of the other buttons'
  /// icons, `Palette.darkBrown`, in a 34x26 box cut close to the drawing so
  /// that it can be shown large.
  static const soundOnIcon = 'assets/icons/sound_on.svg';
  static const soundOffIcon = 'assets/icons/sound_off.svg';

  /// The how-to-play page buttons, pointing up as exported from Figma.
  static const pageArrow = 'assets/icons/page_arrow.svg';
}
