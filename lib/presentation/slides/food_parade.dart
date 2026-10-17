/// The game's foods drifting across a slide.
library;

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../game/model/game_config.dart';
import '../../ui/assets.dart';

/// Every food of the game, faint, turning clockwise as it drifts from left
/// to right, each in its own lane, size and speed, coming back in on the
/// left once it is out on the right. Faint enough that text over it stays
/// easy to read.
class FoodParade extends StatefulWidget {
  const FoodParade({super.key, this.opacity = 0.2, this.seed = 3});

  final double opacity;

  /// Places the foods; the same seed gives the same parade.
  final int seed;

  @override
  State<FoodParade> createState() => _FoodParadeState();
}

class _Food {
  const _Food({
    required this.asset,
    required this.lane,
    required this.size,
    required this.speed,
    required this.spin,
    required this.phase,
  });

  final String asset;

  /// The middle of its lane, as a fraction of the height.
  final double lane;

  /// Width and height of its box [px].
  final double size;

  /// Across [px/s].
  final double speed;

  /// Clockwise [rad/s].
  final double spin;

  /// Where it starts, as a fraction of its way across.
  final double phase;
}

class _FoodParadeState extends State<FoodParade>
    with SingleTickerProviderStateMixin {
  late final List<_Food> _foods = () {
    final random = math.Random(widget.seed);
    final foods = [for (final type in defaultFoodTypes) type.id]
      ..shuffle(random);
    // Lanes spread evenly over the height, in a shuffled order, so that
    // neighbouring lanes do not hold neighbouring foods.
    final lanes = [for (var i = 0; i < foods.length; i++) i]..shuffle(random);
    return [
      for (final (i, id) in foods.indexed)
        _Food(
          asset: GameAssets.food(id),
          lane: (lanes[i] + 0.5) / foods.length,
          size: 110 + random.nextDouble() * 70,
          speed: 50 + random.nextDouble() * 70,
          spin: (0.3 + random.nextDouble() * 0.7) * math.pi / 2,
          phase: random.nextDouble(),
        ),
    ];
  }();

  late final Ticker _ticker;
  var _seconds = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _seconds = elapsed.inMicroseconds / 1e6);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = AlwaysStoppedAnimation(widget.opacity);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final food in _foods) _place(food, box.biggest, opacity),
            ],
          );
        },
      ),
    );
  }

  Widget _place(_Food food, Size area, Animation<double> opacity) {
    final run = area.width + food.size;
    final across = (food.phase + _seconds * food.speed / run) % 1;
    return Positioned(
      left: across * run - food.size,
      top: food.lane * area.height - food.size / 2,
      width: food.size,
      height: food.size,
      child: Transform.rotate(
        angle: food.spin * _seconds + food.phase * 2 * math.pi,
        child: Image.asset(food.asset, fit: BoxFit.contain, opacity: opacity),
      ),
    );
  }
}
