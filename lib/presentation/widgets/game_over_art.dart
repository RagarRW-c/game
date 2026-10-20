import 'package:flutter/material.dart';

import '../theme/game_theme.dart';

/// The frame paints around natural-height content, including wrapped actions.
/// Its edges do not consume or constrain the content's layout.
class GameOverPanel extends StatelessWidget {
  const GameOverPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66101835),
                blurRadius: 26,
                offset: Offset(0, 12)),
          ],
        ),
        child: CustomPaint(
          painter: const _PanelPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            child: child,
          ),
        ),
      );
}

class _PanelPainter extends CustomPainter {
  const _PanelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(bounds, const Radius.circular(36));
    // A shaded lower edge gives the panel thickness without another layout box.
    canvas.drawRRect(outer.shift(const Offset(0, 6)),
        Paint()..color = const Color(0xFF796180));
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8EA), Color(0xFFD8C2CC), Color(0xFFAE91AC)],
          stops: [0, 0.45, 1],
        ).createShader(bounds),
    );
    final face =
        RRect.fromRectAndRadius(bounds.deflate(4), const Radius.circular(32));
    canvas.drawRRect(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFECDDE9), Color(0xFFFFFAEE), Color(0xFFF2E8E3)],
          stops: [0, 0.30, 1],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipRRect(face);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.65, -1),
          radius: 1.1,
          colors: [Color(0xAAFFFFFF), Color(0x00FFFFFF)],
        ).createShader(bounds),
    );
    // Curved shoulder seams visually seat the headline inside the frame.
    final seam = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(12, 55)
          ..lineTo(12, 36)
          ..quadraticBezierTo(12, 12, 36, 12)
          ..lineTo(size.width * 0.35, 12),
        seam);
    canvas.drawPath(
        Path()
          ..moveTo(size.width - 12, size.height - 55)
          ..lineTo(size.width - 12, size.height - 36)
          ..quadraticBezierTo(size.width - 12, size.height - 12,
              size.width - 36, size.height - 12)
          ..lineTo(size.width * 0.65, size.height - 12),
        seam..color = const Color(0x55B69AAC));
    canvas.restore();
    canvas.drawRRect(
        face,
        Paint()
          ..color = const Color(0xCCFFFDF4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_PanelPainter oldDelegate) => false;
}

/// Seven occupied recesses, with individual tile faces and a raised front lip.
/// Decorative UI art only: no engine tiles, hit targets or animation controllers.
class FullTrayIllustration extends StatelessWidget {
  const FullTrayIllustration({super.key});

  static const _colors = [
    Color(0xFF71AD89),
    Color(0xFFE0AC56),
    Color(0xFF9C84C0),
    Color(0xFF6BAECD),
    Color(0xFFD086A0),
    Color(0xFF74B9A7),
    Color(0xFFBD986B),
  ];
  static const _icons = [
    Icons.local_florist_rounded,
    Icons.star_rounded,
    Icons.diamond_rounded,
    Icons.water_drop_rounded,
    Icons.favorite_rounded,
    Icons.energy_savings_leaf_rounded,
    Icons.wb_sunny_rounded,
  ];

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Tray full: 7 of 7 slots occupied',
        image: true,
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: SizedBox(
              width: 312,
              height: 144,
              child: CustomPaint(
                painter: const _TrayAtmospherePainter(),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.fromLTRB(7, 10, 7, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF857496), Color(0xFF3E345C)],
                      ),
                      border:
                          Border.all(color: const Color(0xFFF8DAB5), width: 2),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0xFF392D51), offset: Offset(0, 6)),
                        BoxShadow(
                            color: Color(0x334F345D),
                            blurRadius: 12,
                            offset: Offset(0, 12)),
                      ],
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x33F8DAB5)],
                        stops: [0.9, 1],
                      ),
                    ),
                    child: Row(children: [
                      for (var i = 0; i < _colors.length; i++) ...[
                        if (i > 0) const SizedBox(width: 3),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF342A4B),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFF9481A4)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(1, 1, 1, 5),
                              child: Container(
                                key: ValueKey('game_over_tray_tile_$i'),
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(9),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color.lerp(
                                          _colors[i], Colors.white, 0.40)!,
                                      _colors[i]
                                    ],
                                  ),
                                  border: Border.all(
                                      color: const Color(0xFFFFF4E2),
                                      width: 1.3),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Color.lerp(_colors[i],
                                            const Color(0xFF342A4B), 0.48)!,
                                        offset: const Offset(0, 3)),
                                  ],
                                ),
                                child: Stack(children: [
                                  Positioned(
                                    top: 3,
                                    left: 3,
                                    right: 3,
                                    height: 5,
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(6),
                                    )),
                                  ),
                                  Center(
                                      child: Icon(_icons[i],
                                          color: Colors.white,
                                          size: 18,
                                          shadows: const [
                                        Shadow(
                                            color: Color(0x55433659),
                                            offset: Offset(0, 1))
                                      ])),
                                ]),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _TrayAtmospherePainter extends CustomPainter {
  const _TrayAtmospherePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.86),
            width: size.width * 0.8,
            height: 14),
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x334B335F), Color(0x004B335F)],
          ).createShader(bounds));
    canvas.drawOval(
        bounds,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x99FFF0CA), Color(0x00FFF0CA)],
          ).createShader(bounds));
    final arc = Paint()
      ..color = const Color(0x66CCB7CB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(bounds.deflate(12), 3.5, 2.2, false, arc);
    for (final position in [
      const Offset(0.10, 0.12),
      const Offset(0.89, 0.15),
      const Offset(0.95, 0.80)
    ]) {
      final center =
          Offset(size.width * position.dx, size.height * position.dy);
      final sparkle = Path()
        ..moveTo(center.dx, center.dy - 5)
        ..quadraticBezierTo(
            center.dx + 1, center.dy - 1, center.dx + 5, center.dy)
        ..quadraticBezierTo(
            center.dx + 1, center.dy + 1, center.dx, center.dy + 5)
        ..quadraticBezierTo(
            center.dx - 1, center.dy + 1, center.dx - 5, center.dy)
        ..quadraticBezierTo(
            center.dx - 1, center.dy - 1, center.dx, center.dy - 5)
        ..close();
      canvas.drawPath(sparkle,
          Paint()..color = GameColors.accentGoldDark.withValues(alpha: 0.45));
    }
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_TrayAtmospherePainter oldDelegate) => false;
}
