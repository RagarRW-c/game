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

  List<Tile> tiles;
  List<String> tray;
  GameResult result = GameResult.playing;

  List<Tile> get boardTiles =>
      tiles.where((tile) => tile.state == TileState.board).toList();

  bool get canUndo => _history.isNotEmpty && result == GameResult.playing;

  Tile? tileById(String id) {
    for (final tile in tiles) {
      if (tile.id == id) return tile;
    }
    return null;
  }

  /// A board tile is uncovered when no higher-layer active tile overlaps it.
  /// The overlap check uses the rendered board and tile sizes so level JSON can
  /// stay responsive with normalized 0..1 coordinates on any Android phone.
  bool isUncovered(Tile candidate, Size boardSize, Size tileSize) {
    if (candidate.state != TileState.board) return false;
    final candidateRect = candidate.boardRect(boardSize, tileSize);
    return boardTiles.every((other) {
      if (other.id == candidate.id || other.layer <= candidate.layer) {
        return true;
      }
      return !candidateRect.overlaps(other.boardRect(boardSize, tileSize));
    });
  }

  bool tapTile(String id, Size boardSize, Size tileSize) {
    if (result != GameResult.playing) return false;
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
