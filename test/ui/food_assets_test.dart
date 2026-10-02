import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/model/game_config.dart';
import 'package:pendulum_feeding_game/ui/assets.dart';

Set<String> _pngNames(String dir) => {
  for (final file in Directory(dir).listSync().whereType<File>())
    if (file.path.endsWith('.png')) file.uri.pathSegments.last,
};

void main() {
  final ids = [for (final type in defaultFoodTypes) type.id];

  test('food ids are unique', () {
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('every food has an image, and every image is a food', () {
    expect(_pngNames('assets/images/food'), {
      for (final id in ids) GameAssets.food(id).split('/').last,
    });
  });

  test('every food image is made from its art', () {
    // Run `dart run tool/images.dart` after changing art/food/.
    expect(_pngNames('art/food'), _pngNames('assets/images/food'));
  });
}
