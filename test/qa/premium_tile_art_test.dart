import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/globe_tile_symbol.dart';
import 'package:triple_tile_adventure/presentation/widgets/premium_tile_symbol.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_face.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_effects.dart';

// Independent product mapping: neither the renderer nor catalog generates the
// expected result. Labels and saved IDs remain the world's existing identities.
const _worldSymbols = {
  TileVisualTheme.garden: [
    TileIllustration.sun,
    TileIllustration.seeds,
    TileIllustration.clover
  ],
  TileVisualTheme.ocean: [
    TileIllustration.lagoon,
    TileIllustration.starfish,
    TileIllustration.gem
  ],
  TileVisualTheme.candy: [
    TileIllustration.sugar,
    TileIllustration.caramel,
    TileIllustration.wafer
  ],
  TileVisualTheme.space: [
    TileIllustration.asteroids,
    TileIllustration.portal,
    TileIllustration.planet
  ],
  TileVisualTheme.desert: [
    TileIllustration.heat,
    TileIllustration.drop,
    TileIllustration.relic
  ],
  TileVisualTheme.ice: [
    TileIllustration.aurora,
    TileIllustration.icicle,
    TileIllustration.snowball
  ],
  TileVisualTheme.jungle: [
    TileIllustration.sun,
    TileIllustration.river,
    TileIllustration.fern
  ],
  TileVisualTheme.volcano: [
    TileIllustration.sun,
    TileIllustration.drop,
    TileIllustration.flame
  ],
  TileVisualTheme.dream: [
    TileIllustration.dawn,
    TileIllustration.mist,
    TileIllustration.bloom
  ],
  TileVisualTheme.crystal: [
    TileIllustration.sun,
    TileIllustration.drop,
    TileIllustration.amethyst
  ],
};
const _ids = ['sun', 'drop', 'clover'];

CustomPainter _painter(TileArt art, bool blocked) =>
    art.illustration == TileIllustration.lagoon
        ? GlobeTilePainter(blocked: blocked)
        : PremiumTilePainter(
            illustration: art.illustration!,
            color: art.color,
            blocked: blocked);

Future<Uint8List> _pixels(CustomPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), const Size(100, 100));
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(100, 100);
    try {
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      return Uint8List.fromList(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final entry in _worldSymbols.entries) {
    test('${entry.key}: intended distinct illustrations paint opaque color',
        () async {
      final catalog = tileCatalogForTheme(entry.key);
      final rendered = <Uint8List>[];
      for (var index = 0; index < _ids.length; index++) {
        final art = catalog[_ids[index]]!;
        expect(art.illustration, entry.value[index]);
        expect(art.assetPath, isNull);
        expect(art.hasIllustratedSymbol, isTrue);
        final active = await _pixels(_painter(art, false));
        final covered = await _pixels(_painter(art, true));
        expect(covered, isNot(orderedEquals(active)),
            reason: '${_ids[index]} must visibly distinguish coverage.');
        for (final pixels in [active, covered]) {
          var opaque = 0;
          var colorful = 0;
          for (var offset = 0; offset < pixels.length; offset += 4) {
            if (pixels[offset + 3] == 255) {
              opaque++;
              final rgb = pixels.sublist(offset, offset + 3)..sort();
              if (rgb.last - rgb.first > 12) colorful++;
            }
          }
          expect(opaque, greaterThan(300),
              reason:
                  'Solid illustration bodies must not inherit shadow alpha.');
          expect(colorful, greaterThan(100),
              reason: 'Coverage mutes color without erasing symbol identity.');
          for (final (x, y) in [(0, 0), (99, 0), (0, 99), (99, 99)]) {
            expect(pixels[(y * 100 + x) * 4 + 3], 0,
                reason:
                    'Artwork must stay inside its allocated symbol bounds.');
          }
        }
        for (final previous in rendered) {
          expect(active, isNot(orderedEquals(previous)),
              reason: 'Different saved IDs must not share identical artwork.');
        }
        rendered.add(active);
      }
    });

    testWidgets('${entry.key}: flight retains themed illustration throughout',
        (tester) async {
      final catalog = tileCatalogForTheme(entry.key);
      try {
        for (final id in _ids) {
          final flight = TileFlight(
              1,
              TileFlightSource(
                  Tile(id: id, type: id, x: 0, y: 0, layer: 0),
                  const Rect.fromLTWH(0, 0, 60, 60),
                  catalog,
                  1,
                  const Size(60, 60)),
              const Rect.fromLTWH(0, 200, 30, 48),
              0,
              false);
          for (final progress in [0.0, .5, 1.0]) {
            await tester.pumpWidget(MaterialApp(
                home: Center(
                    child: SizedBox(
                        width: 60,
                        height: 60,
                        child: TileFlightVisual(
                            flight: flight, progress: progress)))));
            await tester.pumpAndSettle();
            final symbol = find.byType(TileSymbol);
            expect(symbol, findsOneWidget);
            expect(tester.widget<TileSymbol>(symbol).art, same(catalog[id]));
            expect(tester.widget<TileSymbol>(symbol).blocked, isFalse);
            expect(find.descendant(of: symbol, matching: find.byType(Text)),
                findsNothing);
            final paint = tester
                .widget<CustomPaint>(find.descendant(
                    of: symbol, matching: find.byType(CustomPaint)))
                .painter!;
            if (catalog[id]!.illustration == TileIllustration.lagoon) {
              expect(paint, isA<GlobeTilePainter>());
            } else {
              expect(paint, isA<PremiumTilePainter>());
              expect((paint as PremiumTilePainter).illustration,
                  catalog[id]!.illustration);
            }
            expect(tester.takeException(), isNull);
          }
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  test('default catalog also resolves every ID without legacy glyphs', () {
    expect(tileCatalog, hasLength(15));
    expect(tileCatalog.values.every((art) => art.hasIllustratedSymbol), isTrue);
    expect(_ids.map((id) => tileCatalog[id]!.illustration),
        [TileIllustration.sun, TileIllustration.drop, TileIllustration.clover]);
  });

  test('ivory cap and bevel stay opaque in active and covered states',
      () async {
    for (final blocked in [false, true]) {
      final pixels = await _pixels(TileFacePainter(
          blocked: blocked,
          highlighted: false,
          pressed: false,
          depth: 1,
          trayBlend: 0));
      for (final y in [50, 93]) {
        expect(pixels[(y * 100 + 50) * 4 + 3], 255,
            reason: 'Tile body must not inherit the contact shadow alpha.');
      }
      if (!blocked) {
        final center =
            pixels.sublist((50 * 100 + 50) * 4, (50 * 100 + 50) * 4 + 3);
        expect(center.every((channel) => channel > 220), isTrue,
            reason: 'Active non-PNG tiles must have a bright ivory face.');
      }
    }
  });
}
