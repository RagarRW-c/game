import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ocean's existing Lagoon symbol, drawn as glossy enamel instead of a dark
/// monochrome font glyph. The surrounding TileFace still owns the ivory body.
class GlobeTilePainter extends CustomPainter {
  const GlobeTilePainter({required this.blocked});
  final bool blocked;

  Color _color(int value) {
    final color = Color(value);
    return blocked ? Color.lerp(color, const Color(0xFF657D83), .45)! : color;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    if (side <= 0) return;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 100);
    final pen = Paint();
    canvas.drawOval(const Rect.fromLTWH(17, 86, 68, 9),
        pen..color = const Color(0x33243644));
    const sphere = Rect.fromLTWH(7, 4, 86, 86);
    canvas.drawOval(
        sphere,
        pen
          // Shader output is modulated by Paint.color's alpha. Do not carry
          // the translucent cast shadow into the opaque ocean gradient.
          ..color = Colors.white
          ..shader = RadialGradient(
            center: const Alignment(-.45, -.55),
            radius: 1,
            colors: [
              _color(0xFF8BF3FF),
              _color(0xFF21BDE8),
              _color(0xFF167FC8),
              _color(0xFF07548A),
            ],
            stops: const [0, .4, .78, 1],
          ).createShader(sphere));
    canvas.drawOval(
        sphere,
        pen
          ..shader = null
          ..color = _color(0xFF07536A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2);

    // Original simplified continent silhouettes, readable at tray size.
    final west = Path()
      ..moveTo(24, 18)
      ..quadraticBezierTo(35, 9, 46, 13)
      ..lineTo(44, 23)
      ..lineTo(36, 28)
      ..lineTo(39, 36)
      ..lineTo(32, 42)
      ..lineTo(32, 50)
      ..lineTo(25, 46)
      ..lineTo(20, 35)
      ..lineTo(13, 32)
      ..quadraticBezierTo(16, 23, 24, 18)
      ..close();
    final south = Path()
      ..moveTo(34, 48)
      ..lineTo(45, 49)
      ..lineTo(51, 57)
      ..lineTo(46, 65)
      ..lineTo(44, 74)
      ..lineTo(36, 82)
      ..lineTo(33, 73)
      ..lineTo(35, 64)
      ..lineTo(30, 56)
      ..close();
    final east = Path()
      ..moveTo(60, 16)
      ..quadraticBezierTo(77, 20, 85, 33)
      ..lineTo(78, 37)
      ..lineTo(80, 44)
      ..lineTo(72, 46)
      ..lineTo(69, 55)
      ..lineTo(66, 66)
      ..lineTo(59, 72)
      ..lineTo(54, 62)
      ..lineTo(56, 52)
      ..lineTo(51, 45)
      ..lineTo(55, 37)
      ..lineTo(65, 36)
      ..lineTo(60, 29)
      ..lineTo(53, 28)
      ..close();
    for (final land in [west, south, east]) {
      canvas.drawPath(
          land,
          pen
            ..style = PaintingStyle.fill
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _color(0xFFD5FF68),
                _color(0xFF79D82B),
                _color(0xFF269343)
              ],
            ).createShader(sphere));
      canvas.drawPath(
          land,
          pen
            ..shader = null
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 1.8
            ..color = _color(0xFF287939));
    }
    canvas.drawArc(
        sphere.deflate(4),
        3.35,
        1.25,
        false,
        pen
          ..color = Colors.white.withValues(alpha: blocked ? .3 : .7)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round);
    canvas.drawOval(
        const Rect.fromLTWH(24, 14, 15, 9),
        pen
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: blocked ? .35 : .9));
    canvas.restore();
  }

  @override
  bool shouldRepaint(GlobeTilePainter oldDelegate) =>
      blocked != oldDelegate.blocked;
}
