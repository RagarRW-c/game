import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../theme/game_theme.dart';

/// Shared by board tiles, flight copies and tray snapshots. All artwork stays
/// inside the measured face, so changing its styling cannot change hit geometry.
class TileFace extends StatelessWidget {
  const TileFace({
    super.key,
    required this.art,
    required this.blocked,
    required this.highlighted,
    required this.pressed,
    required this.depth,
    required this.trayBlend,
  });

  final TileArt art;
  final bool blocked;
  final bool highlighted;
  final bool pressed;
  final double depth;
  final double trayBlend;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: TileFacePainter(
            blocked: blocked,
            highlighted: highlighted,
            pressed: pressed,
            depth: depth,
            trayBlend: trayBlend),
        child: LayoutBuilder(builder: (context, constraints) {
          final size = constraints.biggest;
          final face = TileFacePainter.faceRect(size);
          final symbolSize = math.min(face.width, face.height) * .76;
          return Stack(children: [
            Positioned.fromRect(
                rect: Rect.fromCenter(
                    center: face.center, width: symbolSize, height: symbolSize),
                child: TileSymbol(art: art, blocked: blocked)),
          ]);
        }),
      );
}

/// Ivory ceramic cap, a grey lower bevel and a fine recessed outline. No
/// image assets, blur filters, clipping layers or per-tile controllers.
class TileFacePainter extends CustomPainter {
  const TileFacePainter({
    required this.blocked,
    required this.highlighted,
    required this.pressed,
    required this.depth,
    required this.trayBlend,
  });

  final bool blocked;
  final bool highlighted;
  final bool pressed;
  final double depth;
  final double trayBlend;

  static Rect faceRect(Size size) {
    final unit = math.min(size.width, size.height);
    return Rect.fromLTRB(unit * .025, unit * .025, size.width - unit * .025,
        size.height - unit * .12);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = math.min(size.width, size.height);
    final face = faceRect(size);
    final radius = Radius.circular(unit * .19);
    final cap = RRect.fromRectAndRadius(face, radius);
    final body = RRect.fromRectAndRadius(
        Rect.fromLTRB(face.left, face.top + unit * .06, face.right,
            size.height - unit * .035),
        radius);
    final pen = Paint();
    // A tight contact shadow reads as physical thickness even on tiny slots.
    canvas.drawRRect(
        body.shift(Offset(0, unit * .025)),
        pen
          ..color = const Color(0xFF182A36).withValues(
              alpha: .23 + depth.clamp(0.0, 1.0) * .08 - trayBlend * .03));
    canvas.drawRRect(
        body,
        pen
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD6D9D4), Color(0xFF8C979B)],
          ).createShader(body.outerRect));
    canvas.drawRRect(
        cap,
        pen
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: blocked
                ? const [Color(0xFFCDD5D4), Color(0xFFA2B1B2)]
                : [
                    Colors.white,
                    pressed ? const Color(0xFFFFE9B6) : const Color(0xFFFFFCF2),
                    const Color(0xFFE0E4E1),
                  ],
            stops: blocked ? null : const [0, .52, 1],
          ).createShader(face));
    pen
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * (highlighted ? .045 : .018)
      ..color = highlighted
          ? GameColors.tileHighlight
          : const Color(0xFF6F8088).withValues(alpha: .55);
    canvas.drawRRect(cap, pen);
    canvas.drawRRect(
        cap.deflate(unit * .027),
        pen
          ..strokeWidth = unit * .024
          ..color = Colors.white.withValues(alpha: blocked ? .25 : .88));
  }

  @override
  bool shouldRepaint(TileFacePainter old) =>
      blocked != old.blocked ||
      highlighted != old.highlighted ||
      pressed != old.pressed ||
      depth != old.depth ||
      trayBlend != old.trayBlend;
}

/// Original theme glyphs rendered as coloured, outlined enamel emblems. Text
/// here is an icon-font shape, not a label; GameTileWidget owns accessible names.
class TileSymbol extends StatelessWidget {
  const TileSymbol({super.key, required this.art, required this.blocked});
  final TileArt art;
  final bool blocked;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: LayoutBuilder(builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          final color = blocked
              ? Color.lerp(art.color, const Color(0xFF657D83), .45)!
              : art.color;
          final outline = Color.lerp(color, const Color(0xFF243644), .62)!;
          final style = TextStyle(
              fontFamily: art.icon.fontFamily,
              package: art.icon.fontPackage,
              fontSize: side,
              height: 1,
              fontWeight: FontWeight.normal);
          Widget glyph(Paint paint, {List<Shadow>? shadows}) => Text(
                String.fromCharCode(art.icon.codePoint),
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.noScaling,
                style: style.copyWith(foreground: paint, shadows: shadows),
              );
          return FittedBox(
            child: Stack(children: [
              glyph(
                  Paint()
                    ..color = outline
                    ..style = PaintingStyle.stroke
                    ..strokeJoin = StrokeJoin.round
                    ..strokeWidth = side * .045,
                  shadows: [
                    Shadow(
                        color: outline.withValues(alpha: .3),
                        offset: Offset(0, side * .035)),
                  ]),
              glyph(Paint()
                ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(color, Colors.white, .30)!,
                    color,
                    Color.lerp(color, Colors.black, .24)!,
                  ],
                  stops: const [0, .38, 1],
                ).createShader(Rect.fromLTWH(0, 0, side, side))),
            ]),
          );
        }),
      );
}
