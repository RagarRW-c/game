import 'dart:math' as math;

import 'package:flutter/material.dart';

enum BoosterAction { undo, hint, shuffle }

/// Original filled silhouettes in a shared 64px coordinate system.
class BoosterActionArtwork extends StatelessWidget {
  const BoosterActionArtwork(this.action, {super.key});
  final BoosterAction action;

  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _BoosterSymbolPainter(action), child: const SizedBox.expand());
}

class BoosterMedallionPainter extends CustomPainter {
  const BoosterMedallionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    final rim = Path()..addOval(rect);
    canvas.drawShadow(rim, const Color(0x990B1823), 3, false);
    canvas.drawOval(
        rect,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFBAC5D4),
                Color(0xFFF9FBFF),
                Color(0xFF8793A5)
              ],
              stops: [
                0,
                .45,
                .7,
                1
              ]).createShader(rect));
    final face = rect.deflate(size.width * .045);
    canvas.drawOval(
        face,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF384B59),
                Color(0xFF43515B),
                Color(0xFF696B6C),
                Color(0xFF53595D),
                Color(0xFF343D46)
              ],
              stops: [
                0,
                .16,
                .17,
                .58,
                1
              ]).createShader(face));
    canvas.drawOval(
        face,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF2D3846));
    canvas.drawArc(
        rect.deflate(1),
        math.pi * 1.1,
        math.pi * .8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xCCFFFFFF));
  }

  @override
  bool shouldRepaint(BoosterMedallionPainter oldDelegate) => false;
}

class _BoosterSymbolPainter extends CustomPainter {
  const _BoosterSymbolPainter(this.action);
  final BoosterAction action;

  Path _star(Offset center, double radius) {
    final points = List.generate(10, (i) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final length = radius * (i.isEven ? 1 : .53);
      return center + Offset(math.cos(angle), math.sin(angle)) * length;
    });
    // Rounded tips retain the bold, soft silhouette at phone size.
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final previous = points[(i + 9) % 10];
      final current = points[i];
      final next = points[(i + 1) % 10];
      final before = Offset.lerp(current, previous, .18)!;
      final after = Offset.lerp(current, next, .18)!;
      if (i == 0) {
        path.moveTo(before.dx, before.dy);
      } else {
        path.lineTo(before.dx, before.dy);
      }
      path.quadraticBezierTo(current.dx, current.dy, after.dx, after.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final fill = Paint()..color = Colors.white;
    switch (action) {
      case BoosterAction.undo:
        canvas.drawPath(
            Path()
              ..moveTo(24, 8)
              ..quadraticBezierTo(21, 5, 18, 9)
              ..lineTo(5, 24)
              ..quadraticBezierTo(1, 29, 7, 33)
              ..lineTo(23, 43)
              ..quadraticBezierTo(28, 46, 28, 40)
              ..lineTo(28, 33)
              ..cubicTo(44, 28, 52, 37, 42, 51)
              ..quadraticBezierTo(40, 55, 45, 53)
              ..cubicTo(66, 43, 63, 14, 39, 15)
              ..lineTo(28, 16)
              ..lineTo(24, 8)
              ..close(),
            fill);
      case BoosterAction.hint:
        canvas.drawLine(
            const Offset(15, 56),
            const Offset(33, 32),
            Paint()
              ..color = Colors.white
              ..strokeWidth = 9
              ..strokeCap = StrokeCap.round);
        canvas.drawPath(_star(const Offset(39, 23), 22), fill);
        canvas.drawPath(_star(const Offset(10, 12), 6), fill);
        canvas.drawPath(_star(const Offset(8, 34), 5), fill);
        canvas.drawPath(_star(const Offset(56, 48), 6), fill);
      case BoosterAction.shuffle:
        final stroke = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(
            Path()
              ..moveTo(8, 49)
              ..cubicTo(30, 49, 30, 15, 49, 15),
            stroke);
        canvas.drawPath(
            Path()
              ..moveTo(8, 15)
              ..cubicTo(30, 15, 30, 49, 49, 49),
            stroke);
        for (final y in [15.0, 49.0]) {
          canvas.drawPath(
              Path()
                ..moveTo(46, y - 11)
                ..quadraticBezierTo(44, y - 13, 44, y - 8)
                ..lineTo(44, y + 8)
                ..quadraticBezierTo(44, y + 13, 48, y + 10)
                ..lineTo(59, y + 2)
                ..quadraticBezierTo(62, y, 58, y - 3)
                ..lineTo(46, y - 11)
                ..close(),
              fill);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoosterSymbolPainter oldDelegate) =>
      oldDelegate.action != action;
}

class BoosterCoinPainter extends CustomPainter {
  const BoosterCoinPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    const rect = Rect.fromLTWH(1, 1, 22, 22);
    canvas.drawOval(
        rect,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF88B),
                Color(0xFFFFCE26),
                Color(0xFFE99208)
              ]).createShader(rect));
    canvas.drawCircle(
        const Offset(12, 12),
        8.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFFEC73));
    canvas.drawPath(
        Path()
          ..moveTo(15, 7)
          ..cubicTo(8, 4, 7, 12, 12, 12)
          ..cubicTo(18, 12, 16, 20, 8, 17),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFBC7706));
    canvas.drawLine(
        const Offset(12, 5),
        const Offset(12, 19),
        Paint()
          ..strokeWidth = 1.2
          ..color = const Color(0xFFBC7706));
    canvas.restore();
  }

  @override
  bool shouldRepaint(BoosterCoinPainter oldDelegate) => false;
}
