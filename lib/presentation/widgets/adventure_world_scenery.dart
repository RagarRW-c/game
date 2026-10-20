import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../theme/world_theme.dart';

/// Authored vector scenery, shared by destination panoramas and the map.
/// Map motifs stay at the edges; they never participate in input or semantics.
class AdventureWorldScenery extends StatelessWidget {
  const AdventureWorldScenery({
    super.key,
    required this.theme,
    this.panorama = false,
  });

  final WorldVisualTheme theme;
  final bool panorama;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _SceneryPainter(theme, panorama),
            ),
          ),
        ),
      );
}

class _SceneryPainter extends CustomPainter {
  const _SceneryPainter(this.theme, this.panorama);
  final WorldVisualTheme theme;
  final bool panorama;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size,
        Paint()..shader = theme.background.createShader(Offset.zero & size));
    // Broad, overlapping terrain bands provide depth behind the route.
    for (var layer = 0; layer < 3; layer++) {
      final step = panorama ? size.height : 360.0;
      for (var y = -step; y < size.height; y += step) {
        final base = y + step * (0.65 + layer * 0.15);
        final terrain = Path()
          ..moveTo(0, base)
          ..cubicTo(size.width * .32, base - 60, size.width * .58, base + 70,
              size.width, base - 25)
          ..lineTo(size.width, y + step + 130)
          ..lineTo(0, y + step + 130)
          ..close();
        canvas.drawPath(
            terrain,
            Paint()
              ..color = (layer.isEven ? theme.secondaryAccent : Colors.black)
                  .withValues(alpha: layer == 0 ? .08 : .12));
      }
    }
    final count = panorama ? 5 : (size.height / 160).ceil();
    for (var i = 0; i < count; i++) {
      final x = panorama
          ? size.width * (.08 + i * .21)
          : (i.isEven ? size.width * .07 : size.width * .93);
      final y = panorama ? size.height * (.40 + (i % 3) * .18) : 80.0 + i * 160;
      canvas.save();
      canvas.translate(x, y);
      final scale = panorama ? .85 + (i % 2) * .25 : 1.0;
      canvas.scale(scale);
      _motif(canvas, i);
      canvas.restore();
    }
    // Foreground grass / reef / rocks frame both sides without hiding nodes.
    final edge = Paint()..color = theme.primaryAccent.withValues(alpha: .24);
    canvas.drawOval(
        Rect.fromLTWH(-45, size.height - 130, size.width * .45, 180), edge);
    canvas.drawOval(
        Rect.fromLTWH(size.width * .8, size.height - 100, 160, 140), edge);
    canvas.restore();
  }

  void _motif(Canvas c, int index) {
    final accent = theme.secondaryAccent;
    final light = Color.lerp(accent, Colors.white, .55)!;
    final dark = Color.lerp(theme.primaryAccent, Colors.black, .48)!;
    final paint = Paint()..color = accent;
    void oval(double x, double y, double w, double h, Color color) {
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: h),
          Paint()..color = color);
    }

    void star(double x, double y, double r, Color color) {
      final p = Path();
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final radius = i.isEven ? r : r * .28;
        final point =
            Offset(x + math.cos(a) * radius, y + math.sin(a) * radius);
        if (i == 0) {
          p.moveTo(point.dx, point.dy);
        } else {
          p.lineTo(point.dx, point.dy);
        }
      }
      c.drawPath(p..close(), Paint()..color = color);
    }

    switch (theme.tileTheme) {
      case TileVisualTheme.garden:
        oval(0, 26, 78, 18, dark.withValues(alpha: .3));
        c.drawLine(
            const Offset(0, 25),
            const Offset(0, -20),
            Paint()
              ..color = dark
              ..strokeWidth = 5);
        oval(-13, 8, 26, 12, accent);
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3;
          oval(math.cos(angle) * 14, -20 + math.sin(angle) * 14, 22, 22,
              index.isEven ? const Color(0xFFFFD2DE) : Colors.white);
        }
        oval(0, -20, 15, 15, const Color(0xFFFFC94C));
        break;
      case TileVisualTheme.ocean:
        final coral = Paint()
          ..color = const Color(0xFFFFADA8)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        c.drawPath(
            Path()
              ..moveTo(0, 30)
              ..lineTo(0, -25)
              ..moveTo(0, 10)
              ..quadraticBezierTo(-25, 8, -25, -10)
              ..moveTo(0, -5)
              ..quadraticBezierTo(20, -5, 22, -28),
            coral);
        for (var i = 0; i < 3; i++) {
          c.drawCircle(
              Offset(20.0 - i * 16, -45.0 - i * 16),
              5.0 + i * 2,
              Paint()
                ..color = light.withValues(alpha: .7)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2);
        }
        break;
      case TileVisualTheme.candy:
        c.drawLine(
            const Offset(0, 35),
            const Offset(0, -20),
            Paint()
              ..color = Colors.white
              ..strokeWidth = 6);
        oval(0, -15, 54, 54, const Color(0xFFFFD1E8));
        c.drawArc(
            Rect.fromCircle(center: const Offset(0, -15), radius: 18),
            0,
            math.pi * 1.7,
            false,
            Paint()
              ..color = const Color(0xFFED70AA)
              ..strokeWidth = 7
              ..style = PaintingStyle.stroke);
        oval(23, 32, 32, 20, const Color(0xFFBBA4F4));
        break;
      case TileVisualTheme.space:
        oval(0, 0, 52, 52, const Color(0xFFAF91EF));
        c.save();
        c.rotate(-.4);
        c.drawOval(
            const Rect.fromLTWH(-43, -12, 86, 24),
            Paint()
              ..color = accent
              ..strokeWidth = 4
              ..style = PaintingStyle.stroke);
        c.restore();
        star(32, -42, 8, Colors.white);
        star(-29, 37, 5, accent);
        break;
      case TileVisualTheme.desert:
        oval(0, 35, 90, 22, const Color(0xFFD99359));
        final cactus = Paint()
          ..color = const Color(0xFF54896A)
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        c.drawPath(
            Path()
              ..moveTo(0, 30)
              ..lineTo(0, -35)
              ..moveTo(0, 5)
              ..lineTo(-21, 5)
              ..lineTo(-21, -17)
              ..moveTo(0, -9)
              ..lineTo(20, -9)
              ..lineTo(20, -30),
            cactus);
        oval(24, 29, 30, 23, const Color(0xFFB86C48));
        break;
      case TileVisualTheme.ice:
        oval(0, 30, 100, 32, Colors.white.withValues(alpha: .7));
        for (var i = 0; i < 3; i++) {
          final x = -24.0 + i * 25;
          c.drawPath(
              Path()
                ..moveTo(x - 18, 20)
                ..lineTo(x, -48.0 + i * 13)
                ..lineTo(x + 21, 20)
                ..close(),
              Paint()..color = i.isEven ? light : const Color(0xFF7BCEDD));
        }
        star(-25, -42, 9, Colors.white);
        break;
      case TileVisualTheme.jungle:
        c.drawLine(
            const Offset(0, 40),
            const Offset(0, -25),
            Paint()
              ..color = dark
              ..strokeWidth = 7);
        for (var i = 0; i < 6; i++) {
          c.save();
          c.rotate(i * math.pi / 3);
          oval(20, -8, 62, 22, i.isEven ? accent : const Color(0xFF20A987));
          c.drawLine(
              const Offset(0, -8),
              const Offset(47, -8),
              Paint()
                ..color = dark.withValues(alpha: .4)
                ..strokeWidth = 1.5);
          c.restore();
        }
        break;
      case TileVisualTheme.volcano:
        c.drawPath(
            Path()
              ..moveTo(-48, 35)
              ..lineTo(-15, -34)
              ..lineTo(13, -34)
              ..lineTo(48, 35)
              ..close(),
            Paint()..color = dark);
        c.drawPath(
            Path()
              ..moveTo(-13, -29)
              ..lineTo(10, -29)
              ..lineTo(4, -9)
              ..lineTo(20, 12)
              ..lineTo(13, 36)
              ..lineTo(-3, 9)
              ..lineTo(-8, -7)
              ..close(),
            Paint()..color = const Color(0xFFFF9554));
        oval(0, -34, 30, 10, const Color(0xFFFFDE7B));
        star(8, -53, 6, accent);
        break;
      case TileVisualTheme.dream:
        oval(-22, 5, 54, 30, const Color(0xFFF4DEFF));
        oval(0, -6, 55, 48, Colors.white);
        oval(25, 7, 55, 30, const Color(0xFFE7D9FF));
        star(10, -48, 14, const Color(0xFFFFDD83));
        star(-36, -28, 7, Colors.white);
        break;
      case TileVisualTheme.crystal:
        for (var i = 0; i < 3; i++) {
          final x = (i - 1) * 24.0;
          final top = i == 1 ? -55.0 : -25.0;
          c.drawPath(
              Path()
                ..moveTo(x - 13, 25)
                ..lineTo(x - 17, top + 15)
                ..lineTo(x, top)
                ..lineTo(x + 17, top + 15)
                ..lineTo(x + 13, 25)
                ..close(),
              Paint()..color = i.isEven ? const Color(0xFFC9A5FF) : light);
          c.drawPath(
              Path()
                ..moveTo(x, top)
                ..lineTo(x + 17, top + 15)
                ..lineTo(x + 13, 25)
                ..lineTo(x, 25)
                ..close(),
              Paint()..color = theme.primaryAccent.withValues(alpha: .6));
        }
        star(29, -44, 9, Colors.white);
        break;
    }
    // A small consistent highlight unifies the hand-built scenery.
    paint.color = Colors.white.withValues(alpha: .35);
    c.drawCircle(const Offset(-7, -14), 3, paint);
  }

  @override
  bool shouldRepaint(_SceneryPainter oldDelegate) =>
      oldDelegate.theme != theme || oldDelegate.panorama != panorama;
}
