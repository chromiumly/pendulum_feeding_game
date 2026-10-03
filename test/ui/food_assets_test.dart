import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/model/game_config.dart';
import 'package:pendulum_feeding_game/ui/assets.dart';

/// The names of the images in [dir] without their extensions, so that an
/// original (`.png` in art/) and its WebP in assets/ compare equal.
Set<String> _imageNames(String dir) => {
  for (final file in Directory(dir).listSync().whereType<File>())
    if (file.path.endsWith('.png') || file.path.endsWith('.webp'))
      file.uri.pathSegments.last.split('.').first,
};

void main() {
  final ids = [for (final type in defaultFoodTypes) type.id];

  test('food ids are unique', () {
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('every food has an image, and every image is a food', () {
    expect(_imageNames('assets/images/food'), {
      for (final id in ids)
        GameAssets.food(id).split('/').last.split('.').first,
    });
  });

  test('every food image is made from its art', () {
    // Run `dart run tool/images.dart` after changing art/food/.
    expect(_imageNames('art/food'), _imageNames('assets/images/food'));
  });

  test('every other image is made from its art', () {
    // Run `dart run tool/images.dart` after changing art/.
    for (final dir in ['background', 'effects', 'bride', 'groom', 'pendulum']) {
      expect(
        _imageNames('assets/images/$dir'),
        _imageNames('art/$dir'),
        reason: dir,
      );
    }
  });
}
