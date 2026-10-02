import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/game/model/game_config.dart';
import 'package:pendulum_feeding_game/game/model/game_session.dart';
import 'package:pendulum_feeding_game/game/model/rules.dart';

/// Draw probabilities of the default foods after [gamesPlayed] games.
List<double> _probabilities(int gamesPlayed) {
  const config = GameConfig();
  return foodProbabilities(
    count: defaultFoodTypes.length,
    bias: favouriteBias(
      gamesPlayed: gamesPlayed,
      limit: config.favouriteBiasLimit,
      halfPlays: config.favouriteBiasHalfPlays,
    ),
  );
}

double _top5(List<double> p) => p.take(5).fold(0, (sum, x) => sum + x);

/// Average points of a drawn food, before the combo bonus.
double _expectedPoints(List<double> p) =>
    [for (var i = 0; i < p.length; i++) p[i] * defaultFoodTypes[i].points]
        .fold(0, (sum, x) => sum + x);

void main() {
  test('foods score 150 - 5 x (rank - 1), in order of favourites', () {
    expect(defaultFoodTypes, hasLength(20));
    for (var i = 0; i < defaultFoodTypes.length; i++) {
      expect(defaultFoodTypes[i].points, 150 - 5 * i);
    }
  });

  test('food points are multiples of 5, so combo points stay whole', () {
    for (final type in defaultFoodTypes) {
      expect(type.points % 5, 0, reason: type.id);
    }
  });

  group('favourite draw', () {
    test('a first game draws every food alike', () {
      for (final p in _probabilities(0)) {
        expect(p, closeTo(1 / 20, 1e-12));
      }
      expect(_expectedPoints(_probabilities(0)), closeTo(102.5, 1e-9));
    });

    test('favours the favourites more with every finished game', () {
      // Values from the design discussion.
      final one = _probabilities(1);
      expect(one.first, closeTo(0.06347, 1e-5));
      expect(_top5(one), closeTo(0.30128, 1e-5));
      expect(_expectedPoints(one), closeTo(106.855, 1e-3));

      final five = _probabilities(5);
      expect(_top5(five), closeTo(0.41086, 1e-5));
      expect(_expectedPoints(five), closeTo(115.109, 1e-3));

      final ten = _probabilities(10);
      expect(ten.first, closeTo(0.11377, 1e-5));
      expect(_top5(ten), closeTo(0.46599, 1e-5));
      expect(ten.last, closeTo(0.0154, 1e-5));
      expect(_expectedPoints(ten), closeTo(118.827, 1e-3));
    });

    test('rises smoothly without limit on games, towards the bias limit', () {
      var previous = _probabilities(0);
      for (var n = 1; n <= 200; n++) {
        final p = _probabilities(n);
        expect(p.first, greaterThan(previous.first));
        expect(p.last, lessThan(previous.last));
        previous = p;
      }
      final limit = foodProbabilities(count: 20, bias: 3);
      expect(_top5(previous), lessThan(_top5(limit)));
      expect(_top5(limit), closeTo(0.57016, 1e-5));
      expect(_expectedPoints(limit), closeTo(125.208, 1e-3));
    });

    test('ranks foods by favourite, and keeps every food possible', () {
      final p = _probabilities(1000000);
      expect(p.fold(0.0, (sum, x) => sum + x), closeTo(1, 1e-12));
      for (var i = 1; i < p.length; i++) {
        expect(p[i], lessThan(p[i - 1]));
      }
      // About 0.76%: even the last food comes now and then.
      expect(p.last, greaterThan(0.005));
    });
  });

  group('drawIndex', () {
    test('draws each index about as often as its probability', () {
      const probabilities = [0.5, 0.3, 0.2];
      final random = math.Random(42);
      final counts = List.filled(3, 0);
      const draws = 100000;
      for (var i = 0; i < draws; i++) {
        counts[drawIndex(probabilities, random)]++;
      }
      for (var i = 0; i < 3; i++) {
        expect(counts[i] / draws, closeTo(probabilities[i], 0.01));
      }
    });

    test('is the same for the same random seed', () {
      List<int> draws(int seed) {
        final random = math.Random(seed);
        final p = _probabilities(3);
        return [for (var i = 0; i < 20; i++) drawIndex(p, random)];
      }

      expect(draws(7), draws(7));
    });
  });

  test('a session draws its foods for the given play count', () {
    final session = GameSession(gamesPlayed: 10);
    expect(session.foodTypeProbabilities, _probabilities(10));
    expect(GameSession().foodTypeProbabilities, _probabilities(0));
  });

  group('favouriteBonus', () {
    ({double uplift, double maxUplift}) bonus(int gamesPlayed) {
      const config = GameConfig();
      return favouriteBonus(
        points: [for (final type in defaultFoodTypes) type.points],
        gamesPlayed: gamesPlayed,
        biasLimit: config.favouriteBiasLimit,
        halfPlays: config.favouriteBiasHalfPlays,
      );
    }

    test('is the rise in average points over a first game', () {
      expect(bonus(0).uplift, closeTo(0, 1e-12));
      // 115.109 / 102.5 and 125.208 / 102.5, from the draw tests above.
      expect(bonus(5).uplift, closeTo(0.12301, 1e-4));
      expect(bonus(5).maxUplift, closeTo(0.22154, 1e-4));
    });

    test('the gauge fills towards, but never reaches, the most', () {
      double gauge(int n) => bonus(n).uplift / bonus(n).maxUplift;
      expect(gauge(1), closeTo(0.19, 0.005));
      expect(gauge(5), closeTo(0.56, 0.005));
      expect(gauge(10), closeTo(0.72, 0.005));
      expect(gauge(1000), lessThan(1));
    });

    test('a session has the bonus for its play count', () {
      expect(GameSession(gamesPlayed: 5).playBonus, bonus(5));
    });
  });
}
