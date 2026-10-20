import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import 'support/solver.dart';

const board = Size(1000, 1000);
const side = Size(20, 20);

List<Tile> forcedStack() {
  final types = tileCatalog.keys.take(8).toList();
  return [
    for (var i = 0; i < 24; i++)
      Tile(id: 't$i', type: types[(23 - i) % 8], x: 0, y: 0, layer: i),
  ];
}

// Independent small-board oracle uses actual tap transitions instead of masks.
bool exhaustiveOracle(List<Tile> tiles) {
  bool visit(GameEngine state) {
    if (state.result == GameResult.won) return state.tray.isEmpty;
    if (state.result == GameResult.lost || state.tray.length >= 7) return false;
    for (final candidate in state.boardTiles) {
      final next = GameEngine(state.tiles)..tray = List.of(state.tray);
      if (next.tapTile(candidate.id, board, side) && visit(next)) return true;
    }
    return false;
  }

  return visit(GameEngine(tiles));
}

void main() {
  test('SOLVED includes a complete witness replayable by the real engine', () {
    final tiles = List.generate(
        108,
        (i) => Tile(
              id: 't$i',
              type: 'apple',
              x: 0,
              y: 0,
              layer: i,
            ));
    final result = const BoardSolver().solve(tiles, board, side);
    expect(result.status, SolveStatus.solved);
    expect(result.path.length, 108);
    expect(const BoardSolver().replay(tiles, board, side, result.path), isTrue);
  });

  test(
      'divisibility does not prove solvability: forced full tray is UNSOLVABLE',
      () {
    final result = const BoardSolver().solve(forcedStack(), board, side);
    expect(result.status, SolveStatus.unsolvable);
    expect(result.reason, 'Exhaustive tap search');
    expect(exhaustiveOracle(forcedStack()), isFalse);
  });

  test('node/time cutoffs return UNKNOWN, never UNSOLVABLE', () {
    expect(
        const BoardSolver(maxNodes: 0).solve(forcedStack(), board, side).status,
        SolveStatus.unknown);
    expect(
        const BoardSolver(timeLimit: Duration.zero)
            .solve(forcedStack(), board, side)
            .status,
        SolveStatus.unknown);
  });

  test('search can find a path when the reverse-paint candidate fails', () {
    final tiles = [
      for (final t in forcedStack())
        Tile(
            id: t.id,
            type: t.type,
            x: int.parse(t.id.substring(1)) * 0.03,
            y: 0,
            layer: 0),
    ];
    final result = const BoardSolver().solve(tiles, board, side);
    expect(result.status, SolveStatus.solved);
    expect(result.reason, 'Engine-replayed search witness');
  });

  test('search masks handle more than 64 tiles without integer truncation', () {
    final types = tileCatalog.keys.take(8).toList();
    final tiles = List.generate(
        72,
        (i) => Tile(
              id: 't$i',
              type: types[i % 8],
              x: (i % 10) * 0.08,
              y: (i ~/ 10) * 0.08,
              layer: 0,
            ));
    final result = const BoardSolver().solve(tiles, board, side);
    expect(result.status, SolveStatus.solved);
    expect(result.reason, 'Engine-replayed search witness');
    expect(result.path.length, 72);
  });

  test(
      'solver agrees with exhaustive engine transitions on small layered boards',
      () {
    // All 20 ways to place three apples among six tiles, at three geometries.
    for (var mask = 0; mask < 64; mask++) {
      if (mask.toRadixString(2).split('').where((b) => b == '1').length != 3) {
        continue;
      }
      for (var layout = 0; layout < 3; layout++) {
        final tiles = List.generate(
            6,
            (i) => Tile(
                  id: 't$i',
                  type: mask & (1 << i) != 0 ? 'apple' : 'berry',
                  x: layout == 0 ? i * 0.05 : (i % 2) * 0.01,
                  y: layout == 2 ? (i ~/ 2) * 0.01 : 0,
                  layer: layout == 1 ? i : 0,
                ));
        final result = const BoardSolver().solve(tiles, board, side);
        expect(result.status == SolveStatus.solved, exhaustiveOracle(tiles),
            reason: 'mask=$mask layout=$layout result=${result.reason}');
        expect(result.status, isNot(SolveStatus.unknown));
      }
    }
  });
}
