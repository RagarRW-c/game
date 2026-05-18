import 'dart:math';
import 'dart:ui';

import 'game_result.dart';
import 'tile.dart';

class GameSnapshot {
  const GameSnapshot({required this.tiles, required this.tray});

  final List<Tile> tiles;
  final List<String> tray;
}

class GameEngine {
  GameEngine(List<Tile> startingTiles)
      : tiles = List<Tile>.from(startingTiles),
        tray = <String>[];

  static const int trayLimit = 7;
  final Random _random = Random();
  final List<GameSnapshot> _history = <GameSnapshot>[];
  Size _boardSize = Size.zero;
  Size _fallbackTileSize = Size.zero;

  List<Tile> tiles;
  List<String> tray;
  GameResult result = GameResult.playing;

  List<Tile> get boardTiles =>
      tiles.where((tile) => tile.state == TileState.board).toList();

  List<Tile> get paintOrderedBoardTiles => List<Tile>.from(boardTiles)
    ..sort((a, b) {
      final layerComparison = a.zIndex.compareTo(b.zIndex);
      return layerComparison != 0 ? layerComparison : a.id.compareTo(b.id);
    });

  bool get canUndo => _history.isNotEmpty && result == GameResult.playing;

  Tile? tileById(String id) {
    for (final tile in tiles) {
      if (tile.id == id) return tile;
    }
    return null;
  }

  void configureBoardGeometry(Size boardSize, Size fallbackTileSize) {
    _boardSize = boardSize;
    _fallbackTileSize = fallbackTileSize;
  }

  /// Returns true when any visible tile painted above [tile] intersects this
  /// tile's rendered rectangle. `Rect.overlaps` is intentionally strict: if
  /// even a tiny area intersects, the lower tile is considered covered and
  /// cannot be tapped. Edge-only contact is allowed because there is no covered
  /// area. Tiles with a larger z-index/layer are above lower layers; ties use
  /// the same deterministic paint order as the UI so same-layer overlaps cannot
  /// accidentally remain tappable. This matches layered Mahjong/Triple Tile
  /// behavior where only fully uncovered, top-most visible tiles interact.
  bool isTileCovered(Tile tile) {
    if (!tile.visibleOnBoard || _boardSize == Size.zero) return true;

    final tileRect = tile.boardRect(_boardSize, _fallbackTileSize);
    for (final other in boardTiles) {
      if (other.id == tile.id || !_isAbove(other, tile)) continue;
      if (tileRect.overlaps(other.boardRect(_boardSize, _fallbackTileSize))) {
        return true;
      }
    }
    return false;
  }

  bool _isAbove(Tile possibleCover, Tile tile) {
    if (possibleCover.zIndex != tile.zIndex) {
      return possibleCover.zIndex > tile.zIndex;
    }
    return possibleCover.id.compareTo(tile.id) > 0;
  }

  bool isUncovered(Tile candidate, Size boardSize, Size tileSize) {
    configureBoardGeometry(boardSize, tileSize);
    return !isTileCovered(candidate);
  }

  bool tapTile(String id, Size boardSize, Size tileSize) {
    if (result != GameResult.playing) return false;
    configureBoardGeometry(boardSize, tileSize);
    final tile = tileById(id);
    if (tile == null || !isUncovered(tile, boardSize, tileSize)) return false;

    _saveSnapshot();
    tiles = tiles
        .map((item) => item.id == id ? item.copyWith(state: TileState.tray) : item)
        .toList();
    tray = <String>[...tray, id];
    _removeTriplesFromTray();
    _updateResult();
    return true;
  }

  /// Triple-match resolution happens immediately after every tap. Keeping tray
  /// IDs instead of tile objects lets animations locate the canonical tile data.
  void _removeTriplesFromTray() {
    final idsByType = <String, List<String>>{};
    for (final id in tray) {
      final tile = tileById(id);
      if (tile == null) continue;
      idsByType.putIfAbsent(tile.type, () => <String>[]).add(id);
    }

    final matchedIds = <String>{};
    for (final entry in idsByType.entries) {
      if (entry.value.length >= 3) {
        matchedIds.addAll(entry.value.take(3));
      }
    }
    if (matchedIds.isEmpty) return;

    tiles = tiles
        .map((tile) => matchedIds.contains(tile.id)
            ? tile.copyWith(state: TileState.matched)
            : tile)
        .toList();
    tray = tray.where((id) => !matchedIds.contains(id)).toList();
  }

  void shuffleBoard() {
    if (result != GameResult.playing) return;
    _saveSnapshot();
    final active = boardTiles;
    final positions = active.map((tile) => (x: tile.x, y: tile.y, layer: tile.layer)).toList()
      ..shuffle(_random);
    var positionIndex = 0;
    tiles = tiles.map((tile) {
      if (tile.state != TileState.board) return tile;
      final position = positions[positionIndex++];
      return Tile(
        id: tile.id,
        type: tile.type,
        x: position.x,
        y: position.y,
        layer: position.layer,
        width: tile.width,
        height: tile.height,
        state: tile.state,
      );
    }).toList();
  }

  String? hint(Size boardSize, Size tileSize) {
    if (result != GameResult.playing) return null;
    final uncovered = boardTiles
        .where((tile) => isUncovered(tile, boardSize, tileSize))
        .toList()
      ..sort((a, b) => a.layer.compareTo(b.layer));
    if (uncovered.isEmpty) return null;

    final trayTypes = tray.map((id) => tileById(id)?.type).whereType<String>();
    for (final type in trayTypes) {
      for (final tile in uncovered) {
        if (tile.type == type) return tile.id;
      }
    }
    return uncovered.last.id;
  }

  void undo() {
    if (!canUndo) return;
    final snapshot = _history.removeLast();
    tiles = List<Tile>.from(snapshot.tiles);
    tray = List<String>.from(snapshot.tray);
    result = GameResult.playing;
  }

  void _saveSnapshot() {
    _history.add(GameSnapshot(
      tiles: List<Tile>.from(tiles),
      tray: List<String>.from(tray),
    ));
    if (_history.length > 20) _history.removeAt(0);
  }

  void _updateResult() {
    if (tray.length > trayLimit) {
      result = GameResult.lost;
    } else if (tiles.every((tile) => tile.state == TileState.matched)) {
      result = GameResult.won;
    }
  }
}
