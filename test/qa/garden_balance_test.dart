import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import 'support/geometry.dart';
import 'support/garden_balance_expectations.dart';

// The only approved asset changes in Garden balancing pass 1.
const _changes = gardenPass1Coordinates;

// Each opening must be visible BEFORE any tile is selected, and must lead to
// full clearance without boosters (not merely consume a convenient triple).
const _openings = <int, List<List<int>>>{
  1: [[24, 26, 28]],
  3: [[30, 32, 34], [31, 33, 35]],
  4: [[30, 32, 34], [31, 33, 35]],
  6: [[28, 32, 34], [31, 33, 35]],
  9: [[37, 39, 41]],
};
const _smallMinimumPlayable = {1: 6, 3: 6, 4: 6, 6: 8, 9: 6};

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

int _longestChain(GameEngine engine, QaGeometry g) {
  final ordered = engine.renderedBoardTiles;
  final depths = List<int>.filled(ordered.length, 1);
  for (var i = ordered.length - 1; i >= 0; i--) {
    for (var j = i + 1; j < ordered.length; j++) {
      if (ordered[i].overlaps(ordered[j], g.board, g.tile)) {
        depths[i] = math.max(depths[i], 1 + depths[j]);
      }
    }
  }
  return depths.reduce(math.max);
}

Rect _bounds(List<Tile> tiles, QaGeometry g) => tiles
    .map((tile) => tile.boardRect(g.board, g.tile))
    .reduce((a, b) => a.expandToInclude(b));

void _expectFullClearance(
    LevelDefinition level, QaGeometry g, List<String> path) {
  final engine = GameEngine(level.tiles, objective: level.objective);
  expect(path.toSet().length, level.tiles.length);
  expect(path.length, level.tiles.length);
  var peak = 0;
  for (var i = 0; i < path.length; i++) {
    expect(engine.tapTile(path[i], g.board, g.tile), isTrue,
        reason: 'Move $i: ${path[i]} must be accepted without boosters');
    peak = math.max(peak, engine.tray.length);
    expect(engine.result,
        i == path.length - 1 ? GameResult.won : GameResult.playing,
        reason: 'Full clearance required; no early loss or victory at move $i');
  }
  expect(peak, lessThanOrEqualTo(4),
      reason: 'The preserved witness retains its two-slot safety margin');
  expect(engine.boardTiles, isEmpty);
  expect(engine.tray, isEmpty);
  expect(engine.tiles.every((t) => t.state == TileState.matched), isTrue);
  if (level.objective != null) expect(engine.objectiveComplete, isTrue);
}

void main() {
  final baseline = _read('test/qa/fixtures/garden_balance_before.json');
  final cases = (baseline['levels'] as List).cast<Map<String, dynamic>>();

  test('frozen baseline covers exactly the five approved non-boss levels', () {
    expect(cases.map((entry) => entry['before']['level']).toSet(),
        _changes.keys.toSet());
    expect(cases.length, _changes.length);
  });

  for (final entry in cases) {
    final before = entry['before'] as Map<String, dynamic>;
    final id = before['level'] as int;
    final path = 'assets/levels/level_${id.toString().padLeft(2, '0')}.json';

    test('Garden $id changes only the reviewed coordinates', () {
      final expected = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
      for (final tile in (expected['tiles'] as List).cast<Map<String, dynamic>>()) {
        tile.addAll(_changes[id]![tile['id']] ?? <String, double>{});
      }
      // Also freezes objectives, time metadata, types, inventory, layers, IDs,
      // paint order and layoutPattern. No regeneration of other level content.
      expect(_read(path), expected);
    });

    for (final screen in qaScreens) {
      test('Garden $id / ${screen.name}: openings, depth and full clearance', () {
        final level = LevelDefinition.fromJson(_read(path));
        final original = LevelDefinition.fromJson(before);
        final g = screen.geometry();
        final engine = GameEngine(level.tiles)
          ..updateBoardGeometry(g.board, g.tile);
        final previous = GameEngine(original.tiles)
          ..updateBoardGeometry(g.board, g.tile);
        final measured = (entry['measured']['screens'] as List)
            .cast<Map<String, dynamic>>()
            .singleWhere((row) => row['screen'] == screen.name);
        final oldGeometry = measured['geometry'] as Map<String, dynamic>;
        final available = engine.boardTiles
            .where((t) => !engine.isTileCovered(t))
            .map((t) => t.id)
            .toSet();

        expect(previous.boardTiles.where((t) => !previous.isTileCovered(t)).length,
            oldGeometry['initial_playable']);
        expect(_longestChain(previous, g), oldGeometry['max_blocker_chain_tiles']);
        expect(available.length,
            greaterThanOrEqualTo(oldGeometry['initial_playable'] as int));
        expect(_longestChain(engine, g),
            lessThanOrEqualTo(oldGeometry['max_blocker_chain_tiles'] as int));
        if (screen == qaScreens.first) {
          expect(available.length, greaterThanOrEqualTo(_smallMinimumPlayable[id]!));
          if (id == 3 || id == 6) {
            expect(_longestChain(engine, g),
                lessThan(oldGeometry['max_blocker_chain_tiles'] as int));
          }
        }

        // Preserve the outer silhouette and remain inside the same logical
        // canvas used by the production FittedBox on every QA aspect ratio.
        expect(_bounds(level.tiles, g), _bounds(original.tiles, g));
        for (final tile in level.tiles) {
          final rect = tile.boardRect(g.board, g.tile);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(g.board.width));
          expect(rect.bottom, lessThanOrEqualTo(g.board.height));
        }
        final counts = <String, int>{};
        for (final tile in level.tiles) {
          counts.update(tile.type, (n) => n + 1, ifAbsent: () => 1);
        }
        expect(counts.values.every((n) => n % 3 == 0), isTrue);

        final reverse = engine.renderedBoardTiles.reversed.map((t) => t.id).toList();
        _expectFullClearance(level, g, reverse);
        for (final indices in _openings[id]!) {
          final opening = indices
              .map((index) => 'L${id}_T${index.toString().padLeft(3, '0')}')
              .toList();
          expect(available, containsAll(opening));
          expect(opening.map((tileId) => engine.tileById(tileId)!.type).toSet(),
              hasLength(1));
          final start = GameEngine(level.tiles, objective: level.objective);
          for (final tileId in opening) {
            expect(start.tapTile(tileId, g.board, g.tile), isTrue);
          }
          expect(start.tray, isEmpty);
          expect(start.boardTiles.length, level.tiles.length - 3);
          expect(start.result, GameResult.playing);
          if (id == 1) expect(start.objectiveComplete, isTrue);
          _expectFullClearance(level, g,
              [...opening, ...reverse.where((tileId) => !opening.contains(tileId))]);
        }
      });
    }
  }
}
