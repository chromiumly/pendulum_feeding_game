import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/flame/components/eaten_effect.dart';
import 'package:pendulum_feeding_game/game/model/rules.dart';
import 'package:pendulum_feeding_game/ui/format.dart';

void main() {
  test('a heart per food in a row, a big one for every 5', () {
    expect(EatenEffect.heartCount(1), (big: 0, small: 1));
    expect(EatenEffect.heartCount(2), (big: 0, small: 2));
    expect(EatenEffect.heartCount(4), (big: 0, small: 4));
    expect(EatenEffect.heartCount(5), (big: 1, small: 0));
    expect(EatenEffect.heartCount(13), (big: 2, small: 3));
    expect(EatenEffect.heartCount(20), (big: 4, small: 0));
  });

  test('lays out big hearts first, around the mouth', () {
    final layout = EatenEffect.heartLayout(7);
    expect(
      [for (final h in layout) h.size],
      [EatenEffect.bigHeartSize, EatenEffect.heartSize, EatenEffect.heartSize],
    );
    for (final h in layout) {
      // Vector2 is single precision.
      expect(h.offset.length, closeTo(58, 1e-4));
    }
  });

  test('two hearts land left of the mouth and to its lower right', () {
    final [left, right] = EatenEffect.heartLayout(2);
    expect(left.offset.x, lessThan(-40));
    expect(left.offset.y, lessThan(0));
    expect(right.offset.x, greaterThan(40));
    expect(right.offset.y, greaterThan(0));
  });

  test('the combo label joins the count to the word', () {
    expect(formatCombo(1, comboMultiplier(1)), '1COMBO ×1.0');
    expect(formatCombo(3, comboMultiplier(3)), '3COMBO ×1.4');
    expect(formatCombo(20, comboMultiplier(20)), '20COMBO ×4.8');
  });
}
