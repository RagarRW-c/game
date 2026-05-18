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
        return (originalIndexById[a.id] ?? 0).compareTo(
          originalIndexById[b.id] ?? 0,
        );
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
    final validBoard = boardSize.width.isFinite &&
        boardSize.height.isFinite &&
        boardSize.width > 0 &&
        boardSize.height > 0;
    final validTile = tileSize.width.isFinite &&
        tileSize.height.isFinite &&
        tileSize.width > 0 &&
        tileSize.height > 0;
    _boardSize = validBoard ? boardSize : Size.zero;
    _tileSize = validTile ? tileSize : Size.zero;
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

    _sanitizeTray();
    if (tray.length >= trayLimit) {
      result = GameResult.lost;
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

  /// Triple-match resolution happens immediately after every collection. Keeping
  /// tray IDs instead of tile objects lets animations locate canonical tile data.
  void _removeTriplesFromTray({Set<String>? preferredMatchedIds}) {
    final matchedIds = <String>{};

    if (preferredMatchedIds != null && preferredMatchedIds.length >= 3) {
      final preferredByType = <String, List<String>>{};
      for (final id in preferredMatchedIds) {
        final tile = tileById(id);
        if (tile == null) continue;
        preferredByType.putIfAbsent(tile.type, () => <String>[]).add(id);
      }
      for (final ids in preferredByType.values) {
        if (ids.length >= 3) matchedIds.addAll(ids.take(3));
      }
    }

    _sanitizeTray();
    final idsByType = <String, List<String>>{};
    for (final id in List<String>.from(tray)) {
      if (matchedIds.contains(id)) continue;
      final tile = tileById(id);
      if (tile == null) continue;
      idsByType.putIfAbsent(tile.type, () => <String>[]).add(id);
    }

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
    final active = boardTiles;
    if (active.length < 2) return;

    _saveSnapshot();
    final shuffledTypes = active.map((tile) => tile.type).toList()
      ..shuffle(_random);
    var typeIndex = 0;
    tiles = tiles.map((tile) {
      if (tile.state != TileState.board) return tile;
      return tile.copyWith(type: shuffledTypes[typeIndex++]);
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

  bool collectAvailableTriple(Size boardSize, Size tileSize) {
    if (result != GameResult.playing) return false;
    updateBoardGeometry(boardSize, tileSize);
    final idsByType = <String, List<String>>{};
    for (final tile in renderedBoardTiles) {
      if (isTileCovered(tile)) continue;
      idsByType.putIfAbsent(tile.type, () => <String>[]).add(tile.id);
    }

    List<String>? triple;
    for (final entry in idsByType.entries) {
      if (entry.value.length >= 3) {
        triple = entry.value;
        break;
      }
    }
    if (triple == null) return false;

    final tripleIds = triple.take(3).toList();
    final tripleIdSet = tripleIds.toSet();
    _saveSnapshot();
    tiles = tiles
        .map((tile) => tripleIdSet.contains(tile.id)
            ? tile.copyWith(state: TileState.tray)
            : tile)
        .toList();
    tray = <String>[...tray, ...tripleIds].take(trayLimit + 1).toList();
    _removeTriplesFromTray(preferredMatchedIds: tripleIdSet);
    _updateResult();
    return true;
  }

  void undo() {
    if (!canUndo) return;
    final snapshot = _history.removeLast();
    tiles = List<Tile>.from(snapshot.tiles);
    tray = List<String>.from(snapshot.tray);
    _sanitizeTray();
    result = GameResult.playing;
  }

  void _sanitizeTray() {
    final knownIds = tiles.map((tile) => tile.id).toSet();
    final seenIds = <String>{};
    tray = tray.where((id) => knownIds.contains(id) && seenIds.add(id)).toList();
  }

  void _saveSnapshot() {
    _history.add(GameSnapshot(
      tiles: List<Tile>.from(tiles),
      tray: List<String>.from(tray),
    ));
    if (_history.length > 20) _history.removeAt(0);
  }

  void _updateResult() {
    _sanitizeTray();
    if (tray.length > trayLimit) {
      result = GameResult.lost;
    } else if (tiles.every((tile) => tile.state == TileState.matched)) {
      result = GameResult.won;
    }
  }
}
