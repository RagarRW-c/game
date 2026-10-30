import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
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

const _level3Asset = 'assets/levels/level_03.json';

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
  _Levels([this.layout = _tiles]);
  final List<Tile> layout;

  @override
  Future<LevelDefinition> loadLevel(int level) async => LevelDefinition(
      level: level,
      name: 'Coverage fixture',
      timeBonusSeconds: 60,
      tiles: layout);
}

class _Boards extends EndlessBoardGenerator {
  _Boards([this.layout = _tiles]);
  final List<Tile> layout;

  final List<TileVisualTheme> themes = [];
  @override
  List<Tile> generate({required int round, required TileVisualTheme theme}) {
    themes.add(theme);
    return List.of(layout);
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
    expect(opacity.opacity, 1,
        reason: 'Active tiles are full strength; covered bodies stay opaque '
            'while their artwork uses the distinct blocked tint.');
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
  for (final screen in qaScreens) {
    testWidgets(
        'real Campaign Level 3 ${screen.name}: leaves uncover and accept taps',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = screen.size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // CachingAssetBundle retains Future<String>, not just decoded text.
      // A completed Future from the preceding test schedules new listeners in
      // that test's now-inactive FakeAsync zone, leaving the loading spinner
      // running forever. Keep the real repository, but isolate this asset cache.
      rootBundle.evict(_level3Asset);
      addTearDown(() => rootBundle.evict(_level3Asset));
      SharedPreferences.setMockInitialValues({
        'vibration_enabled': false,
        'level_one_tutorial_seen': true,
      });
      // Inspect the shipped level, not a hand-authored replacement layout.
      final level = LevelDefinition.fromJson(
          jsonDecode(File(_level3Asset).readAsStringSync())
              as Map<String, dynamic>);
      final geometry = screen.geometry();
      final oracle = GameEngine(level.tiles)
        ..updateBoardGeometry(geometry.board, geometry.tile);
      expect(level.tiles.where((t) => t.type == 'leaf').map((t) => t.id),
          ['L3_T000', 'L3_T002', 'L3_T004']);
      expect(level.tiles.where((t) => t.type == 'shell'), isEmpty,
          reason:
              'The shipped Level 3 has no Paper Roll; shuffle cannot add types.');
      Set<String> coveredIds() => oracle.renderedBoardTiles
          .where(oracle.isTileCovered)
          .map((t) => t.id)
          .toSet();
      try {
        await tester.pumpWidget(AppScope(
            progressRepository: _Progress(),
            levelRepository: LevelRepository(),
            audioService: _Audio(),
            child: MaterialApp(
                theme: GameTheme.theme(),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        padding:
                            EdgeInsets.only(top: screen.safeTop, bottom: 24),
                        viewPadding:
                            EdgeInsets.only(top: screen.safeTop, bottom: 24)),
                    child: child!),
                home: const GameScreen(level: 3))));
        // The test asset handler reads synchronously; one frame flushes the
        // repository microtasks and renders FutureBuilder's completed snapshot.
        // Diagnose loading independently of finite gameplay animation settling.
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_board(), findsNWidgets(level.tiles.length),
            reason:
                'Level 3 must load in this viewport test\'s FakeAsync zone.');
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await _settle(tester);
        await loadVisibleTileImages(tester);
        _expectBoard(tester, oracle, TileVisualTheme.garden,
            covered: coveredIds());
        for (final id in ['L3_T000', 'L3_T002', 'L3_T004']) {
          expect(tester.widget<GameTileWidget>(_board(id)).blocked, isTrue,
              reason: '$id has actual higher painted blockers at level start.');
          expect(oracle.tapTile(id, geometry.board, geometry.tile), isFalse);
        }
        // Legal in all three viewport geometries, including same-layer blockers.
        // Keep T001 on the board to exercise the final leaf triple without
        // entering victory/video/navigation, which have separate coverage.
        const moves = [
          35,
          33,
          31,
          34,
          32,
          30,
          29,
          27,
          25,
          28,
          26,
          24,
          23,
          17,
          4,
          22,
          21,
          20,
          18,
          19,
          15,
          16,
          14,
          13,
          12,
          11,
          9,
          10,
          7,
          8,
          6,
          5,
          3,
          2,
          0,
        ];
        for (final number in moves) {
          final id = 'L3_T${number.toString().padLeft(3, '0')}';
          final widget = tester.widget<GameTileWidget>(_board(id));
          expect(widget.enabled, isTrue,
              reason: 'Legal move $id on ${screen.name}');
          expect(widget.blocked, isFalse);
          await tester.tap(_board(id));
          expect(oracle.tapTile(id, geometry.board, geometry.tile), isTrue);
          await _settle(tester);
          _expectBoard(tester, oracle, TileVisualTheme.garden,
              covered: coveredIds());
          expect(_board(id), findsNothing,
              reason: 'The pointer must select $id.');
        }
        expect(oracle.renderedBoardTiles.map((t) => t.id), ['L3_T001']);
        expect(oracle.tray, ['L3_T005', 'L3_T003']);
        for (final id in ['L3_T000', 'L3_T002', 'L3_T004']) {
          expect(oracle.tileById(id)!.state, TileState.matched);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
  }

  test('real Level 3 preserves qualifying logical gaps between rounded bodies',
      () {
    final level = LevelDefinition.fromJson(
        jsonDecode(File('assets/levels/level_03.json').readAsStringSync())
            as Map<String, dynamic>);
    for (final sample in [
      (qaScreens[0], 'L3_T000', 'L3_T027'),
      (qaScreens[1], 'L3_T028', 'L3_T030'),
      (qaScreens[2], 'L3_T019', 'L3_T033'),
    ]) {
      final geometry = sample.$1.geometry();
      final lower = level.tiles.singleWhere((t) => t.id == sample.$2);
      final upper = level.tiles.singleWhere((t) => t.id == sample.$3);
      final first = lower.boardRect(geometry.board, geometry.tile);
      final second = upper.boardRect(geometry.board, geometry.tile);
      final intersection = first.intersect(second);
      final ratio = intersection.width *
          intersection.height /
          (first.width * first.height);
      expect(ratio, greaterThanOrEqualTo(.03));
      expect(ratio, lessThan(.05));
      expect(
          TileBodyGeometry.bodiesOverlap(
              TileFacePainter.bodyRect(geometry.tile).shift(first.topLeft),
              TileFacePainter.bodyRect(geometry.tile).shift(second.topLeft)),
          isFalse);
      final engine = GameEngine([lower, upper])
        ..updateBoardGeometry(geometry.board, geometry.tile);
      expect(engine.isTileCovered(lower), isTrue);
      expect(engine.tapTile(lower.id, geometry.board, geometry.tile), isFalse);
      expect(engine.tapTile(upper.id, geometry.board, geometry.tile), isTrue);
      expect(engine.tapTile(lower.id, geometry.board, geometry.tile), isTrue);
    }
  });

  for (final endless in [false, true]) {
    for (final screen in qaScreens) {
      for (final type in ['leaf', 'shell']) {
        testWidgets('$endless ${screen.name} $type: painted body owns the tap',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = screen.size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final geometry = screen.geometry(endless: endless);
          for (final offset in [
            const Offset(.84, .84), // 2.56%: selectable rounded corner.
            const Offset(1.1, 0), // Fully separated.
            const Offset(.74, .74), // 6.76%: genuinely covered.
            const Offset(.96, 0), // 4%: logical coverage despite PNG padding.
          ]) {
            SharedPreferences.setMockInitialValues({
              'vibration_enabled': false,
              'level_one_tutorial_seen': true,
            });
            final layout = [
              Tile(id: 'lower', type: type, x: .1, y: .1, layer: 0),
              Tile(
                  id: 'upper',
                  type: type == 'leaf' ? 'shell' : 'leaf',
                  x: .1 +
                      offset.dx * geometry.tile.width / geometry.board.width,
                  y: .1 +
                      offset.dy * geometry.tile.height / geometry.board.height,
                  layer: 1),
              const Tile(id: 'spare', type: 'berry', x: .7, y: .7, layer: 0),
            ];
            final oracle = GameEngine(layout)
              ..updateBoardGeometry(geometry.board, geometry.tile);
            final covered = offset.dx == .74 || offset.dx == .96;
            try {
              await tester.pumpWidget(AppScope(
                  progressRepository: _Progress(),
                  levelRepository: _Levels(layout),
                  audioService: _Audio(),
                  child: MaterialApp(
                      theme: GameTheme.theme(),
                      builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                              padding: EdgeInsets.only(
                                  top: screen.safeTop, bottom: 24),
                              viewPadding: EdgeInsets.only(
                                  top: screen.safeTop, bottom: 24)),
                          child: child!),
                      home: endless
                          ? EndlessScreen.forTesting(
                              boardGenerator: _Boards(layout))
                          : const GameScreen(level: 2))));
              await _settle(tester);
              await loadVisibleTileImages(tester);
              _expectBoard(tester, oracle, TileVisualTheme.garden,
                  covered: {if (covered) 'lower'});
              final box = tester.renderObject<RenderBox>(_board('lower'));
              final local = covered
                  ? box.size.center(Offset.zero)
                  : Offset(box.size.width * .85, box.size.height * .85);
              final point = box.localToGlobal(local);
              expect(
                  TileFacePainter.bodyRect(box.size).contains(local), isTrue);
              if (offset.dx == .84) {
                final upper = tester.renderObject<RenderBox>(_board('upper'));
                final upperPoint = upper.globalToLocal(point);
                expect((Offset.zero & upper.size).contains(upperPoint), isTrue,
                    reason:
                        'Reproduces interception by the old rectangular hit box.');
                expect(
                    TileFacePainter.bodyRect(upper.size).contains(upperPoint),
                    isFalse,
                    reason: 'Only the lower tile is painted at this point.');
              }
              await tester.tapAt(point);
              expect(oracle.tapTile('lower', geometry.board, geometry.tile),
                  !covered);
              await tester.pump();
              _expectBoard(tester, oracle, TileVisualTheme.garden,
                  covered: {if (covered) 'lower'});
              // A live flight must not intercept the next legitimate board tap.
              await tester.tap(_board('upper'));
              expect(oracle.tapTile('upper', geometry.board, geometry.tile),
                  isTrue);
              await tester.pump();
              await _settle(tester);
              _expectBoard(tester, oracle, TileVisualTheme.garden, covered: {});
              if (covered) {
                await tester.tap(_board('lower'));
                expect(oracle.tapTile('lower', geometry.board, geometry.tile),
                    isTrue);
                await _settle(tester);
                _expectBoard(tester, oracle, TileVisualTheme.garden,
                    covered: {});
              }
              expect(oracle.tray,
                  covered ? ['upper', 'lower'] : ['lower', 'upper']);
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
            }
          }
        });
      }
    }
  }

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
            await tester.tap(find.byWidgetPredicate((w) =>
                w is GameBoosterButton &&
                w.action == BoosterAction.hint &&
                w.label == 'Hint' &&
                w.badge == 'x2'));
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
            await tester.tap(find.byWidgetPredicate((w) =>
                w is GameBoosterButton &&
                w.action == BoosterAction.hint &&
                w.label == 'Hint' &&
                w.badge == 'x1'));
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
