import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import 'lucky_wheel_art.dart';

/// One bounded paint layer, no overlay entries, timers, assets or particle state.
/// Coordinates are resolved from the live layout, including scroll and resize.
class WheelRewardPainter extends CustomPainter {
  WheelRewardPainter({
    required this.animation,
    required this.layerKey,
    required this.wheelArtKey,
    required this.winningSegmentKey,
    required this.winningIndex,
    required this.counterKey,
    required this.coins,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final GlobalKey layerKey;
  final GlobalKey wheelArtKey;
  final GlobalKey winningSegmentKey;
  final int winningIndex;
  final GlobalKey counterKey;
  final bool coins;
  static const coinBaseRadius = 11.5;

  Rect? _rect(GlobalKey key, RenderBox layer) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
        box.getTransformTo(layer), Offset.zero & box.size);
  }

  /// Transform the *same annular sector path* used by the wheel face. The
  /// render-box transform includes wheel rotation, FittedBox scale and scroll.
  Path? get winningOutlinePath {
    final layer = layerKey.currentContext?.findRenderObject();
    final wheel = wheelArtKey.currentContext?.findRenderObject();
    if (layer is! RenderBox ||
        wheel is! RenderBox ||
        !layer.hasSize ||
        !wheel.hasSize) {
      return null;
    }
    return LuckyWheelGeometry.sectorPath(winningIndex)
        .transform(wheel.getTransformTo(layer).storage);
  }

  Rect? get winningOutlineRect => winningOutlinePath?.getBounds();

  Offset? get winningSectorCenter {
    final layer = layerKey.currentContext?.findRenderObject();
    final wheel = wheelArtKey.currentContext?.findRenderObject();
    if (layer is! RenderBox ||
        wheel is! RenderBox ||
        !layer.hasSize ||
        !wheel.hasSize) {
      return null;
    }
    return MatrixUtils.transformPoint(wheel.getTransformTo(layer),
        LuckyWheelGeometry.rewardCenter(winningIndex));
  }

  /// Only the seven coins currently in flight; bounds include their full size.
  /// Resolving both endpoints from render boxes keeps the path responsive.
  List<Rect> get coinFlightBounds {
    final t = animation.value;
    if (!coins || t <= 0 || t >= 1) return const [];
    final layer = layerKey.currentContext?.findRenderObject();
    if (layer is! RenderBox || !layer.hasSize) return const [];
    final counter = _rect(counterKey, layer);
    final origin = winningSectorCenter;
    if (origin == null || counter == null) return const [];
    final target = counter.center;
    final bounds = <Rect>[];
    for (var i = 0; i < 7; i++) {
      final u = ((t - (.16 + i * .035)) / .6).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue;
      bounds.add(_coinBounds(origin, target, i, u));
    }
    return bounds;
  }

  Rect _coinBounds(Offset origin, Offset target, int index, double progress) {
    final v = Curves.easeInOutCubic.transform(progress);
    final control = (origin + target) / 2 + Offset((index - 3) * 15.0, -65);
    final point = origin * ((1 - v) * (1 - v)) +
        control * (2 * (1 - v) * v) +
        target * (v * v);
    return Rect.fromCircle(
        center: point, radius: coinBaseRadius * (1 - .22 * v));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t <= 0 || t >= 1) return;
    final outline = winningOutlinePath;
    final origin = winningSectorCenter;
    if (outline == null || origin == null) return;
    final fade = (1 - t).clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = GameColors.accentGold.withValues(alpha: fade);
    // The border follows the rendered wedge, including both radial sides.
    canvas.drawPath(
        outline,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < 12; i++) {
      final angle = i * 2 * math.pi / 12;
      final radius = 12 + 52 * Curves.easeOutCubic.transform(t);
      final point = origin + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(point, (i.isEven ? 3.0 : 2.0) * fade, paint);
    }
    for (final coin in coinFlightBounds) {
      final point = coin.center;
      final radius = coin.width / 2;
      paint.color = GameColors.accentGold;
      canvas.drawCircle(point, radius, paint);
      paint.color = GameColors.accentGoldDark;
      canvas.drawCircle(
          point,
          radius * .76,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.7);
      canvas.drawLine(point - Offset(0, radius * .48),
          point + Offset(0, radius * .48), paint);
      paint
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: .65 * fade);
      canvas.drawCircle(
          point + Offset(-radius * .34, -radius * .32), radius * .13, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WheelRewardPainter oldDelegate) =>
      animation != oldDelegate.animation ||
      coins != oldDelegate.coins ||
      layerKey != oldDelegate.layerKey ||
      wheelArtKey != oldDelegate.wheelArtKey ||
      winningSegmentKey != oldDelegate.winningSegmentKey ||
      winningIndex != oldDelegate.winningIndex ||
      counterKey != oldDelegate.counterKey;
}
