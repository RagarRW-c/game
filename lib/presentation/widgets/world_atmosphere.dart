import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../theme/game_theme.dart';
import '../theme/world_theme.dart';

/// Static, resolution-independent scenery. No tickers, filters, hit targets or
/// random particle simulation; the quiet central region keeps boards readable.
class WorldAtmosphere extends StatelessWidget {
  const WorldAtmosphere({super.key, this.theme});
  final WorldVisualTheme? theme;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(painter: _AtmospherePainter(theme)),
          ),
        ),
      );
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter(this.theme);
  final WorldVisualTheme? theme;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final primary = theme?.primaryAccent ?? GameColors.primaryBlueLight;
    final secondary = theme?.secondaryAccent ?? GameColors.accentGold;
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.9, -0.8),
            radius: 1.1,
            colors: [secondary.withValues(alpha: 0.22), Colors.transparent],
          ).createShader(bounds));
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.95, 0.1),
            radius: 0.95,
            colors: [primary.withValues(alpha: 0.20), Colors.transparent],
          ).createShader(bounds));

    final type = theme?.tileTheme;
    final silhouette = Paint()..color = Colors.white.withValues(alpha: 0.08);
    // Soft cloud banks sit at the edges and leave the play area quiet.
    if (type == null ||
        type == TileVisualTheme.dream ||
        type == TileVisualTheme.garden) {
      final cloud = Paint()..color = Colors.white.withValues(alpha: 0.10);
      for (var bank = 0; bank < 2; bank++) {
        final x = bank == 0 ? size.width * 0.02 : size.width * 0.96;
        final y = size.height * (bank == 0 ? 0.14 : 0.40);
        for (var puff = 0; puff < 3; puff++) {
          canvas.drawOval(
              Rect.fromCenter(
                  center:
                      Offset(x + (puff - 1) * 30, y + (puff == 1 ? -12 : 4)),
                  width: 80,
                  height: 40),
              cloud);
        }
      }
    }
    if (type == TileVisualTheme.space ||
        type == TileVisualTheme.crystal ||
        type == TileVisualTheme.ice) {
      final path = Path()
        ..moveTo(size.width * 0.66, size.height)
        ..lineTo(size.width * 0.88, size.height * 0.74)
        ..lineTo(size.width, size.height * 0.87)
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, silhouette);
      canvas.drawPath(
          Path()
            ..moveTo(0, size.height * 0.13)
            ..lineTo(size.width * 0.24, size.height * 0.22)
            ..lineTo(0, size.height * 0.33)
            ..close(),
          silhouette);
      if (type == TileVisualTheme.space) {
        final line = Paint()
          ..color = Colors.white.withValues(alpha: 0.14)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
        canvas.drawPath(
            Path()
              ..moveTo(size.width * 0.72, size.height * 0.07)
              ..lineTo(size.width * 0.89, size.height * 0.12)
              ..lineTo(size.width * 0.8, size.height * 0.24),
            line);
      }
    } else if (type == TileVisualTheme.garden ||
        type == TileVisualTheme.jungle) {
      for (var i = 0; i < 4; i++) {
        final x = i.isEven ? 0.0 : size.width;
        final direction = i.isEven ? 1.0 : -1.0;
        final y = size.height * (0.2 + i * 0.19);
        canvas.drawPath(
            Path()
              ..moveTo(x, y + 48)
              ..quadraticBezierTo(
                  x + 74 * direction, y + 10, x + 18 * direction, y - 30)
              ..quadraticBezierTo(x - 6 * direction, y + 12, x, y + 48)
              ..close(),
            silhouette);
        canvas.drawPath(
            Path()
              ..moveTo(x, y + 48)
              ..quadraticBezierTo(
                  x + 28 * direction, y + 26, x + 40 * direction, y + 12),
            Paint()
              ..color = secondary.withValues(alpha: 0.16)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      }
    } else if (type == TileVisualTheme.candy || type == TileVisualTheme.dream) {
      for (var i = 0; i < 4; i++) {
        canvas.drawCircle(
            Offset(i.isEven ? size.width * 0.04 : size.width * 0.96,
                size.height * (0.17 + i * 0.22)),
            30.0 + i * 9,
            silhouette);
      }
    } else if (type == TileVisualTheme.volcano) {
      canvas.drawPath(
          Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width * 0.15, size.height * 0.80)
            ..lineTo(size.width * 0.24, size.height * 0.85)
            ..lineTo(size.width * 0.33, size.height * 0.82)
            ..lineTo(size.width * 0.53, size.height)
            ..close(),
          silhouette);
    }

    // Ocean swells, desert dunes and a soft horizon in every other world.
    for (var band = 0; band < 3; band++) {
      final y = size.height * (0.83 + band * 0.055);
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(size.width * 0.28, y - 32, size.width * 0.65, y + 30,
            size.width, y - 12)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path,
          Paint()..color = primary.withValues(alpha: 0.10 + band * 0.035));
    }
    for (var i = 0; i < 18; i++) {
      final x = size.width *
          (i.isEven ? 0.04 + (i % 3) * 0.055 : 0.84 + (i % 3) * 0.055);
      final y = size.height * (0.06 + ((i * 37) % 88) / 100);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: i % 3 == 0 ? 0.30 : 0.14);
      if (type == TileVisualTheme.ocean) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawCircle(Offset(x, y), 3.0 + (i % 4) * 2, paint);
      } else {
        canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * 0.5, paint);
      }
    }
    // Edge depth is painted once; no blur filters or animated layers.
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = const RadialGradient(
            radius: 0.85,
            colors: [Colors.transparent, Color(0x33101A32)],
            stops: [0.45, 1],
          ).createShader(bounds));
    if (type == TileVisualTheme.candy) {
      final paint = Paint()
        ..color = secondary.withValues(alpha: 0.13)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
          Rect.fromCircle(
              center: Offset(size.width * 0.97, size.height * 0.2),
              radius: size.width * 0.22),
          -math.pi,
          math.pi * 1.6,
          false,
          paint);
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      oldDelegate.theme != theme;
}
