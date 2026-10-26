import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_face.dart';

void main() {
  for (final theme in TileVisualTheme.values) {
    testWidgets('$theme: enamel symbols fit narrow tray and board faces',
        (tester) async {
      final catalog = tileCatalogForTheme(theme);
      for (final size in [
        const Size(24, 60),
        const Size(48, 48),
        const Size(72, 72),
      ]) {
        for (final blocked in [false, true]) {
          await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                  textScaler: TextScaler.linear(2), disableAnimations: true),
              child: Scaffold(
                body: Wrap(children: [
                  for (final entry in catalog.entries)
                    SizedBox(
                      width: size.width,
                      height: size.height,
                      child: GameTileWidget(
                        key: ValueKey(entry.key),
                        tile: Tile(
                            id: entry.key,
                            type: entry.key,
                            x: 0,
                            y: 0,
                            layer: 0),
                        enabled: !blocked,
                        blocked: blocked,
                        highlighted: entry.key == catalog.keys.first,
                        catalog: catalog,
                        trayTile: size.width == 24,
                        onTap: () {},
                      ),
                    ),
                ]),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          for (final entry in catalog.entries) {
            final tile = find.byKey(ValueKey(entry.key));
            expect(tester.getSize(tile), size);
            final symbol =
                find.descendant(of: tile, matching: find.byType(TileSymbol));
            expect(symbol, findsOneWidget);
            expect(tester.widget<TileSymbol>(symbol).art, same(entry.value));
            final visibleFace =
                TileFacePainter.faceRect(size).shift(tester.getTopLeft(tile));
            final bounds = tester.getRect(symbol);
            expect(visibleFace.contains(bounds.topLeft), isTrue);
            expect(visibleFace.contains(bounds.bottomRight), isTrue);
            expect(bounds.width, greaterThan(size.shortestSide * .6));
            expect((bounds.center - visibleFace.center).distance,
                closeTo(0, .000001));
            final face = tester.widget<TileFace>(
                find.descendant(of: tile, matching: find.byType(TileFace)));
            expect(face.blocked, blocked);
            expect(face.highlighted, entry.key == catalog.keys.first);
          }
          expect(tester.takeException(), isNull);
          expect(tester.binding.transientCallbackCount, 0);
        }
      }
    });
  }

  testWidgets('enabled tile sends taps; disabled covered tile does not',
      (tester) async {
    final semantics = tester.ensureSemantics();
    // Flutter verifies outstanding handles before package:test tearDown runs.
    try {
      var taps = 0;
      Future<void> show({required bool covered}) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Center(
                    child: SizedBox(
              width: 60,
              height: 60,
              child: GameTileWidget(
                tile: const Tile(id: 'a', type: 'apple', x: 0, y: 0, layer: 0),
                enabled: !covered,
                blocked: covered,
                highlighted: false,
                onTap: () => taps++,
              ),
            ))),
          ));
      await show(covered: false);
      expect(
          tester.getSemantics(find.bySemanticsLabel('apple')),
          matchesSemantics(
              label: 'apple',
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true));
      await tester.tap(find.byType(GameTileWidget));
      await tester.pumpAndSettle();
      expect(taps, 1);
      await show(covered: true);
      expect(
          tester.getSemantics(find.bySemanticsLabel('apple')),
          matchesSemantics(
              label: 'apple',
              hint: 'Covered tile',
              isButton: true,
              hasEnabledState: true,
              isEnabled: false));
      await tester.tap(find.byType(GameTileWidget));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
