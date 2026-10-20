import 'dart:ui';

import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

enum SolveStatus { solved, unsolvable, unknown }

class SolveResult {
  const SolveResult(this.status, this.reason, this.nodes, this.path);
  final SolveStatus status;
  final String reason;
  final int nodes;
  final List<String> path;

  Map<String, Object> toJson() => {
        'status': status.name.toUpperCase(),
        'reason': reason,
        'nodes': nodes,
        'path': path,
      };
}

/// A SOLVED result always has a witness replayed through the real GameEngine.
/// Searches tile taps only: no Shuffle, Undo, Hint or purchases. UNSOLVABLE is
/// limited to that model and this geometry. A budget cutoff is always UNKNOWN.
class BoardSolver {
  const BoardSolver({
    this.maxNodes = 50000,
    this.timeLimit = const Duration(milliseconds: 500),
  });
  final int maxNodes;
  final Duration timeLimit;

  bool replay(List<Tile> tiles, Size board, Size tile, List<String> path,
      {LevelObjective? objective}) {
    final engine = GameEngine(tiles, objective: objective);
    for (final id in path) {
      if (!engine.tapTile(id, board, tile) ||
          engine.result == GameResult.lost) {
        return false;
      }
    }
    return engine.result == GameResult.won &&
        engine.boardTiles.isEmpty &&
        engine.tray.isEmpty &&
        engine.tiles.every((t) => t.state == TileState.matched) &&
        (objective == null || engine.objectiveComplete);
  }

  SolveResult solve(List<Tile> tiles, Size board, Size tile,
      {LevelObjective? objective}) {
    final watch = Stopwatch()..start();
    if (tiles.isEmpty ||
        tiles.map((t) => t.id).toSet().length != tiles.length ||
        tiles.any((t) => t.state != TileState.board) ||
        board.width <= 0 ||
        board.height <= 0 ||
        tile.width <= 0 ||
        tile.height <= 0 ||
        !board.width.isFinite ||
        !board.height.isFinite ||
        !tile.width.isFinite ||
        !tile.height.isFinite ||
        tiles.any((t) => !t.x.isFinite || !t.y.isFinite)) {
      return const SolveResult(
          SolveStatus.unknown, 'Invalid starting state/geometry', 0, []);
    }
    final ordered = GameEngine(tiles).renderedBoardTiles;
    final inventory = <String, int>{};
    for (final t in tiles) {
      inventory.update(t.type, (n) => n + 1, ifAbsent: () => 1);
    }
    if (inventory.values.any((n) => n % 3 != 0) ||
        (objective != null &&
            (inventory[objective.type] ?? 0) < objective.target)) {
      return const SolveResult(SolveStatus.unsolvable,
          'Impossible complete triple clearance/objective inventory', 0, []);
    }

    // Current authoring deliberately provides this cheap candidate. It is a
    // proof only AFTER actual engine replay, never just a divisibility check.
    final reverse = ordered.reversed.map((t) => t.id).toList();
    if (replay(tiles, board, tile, reverse, objective: objective)) {
      return SolveResult(SolveStatus.solved,
          'Engine-replayed reverse paint order', 0, reverse);
    }

    final types = inventory.keys.toList();
    final typeIndex = ordered.map((t) => types.indexOf(t.type)).toList();
    final bits = List.generate(ordered.length, (i) => BigInt.one << i);
    final blockers = List.generate(ordered.length, (_) => BigInt.zero);
    for (var i = 0; i < ordered.length; i++) {
      for (var j = i + 1; j < ordered.length; j++) {
        if (ordered[i].overlaps(ordered[j], board, tile)) {
          blockers[i] |= bits[j];
        }
      }
    }
    final failed = <BigInt>{};
    final counts = List<int>.filled(types.length, 0);
    final path = <String>[];
    var nodes = 0;
    var cutoff = false;
    bool search(BigInt remaining, int trayCount) {
      if (watch.elapsed >= timeLimit || nodes >= maxNodes) {
        cutoff = true;
        return false;
      }
      nodes++;
      if (remaining == BigInt.zero) return trayCount == 0;
      // A tray still full after triple resolution is lost on that move.
      // Matching resolves first, so a seventh-slot triple remains legal.
      if (trayCount >= GameEngine.trayLimit || failed.contains(remaining)) {
        return false;
      }
      final candidates = <int>[
        for (var i = 0; i < ordered.length; i++)
          if ((remaining & bits[i]) != BigInt.zero &&
              (remaining & blockers[i]) == BigInt.zero)
            i,
      ]..sort((a, b) {
          final priority = counts[typeIndex[b]].compareTo(counts[typeIndex[a]]);
          return priority != 0 ? priority : b.compareTo(a);
        });
      for (final i in candidates) {
        final type = typeIndex[i];
        final previous = counts[type];
        counts[type] = (previous + 1) % 3;
        path.add(ordered[i].id);
        if (search(remaining ^ bits[i], trayCount + (previous == 2 ? -2 : 1))) {
          return true;
        }
        path.removeLast();
        counts[type] = previous;
        if (cutoff) return false;
      }
      // Tray counts are determined by removed tile types modulo three;
      // therefore the remaining-board mask is a complete memoization key.
      failed.add(remaining);
      return false;
    }

    final solved = search((BigInt.one << ordered.length) - BigInt.one, 0);
    if (solved) {
      if (!replay(tiles, board, tile, path, objective: objective)) {
        return SolveResult(SolveStatus.unknown,
            'Solver/engine disagreement: witness rejected', nodes, []);
      }
      return SolveResult(SolveStatus.solved, 'Engine-replayed search witness',
          nodes, List.of(path));
    }
    return SolveResult(
      cutoff ? SolveStatus.unknown : SolveStatus.unsolvable,
      cutoff ? 'TIMEOUT or node budget exhausted' : 'Exhaustive tap search',
      nodes,
      const [],
    );
  }
}
