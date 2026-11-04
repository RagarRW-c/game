import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_effects.dart';

Future<Uint8List> _raster(CustomPainter painter, Size size, int dpr) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(dpr.toDouble());
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
      (size.width * dpr).round(), (size.height * dpr).round());
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return Uint8List.fromList(data.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void _expectLocalInk(Uint8List pixels, Size size, int dpr, List<Rect> regions) {
  final width = (size.width * dpr).round();
  var ink = 0;
  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i + 3] == 0) continue;
    ink++;
    final index = i ~/ 4;
    final point =
        Offset((index % width + .5) / dpr, (index ~/ width + .5) / dpr);
    expect(regions.any((rect) => rect.contains(point)), isTrue,
        reason: 'Effect leaked into a neighboring slot at $point (DPR $dpr)');
  }
  expect(ink, greaterThan(0),
      reason: 'A clipping assertion must not pass on blank paint');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final dpr in [1, 3]) {
    for (final side in [19.0, 24.0, 32.0, 45.0]) {
      test('match $side px DPR $dpr: light/particles stay inside their faces',
          () async {
        final size = Size(side * 3 + 32, side + 16);
        final rects = [
          for (var i = 0; i < 3; i++)
            Rect.fromLTWH(8 + i * (side + 8), 8, side, side)
        ];
        final burst = TrayBurst(1, rects, -1);
        // Compression light and two particle phases, including late fading.
        for (final progress in [50 / 640, .3, .8]) {
          final pixels =
              await _raster(MatchBurstPainter(burst, progress), size, dpr);
          _expectLocalInk(pixels, size, dpr, rects);
          if (progress == 50 / 640) {
            // The center carries only a translucent warm wash, not the old
            // near-opaque white flash. Edges can retain stronger contrast.
            final width = (size.width * dpr).round();
            for (final rect in rects) {
              final index = ((rect.center.dy * dpr).floor() * width +
                      (rect.center.dx * dpr).floor()) *
                  4;
              expect(pixels[index + 3], inInclusiveRange(1, 46));
            }
          }
        }
        final settled = await _raster(MatchBurstPainter(burst, 1), size, dpr);
        expect(settled.every((channel) => channel == 0), isTrue);
      });

      for (final kind in BoardCueKind.values) {
        test('$kind $side px DPR $dpr: local cue has contrast and settles',
            () async {
          final rect = Rect.fromLTWH(0, 0, side, side);
          final cue = BoardCue(1, kind, [rect]);
          final pixels =
              await _raster(BoardCuePainter(cue, .5), rect.size, dpr);
          _expectLocalInk(pixels, rect.size, dpr, [rect]);
          expect(
              [for (var i = 3; i < pixels.length; i += 4) pixels[i]]
                  .any((alpha) => alpha >= 128),
              isTrue,
              reason: 'The peripheral cue must have a visible stroke');
          // No overlay obscures the central symbol.
          final width = (side * dpr).round();
          final center = (width ~/ 2 * width + width ~/ 2) * 4;
          expect(pixels[center + 3], 0);
          final settled =
              await _raster(BoardCuePainter(cue, 1), rect.size, dpr);
          expect(settled.every((channel) => channel == 0), isTrue);
        });
      }
    }
  }

  test(
      'accepted pickup has first-frame light without extending flight duration',
      () async {
    const source = TileFlightSource(
        Tile(id: 'a', type: 'apple', x: 0, y: 0, layer: 0),
        Rect.fromLTWH(10, 10, 45, 45),
        tileCatalog,
        1,
        Size(45, 45));
    const flight =
        TileFlight(1, source, Rect.fromLTWH(80, 80, 25, 50), 0, false);
    final pixels = await _raster(
        const FlightAccentPainter(flight, 0), const Size(120, 140), 1);
    _expectLocalInk(pixels, const Size(120, 140), 1, [source.rect.inflate(3)]);
    expect(TileFlight.duration, const Duration(milliseconds: 440));
    expect(flight.rectAt(0), source.rect);
    expect(flight.rectAt(1), flight.target);
  });

  for (final blocked in [false, true]) {
    for (final reduced in [false, true]) {
      testWidgets(
          'blocked=$blocked reduced=$reduced: press stays subtle and never accepts early',
          (tester) async {
        var accepted = 0;
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
              child: SizedBox(
                  width: 45,
                  height: 45,
                  child: GameTileWidget(
                      tile: const Tile(
                          id: 'press', type: 'apple', x: 0, y: 0, layer: 0),
                      enabled: true,
                      blocked: blocked,
                      highlighted: false,
                      onTap: () => accepted++))),
        )));
        final tile = find.byType(GameTileWidget);
        final gesture = await tester.startGesture(tester.getCenter(tile));
        // Resolve the gesture's standard tap-down deadline, then the explicit
        // 55 ms press clock. These are virtual test frames, not wall sleeps.
        await tester.pump(kPressTimeout);
        await tester.pump(const Duration(milliseconds: 55));
        final transform = tester.widget<Transform>(
            find.descendant(of: tile, matching: find.byType(Transform)).first);
        expect(transform.transform.storage[0],
            closeTo(blocked || reduced ? 1 : .96, 1e-6));
        expect(accepted, 0);
        await gesture.up();
        expect(accepted, blocked ? 0 : 1);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
