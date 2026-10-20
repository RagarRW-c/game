import 'dart:ui';

import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

/// Independent exhaustive tap search for regression fixtures. It uses actual
/// engine states/transitions, not solver blocker masks or modulo-three updates.
/// A budget cutoff throws (inconclusive), never reports an impossible board.
bool engineCanClearWithoutBoosters(List<Tile> tiles, Size board, Size tile,
    {int maxStates = 100000}) {
  final seen = <String>{};
  bool visit(GameEngine engine) {
    if (engine.result == GameResult.won) {
      return engine.boardTiles.isEmpty &&
          engine.tray.isEmpty &&
          engine.tiles.every((t) => t.state == TileState.matched);
    }
    if (engine.result == GameResult.lost) return false;

    // For taps only, board IDs and the actual tray type multiset determine
    // future play. Tray order/history matter to boosters, which are excluded.
    final trayTypes =
        engine.tray.map((id) => engine.tileById(id)!.type).toList()..sort();
    final key =
        '${engine.boardTiles.map((t) => t.id).join(',')}|${trayTypes.join(',')}';
    if (!seen.add(key)) return false;
    if (seen.length > maxStates) {
      throw StateError(
          'Engine oracle inconclusive: exceeded $maxStates states');
    }
    for (final candidate in engine.renderedBoardTiles) {
      if (engine.isTileCovered(candidate)) continue;
      final next = GameEngine(engine.tiles)..tray = List.of(engine.tray);
      if (next.tapTile(candidate.id, board, tile) && visit(next)) return true;
    }
    return false;
  }

  return visit(GameEngine(tiles)..updateBoardGeometry(board, tile));
}
