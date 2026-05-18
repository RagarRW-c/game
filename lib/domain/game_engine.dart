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

  /// Board tiles in the same order Flutter paints them in the board Stack.
  ///
  /// Later entries are rendered above earlier entries and therefore win any
  /// visible overlap. Ties within a layer keep the canonical tile list order so
  /// coverage checks use the same z-index as the UI.
  List<Tile> get renderedBoardTiles {
    final originalIndexById = <String, int>{};
    for (var index = 0; index < tiles.length; index++) {
      originalIndexById[tiles[index].id] = index;
    }

    return boardTiles.toList()
      ..sort((a, b) {
        final layerComparison = a.layer.compareTo(b.layer);
        if (layerComparison != 0) return layerComparison;
        return originalIndexById[a.id]!.compareTo(originalIndexById[b.id]!);
      });
  }

  bool get canUndo => _history.isNotEmpty && result == GameResult.playing;

  Tile? tileById(String id) {
    for (final tile in tiles) {
      if (tile.id == id) return tile;
    }
    return null;
  }

  Size _boardSize = Size.zero;
  Size _tileSize = Size.zero;

  /// Updates the rendered board geometry used for tile overlap checks.
  ///
  /// Level data stores normalized coordinates, so coverage has to be evaluated
  /// against the current rendered board and tile dimensions.
  void updateBoardGeometry(Size boardSize, Size tileSize) {
    _boardSize = boardSize;
    _tileSize = tileSize;
  }

  /// A board tile is covered when any active tile rendered above it has a
  /// visible rectangular overlap with it.
  bool isTileCovered(Tile tile) {
    if (tile.state != TileState.board ||
        _boardSize == Size.zero ||
        _tileSize == Size.zero) {
      return false;
    }

    final renderedTiles = renderedBoardTiles;
    final tileRenderIndex = renderedTiles.indexWhere(
      (item) => item.id == tile.id,
    );
    if (tileRenderIndex == -1) return false;

    return renderedTiles
        .skip(tileRenderIndex + 1)
        .any((other) => tile.overlaps(other, _boardSize, _tileSize));
  }

  /// A board tile is uncovered only when no tile rendered above it overlaps it.
  bool isUncovered(Tile candidate, Size boardSize, Size tileSize) {
    updateBoardGeometry(boardSize, tileSize);
    return candidate.state == TileState.board && !isTileCovered(candidate);
  }

  bool tapTile(String id, Size boardSize, Size tileSize) {
    if (result != GameResult.playing) return false;
    updateBoardGeometry(boardSize, tileSize);
    final tile = tileById(id);
    if (tile == null || tile.state != TileState.board || isTileCovered(tile)) {
      return false;
    }

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
    final uncovered = renderedBoardTiles
        .where((tile) => isUncovered(tile, boardSize, tileSize))
        .toList();
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
