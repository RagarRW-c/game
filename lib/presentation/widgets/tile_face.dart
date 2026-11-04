import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../../core/tile_body_geometry.dart';
import '../theme/game_theme.dart';
import 'globe_tile_symbol.dart';
import 'premium_tile_symbol.dart';

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

  /// Complete sprite remains square even in the narrow, tall tray slots.
  static Rect artworkRect(Size size) => TileBodyGeometry.artworkRect(size);

  @override
  Widget build(BuildContext context) {
    if (art.assetPath != null) {
      return LayoutBuilder(builder: (context, constraints) {
        return Stack(children: [
          Positioned.fromRect(
              rect: artworkRect(constraints.biggest),
              child: CustomPaint(
                  foregroundPainter:
                      highlighted ? const _ApprovedTileHighlight() : null,
                  child: TileSymbol(art: art, blocked: blocked))),
        ]);
      });
    }
    return CustomPaint(
      painter: TileFacePainter(
          blocked: blocked,
          highlighted: highlighted,
          pressed: pressed,
          depth: depth,
          trayBlend: trayBlend),
      child: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        final face = TileFacePainter.faceRect(size);
        // 10.5% larger symbols inside the same measured face/hit rectangle.
        final symbolSize = math.min(face.width, face.height) * .84;
        return Stack(children: [
          Positioned.fromRect(
              rect: Rect.fromCenter(
                  center: face.center, width: symbolSize, height: symbolSize),
              child: TileSymbol(art: art, blocked: blocked)),
        ]);
      }),
    );
  }
}

/// A consistent blocked surface for every world and artwork family. Keep the
/// underlying body opaque: reducing tile opacity would expose lower symbols.
/// Simple paint primitives add no font/asset loading or accessibility node.
/// Tiny fitted tiles use a coarse blocked bar; larger tiles retain the lock.
class BlockedTileOverlayPainter extends CustomPainter {
  const BlockedTileOverlayPainter({this.renderedSide});

  /// Supplied by the render object at paint time, after ancestor FittedBox
  /// transforms. Standalone painter use defaults to unscaled logical pixels.
  final double Function()? renderedSide;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = size.shortestSide;
    final body = TileFacePainter.bodyRect(size);
    canvas.drawRRect(body, Paint()..color = const Color(0x59304450));

    // Lower-center placement keeps the main symbol recognizable. The entire
    // badge stays inside the resting body and follows its normal paint order.
    final center = Offset(body.center.dx, body.top + body.height * .78);
    final screenSide = renderedSide?.call() ?? unit;
    if (screenSide.isFinite && screenSide > 0 && screenSide < 28) {
      // Below ~28px the old lock's shackle/body become a 3-4px white blob.
      // A horizontal blocked marker has no hole or tiny detail to resolve.
      // The six approved captures render at >=29px and keep the lock below.
      final pixel = unit / screenSide;
      // Cap very extreme downscales so the marker always fits inside the body.
      final markerPixel = math.min(pixel, unit / 19);
      final stroke = math.min(pixel * .8, unit * .05);
      canvas.drawRRect(
          body.deflate(stroke / 2),
          Paint()
            ..color = const Color(0xFF304450)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: center,
                  width: markerPixel * 8,
                  height: markerPixel * 3.5),
              Radius.circular(markerPixel * 1.75)),
          Paint()..color = const Color(0xFF304450));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: center,
                  width: markerPixel * 6,
                  height: markerPixel * 2),
              Radius.circular(markerPixel * .5)),
          Paint()..color = Colors.white);
      return;
    }

    // Approved larger-size path: keep its geometry, colors and draw order exact.
    canvas.drawCircle(
        center, unit * .14, Paint()..color = const Color(0xFF304450));
    final shackle = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center - Offset(0, unit * .035),
            width: unit * .10,
            height: unit * .11),
        Radius.circular(unit * .045));
    canvas.drawRRect(
        shackle,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * .022);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx - unit * .08, center.dy - unit * .005,
                unit * .16, unit * .11),
            Radius.circular(unit * .02)),
        Paint()..color = Colors.white);
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(BlockedTileOverlayPainter oldDelegate) =>
      renderedSide != oldDelegate.renderedSide;
}

class _ApprovedTileHighlight extends CustomPainter {
  const _ApprovedTileHighlight();

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    // Matches the common extracted body inside the transparent 320px canvas.
    final body = Rect.fromLTRB(unit * .045, unit * .025,
        size.width - unit * .045, size.height - unit * .04);
    canvas.drawRRect(
        RRect.fromRectAndRadius(body, Radius.circular(unit * .21)),
        Paint()
          ..color = GameColors.tileHighlight
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * .04);
  }

  @override
  bool shouldRepaint(_ApprovedTileHighlight oldDelegate) => false;
}

/// Ivory ceramic cap, a grey lower bevel and a fine recessed outline. No
/// blur filters, clipping layers or per-tile controllers. Used only for symbols
/// not represented in the approved sheet; image tiles already include a body.
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

  /// Presentation bounds shared with the complete PNG bodies. This does not
  /// change the separately defined engine coverage footprints or hit boxes.
  static RRect bodyRect(Size size) => TileBodyGeometry.illustratedBody(size);

  static Rect faceRect(Size size) {
    final body = bodyRect(size).outerRect;
    return Rect.fromLTRB(body.left, body.top, body.right,
        body.bottom - size.shortestSide * .085);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = math.min(size.width, size.height);
    final face = faceRect(size);
    final radius = bodyRect(size).tlRadius;
    final cap = RRect.fromRectAndRadius(face, radius);
    final bounds = bodyRect(size).outerRect;
    final body = RRect.fromRectAndRadius(
        Rect.fromLTRB(
            bounds.left, bounds.top + unit * .06, bounds.right, bounds.bottom),
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
          // The contact shadow's alpha must not tint the opaque tile body.
          ..color = Colors.white
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
    // Keep the outline inside the measured body rather than enlarging it.
    canvas.drawRRect(cap.deflate(pen.strokeWidth / 2), pen);
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

/// Approved sprites or explicit original illustrations for every saved type.
/// The glyph fallback is only for unknown/unconfigured art, not catalog tiles.
/// GameTileWidget (or the preview's label) owns accessible names.
class TileSymbol extends StatelessWidget {
  const TileSymbol({super.key, required this.art, required this.blocked});
  final TileArt art;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final asset = art.assetPath;
    if (asset != null) {
      return Image.asset(asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          gaplessPlayback: true,
          color: blocked ? const Color(0xFF9DAFB5) : null,
          colorBlendMode: BlendMode.modulate);
    }
    if (art.illustration == TileIllustration.lagoon) {
      return ExcludeSemantics(
          child: CustomPaint(painter: GlobeTilePainter(blocked: blocked)));
    }
    final illustration = art.illustration;
    if (illustration != null) {
      return ExcludeSemantics(
          child: CustomPaint(
              painter: PremiumTilePainter(
                  illustration: illustration,
                  color: art.color,
                  blocked: blocked)));
    }
    return ExcludeSemantics(
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
}
