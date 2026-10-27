import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';

/// Original small-format artwork: solid enamel silhouettes, bevel outlines,
/// colored shading and restrained specular highlights. No font glyphs, image
/// loading, offscreen layers, timers or animation state are needed.
class PremiumTilePainter extends CustomPainter {
  const PremiumTilePainter({
    required this.illustration,
    required this.color,
    required this.blocked,
  });

  final TileIllustration illustration;
  final Color color;
  final bool blocked;

  Color _tone(Color value) =>
      blocked ? Color.lerp(value, const Color(0xFF657D83), .45)! : value;

  Path _oval(double x, double y, double w, double h) =>
      Path()..addOval(Rect.fromLTWH(x, y, w, h));

  Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  Path _star(int points, double outer, double inner,
      {Offset center = const Offset(50, 49), double turn = -math.pi / 2}) {
    return _polygon(List.generate(points * 2, (index) {
      final a = turn + index * math.pi / points;
      final r = index.isEven ? outer : inner;
      return center + Offset(math.cos(a) * r, math.sin(a) * r);
    }));
  }

  void _enamel(Canvas canvas, Path path, Color base, {bool shadow = true}) {
    final outline = Color.lerp(base, const Color(0xFF233B35), .62)!;
    if (shadow) {
      canvas.drawPath(path.shift(const Offset(0, 3)),
          Paint()..color = const Color(0x30243644));
    }
    // Use fresh paints: shadow alpha must never modulate an opaque shader.
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _tone(Color.lerp(base, const Color(0xFFFFFFB8), .55)!),
              _tone(base),
              _tone(Color.lerp(base, const Color(0xFF173C43), .38)!),
            ],
            stops: const [0, .42, 1],
          ).createShader(path.getBounds()));
    canvas.drawPath(
        path,
        Paint()
          ..color = _tone(outline)
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.6);
  }

  void _line(Canvas canvas, Path path, Color base, double width) {
    canvas.drawPath(
        path,
        Paint()
          ..color = _tone(base)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
  }

  void _glint(Canvas canvas, double x, double y,
      {double width = 10, double height = 5}) {
    canvas.drawOval(Rect.fromLTWH(x, y, width, height),
        Paint()..color = Colors.white.withValues(alpha: blocked ? .32 : .88));
  }

  void _drop(Canvas canvas, Color base) {
    final path = Path()
      ..moveTo(53, 9)
      ..cubicTo(48, 30, 22, 43, 22, 64)
      ..cubicTo(22, 96, 80, 96, 80, 64)
      ..cubicTo(80, 43, 59, 28, 53, 9)
      ..close();
    _enamel(canvas, path, base);
    _line(
        canvas,
        Path()
          ..moveTo(33, 62)
          ..quadraticBezierTo(31, 72, 40, 77),
        const Color(0xFFDAFFFF),
        4);
    _glint(canvas, 37, 47, width: 7, height: 12);
  }

  void _sun(Canvas canvas, {bool heat = false}) {
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.translate(50, 49);
      canvas.rotate(i * math.pi / 4);
      _enamel(
          canvas,
          Path()
            ..moveTo(-6, -28)
            ..quadraticBezierTo(-6, -34, 0, -41)
            ..quadraticBezierTo(6, -34, 6, -28)
            ..close(),
          heat ? const Color(0xFFFF7133) : color,
          shadow: false);
      canvas.restore();
    }
    _enamel(canvas, _oval(26, 25, 48, 48), color);
    _glint(canvas, 34, 33, width: 16, height: 8);
    _glint(canvas, 55, 56, width: 5, height: 4);
  }

  void _gem(Canvas canvas, Color base) {
    const a = Offset(27, 20), b = Offset(73, 20), c = Offset(89, 42);
    const d = Offset(50, 85), e = Offset(11, 42);
    final path = _polygon([a, b, c, d, e]);
    _enamel(canvas, path, base);
    canvas.drawPath(_polygon([a, const Offset(39, 42), e]),
        Paint()..color = _tone(Color.lerp(base, Colors.white, .55)!));
    canvas.drawPath(_polygon([b, c, const Offset(63, 42)]),
        Paint()..color = _tone(Color.lerp(base, Colors.white, .3)!));
    canvas.drawPath(_polygon([const Offset(63, 42), c, d]),
        Paint()..color = _tone(Color.lerp(base, Colors.black, .27)!));
    _line(
        canvas,
        Path()
          ..moveTo(11, 42)
          ..lineTo(89, 42)
          ..moveTo(27, 20)
          ..lineTo(39, 42)
          ..lineTo(50, 85)
          ..lineTo(63, 42)
          ..lineTo(73, 20),
        Color.lerp(base, Colors.white, .7)!,
        1.7);
    _glint(canvas, 33, 25, width: 20, height: 5);
  }

  void _clover(Canvas canvas) {
    _line(
        canvas,
        Path()
          ..moveTo(49, 53)
          ..quadraticBezierTo(66, 72, 57, 87),
        const Color(0xFF27652B),
        6);
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(49, 46);
      canvas.rotate(i * math.pi / 2);
      _enamel(
          canvas,
          Path()
            ..moveTo(0, 3)
            ..cubicTo(-36, -5, -32, -41, -13, -32)
            ..quadraticBezierTo(0, -43, 8, -29)
            ..quadraticBezierTo(18, -13, 0, 3)
            ..close(),
          color);
      _glint(canvas, -20, -26, width: 9, height: 5);
      canvas.restore();
    }
    _enamel(canvas, _oval(44, 41, 10, 10), const Color(0xFFAADD39));
  }

  void _cluster(Canvas canvas, {required bool rocks}) {
    const positions = [
      (Offset(24, 29), 13.0),
      (Offset(64, 22), 12.0),
      (Offset(49, 53), 18.0),
      (Offset(22, 75), 10.0),
      (Offset(79, 68), 12.0),
    ];
    for (final (center, radius) in positions) {
      if (rocks) {
        _enamel(canvas, _star(7, radius, radius * .85, center: center), color);
        canvas.drawOval(
            Rect.fromCenter(
                center: center + const Offset(3, 3),
                width: radius * .65,
                height: radius * .45),
            Paint()..color = _tone(Color.lerp(color, Colors.black, .4)!));
      } else {
        _enamel(canvas, _oval(center.dx - 8, center.dy - 12, 16, 24), color);
        _line(
            canvas,
            Path()
              ..moveTo(center.dx + 1, center.dy - 5)
              ..lineTo(center.dx - 2, center.dy + 6),
            const Color(0xFF6D782A),
            1.5);
      }
      _glint(canvas, center.dx - 6, center.dy - 8, width: 7, height: 4);
    }
  }

  void _planet(Canvas canvas) {
    _enamel(canvas, _oval(23, 17, 56, 62), color);
    _line(
        canvas,
        Path()
          ..moveTo(29, 37)
          ..quadraticBezierTo(53, 44, 73, 33),
        Color.lerp(color, Colors.white, .5)!,
        5);
    final ring = Path()
      ..moveTo(23, 47)
      ..cubicTo(-4, 81, 73, 91, 90, 42)
      ..cubicTo(95, 32, 83, 29, 78, 34)
      ..cubicTo(86, 51, 27, 78, 20, 61)
      ..quadraticBezierTo(19, 56, 23, 47)
      ..close();
    _enamel(canvas, ring, const Color(0xFFF4A8EF));
    _glint(canvas, 34, 25, width: 15, height: 7);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 100);
    switch (illustration) {
      case TileIllustration.sun:
        _sun(canvas);
      case TileIllustration.heat:
        _sun(canvas, heat: true);
      case TileIllustration.drop:
        _drop(canvas, color);
      case TileIllustration.gem:
      case TileIllustration.caramel:
        _gem(canvas, color);
      case TileIllustration.clover:
        _clover(canvas);
      case TileIllustration.seeds:
        _cluster(canvas, rocks: false);
      case TileIllustration.asteroids:
        _cluster(canvas, rocks: true);
      case TileIllustration.planet:
        _planet(canvas);
      case TileIllustration.starfish:
      case TileIllustration.wafer:
        _enamel(canvas, _star(5, 40, 21), color);
        if (illustration == TileIllustration.wafer) {
          for (final x in [42.0, 50.0, 58.0]) {
            _line(
                canvas,
                Path()
                  ..moveTo(x, 34)
                  ..lineTo(x, 63),
                const Color(0xFFB77922),
                2);
            _line(
                canvas,
                Path()
                  ..moveTo(36, x)
                  ..lineTo(64, x),
                const Color(0xFFB77922),
                2);
          }
        } else {
          for (var i = 0; i < 5; i++) {
            final a = -math.pi / 2 + i * math.pi * 2 / 5;
            for (final r in [9.0, 18.0]) {
              _glint(canvas, 48 + math.cos(a) * r, 47 + math.sin(a) * r,
                  width: 4, height: 4);
            }
          }
        }
        _glint(canvas, 44, 29, width: 7, height: 5);
      case TileIllustration.sugar:
        for (final (offset, scale) in [
          (const Offset(0, 6), .68),
          (const Offset(31, 27), .62),
          (const Offset(37, 0), .52)
        ]) {
          canvas.save();
          canvas.translate(offset.dx, offset.dy);
          canvas.scale(scale);
          _gem(canvas, const Color(0xFFFFEAB4));
          canvas.restore();
        }
        _enamel(canvas, _star(4, 10, 3, center: const Offset(22, 79)), color);
      case TileIllustration.portal:
        final ring = Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(const Rect.fromLTWH(16, 10, 68, 80))
          ..addOval(const Rect.fromLTWH(31, 26, 38, 48));
        _enamel(canvas, ring, color);
        _line(
            canvas,
            Path()
              ..moveTo(28, 28)
              ..quadraticBezierTo(47, 6, 69, 27),
            const Color(0xFFFFDCFF),
            4);
        _enamel(canvas, _star(4, 10, 3, center: const Offset(50, 49)),
            const Color(0xFF91F7FF));
      case TileIllustration.relic:
        _enamel(
            canvas,
            _polygon(const [
              Offset(50, 12),
              Offset(80, 37),
              Offset(72, 74),
              Offset(50, 87),
              Offset(28, 74),
              Offset(20, 37)
            ]),
            color);
        _enamel(canvas, _star(4, 20, 8), const Color(0xFF41D5C1));
        _glint(canvas, 35, 27, width: 12, height: 5);
      case TileIllustration.aurora:
        for (var i = 0; i < 3; i++) {
          final y = 21.0 + i * 20;
          final ribbon = Path()
            ..moveTo(12, y + 20)
            ..cubicTo(37, y - 20, 65, y + 36, 88, y)
            ..lineTo(87, y + 14)
            ..cubicTo(64, y + 49, 35, y - 1, 13, y + 35)
            ..close();
          _enamel(
              canvas,
              ribbon,
              [
                const Color(0xFF60E5BB),
                const Color(0xFF54BCEC),
                const Color(0xFFC992F5)
              ][i]);
        }
      case TileIllustration.icicle:
      case TileIllustration.amethyst:
        for (final (x, top, bottom) in [
          (30.0, 26.0, 78.0),
          (68.0, 29.0, 81.0),
          (49.0, 10.0, 91.0)
        ]) {
          _enamel(
              canvas,
              _polygon([
                Offset(x, top),
                Offset(x + 12, top + 14),
                Offset(x + 10, bottom - 12),
                Offset(x, bottom),
                Offset(x - 10, bottom - 12),
                Offset(x - 12, top + 14)
              ]),
              color);
          _line(
              canvas,
              Path()
                ..moveTo(x, top + 5)
                ..lineTo(x, bottom - 8),
              Color.lerp(color, Colors.white, .75)!,
              2);
        }
      case TileIllustration.snowball:
        _enamel(canvas, _oval(14, 15, 72, 72), color);
        _glint(canvas, 26, 27, width: 23, height: 13);
        for (final p in [
          const Offset(62, 58),
          const Offset(55, 70),
          const Offset(72, 46)
        ]) {
          canvas.drawCircle(
              p, 2.4, Paint()..color = _tone(const Color(0xFF96BFCF)));
        }
      case TileIllustration.river:
        _enamel(
            canvas,
            Path()
              ..moveTo(24, 12)
              ..lineTo(63, 12)
              ..cubicTo(91, 35, 23, 43, 55, 59)
              ..quadraticBezierTo(82, 74, 65, 88)
              ..lineTo(23, 88)
              ..cubicTo(58, 61, 3, 65, 21, 42)
              ..quadraticBezierTo(48, 23, 24, 12)
              ..close(),
            color);
        _line(
            canvas,
            Path()
              ..moveTo(46, 20)
              ..cubicTo(69, 36, 17, 42, 40, 58)
              ..quadraticBezierTo(68, 74, 45, 80),
            const Color(0xFFCAFCFF),
            3);
      case TileIllustration.fern:
        _line(
            canvas,
            Path()
              ..moveTo(35, 89)
              ..quadraticBezierTo(66, 47, 56, 12),
            const Color(0xFF2C6C2D),
            5);
        for (var i = 0; i < 4; i++) {
          final y = 30.0 + i * 14;
          for (final direction in [-1, 1]) {
            final x = 57.0 - i * 3;
            _enamel(
                canvas,
                Path()
                  ..moveTo(x, y + 8)
                  ..quadraticBezierTo(
                      x + direction * 30, y + 10, x + direction * 29, y - 10)
                  ..quadraticBezierTo(x + direction * 9, y - 12, x, y + 8)
                  ..close(),
                color);
          }
        }
      case TileIllustration.flame:
        _enamel(
            canvas,
            Path()
              ..moveTo(53, 8)
              ..cubicTo(19, 34, 40, 38, 23, 47)
              ..cubicTo(5, 74, 34, 95, 57, 87)
              ..cubicTo(91, 80, 86, 48, 73, 31)
              ..quadraticBezierTo(70, 52, 62, 50)
              ..quadraticBezierTo(68, 24, 53, 8)
              ..close(),
            const Color(0xFFF36B23));
        _enamel(
            canvas,
            Path()
              ..moveTo(50, 45)
              ..cubicTo(29, 66, 35, 84, 54, 80)
              ..quadraticBezierTo(74, 76, 50, 45)
              ..close(),
            color,
            shadow: false);
        _glint(canvas, 31, 56, width: 5, height: 10);
      case TileIllustration.dawn:
        _enamel(canvas, _oval(25, 21, 52, 52), color);
        for (var i = 0; i < 3; i++) {
          _enamel(
              canvas,
              Path()
                ..addRRect(RRect.fromRectAndRadius(
                    Rect.fromLTWH(12.0 + i * 6, 62.0 + i * 9, 76.0 - i * 12, 5),
                    const Radius.circular(2.5))),
              const Color(0xFFF7A0A5),
              shadow: false);
        }
        _glint(canvas, 34, 31, width: 16, height: 7);
      case TileIllustration.mist:
        // One cohesive cloud silhouette, then two glossy mist ribbons.
        _enamel(
            canvas,
            Path()
              ..moveTo(19, 59)
              ..cubicTo(0, 57, 11, 30, 28, 34)
              ..cubicTo(27, 7, 65, 7, 67, 31)
              ..cubicTo(92, 23, 99, 60, 79, 62)
              ..lineTo(19, 59)
              ..close(),
            color);
        for (final (x, y, w) in [(22.0, 72.0, 56.0), (33.0, 84.0, 38.0)]) {
          _enamel(
              canvas,
              Path()
                ..addRRect(RRect.fromRectAndRadius(
                    Rect.fromLTWH(x, y, w, 5), const Radius.circular(2.5))),
              color,
              shadow: false);
        }
        _glint(canvas, 33, 25, width: 17, height: 6);
      case TileIllustration.bloom:
        for (var i = 0; i < 6; i++) {
          canvas.save();
          canvas.translate(50, 50);
          canvas.rotate(i * math.pi / 3);
          _enamel(canvas, _oval(-13, -39, 26, 38), color);
          _glint(canvas, -7, -32, width: 7, height: 10);
          canvas.restore();
        }
        _enamel(canvas, _oval(36, 36, 28, 28), const Color(0xFFFFCA35));
        _glint(canvas, 41, 41, width: 9, height: 5);
      case TileIllustration.lagoon:
        // Lagoon has its own original continent artwork and separate painter.
        throw StateError('Lagoon must use GlobeTilePainter');
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PremiumTilePainter oldDelegate) =>
      illustration != oldDelegate.illustration ||
      color != oldDelegate.color ||
      blocked != oldDelegate.blocked;
}
