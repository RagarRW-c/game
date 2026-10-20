import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/game_theme.dart';

/// A short, one-shot entrance; never loops or changes interaction timing.
class GameEntrance extends StatelessWidget {
  const GameEntrance({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: child,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        ),
      );
}

/// Painted decoration stays outside the semantics and hit-test trees.
class GameCelebrationHalo extends StatelessWidget {
  const GameCelebrationHalo(
      {super.key, required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _HaloPainter(color),
        child: child,
      );
}

class _HaloPainter extends CustomPainter {
  const _HaloPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.48;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (var i = 0; i < 10; i++) {
      final angle = i * math.pi / 5 - math.pi / 2;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final paint = Paint()
        ..color = color.withValues(alpha: i.isEven ? 0.8 : 0.4);
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + math.pi / 4);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: i.isEven ? 6 : 4,
                  height: i.isEven ? 6 : 4),
              const Radius.circular(1.5)),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HaloPainter oldDelegate) => oldDelegate.color != color;
}

/// Original menu illustration made from UI shapes, independent of game tiles.
class AdventureEmblem extends StatelessWidget {
  const AdventureEmblem({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: IgnorePointer(
          child: SizedBox(
            width: 200,
            height: 124,
            child: GameCelebrationHalo(
              color: const Color(0xFFFFDE85),
              child: Stack(alignment: Alignment.center, children: [
                _tile(-0.24, const Offset(-48, 8), Icons.local_florist_rounded,
                    const Color(0xFF52BA8B)),
                _tile(0.23, const Offset(48, 8), Icons.water_drop_rounded,
                    const Color(0xFF56AFDC)),
                _tile(0, const Offset(0, -4), Icons.star_rounded,
                    const Color(0xFFFFBA50)),
              ]),
            ),
          ),
        ),
      );

  Widget _tile(double angle, Offset offset, IconData icon, Color color) =>
      Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: 72,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(color, Colors.white, 0.35)!, color],
              ),
              border: Border.all(color: const Color(0xFFFFF6DF), width: 3),
              boxShadow: [
                BoxShadow(
                    color: Color.lerp(color, const Color(0xFF392F5C), 0.45)!,
                    offset: const Offset(0, 5)),
                ...GameShadows.medium(),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 44, shadows: const [
              Shadow(color: Color(0x333A3159), offset: Offset(0, 3))
            ]),
          ),
        ),
      );
}
