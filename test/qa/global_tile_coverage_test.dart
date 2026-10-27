import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/core/tile_body_geometry.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/endless_board_generator.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/endless_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';
import 'package:triple_tile_adventure/presentation/widgets/globe_tile_symbol.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_effects.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_face.dart';

import 'support/geometry.dart';
import 'support/tile_asset_images.dart';

// Three complete triples. Two blockers cover base; removing only the top
// blocker must not expose base. All types, including the world-specific sun,
// retain their real saved IDs. Keep this order deliberately unsorted by layer.
const _tiles = [
  Tile(id: 'base', type: 'apple', x: .1, y: .1, layer: 0),
  Tile(id: 'cover', type: 'berry', x: .1, y: .1, layer: 2),
  Tile(id: 'middle', type: 'sun', x: .1, y: .1, layer: 1),
  Tile(id: 'berry1', type: 'berry', x: .4, y: .1, layer: 0),
  Tile(id: 'berry2', type: 'berry', x: .7, y: .1, layer: 0),
  Tile(id: 'sun1', type: 'sun', x: .4, y: .4, layer: 0),
  Tile(id: 'sun2', type: 'sun', x: .7, y: .4, layer: 0),
  Tile(id: 'apple1', type: 'apple', x: .1, y: .7, layer: 0),
  Tile(id: 'apple2', type: 'apple', x: .4, y: .7, layer: 0),
];

class _Levels extends LevelRepository {
  @override
  Future<LevelDefinition> loadLevel(int level) async => LevelDefinition(
      level: level,
      name: 'Coverage fixture',
      timeBonusSeconds: 60,
      tiles: _tiles);
}

class _Boards extends EndlessBoardGenerator {
  final List<TileVisualTheme> themes = [];
  @override
  List<Tile> generate({required int round, required TileVisualTheme theme}) {
    themes.add(theme);
    return List.of(_tiles);
  }
}

class _Audio implements GameAudioService {
  @override
  bool sfxEnabled = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Progress extends ProgressRepository {
  @override
  Future<List<PendingAchievementPopup>>
      consumePendingAchievementPopups() async {
    await super.consumePendingAchievementPopups();
    return [];
  }
}

Finder _board([String? id]) => find.byWidgetPredicate((widget) =>
    widget is GameTileWidget &&
    !widget.trayTile &&
    (id == null || widget.tile.id == id));

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
  expect(tester.takeException(), isNull);
}

void _expectBoard(WidgetTester tester, GameEngine oracle, TileVisualTheme theme,
    {required Set<String> covered}) {
  final widgets = tester.widgetList<GameTileWidget>(_board()).toList();
  expect(widgets.map((widget) => widget.tile.id),
      orderedEquals(oracle.renderedBoardTiles.map((tile) => tile.id)));
  for (final widget in widgets) {
    final expected = covered.contains(widget.tile.id);
    final tile = _board(widget.tile.id);
    expect(oracle.isTileCovered(widget.tile), expected, reason: widget.tile.id);
    expect(widget.blocked, expected, reason: widget.tile.id);
    expect(widget.enabled, !expected, reason: widget.tile.id);
    expect(widget.onTap == null, expected, reason: widget.tile.id);
    expect(widget.catalog, same(tileCatalogForTheme(theme)));
    final ignored = tester.widget<IgnorePointer>(
        find.ancestor(of: tile, matching: find.byType(IgnorePointer)).first);
    expect(ignored.ignoring, expected);
    final face = tester.widget<TileFace>(
        find.descendant(of: tile, matching: find.byType(TileFace)));
    expect(face.blocked, expected);
    final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(of: tile, matching: find.byType(AnimatedOpacity)));
    expect(opacity.opacity, expected ? .86 : 1,
        reason: 'Settled uncovered tiles must use the full active appearance.');
    if (face.art.assetPath != null) {
      final image = tester.widget<Image>(
          find.descendant(of: tile, matching: find.byType(Image)));
      expect(image.color, expected ? const Color(0xFF9DAFB5) : null);
    }
  }
  final tray = tester.widget<GameTray>(find.byType(GameTray));
  expect(tray.trayTiles, hasLength(GameEngine.trayLimit));
  expect(tray.trayTiles.whereType<Tile>().map((tile) => tile.id), oracle.tray);
}

void main() {
  test('Lagoon globe is restricted to Ocean sun, not the shared sun ID', () {
    for (final theme in TileVisualTheme.values) {
      expect(tileCatalogForTheme(theme).keys, orderedEquals(tileCatalog.keys));
      expect(tileCatalogForTheme(theme), hasLength(15));
      for (final entry in tileCatalogForTheme(theme).entries) {
        expect(TileBodyGeometry.illustratedTypes.contains(entry.key),
            entry.value.assetPath != null,
            reason:
                '$theme / ${entry.key}: coverage must use the rendered body');
        expect(entry.value.icon == Icons.public_rounded,
            theme == TileVisualTheme.ocean && entry.key == 'sun',
            reason: '$theme / ${entry.key}');
        expect(entry.value.illustration == TileIllustration.lagoon,
            theme == TileVisualTheme.ocean && entry.key == 'sun');
        expect(entry.value.hasIllustratedSymbol, isTrue);
        if (entry.key == 'sun') {
          expect(entry.value.assetPath, isNull);
          expect(entry.value.illustration, isNotNull);
        }
      }
    }
  });

  for (final side in [50.0, 57.6, 65.92, 70.0]) {
    test(
        'every saved type retains logical partial blocking and 3% policy at $side px',
        () {
      const board = Size(412, 915);
      final size = Size.square(side);
      for (final firstType in tileCatalog.keys) {
        for (final secondType in ['berry', 'drop']) {
          final base = Tile(id: 'a', type: firstType, x: .1, y: .1, layer: 0);
          Tile shifted(double x, double y) => Tile(
              id: 'b',
              type: secondType,
              x: .1 + x * side / board.width,
              y: .1 + y * side / board.height,
              layer: 1);
          expect(base.overlaps(shifted(0, 0), board, size), isTrue);
          expect(base.overlaps(shifted(.65, 0), board, size), isTrue);
          expect(base.overlaps(shifted(.74, .74), board, size), isTrue,
              reason:
                  'A small but qualifying partial overlap remains blocked.');
          expect(base.overlaps(shifted(.96, 0), board, size), isTrue,
              reason: 'PNG margins cannot erase a 4% layer dependency.');
          expect(base.overlaps(shifted(.8, .8), board, size), isTrue);
          expect(base.overlaps(shifted(.98, 0), board, size), isFalse);
          expect(base.overlaps(shifted(.84, .84), board, size), isFalse);
          expect(base.overlaps(shifted(1, 0), board, size), isFalse);

          // Rendering still fits inside the unchanged logical footprint. It
          // must not redefine the authored dependency graph in either direction.
          final body = TileBodyGeometry.bodyFor(firstType, size).outerRect;
          expect(body.left, greaterThanOrEqualTo(0));
          expect(body.top, greaterThanOrEqualTo(0));
          expect(body.right, lessThanOrEqualTo(side));
          expect(body.bottom, lessThanOrEqualTo(side));
          // Straddle 3% rather than put fractional-size translations exactly
          // on it. The exact boundary has an integer-coordinate engine test.
          const offsets = [0.0, .5, .7, .74, .8, .84, .9, .935, .945, .98, 1.0];
          for (final x in offsets) {
            for (final y in offsets) {
              final other = shifted(x, y);
              final covered = base.overlaps(other, board, size);
              expect(other.overlaps(base, board, size), covered,
                  reason:
                      'Coverage geometry must be symmetric before z-order.');
              final logicalBase = base.boardRect(board, size);
              final logicalIntersection =
                  logicalBase.intersect(other.boardRect(board, size));
              expect(
                  covered,
                  logicalIntersection.width *
                          logicalIntersection.height /
                          (logicalBase.width * logicalBase.height) >=
                      .03,
                  reason: 'Artwork may neither remove nor add dependencies.');
            }
          }
        }
      }
    });
  }

  test('Endless terrace neighbors retain an authored shallow dependency', () {
    final geometry = qaScreens.first.geometry(endless: true);
    // Round-14 terraces: 0.190 cell stride, alternating 0.018 layer offsets.
    // Centers differ by 46.2 px; 51.2 px logical tiles overlap by 5 px.
    // The 46.08 px PNG bodies do not touch, but cannot erase this gameplay edge.
    const lower = Tile(
        id: 'lower', type: 'apple', x: .075 + .190 - .018, y: .100, layer: 0);
    const upper =
        Tile(id: 'upper', type: 'berry', x: .075 + .018, y: .100, layer: 1);
    final engine = GameEngine([lower, upper])
      ..updateBoardGeometry(geometry.board, geometry.tile);
    expect(
        TileBodyGeometry.bodiesOverlap(
            TileBodyGeometry.bodyFor(lower.type, geometry.tile)
                .shift(lower.boardRect(geometry.board, geometry.tile).topLeft),
            TileBodyGeometry.bodyFor(upper.type, geometry.tile)
                .shift(upper.boardRect(geometry.board, geometry.tile).topLeft)),
        isFalse);
    expect(engine.isTileCovered(lower), isTrue);
    expect(engine.findBestHintTileIds(), isNot(contains(lower.id)));
    expect(engine.tapTile(lower.id, geometry.board, geometry.tile), isFalse);
    expect(engine.tapTile(upper.id, geometry.board, geometry.tile), isTrue);
    expect(engine.isTileCovered(lower), isFalse);
    expect(engine.tapTile(lower.id, geometry.board, geometry.tile), isTrue);
  });

  for (final theme in TileVisualTheme.values) {
    for (final endless in [false, true]) {
      for (final screen in qaScreens) {
        testWidgets(
            '${endless ? 'Endless' : 'Campaign'} $theme ${screen.name}: coverage, taps, hints and uncovering agree',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = screen.size;
          SharedPreferences.setMockInitialValues({'vibration_enabled': false});
          final progress = _Progress();
          final boards = _Boards();
          final geometry = screen.geometry(endless: endless);
          final oracle = GameEngine(_tiles)
            ..updateBoardGeometry(geometry.board, geometry.tile);
          try {
            await progress.setLevelOneTutorialSeen();
            await tester.pumpWidget(AppScope(
              levelRepository: _Levels(),
              progressRepository: progress,
              audioService: _Audio(),
              child: MaterialApp(
                theme: GameTheme.theme(),
                navigatorObservers: [appRouteObserver],
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        padding:
                            EdgeInsets.only(top: screen.safeTop, bottom: 24),
                        viewPadding:
                            EdgeInsets.only(top: screen.safeTop, bottom: 24)),
                    child: child!),
                home: endless
                    ? EndlessScreen.forTesting(
                        initialRound: theme.index * 3 + 1,
                        boardGenerator: boards)
                    : GameScreen(level: theme.index * 10 + 1),
              ),
            ));
            await _settle(tester);
            await loadVisibleTileImages(tester);
            if (endless) expect(boards.themes, [theme]);
            _expectBoard(tester, oracle, theme, covered: {'base', 'middle'});

            final globes = find.byWidgetPredicate((widget) =>
                widget is CustomPaint && widget.painter is GlobeTilePainter);
            expect(
                globes,
                theme == TileVisualTheme.ocean
                    ? findsNWidgets(3)
                    : findsNothing,
                reason: 'Only Ocean sun/Lagoon may use the globe artwork.');
            expect(
                oracle.tapTile('base', geometry.board, geometry.tile), isFalse);
            expect(oracle.tapTile('middle', geometry.board, geometry.tile),
                isFalse);
            expect(oracle.findBestHintTileIds(),
                unorderedEquals(['cover', 'berry1', 'berry2']));

            // Real hit testing selects the highest painted layer, not base.
            await tester.tap(_board('cover'));
            expect(
                oracle.tapTile('cover', geometry.board, geometry.tile), isTrue);
            await tester.pump();
            expect(tester.widget<GameTileWidget>(_board('middle')).enabled,
                isTrue);
            expect(
                tester.widget<GameTileWidget>(_board('base')).blocked, isTrue);
            expect(find.byType(TileFlightVisual), findsOneWidget);
            expect(TileFlight.duration, const Duration(milliseconds: 440));
            await tester.pump(const Duration(milliseconds: 439));
            expect(find.byType(TileFlightVisual), findsOneWidget);
            await tester.pump(const Duration(milliseconds: 1));
            await _settle(tester);
            expect(find.byType(TileFlightVisual), findsNothing);
            _expectBoard(tester, oracle, theme, covered: {'base'});

            // The real Hint action must complete the tray's berry pair first.
            final firstHint = oracle.findBestHintTileIds();
            expect(firstHint, unorderedEquals(['berry1', 'berry2']));
            expect(
                firstHint
                    .every((id) => !oracle.isTileCovered(oracle.tileById(id)!)),
                isTrue);
            await tester.tap(find.text('Hint x2'));
            expect(oracle.collectHintTileIds(firstHint), isTrue);
            await _settle(tester);
            _expectBoard(tester, oracle, theme, covered: {'base'});
            expect(oracle.tileById('cover')!.state, TileState.matched);
            expect(_board('cover'), findsNothing);

            final secondHint = oracle.findBestHintTileIds();
            expect(secondHint, unorderedEquals(['middle', 'sun1', 'sun2']));
            expect(
                secondHint
                    .every((id) => !oracle.isTileCovered(oracle.tileById(id)!)),
                isTrue);
            await tester.tap(find.text('Hint x1'));
            expect(oracle.collectHintTileIds(secondHint), isTrue);
            await _settle(tester);
            _expectBoard(tester, oracle, theme, covered: {});
            expect(_board('middle'), findsNothing);

            await tester.tap(_board('base'));
            expect(
                oracle.tapTile('base', geometry.board, geometry.tile), isTrue);
            await _settle(tester);
            _expectBoard(tester, oracle, theme, covered: {});
            expect(oracle.tray, ['base']);
            expect(tester.binding.transientCallbackCount, 0);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            SharedPreferences.setMockInitialValues({});
          }
        });
      }
    }
  }
}
