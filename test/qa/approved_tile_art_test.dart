import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/core/tile_body_geometry.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/presentation/theme/world_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_face.dart';
import 'package:triple_tile_adventure/presentation/widgets/globe_tile_symbol.dart';

import 'support/tile_asset_images.dart';

// Absolute logical pixels: permits double rounding from seventh-width slots
// and centered Rect edges, while rejecting even a 0.000001-pixel size error.
const _geometryTolerance = 1e-9;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const names = [
    'monstera',
    'palm',
    'lotus',
    'chili',
    'kiwi',
    'paper_roll',
    'sack',
    'mitten',
    'lightning',
    'chick',
    'carrot',
    'leaf',
    'golden_x2',
  ];

  for (final name in names) {
    test('$name is a registered square PNG with transparent sheet corners',
        () async {
      final bytes = await rootBundle.load('assets/tiles/approved/$name.png');
      final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      try {
        expect(codec.frameCount, 1);
        final frame = await codec.getNextFrame();
        try {
          expect(frame.image.width, 320);
          expect(frame.image.height, 320);
          final rgba = (await frame.image.toByteData())!;
          int alpha(int x, int y) => rgba.getUint8((y * 320 + x) * 4 + 3);
          for (final point in [(0, 0), (319, 0), (0, 319), (319, 319)]) {
            expect(alpha(point.$1, point.$2), 0);
          }
          expect(alpha(160, 160), 255,
              reason: 'Removing the white sheet must not erase the tile.');
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    });
  }

  test('art mapping preserves saved IDs and distinct symbols within a world',
      () {
    const ids = [
      'apple',
      'banana',
      'berry',
      'carrot',
      'star',
      'shell',
      'flower',
      'moon',
      'gem',
      'leaf',
      'candy',
      'heart',
      'sun',
      'drop',
      'clover',
    ];
    for (final catalog in [
      tileCatalog,
      for (final theme in TileVisualTheme.values) tileCatalogForTheme(theme),
    ]) {
      expect(catalog.keys, orderedEquals(ids));
      final paths =
          catalog.values.map((art) => art.assetPath).whereType<String>();
      expect(paths.toSet().length, paths.length,
          reason: 'Different match IDs must not share an identical sprite.');
      for (final path in paths) {
        expect(names.map((name) => 'assets/tiles/approved/$name.png'),
            contains(path));
        expect(path, isNot(contains('golden_x2')),
            reason: 'No existing tile has an x2 reward mechanic.');
      }
    }
    const mapping = {
      'apple': ('kiwi', 'Kiwi'),
      'banana': ('palm', 'Palm'),
      'berry': ('chili', 'Chili'),
      'carrot': ('carrot', 'Carrot'),
      'star': ('lightning', 'Lightning'),
      'shell': ('paper_roll', 'Paper Roll'),
      'flower': ('lotus', 'Lotus'),
      'moon': ('mitten', 'Mitten'),
      'gem': ('sack', 'Burlap Sack'),
      'leaf': ('leaf', 'Leaf'),
      'candy': ('chick', 'Chick'),
      'heart': ('monstera', 'Monstera'),
    };
    expect(TileBodyGeometry.illustratedTypes, unorderedEquals(mapping.keys),
        reason: 'Coverage footprints must follow the actual PNG-backed IDs.');
    for (final theme in TileVisualTheme.values) {
      final catalog = tileCatalogForTheme(theme);
      expect(
          catalog.values.where((art) => art.assetPath != null), hasLength(12));
      for (final entry in mapping.entries) {
        final art = catalog[entry.key]!;
        expect(art.assetPath, 'assets/tiles/approved/${entry.value.$1}.png');
        expect(art, same(tileCatalog[entry.key]),
            reason:
                'Board, preview and default catalogs share the approved set.');
        expect(tileLabelForTheme(theme, entry.key), entry.value.$2);
      }
      for (final id in ['sun', 'drop', 'clover']) {
        expect(catalog[id]!.assetPath, isNull);
        expect(tileLabelForTheme(theme, id), isNotEmpty);
      }
      expect(catalog.values.map((art) => art.label).toSet(), hasLength(15),
          reason:
              'Every selectable type must also have a distinct spoken name.');
    }
  });

  test('active Lagoon ocean paint is saturated and only coverage mutes it',
      () async {
    Future<List<int>> paintedPixel(bool blocked,
        {int x = 80, int y = 60}) async {
      final recorder = ui.PictureRecorder();
      GlobeTilePainter(blocked: blocked)
          .paint(ui.Canvas(recorder), const Size(100, 100));
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(100, 100);
        try {
          final bytes = (await image.toByteData())!;
          final offset = (y * 100 + x) * 4;
          return List.generate(4, (i) => bytes.getUint8(offset + i));
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    }

    // Clear ocean to the right of the continents, away from edge AA.
    final active = await paintedPixel(false);
    final covered = await paintedPixel(true);
    expect(active[3], 255);
    expect(covered[3], 255);
    expect(active[2] - active[0], greaterThan(100),
        reason: 'Active ocean must be vivid blue, not a grey disabled glyph.');
    expect(active[2] - active[0], greaterThan(covered[2] - covered[0] + 20));
    // Below the sphere and its outline, inside only the cast shadow. Making
    // the ocean opaque must not make this separate decorative layer opaque.
    for (final blocked in [false, true]) {
      final shadow = await paintedPixel(blocked, x: 50, y: 93);
      expect(shadow[3], 0x33);
    }
  });

  testWidgets('Ocean Lagoon retains its identity and has a bright active globe',
      (tester) async {
    final art = tileCatalogForTheme(TileVisualTheme.ocean)['sun']!;
    expect(art.label, 'Lagoon');
    expect(art.icon, Icons.public_rounded);
    expect(art.assetPath, isNull);
    expect(art.hasIllustratedSymbol, isTrue);
    final semantics = tester.ensureSemantics();
    try {
      for (final blocked in [false, true]) {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Center(
                    child: SizedBox(
          width: 60,
          height: 60,
          child: GameTileWidget(
            tile: const Tile(id: 'globe', type: 'sun', x: 0, y: 0, layer: 0),
            catalog: tileCatalogForTheme(TileVisualTheme.ocean),
            enabled: !blocked,
            blocked: blocked,
            highlighted: false,
            onTap: () {},
          ),
        )))));
        await tester.pumpAndSettle();
        final painted = find.descendant(
            of: find.byType(TileSymbol),
            matching: find.byWidgetPredicate((widget) =>
                widget is CustomPaint && widget.painter is GlobeTilePainter));
        expect(painted, findsOneWidget);
        expect(
            (tester.widget<CustomPaint>(painted).painter! as GlobeTilePainter)
                .blocked,
            blocked);
        expect(
            tester
                .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
                .opacity,
            blocked ? .86 : 1);
        expect(
            tester.getSemantics(find.bySemanticsLabel('Lagoon')),
            matchesSemantics(
                label: 'Lagoon',
                hint: blocked ? 'Covered tile' : '',
                isButton: true,
                hasEnabledState: true,
                isEnabled: !blocked,
                hasTapAction: !blocked));
        final bounds = tester.getRect(painted);
        expect(bounds.width, greaterThan(40));
        expect(bounds.height, closeTo(bounds.width, _geometryTolerance));
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  for (final scenario in [
    // Authored 4% logical overlaps remain blocking even in transparent artwork
    // margins. Below-threshold and merely touching tiles remain fully active.
    (name: 'logical-margin', offset: const Offset(48, 0), covered: true),
    (name: 'logical-corner', offset: const Offset(40, 40), covered: true),
    (name: 'body-covered', offset: const Offset(30, 0), covered: true),
    (name: 'sub-threshold-edge', offset: const Offset(49, 0), covered: false),
    (
      name: 'sub-threshold-corner',
      offset: const Offset(42, 42),
      covered: false
    ),
    (name: 'touching-edge', offset: const Offset(50, 0), covered: false),
  ]) {
    testWidgets('${scenario.name}: PNG tint agrees with actual selectability',
        (tester) async {
      const board = Size(1000, 1000);
      const tileSize = Size(50, 50);
      const lower = Tile(id: 'lower', type: 'apple', x: 0, y: 0, layer: 0);
      final upper = Tile(
          id: 'upper',
          type: 'berry',
          x: scenario.offset.dx / board.width,
          y: scenario.offset.dy / board.height,
          layer: 1);
      final engine = GameEngine([lower, upper])
        ..updateBoardGeometry(board, tileSize);
      final covered = engine.isTileCovered(lower);
      expect(covered, scenario.covered);
      var accepted = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
        width: 50,
        height: 50,
        child: GameTileWidget(
            tile: lower,
            enabled: !covered,
            blocked: covered,
            highlighted: false,
            onTap: () => accepted = engine.tapTile(lower.id, board, tileSize)),
      )))));
      await loadVisibleTileImages(tester);
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.color, covered ? const Color(0xFF9DAFB5) : null);
      expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          covered ? .86 : 1);
      await tester.tap(find.byType(GameTileWidget));
      await tester.pumpAndSettle();
      expect(accepted, !covered);
      expect(engine.tray, covered ? isEmpty : equals([lower.id]));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('approved tile preserves named controls, hint and covered state',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    try {
      for (final blocked in [false, true]) {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Center(
                    child: SizedBox(
          width: 60,
          height: 60,
          child: GameTileWidget(
            tile: const Tile(id: 'leaf', type: 'leaf', x: 0, y: 0, layer: 0),
            catalog: tileCatalogForTheme(TileVisualTheme.garden),
            enabled: !blocked,
            blocked: blocked,
            highlighted: true,
            onTap: () => taps++,
          ),
        )))));
        await loadVisibleTileImages(tester);
        await tester.pumpAndSettle();
        expect(
            tester.getSemantics(find.bySemanticsLabel('Leaf')),
            matchesSemantics(
              label: 'Leaf',
              hint: blocked ? 'Covered tile' : '',
              isButton: true,
              hasEnabledState: true,
              isEnabled: !blocked,
              hasTapAction: !blocked,
            ));
        final outline = find.descendant(
            of: find.byType(TileFace),
            matching: find.byWidgetPredicate((widget) =>
                widget is CustomPaint && widget.foregroundPainter != null));
        expect(outline, findsOneWidget,
            reason: 'Hints must remain visible above the approved sprite.');
        await tester.tap(find.byType(GameTileWidget));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  for (final viewport in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 915)
  ]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('seven approved tray tiles fit $viewport / $scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport;
        try {
          await tester.pumpWidget(MaterialApp(
              home: MediaQuery(
            data: MediaQueryData(
                size: viewport,
                textScaler: TextScaler.linear(scale),
                disableAnimations: true),
            child: Scaffold(
                body: Center(
                    child: GameTray(
              trayTiles: [
                for (var i = 0; i < 7; i++)
                  Tile(id: 'slot$i', type: 'carrot', x: 0, y: 0, layer: 0)
              ],
              catalog: tileCatalog,
              worldTheme: WorldThemes.garden,
            ))),
          )));
          await loadVisibleTileImages(tester);
          await tester.pumpAndSettle();
          expect(find.byType(GameTileWidget), findsNWidgets(7));
          Rect? previous;
          for (var i = 0; i < 7; i++) {
            final tile = find.byKey(ValueKey('tray_slot$i'));
            final slot = tester.getRect(tile);
            expect(
                slot.width, closeTo((viewport.width - 62) / 7 - 4.5, .00001));
            expect(slot.left, greaterThanOrEqualTo(0));
            expect(slot.right, lessThanOrEqualTo(viewport.width));
            if (previous != null) {
              expect(slot.left, greaterThan(previous.right));
            }
            final symbol = tester.getRect(
                find.descendant(of: tile, matching: find.byType(TileSymbol)));
            expect(symbol.width, closeTo(slot.width, .00001));
            expect(symbol.height, closeTo(symbol.width, _geometryTolerance),
                reason: 'Approved artwork must remain square in every slot.');
            expect(symbol.top, greaterThanOrEqualTo(slot.top));
            expect(symbol.bottom, lessThanOrEqualTo(slot.bottom));
            previous = slot;
          }
          expect(tester.takeException(), isNull);
          expect(tester.binding.transientCallbackCount, 0);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      });
    }
  }
}
