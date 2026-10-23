import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// Integrates a positive velocity profile: a short smooth launch followed by
/// a long smooth brake. Position, velocity and acceleration are continuous at
/// the join; velocity is zero at both ends. No overshoot or terminal correction.
class WheelSpinCurve extends Curve {
  const WheelSpinCurve();

  static const accelerationFraction = .08;

  @override
  double transformInternal(double t) {
    const a = accelerationFraction;
    if (t < a) return t - a / math.pi * math.sin(math.pi * t / a);
    final u = (t - a) / (1 - a);
    return a + 2 * (1 - a) * (u - u * u * u + .5 * u * u * u * u);
  }
}

abstract final class WheelMotion {
  /// Segment zero is at twelve o'clock; segments and rotation both go clockwise.
  /// The selected segment therefore needs the *negative* fractional rotation.
  static double landingTurns(int index, int count,
      {double from = 0, int fullTurns = 5}) {
    if (count <= 0) throw ArgumentError.value(count, 'count');
    RangeError.checkValueInInterval(index, 0, count - 1, 'index');
    return from + fullTurns + ((-index / count - from) % 1);
  }

  static int crossedBoundary(double turns, int count) =>
      (turns * count + .5).floor();
}
