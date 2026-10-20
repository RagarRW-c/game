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

  test('coverage threshold is three percent and edge contact is not overlap',
      () {
    const base = Tile(id: 'a', type: 'apple', x: 0, y: 0, layer: 0);
    Tile above(double x) => Tile(id: 'b', type: 'berry', x: x, y: 0, layer: 1);
    const size = Size(100, 100);
    const tile = Size(10, 10);
    expect(base.overlaps(above(0.098), size, tile), isFalse); // 2%
    expect(base.overlaps(above(0.096), size, tile), isTrue); // 4%
    expect(base.overlaps(above(0.1), size, tile), isFalse); // edge
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

  test('Hint respects the current batch capacity rule without tray overflow',
      () {
    final engine = GameEngine(openTiles([
      'apple',
      'apple',
      'apple',
      'banana',
      'berry',
      'carrot',
      'star',
      'shell',
    ]))
      ..updateBoardGeometry(board, tileSize);
    pick(engine, ['t3', 't4', 't5', 't6', 't7']);
    final ids = engine.findBestHintTileIds();
    expect(ids.toSet(), {'t0', 't1', 't2'});
    // Current Hint requires room for the complete batch before matching.
    expect(engine.collectHintTileIds(ids), isFalse);
    expect(engine.tray.length, 5);
    expect(engine.result, GameResult.lost);
    expect(engine.boardTiles.length, 3);
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
