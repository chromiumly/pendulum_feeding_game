/// Turns real frame times into fixed simulation steps.
library;

/// Converts variable frame times into a whole number of fixed steps.
///
/// Leftover time is carried to the next frame. After a long stall (tab switch,
/// GC pause) at most [maxStepsPerFrame] steps run and the rest is dropped, so
/// the game slows down instead of freezing to catch up.
class FixedStepClock {
  FixedStepClock({required this.stepDt, this.maxStepsPerFrame = 5});

  /// Length of one fixed step [s].
  final double stepDt;

  /// Most steps run for one frame; time beyond them is dropped.
  final int maxStepsPerFrame;

  double _accumulator = 0;

  /// Returns how many fixed steps to run for a frame of [frameDt] seconds.
  int advance(double frameDt) {
    _accumulator += frameDt;
    var steps = 0;
    while (_accumulator >= stepDt && steps < maxStepsPerFrame) {
      _accumulator -= stepDt;
      steps++;
    }
    if (steps == maxStepsPerFrame && _accumulator >= stepDt) {
      _accumulator = 0;
    }
    return steps;
  }
}
