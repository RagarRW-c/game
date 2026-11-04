import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_face.dart';

import 'support/tile_asset_images.dart';

// Frozen pre-adaptation paint recipe. This is not a replacement Golden: it
// protects the already-reviewed larger cue without accepting new screenshots.
class _ApprovedLock extends CustomPainter {
  const _ApprovedLock();

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final body = TileFacePainter.bodyRect(size);
    canvas.drawRRect(body, Paint()..color = const Color(0x59304450));
    final center = Offset(body.center.dx, body.top + body.height * .78);
    canvas.drawCircle(
        center, unit * .14, Paint()..color = const Color(0xFF304450));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: center - Offset(0, unit * .035),
                width: unit * .10,
                height: unit * .11),
            Radius.circular(unit * .045)),
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
  bool shouldRepaint(_ApprovedLock oldDelegate) => false;
}

Future<List<int>> _pixels(WidgetTester tester, Finder boundary) async =>
    (await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(boundary)
          .toImage(pixelRatio: 1);
      try {
        return (await image.toByteData())!.buffer.asUint8List().toList();
      } finally {
        image.dispose();
      }
    }))!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final side in [32, 45, 48, 68]) {
    test('$side px: blocked cue is opaque, legible and inside the body',
        () async {
      final size = Size.square(side.toDouble());
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRRect(
          TileFacePainter.bodyRect(size), Paint()..color = Colors.white);
      const BlockedTileOverlayPainter().paint(canvas, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(side, side);
      try {
        final bytes = (await image.toByteData())!;
        List<int> pixel(int x, int y) =>
            List.generate(4, (c) => bytes.getUint8((y * side + x) * 4 + c));
        expect(pixel(0, 0)[3], 0,
            reason: 'Do not fill transparent corners or enlarge the tile.');
        final surface = pixel(side ~/ 2, (side * .3).floor());
        expect(surface[3], 255,
            reason: 'Lower-layer symbols must not show through blocked tiles.');
        expect(surface.take(3), everyElement(lessThan(205)),
            reason: 'A visible scrim must distinguish the blocked surface.');
        var whiteGlyphPixels = 0;
        var darkBadgePixels = 0;
        for (var y = (side * .62).ceil(); y < (side * .9).floor(); y++) {
          for (var x = (side * .36).ceil(); x < (side * .64).floor(); x++) {
            final p = pixel(x, y);
            if (p.take(3).every((c) => c > 245)) whiteGlyphPixels++;
            if (p.take(3).every((c) => c < 100)) darkBadgePixels++;
          }
        }
        expect(whiteGlyphPixels, greaterThan(3),
            reason: 'The lock must survive at the smallest scaled board size.');
        expect(darkBadgePixels, greaterThan(15));
      } finally {
        image.dispose();
        picture.dispose();
      }
    });
  }

  for (final dpr in [1.0, 3.0]) {
    testWidgets('FittedBox cue uses screen size, not local size or DPR=$dpr',
        (tester) async {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(320 * dpr, 568 * dpr);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const boundary = ValueKey('scaled-cue');
      const referenceBoundary = ValueKey('approved-scaled-cue');
      var taps = 0;
      // Retain exactly the same tile widget while only the ancestor scale
      // changes: catches stale paint cached inside AnimatedOpacity's layer.
      final tile = GameTileWidget(
          tile: const Tile(id: 'sun', type: 'sun', x: 0, y: 0, layer: 0),
          enabled: false,
          blocked: true,
          highlighted: false,
          onTap: () => taps++);
      for (final side in [45.0, 19.0, 24.0, 32.0, 45.0]) {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(
              key: boundary,
              child: SizedBox.square(
                  dimension: side,
                  child: FittedBox(
                      child: SizedBox.square(dimension: 51.2, child: tile)))),
          const SizedBox(width: 8),
          RepaintBoundary(
              key: referenceBoundary,
              child: SizedBox.square(
                  dimension: side,
                  child: FittedBox(
                      child: SizedBox.square(
                          dimension: 51.2,
                          child: AnimatedOpacity(
                              opacity: 1,
                              duration: Duration.zero,
                              child: CustomPaint(
                                  foregroundPainter: const _ApprovedLock(),
                                  child: TileFace(
                                      art: tileCatalog['sun']!,
                                      blocked: true,
                                      highlighted: false,
                                      pressed: false,
                                      depth: 1,
                                      trayBlend: 0))))))),
        ])))));
        await tester.pumpAndSettle();
        final cue = find.byWidgetPredicate((w) =>
            w is CustomPaint &&
            w.foregroundPainter is BlockedTileOverlayPainter);
        final render = tester.renderObject<RenderCustomPaint>(cue);
        final painter = render.foregroundPainter! as BlockedTileOverlayPainter;
        expect(render.size, const Size(51.2, 51.2));
        expect(painter.renderedSide!(), closeTo(side, 1e-9));
        final bytes = await _pixels(tester, find.byKey(boundary));
        final width = side.toInt();
        if (side < 28) {
          // The bar must resolve as a horizontal shape, not the previous dot.
          final points = <Offset>[];
          for (var y = (side * .62).floor(); y < (side * .9).ceil(); y++) {
            for (var x = (side * .25).floor(); x < (side * .75).ceil(); x++) {
              final i = (y * width + x) * 4;
              if (bytes[i] > 225 && bytes[i + 1] > 225 && bytes[i + 2] > 225) {
                points.add(Offset(x.toDouble(), y.toDouble()));
              }
            }
          }
          expect(points, isNotEmpty);
          final xs = points.map((p) => p.dx).toList()..sort();
          final ys = points.map((p) => p.dy).toList()..sort();
          expect(xs.last - xs.first + 1, greaterThanOrEqualTo(5));
          expect(ys.last - ys.first + 1, lessThanOrEqualTo(2));
          expect(painter.hitTest(Offset.zero), isFalse);
        } else {
          expect(bytes, await _pixels(tester, find.byKey(referenceBoundary)),
              reason: 'Moving the cue outside retained opacity must not alter '
                  'the approved larger-size composited pixels.');
        }
        await tester.tap(find.byType(GameTileWidget));
        expect(taps, 0);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final side in [19, 24, 29, 32, 45]) {
    testWidgets('$side px: tiny cue stays peripheral; larger cue stays exact',
        (tester) async {
      const boundary = ValueKey('reference-cue');
      Future<List<int>> capture(CustomPainter painter) async {
        await tester.pumpWidget(Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
                child: RepaintBoundary(
                    key: boundary,
                    child: SizedBox.square(
                        dimension: side.toDouble(),
                        child: CustomPaint(
                            foregroundPainter: painter,
                            child: const ColoredBox(
                                color: Colors.transparent)))))));
        await tester.pump();
        return _pixels(tester, find.byKey(boundary));
      }

      final approved = await capture(const _ApprovedLock());
      final current = await capture(const BlockedTileOverlayPainter());
      if (side >= 28) {
        expect(current, approved,
            reason: 'The reviewed lock must remain pixel-identical.');
      } else {
        expect(current, isNot(approved));
        final body = TileFacePainter.bodyRect(Size.square(side.toDouble()));
        final symbolCore =
            Rect.fromLTRB(side * .25, side * .25, side * .75, side * .58);
        var centralSamples = 0;
        for (var y = 0; y < side; y++) {
          for (var x = 0; x < side; x++) {
            final i = (y * side + x) * 4;
            // Compare whole pixel footprints inside the protected symbol core,
            // not just their top-left coordinates. At 19px, row 11 starts
            // before .58 * 19 = 11.02 but spans [11,12): it catches the old
            // lock's antialiased circle (top=11.6624), outside this core.
            // That intentional peripheral change is not symbol obstruction.
            if (x >= symbolCore.left &&
                x + 1 <= symbolCore.right &&
                y >= symbolCore.top &&
                y + 1 <= symbolCore.bottom) {
              centralSamples++;
              expect(current.sublist(i, i + 4), approved.sublist(i, i + 4),
                  reason: '$side px: symbol-core pixel ($x,$y) must retain '
                      'the exact existing scrim, without marker or border.');
            }
            if (!body.inflate(1).contains(Offset(x + .5, y + .5))) {
              expect(current[i + 3], 0,
                  reason: 'No cue outside the resting body.');
            }
          }
        }
        expect(centralSamples, greaterThanOrEqualTo(side * side * .14),
            reason: 'Protect a substantial symbol area, not a token pixel '
                '(54 whole pixels at 19px; 84 at 24px).');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final type in ['leaf', 'shell', 'sun', 'drop']) {
    for (final side in [19.0, 24.0, 48.0]) {
      testWidgets('$type at $side px: blocked cue disappears on uncovering',
          (tester) async {
        const boundaryKey = ValueKey('painted-tile');
        var taps = 0;
        Future<void> show(bool blocked, {bool tray = false}) async {
          await tester.pumpWidget(MaterialApp(
              home: Scaffold(
                  body: Center(
                      child: RepaintBoundary(
                          key: boundaryKey,
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: GameTileWidget(
                              tile: Tile(
                                  id: type, type: type, x: 0, y: 0, layer: 0),
                              catalog:
                                  tileCatalogForTheme(TileVisualTheme.garden),
                              enabled: !blocked,
                              blocked: blocked,
                              trayTile: tray,
                              highlighted: true, // A stale hint must not win.
                              onTap: () => taps++,
                            ),
                          ))))));
          await loadVisibleTileImages(tester);
          await tester.pump();
        }

        // Inspect the actual composited PNG/procedural widget, not just a flag.
        Future<List<int>> badgePixel() => tester.runAsync(() async {
              final boundary = tester
                  .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
              final image = await boundary.toImage(pixelRatio: 1);
              try {
                final bytes = (await image.toByteData())!;
                // Inside the solid bar or larger lock body, away from its edges.
                final x = side ~/ 2;
                final y = side < 28 ? (side * .754).floor() : 37;
                return List.generate(
                    4, (c) => bytes.getUint8((y * side.toInt() + x) * 4 + c));
              } finally {
                image.dispose();
              }
            }).then((value) => value!);

        await show(true);
        expect(await badgePixel(), [255, 255, 255, 255]);
        expect(tester.widget<TileFace>(find.byType(TileFace)).highlighted,
            isFalse);
        await tester.tap(find.byType(GameTileWidget));
        await tester.pump();
        expect(taps, 0);

        await show(false);
        expect(
            find.byWidgetPredicate((widget) =>
                widget is CustomPaint &&
                widget.foregroundPainter is BlockedTileOverlayPainter),
            findsNothing);
        expect(
            tester.widget<TileFace>(find.byType(TileFace)).highlighted, isTrue);
        expect(tester.getSize(find.byType(GameTileWidget)), Size.square(side));
        // Near the body edge, outside the badge: uncovering must retain the
        // existing full resting-body target, not restrict taps to the symbol.
        await tester.tapAt(tester.getTopLeft(find.byType(GameTileWidget)) +
            Offset(side * .875, side * .5));
        await tester.pumpAndSettle();
        expect(taps, 1);
        await show(true, tray: true);
        expect(
            find.byWidgetPredicate((widget) =>
                widget is CustomPaint &&
                widget.foregroundPainter is BlockedTileOverlayPainter),
            findsNothing,
            reason: 'Neither marker nor lock belongs on a tray tile.');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
