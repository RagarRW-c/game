import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

const board = Size(1000, 1000);
const tileSize = Size(50, 50);

List<Tile> openTiles(List<String> types) => [
      for (var i = 0; i < types.length; i++)
        Tile(
            id: 't$i',
            type: types[i],
            x: (i % 10) * 0.09,
            y: (i ~/ 10) * 0.09,
            layer: 0),
    ];

void pick(GameEngine engine, Iterable<String> ids) {
  for (final id in ids) {
    expect(engine.tapTile(id, board, tileSize), isTrue, reason: 'Tap $id');
  }
}

void main() {
  test('three identical tiles match immediately and clear their tray slots',
      () {
    final engine = GameEngine(openTiles(['apple', 'apple', 'apple', 'berry']));
    pick(engine, ['t0', 't1']);
    expect(engine.tray, ['t0', 't1']);
    pick(engine, ['t2']);
    expect(engine.tray, isEmpty);
    expect(engine.tiles.take(3).every((t) => t.state == TileState.matched),
        isTrue);
    expect(engine.result, GameResult.playing);
  });

  test('QA-001 seventh non-matching tile triggers Game Over immediately', () {
    // Triples exist elsewhere, so this is a valid inventory with a bad choice.
    final types = [
      'apple',
      'banana',
      'berry',
      'carrot',
      'star',
      'shell',
      'flower'
    ];
    final engine = GameEngine(openTiles([...types, ...types, ...types]));
    pick(engine, List.generate(6, (i) => 't$i'));
    expect(engine.result, GameResult.playing);
    pick(engine, ['t6']);
    expect(engine.tray.length, GameEngine.trayLimit);
    expect(engine.result, GameResult.lost,
        reason:
            'Full tray without a triple must end the round on the seventh tap');
  });

  test('a triple in the seventh slot resolves before the loss check', () {
    final engine = GameEngine(openTiles([
      'apple',
      'apple',
      'banana',
      'berry',
      'carrot',
      'star',
      'apple',
      'shell',
    ]));
    pick(engine, List.generate(7, (i) => 't$i'));
    expect(engine.tray.length, 4);
    expect(engine.result, GameResult.playing);
  });

  test('tray never accepts an eighth tile after reaching capacity', () {
    final engine = GameEngine(openTiles([
      'apple',
      'banana',
      'berry',
      'carrot',
      'star',
      'shell',
      'flower',
      'moon',
    ]));
    pick(engine, List.generate(7, (i) => 't$i'));
    expect(engine.tapTile('t7', board, tileSize), isFalse);
    expect(engine.tray.length, 7);
    expect(engine.result, GameResult.lost);
    expect(engine.tileById('t7')!.state, TileState.board);
  });

  for (final sameLayer in [false, true]) {
    test('coverage follows paint order (same layer: $sameLayer)', () {
      final engine = GameEngine([
        const Tile(id: 'lower', type: 'apple', x: 0.2, y: 0.2, layer: 0),
        Tile(
            id: 'upper',
            type: 'berry',
            x: 0.2,
            y: 0.2,
            layer: sameLayer ? 0 : 1),
      ]);
      expect(engine.isUncovered(engine.tiles.first, board, tileSize), isFalse);
      expect(engine.tapTile('lower', board, tileSize), isFalse);
      expect(engine.isUncovered(engine.tiles.last, board, tileSize), isTrue);
      pick(engine, ['upper']);
      expect(engine.isUncovered(engine.tiles.first, board, tileSize), isTrue);
      expect(engine.tapTile('upper', board, tileSize), isFalse);
    });
  }

  test('coverage preserves logical dependencies independently of artwork', () {
    const base = Tile(id: 'a', type: 'apple', x: 0, y: 0, layer: 0);
    Tile above(double x) => Tile(id: 'b', type: 'berry', x: x, y: 0, layer: 1);
    const size = Size(100, 100);
    const tile = Size(10, 10);
    double offsetForRatio(double ratio) => .1 * (1 - ratio);
    expect(base.overlaps(above(offsetForRatio(.02)), size, tile), isFalse);
    expect(base.overlaps(above(offsetForRatio(.04)), size, tile), isTrue);
    expect(
        base.overlaps(above(0.08), size, tile), isTrue); // Real body overlap.
    expect(
        base.overlaps(above(0.09), size, tile), isTrue); // 10% logical overlap.
    expect(base.overlaps(above(0.096), size, tile), isTrue,
        reason:
            'Transparent margins must not erase an authored 4% dependency.');
    expect(base.overlaps(above(0.096), size, tile, minimumCoveredRatio: .05),
        isFalse);
    expect(base.overlaps(above(0.1), size, tile), isFalse); // layout edge
    // Integer coordinates exercise the inclusive 3% boundary exactly.
    expect(base.overlaps(above(.97), size, size), isTrue);
    expect(base.overlaps(above(.98), size, size), isFalse);
    // Verify the configurable inclusive threshold independently where the
    // bodies genuinely intersect (integer coordinates avoid rounding).
    expect(base.overlaps(above(.65), size, size, minimumCoveredRatio: .35),
        isTrue);
    expect(base.overlaps(above(.65), size, size, minimumCoveredRatio: .36),
        isFalse);
  });

  for (final sameLayer in [false, true]) {
    for (final scenario in [
      (
        name: 'logical margin overlap',
        offset: const Offset(48, 0),
        covered: true
      ),
      (
        name: 'logical corner overlap',
        offset: const Offset(40, 40),
        covered: true
      ),
      (name: 'physical body', offset: const Offset(30, 0), covered: true),
      (name: 'sub-threshold edge', offset: const Offset(49, 0), covered: false),
      (
        name: 'sub-threshold corner',
        offset: const Offset(42, 42),
        covered: false
      ),
      (name: 'touching edge', offset: const Offset(50, 0), covered: false),
    ]) {
      test('${scenario.name}: coverage and taps agree, same layer $sameLayer',
          () {
        const lower = Tile(id: 'lower', type: 'apple', x: .1, y: .1, layer: 0);
        final upper = Tile(
            id: 'upper',
            type: 'berry',
            x: .1 + scenario.offset.dx / board.width,
            y: .1 + scenario.offset.dy / board.height,
            layer: sameLayer ? 0 : 1);
        // An independent rectangle oracle protects the authored rule.
        final intersection = lower
            .boardRect(board, tileSize)
            .intersect(upper.boardRect(board, tileSize));
        expect(intersection.width * intersection.height / 2500 >= .03,
            scenario.covered);
        final engine = GameEngine([lower, upper])
          ..updateBoardGeometry(board, tileSize);
        expect(engine.isTileCovered(lower), scenario.covered);
        expect(engine.isTileCovered(upper), isFalse);
        expect(engine.isUncovered(lower, board, tileSize), !scenario.covered);
        expect(engine.tapTile(lower.id, board, tileSize), !scenario.covered);
        if (scenario.covered) {
          expect(engine.tray, isEmpty);
          expect(engine.tapTile(upper.id, board, tileSize), isTrue);
          expect(engine.isTileCovered(lower), isFalse,
              reason: 'A tray tile cannot continue covering a board tile.');
          expect(engine.tapTile(lower.id, board, tileSize), isTrue);
        } else {
          expect(engine.tray, [lower.id]);
        }
      });
    }
  }

  test('Shuffle cannot change coverage by exchanging PNG and painted symbols',
      () {
    final engine = GameEngine([
      const Tile(id: 'a', type: 'apple', x: 0, y: 0, layer: 0),
      // Even shallow logical overlap must survive PNG/procedural symbol swaps.
      Tile(
          id: 'b',
          type: 'sun',
          x: tileSize.width * .96 / board.width,
          y: 0,
          layer: 1),
      const Tile(id: 'c', type: 'drop', x: .5, y: .5, layer: 0),
    ])
      ..updateBoardGeometry(board, tileSize);
    for (var i = 0; i < 10; i++) {
      expect(engine.isTileCovered(engine.tileById('a')!), isTrue);
      expect(engine.isTileCovered(engine.tileById('b')!), isFalse);
      expect(engine.isTileCovered(engine.tileById('c')!), isFalse);
      expect(engine.findBestHintTileIds(), isNot(contains('a')));
      expect(engine.tapTile('a', board, tileSize), isFalse);
      expect(engine.tray, isEmpty);
      expect(engine.shuffleBoard(), isTrue);
    }
    expect(engine.isTileCovered(engine.tileById('a')!), isTrue);
  });

  test('Undo restores the last unmatched tile and its blocking relationship',
      () {
    final engine = GameEngine([
      const Tile(id: 't0', type: 'apple', x: 0.2, y: 0.2, layer: 0),
      const Tile(id: 't1', type: 'berry', x: 0.2, y: 0.2, layer: 1),
    ]);
    expect(engine.undo(), isFalse);
    pick(engine, ['t1']);
    expect(engine.canUndo, isTrue);
    expect(engine.undo(), isTrue);
    expect(engine.tray, isEmpty);
    expect(engine.tileById('t1')!.state, TileState.board);
    expect(engine.isUncovered(engine.tiles.first, board, tileSize), isFalse);
  });

  test('Undo cannot resurrect a matched triple', () {
    final engine = GameEngine(openTiles(['apple', 'apple', 'apple', 'berry']));
    pick(engine, ['t0', 't1', 't2']);
    expect(engine.canUndo, isFalse);
    expect(engine.undo(), isFalse);
    expect(engine.tiles.take(3).every((t) => t.state == TileState.matched),
        isTrue);
  });

  test('Shuffle preserves inventory, positions, states, tray and matched tiles',
      () {
    final engine = GameEngine(openTiles([
      'apple',
      'apple',
      'apple',
      'berry',
      'berry',
      'banana',
      'banana',
      'moon',
    ]));
    pick(engine, ['t0', 't1', 't2', 't3']);
    final before = List<Tile>.of(engine.tiles);
    final inventory = engine.boardTiles.map((t) => t.type).toList()..sort();
    expect(engine.shuffleBoard(), isTrue);
    expect(engine.boardTiles.map((t) => t.type).toList()..sort(), inventory);
    expect(engine.tray, ['t3']);
    for (var i = 0; i < before.length; i++) {
      final after = engine.tiles[i];
      expect([
        after.id,
        after.x,
        after.y,
        after.layer,
        after.state
      ], [
        before[i].id,
        before[i].x,
        before[i].y,
        before[i].layer,
        before[i].state
      ]);
      if (before[i].state != TileState.board) {
        expect(after.type, before[i].type);
      }
    }
    // A random shuffle may legally keep the same order; do not assert a change.
  });

  test('Hint prefers completing the tray and only returns uncovered tiles', () {
    final engine = GameEngine(openTiles([
      'apple',
      'apple',
      'apple',
      'berry',
      'berry',
      'berry',
    ]));
    pick(engine, ['t0', 't1']);
    expect(engine.hint(board, tileSize), 't2');
    expect(engine.findBestHintTileIds(), ['t2']);
    expect(engine.collectHintTileIds(['t2']), isTrue);
    expect(engine.tray, isEmpty);
    expect(engine.result, GameResult.playing);
  });

  test('Hint rejects covered IDs atomically and does not mutate the board', () {
    final engine = GameEngine([
      const Tile(id: 'a', type: 'apple', x: 0, y: 0, layer: 0),
      const Tile(id: 'b', type: 'apple', x: 0, y: 0, layer: 1),
      const Tile(id: 'c', type: 'apple', x: 0.2, y: 0.2, layer: 0),
    ])
      ..updateBoardGeometry(board, tileSize);
    expect(engine.findBestHintTileIds(), isEmpty);
    expect(engine.collectHintTileIds(['c', 'a']), isFalse);
    expect(engine.tray, isEmpty);
    expect(engine.boardTiles.length, 3);
  });

  test('photo tray with five tiles: Hint completes the carrot pair first', () {
    // The device photo's tray order: carrot, chili, kiwi, leaf, carrot.
    // An independent sun triple must not take precedence over a one-tile match.
    final engine = GameEngine(openTiles([
      'carrot',
      'berry',
      'apple',
      'leaf',
      'carrot',
      'carrot',
      'sun',
      'sun',
      'sun',
    ]))
      ..updateBoardGeometry(board, tileSize);
    pick(engine, ['t0', 't1', 't2', 't3', 't4']);
    expect(engine.tray, ['t0', 't1', 't2', 't3', 't4']);
    expect(engine.findBestHintTileIds(), ['t5']);
    expect(engine.collectHintTileIds(['t5']), isTrue);
    expect(engine.tray, ['t1', 't2', 't3']);
    expect(engine.result, GameResult.playing);
    for (final id in ['t0', 't4', 't5']) {
      expect(engine.tileById(id)!.state, TileState.matched);
    }
    expect(engine.boardTiles.map((tile) => tile.id), ['t6', 't7', 't8']);
  });

  test('photo tray: covered carrot cannot complete the pair through a blocker',
      () {
    final tiles = openTiles([
      'carrot',
      'berry',
      'apple',
      'leaf',
      'carrot',
      'carrot',
      'sun',
      'sun',
      'sun',
    ]);
    final carrot = tiles[5];
    final engine = GameEngine([
      ...tiles,
      Tile(id: 'cover', type: 'shell', x: carrot.x, y: carrot.y, layer: 1),
    ])
      ..updateBoardGeometry(board, tileSize);
    pick(engine, ['t0', 't1', 't2', 't3', 't4']);
    expect(engine.isTileCovered(carrot), isTrue);
    expect(engine.findBestHintTileIds(), unorderedEquals(['t6', 't7', 't8']));
    expect(engine.collectHintTileIds(['t5']), isFalse);
    expect(engine.tray, ['t0', 't1', 't2', 't3', 't4']);
    expect(engine.tileById('t5')!.state, TileState.board);
    expect(engine.result, GameResult.playing);
  });

  test('Hint collects and matches an exposed triple without duplicate IDs', () {
    final engine = GameEngine(openTiles([
      'apple',
      'apple',
      'apple',
      'berry',
      'berry',
      'berry',
    ]))
      ..updateBoardGeometry(board, tileSize);
    final ids = engine.findBestHintTileIds();
    expect(ids.toSet(), {'t3', 't4', 't5'});
    expect(engine.collectHintTileIds([...ids, ids.first]), isTrue);
    expect(engine.tray, isEmpty);
    expect(engine.tiles.where((t) => t.state == TileState.matched).length, 3);
    expect(engine.result, GameResult.playing);
  });

  for (final occupied in [5, 6]) {
    test('Hint clears an exposed triple directly with $occupied occupied slots',
        () {
      final engine = GameEngine(
          openTiles([
            'apple',
            'apple',
            'apple',
            'banana',
            'berry',
            'carrot',
            'star',
            'shell',
            if (occupied == 6) 'leaf',
            'moon', // Keep gameplay active after the direct clear.
          ]),
          objective: const LevelObjective(type: 'apple', target: 3))
        ..updateBoardGeometry(board, tileSize);
      final before = [for (var i = 3; i < 3 + occupied; i++) 't$i'];
      pick(engine, before);
      final ids = engine.findBestHintTileIds();
      expect(ids.toSet(), {'t0', 't1', 't2'});
      expect(engine.canCollectHintTileIds(ids), isTrue);
      expect(engine.collectHintTileIds([...ids, ids.first]), isTrue);
      expect(engine.tray, before);
      expect(engine.result, GameResult.playing);
      expect(engine.boardTiles.map((tile) => tile.id), ['t${3 + occupied}']);
      for (final id in ids) {
        expect(engine.tileById(id)!.state, TileState.matched);
      }
      expect(engine.objectiveProgress, 3);
      expect(engine.collectHintTileIds(ids), isFalse);
      expect(engine.objectiveProgress, 3);
      expect(engine.tray, before);
      expect(engine.undo(), isFalse,
          reason: 'Matched tiles cannot be resurrected.');
    });
  }

  test('Hint capacity exception rejects mixed, incomplete and covered batches',
      () {
    final initial = openTiles([
      'apple',
      'apple',
      'berry',
      'banana',
      'carrot',
      'star',
      'shell',
      'moon',
      'leaf',
    ]);
    final engine = GameEngine(initial)..updateBoardGeometry(board, tileSize);
    pick(engine, ['t3', 't4', 't5', 't6', 't7', 't8']);
    final before = List<String>.of(engine.tray);
    for (final ids in [
      <String>['t0', 't1'],
      ['t0', 't1', 't2'],
      ['missing']
    ]) {
      expect(engine.canCollectHintTileIds(ids), isFalse);
      expect(engine.collectHintTileIds(ids), isFalse);
      expect(engine.tray, before);
      expect(engine.result, GameResult.playing);
    }
    // A valid triple becomes stale after an added blocker, just as a board
    // change during pending payment must invalidate the captured request.
    engine.tiles = engine.tiles
        .map((tile) => tile.id == 't2' ? tile.copyWith(type: 'apple') : tile)
        .toList();
    expect(engine.canCollectHintTileIds(['t0', 't1', 't2']), isTrue);
    engine.tiles
        .add(const Tile(id: 'cover', type: 'sun', x: 0, y: 0, layer: 1));
    expect(engine.canCollectHintTileIds(['t0', 't1', 't2']), isFalse);
    expect(engine.collectHintTileIds(['t0', 't1', 't2']), isFalse);
    expect(engine.tray, before);
  });

  test('six-slot Hint skips an unfit tray completion for an exposed triple',
      () {
    final engine = GameEngine(openTiles([
      'carrot',
      'apple',
      'berry',
      'leaf',
      'moon',
      'shell',
      'carrot',
      'carrot',
      'sun',
      'sun',
      'sun',
    ]))
      ..updateBoardGeometry(board, tileSize);
    pick(engine, ['t0', 't1', 't2', 't3', 't4', 't5']);
    final ids = engine.findBestHintTileIds();
    expect(ids, unorderedEquals(['t8', 't9', 't10']));
    expect(engine.collectHintTileIds(ids), isTrue);
    expect(engine.tray, ['t0', 't1', 't2', 't3', 't4', 't5']);
    expect(engine.boardTiles.map((tile) => tile.id), ['t6', 't7']);
    // Ordinary selection still loses at seven unmatched tiles.
    expect(engine.tapTile('t6', board, tileSize), isTrue);
    expect(engine.tray, hasLength(GameEngine.trayLimit));
    expect(engine.result, GameResult.lost);
  });

  test('objective completion does not win while tiles remain on the board', () {
    final engine = GameEngine(
      openTiles(['apple', 'apple', 'apple', 'berry', 'berry', 'berry']),
      objective: const LevelObjective(type: 'apple', target: 3),
    );
    pick(engine, ['t0', 't1', 't2']);
    expect(engine.objectiveComplete, isTrue);
    expect(engine.objectiveProgress, 3);
    expect(engine.result, GameResult.playing);
    pick(engine, ['t3', 't4', 't5']);
    expect(engine.result, GameResult.won);
    expect(engine.boardTiles, isEmpty);
    expect(engine.tray, isEmpty);
    expect(engine.tapTile('missing', board, tileSize), isFalse);
    expect(engine.shuffleBoard(), isFalse);
    expect(engine.undo(), isFalse);
    expect(engine.hint(board, tileSize), isNull);
  });
}
