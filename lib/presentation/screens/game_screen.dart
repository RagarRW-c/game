import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../../data/level_repository.dart';
import '../../domain/game_engine.dart';
import '../../domain/game_result.dart';
import '../../domain/level.dart';
import '../../domain/tile.dart';
import '../../main.dart';
import '../widgets/game_tile.dart';
import 'final_code_screen.dart';
import 'main_menu_screen.dart';
import 'win_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level});

  static const route = '/game';
  final int level;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int _maxBoosterUses = 2;

  late Future<LevelDefinition> _levelFuture;
  late AppScope _scope;
  late NavigatorState _navigator;
  GameEngine? _engine;
  String? _hintedTileId;
  int _undoUsesRemaining = _maxBoosterUses;
  int _hintUsesRemaining = _maxBoosterUses;
  int _shuffleUsesRemaining = _maxBoosterUses;
  bool _gameOverDialogShowing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    _navigator = Navigator.of(context);
    _levelFuture = _scope.levelRepository.loadLevel(widget.level);
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _levelFuture = _scope.levelRepository.loadLevel(widget.level);
      _engine = null;
      _resetAnimationState();
      _resetBoosterUses();
    }
  }

  void _ensureEngine(LevelDefinition level) {
    _engine ??= GameEngine(level.tiles);
  }

  Size _tileSize(double width) {
    final side = (width * 0.16).clamp(50.0, 70.0).toDouble();
    return Size(side, side);
  }

  bool _safeSetState(VoidCallback update) {
    if (!mounted) return false;
    setState(update);
    return true;
  }

  void _playSfx(Future<void> Function() play, String cue) {
    unawaited(
      play().catchError((Object error, StackTrace stackTrace) {
        debugPrint('SFX $cue failed: $error');
      }),
    );
  }

  void _resetAnimationState() {
    _hintedTileId = null;
  }

  void _resetBoosterUses() {
    _undoUsesRemaining = _maxBoosterUses;
    _hintUsesRemaining = _maxBoosterUses;
    _shuffleUsesRemaining = _maxBoosterUses;
  }

  void _debugValidateTiles(String source, GameEngine engine) {
    final trayIds = List<String>.from(engine.tray);
    final trayIdSet = trayIds.toSet();
    final seenTileIds = <String>{};
    final duplicateTileIds = <String>{};
    final seenTrayIds = <String>{};
    final duplicateTrayIds = <String>{};
    final unknownTrayIds = <String>[];
    final invalidTypeIds = <String>[];
    final boardTrayConflicts = <String>[];
    final activeButNotBoardOrTray = <String>[];

    for (final id in trayIds) {
      if (!seenTrayIds.add(id)) duplicateTrayIds.add(id);
      if (engine.tileById(id) == null) unknownTrayIds.add(id);
    }

    for (final tile in engine.tiles) {
      if (!seenTileIds.add(tile.id)) duplicateTileIds.add(tile.id);
      if (tile.state != TileState.matched &&
          !tileCatalog.containsKey(tile.type)) {
        invalidTypeIds.add('${tile.id}:${tile.type}');
      }
      if (tile.state == TileState.board && trayIdSet.contains(tile.id)) {
        boardTrayConflicts.add(tile.id);
      }
    }

    final boardVisibleCount = engine.tiles
        .where((tile) =>
            tile.state != TileState.matched && !trayIdSet.contains(tile.id))
        .length;
    final removedCount =
        engine.tiles.where((tile) => tile.state == TileState.matched).length;

    debugPrint(
      'Tile validation [$source]: total=${engine.tiles.length}, '
      'boardVisible=$boardVisibleCount, tray=${trayIds.length}, '
      'removed=$removedCount, activeNeither=${activeButNotBoardOrTray.length}',
    );
    if (duplicateTileIds.isNotEmpty) {
      debugPrint(
          'Tile validation [$source]: duplicate tile ids=${duplicateTileIds.join(',')}');
    }
    if (duplicateTrayIds.isNotEmpty) {
      debugPrint(
          'Tile validation [$source]: duplicate tray ids=${duplicateTrayIds.join(',')}');
    }
    if (unknownTrayIds.isNotEmpty) {
      debugPrint(
          'Tile validation [$source]: unknown tray ids=${unknownTrayIds.join(',')}');
    }
    if (invalidTypeIds.isNotEmpty) {
      debugPrint(
          'Tile validation [$source]: active invalid type/icon=${invalidTypeIds.join(',')}');
    }
    if (boardTrayConflicts.isNotEmpty) {
      debugPrint(
          'Tile validation [$source]: board/tray conflicts=${boardTrayConflicts.join(',')}');
    }
    if (activeButNotBoardOrTray.isNotEmpty) {
      debugPrint(
          'Tile validation [$source]: active neither board nor tray=${activeButNotBoardOrTray.join(',')}');
    }
  }

  Future<void> _onTileTap(
    LevelDefinition level,
    Tile tile,
    Size boardSize,
    Size tileSize,
  ) async {
    final engine = _engine;
    if (engine == null || engine.result != GameResult.playing) {
      return;
    }

    final canonicalTile = engine.tileById(tile.id);
    if (canonicalTile == null ||
        !engine.isUncovered(canonicalTile, boardSize, tileSize)) {
      debugPrint('Tile selection ignored: id=${tile.id}, selectable=false');
      return;
    }

    final beforeTrayIds = List<String>.from(engine.tray);
    debugPrint(
        'Tile selection started: id=${canonicalTile.id}, tray=${beforeTrayIds.length}');

    late final bool moved;
    if (!_safeSetState(() {
      _hintedTileId = null;
      moved = engine.tapTile(canonicalTile.id, boardSize, tileSize);
    })) {
      return;
    }
    _playSfx(_scope.audioService.playTap, 'tap');

    if (!moved) {
      debugPrint(
          'Tile selection aborted: id=${canonicalTile.id}, engine rejected move');
      _debugValidateTiles('tap-rejected', engine);
      if (engine.result == GameResult.lost) {
        await _handleGameOver(level: level);
      }
      return;
    }

    final matchedIds = _matchedIdsAfterMove(
      beforeTrayIds,
      collectedId: canonicalTile.id,
    );
    debugPrint(
        'Tray insertion complete: id=${canonicalTile.id}, tray=${engine.tray.length}');
    if (matchedIds.isNotEmpty) {
      debugPrint('Match removed: ids=${matchedIds.join(',')}');
      _playSfx(_scope.audioService.playMatch, 'match');
    }
    _debugValidateTiles('tap', engine);

    if (engine.result == GameResult.won) await _handleWin();
    if (!mounted) return;
    if (engine.result == GameResult.lost) await _handleGameOver(level: level);
  }

  Future<void> _useCatPowerUp(
    LevelDefinition level,
    Size boardSize,
    Size tileSize,
  ) async {
    final engine = _engine;
    if (_hintUsesRemaining <= 0 ||
        engine == null ||
        engine.result != GameResult.playing) {
      return;
    }
    final catIds = _availableTripleIds(boardSize, tileSize);
    if (catIds == null) {
      final hintId = engine.hint(boardSize, tileSize);
      debugPrint('Cat helper hint: id=$hintId');
      if (hintId == null) return;
      _safeSetState(() {
        _hintedTileId = hintId;
        _hintUsesRemaining--;
      });
      _debugValidateTiles('hint-highlight', engine);
      _playSfx(_scope.audioService.playBooster, 'booster');
      return;
    }

    final beforeTrayIds = List<String>.from(engine.tray);
    debugPrint('Cat helper started: ids=${catIds.join(',')}');
    late final bool collected;
    if (!_safeSetState(() {
      _hintedTileId = null;
      collected = engine.collectAvailableTriple(
        boardSize,
        tileSize,
        preferredIds: catIds.toSet(),
      );
      if (collected) _hintUsesRemaining--;
    })) {
      return;
    }
    _playSfx(_scope.audioService.playBooster, 'booster');

    if (!collected) {
      debugPrint('Cat helper aborted: no triple was collected');
      _debugValidateTiles('cat-rejected', engine);
      return;
    }

    final removedIds =
        _matchedIdsAfterMove(beforeTrayIds, preferredIds: catIds.toSet());
    debugPrint(
        'Cat helper tray insertion: ids=${catIds.join(',')}, tray=${engine.tray.length}');
    if (removedIds.isNotEmpty) {
      debugPrint('Match removed: ids=${removedIds.join(',')}');
      _playSfx(_scope.audioService.playMatch, 'match');
    }
    debugPrint('Cat helper complete');
    _debugValidateTiles('cat', engine);
    if (engine.result == GameResult.won) await _handleWin();
    if (!mounted) return;
    if (engine.result == GameResult.lost) await _handleGameOver(level: level);
  }

  List<String>? _availableTripleIds(Size boardSize, Size tileSize) {
    final engine = _engine;
    if (engine == null || engine.result != GameResult.playing) return null;
    engine.updateBoardGeometry(boardSize, tileSize);
    final idsByType = <String, List<String>>{};
    for (final tile in List<Tile>.from(engine.renderedBoardTiles).reversed) {
      if (engine.isTileCovered(tile)) continue;
      idsByType.putIfAbsent(tile.type, () => <String>[]).add(tile.id);
    }
    for (final ids in idsByType.values) {
      if (ids.length >= 3) return ids.take(3).toList();
    }
    return null;
  }

  Set<String> _matchedIdsAfterMove(
    List<String> beforeTrayIds, {
    String? collectedId,
    Set<String>? preferredIds,
  }) {
    final engine = _engine;
    if (engine == null) return <String>{};
    final afterTrayIds = engine.tray.toSet();
    final candidateIds = <String>{
      ...beforeTrayIds,
      if (collectedId != null) collectedId,
      if (preferredIds != null) ...preferredIds,
    };
    return candidateIds
        .where((id) {
          final tile = engine.tileById(id);
          return tile != null &&
              tile.state == TileState.matched &&
              !afterTrayIds.contains(id);
        })
        .take(3)
        .toSet();
  }

  Future<void> _handleGameOver({required LevelDefinition? level}) async {
    if (_gameOverDialogShowing || !mounted) return;
    _gameOverDialogShowing = true;
    _playSfx(_scope.audioService.playLose, 'lose');
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Game Over'),
        content: const Text(
            'The tray is full. Restart the level or return to the menu.'),
        actions: [
          TextButton(
            onPressed: () {
              _navigator.pop();
              _navigator.popUntil(ModalRoute.withName(MainMenuScreen.route));
            },
            child: const Text('Return to Menu'),
          ),
          FilledButton.icon(
            onPressed: level == null
                ? null
                : () {
                    _navigator.pop();
                    if (!mounted) return;
                    _safeSetState(() {
                      _engine = GameEngine(level.tiles);
                      _resetAnimationState();
                      _resetBoosterUses();
                    });
                  },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Restart Level'),
          ),
        ],
      ),
    );
    if (mounted) _gameOverDialogShowing = false;
  }

  Future<void> _handleWin() async {
    if (!mounted) return;
    final scope = _scope;
    await scope.progressRepository.unlockNextLevel(widget.level);
    if (!mounted) return;
    _playSfx(scope.audioService.playWin, 'win');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WinScreen(
        level: widget.level,
        isFinalLevel: widget.level == LevelRepository.levelCount,
        onMap: () {
          if (!mounted) return;
          _navigator.pop();
          _navigator.pop();
        },
        onNext: () async {
          if (!mounted) return;
          _navigator.pop();
          if (widget.level == LevelRepository.levelCount) {
            final code = await scope.progressRepository.finalCode();
            if (!mounted) return;
            await _navigator.pushReplacement(
              MaterialPageRoute<void>(
                  builder: (_) => FinalCodeScreen(code: code)),
            );
          } else {
            if (!mounted) return;
            await _navigator.pushReplacementNamed(
              GameScreen.route,
              arguments: widget.level + 1,
            );
          }
        },
      ),
    );
  }

  List<Tile> _renderedBoardSnapshot(
    GameEngine engine,
    Size boardSize,
    Size tileSize,
  ) {
    engine.updateBoardGeometry(boardSize, tileSize);
    final trayIds = List<String>.from(engine.tray).toSet();
    final seenIds = <String>{};
    final boardIds = List<Tile>.from(engine.tiles)
        .where((tile) {
          if (!seenIds.add(tile.id)) {
            debugPrint('Board render skipped duplicate tile id=${tile.id}');
            return false;
          }
          if (tile.state == TileState.matched) return false;
          if (trayIds.contains(tile.id)) {
            debugPrint('Board render skipped tray tile id=${tile.id}');
            return false;
          }
          if (!tileCatalog.containsKey(tile.type)) {
            debugPrint(
              'Board render active tile has unknown type/icon id=${tile.id}, type=${tile.type}',
            );
          }
          return true;
        })
        .map((tile) => tile.id)
        .toSet();
    return List<Tile>.from(engine.renderedBoardTiles)
        .where((tile) => boardIds.contains(tile.id))
        .toList(growable: false);
  }

  Map<String, bool> _coveredByIdSnapshot(
    List<Tile> renderedBoardTiles,
    Size boardSize,
    Size tileSize,
  ) {
    final tiles = List<Tile>.from(renderedBoardTiles);
    final coveredById = <String, bool>{};
    for (var index = 0; index < tiles.length; index++) {
      final tile = tiles[index];
      coveredById[tile.id] = tiles
          .skip(index + 1)
          .any((other) => tile.overlaps(other, boardSize, tileSize));
    }
    return coveredById;
  }

  List<Tile?> _traySnapshot(GameEngine engine) {
    final tilesById = <String, Tile>{
      for (final tile in List<Tile>.from(engine.tiles)) tile.id: tile,
    };
    final seenIds = <String>{};
    final visibleIds = List<String>.from(engine.tray)
        .where((id) {
          final tile = tilesById[id];
          if (tile == null) {
            debugPrint('Tray render skipped unknown tile id=$id');
            return false;
          }
          if (!seenIds.add(id)) {
            debugPrint('Tray render skipped duplicate tile id=$id');
            return false;
          }
          if (!tileCatalog.containsKey(tile.type)) {
            debugPrint(
              'Tray render tile has unknown type/icon id=$id, type=${tile.type}',
            );
          }
          return true;
        })
        .take(GameEngine.trayLimit)
        .toList(growable: false);

    return List<Tile?>.generate(
      GameEngine.trayLimit,
      (index) =>
          index < visibleIds.length ? tilesById[visibleIds[index]] : null,
      growable: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LevelDefinition>(
      future: _levelFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Game build failed to load level: ${snapshot.error}');
          return _FallbackGameScaffold(
            title: 'Level ${widget.level}',
            message:
                'We could not load this level. Please go back and try again.',
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final level = snapshot.data!;
        _ensureEngine(level);
        final engine = _engine!;
        final boardCount = List<Tile>.from(engine.boardTiles).length;

        return Scaffold(
          appBar: AppBar(
            title: Text(level.name),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: Text(
                    '$boardCount left',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              try {
                final boardHeight = constraints.maxHeight - 156;
                final boardSize = Size(
                  constraints.maxWidth,
                  boardHeight.clamp(360.0, 620.0).toDouble(),
                );
                final tileSize = _tileSize(constraints.maxWidth);
                final renderedBoardTiles = _renderedBoardSnapshot(
                  engine,
                  boardSize,
                  tileSize,
                );
                final coveredById = _coveredByIdSnapshot(
                  renderedBoardTiles,
                  boardSize,
                  tileSize,
                );
                final trayTiles = _traySnapshot(engine);
                final hintedTileId = _hintedTileId;
                final maxLayer = renderedBoardTiles.isEmpty
                    ? 0
                    : renderedBoardTiles.map((tile) => tile.layer).reduce(max);
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFB8F7FF), Color(0xFFFFF6C7)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: boardSize.width,
                            height: boardSize.height,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    margin: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.34),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                                for (final tile in renderedBoardTiles)
                                  Positioned(
                                    key: ValueKey(tile.id),
                                    left: tile.x * boardSize.width,
                                    top: tile.y * boardSize.height,
                                    width: tileSize.width,
                                    height: tileSize.height,
                                    child: Builder(
                                      builder: (context) {
                                        final covered =
                                            coveredById[tile.id] ?? true;
                                        final depth = maxLayer == 0
                                            ? 1.0
                                            : tile.layer / maxLayer;
                                        return IgnorePointer(
                                          ignoring: covered,
                                          child: GameTileWidget(
                                            tile: tile,
                                            enabled: !covered,
                                            blocked: covered,
                                            depth: depth,
                                            highlighted:
                                                hintedTileId == tile.id,
                                            onTap: covered
                                                ? null
                                                : () => _onTileTap(
                                                      level,
                                                      tile,
                                                      boardSize,
                                                      tileSize,
                                                    ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _BoosterBar(
                        onShuffle: _shuffleUsesRemaining > 0
                            ? () {
                                debugPrint('Shuffle started');
                                late final bool shuffled;
                                _safeSetState(() {
                                  _hintedTileId = null;
                                  shuffled = engine.shuffleBoard();
                                  if (shuffled) _shuffleUsesRemaining--;
                                });
                                if (shuffled) {
                                  _playSfx(_scope.audioService.playBooster,
                                      'booster');
                                  _debugValidateTiles('shuffle', engine);
                                }
                                debugPrint('Shuffle completed');
                              }
                            : null,
                        onHint: _hintUsesRemaining > 0
                            ? () => _useCatPowerUp(level, boardSize, tileSize)
                            : null,
                        undoRemaining: _undoUsesRemaining,
                        hintRemaining: _hintUsesRemaining,
                        shuffleRemaining: _shuffleUsesRemaining,
                        onUndo: engine.canUndo && _undoUsesRemaining > 0
                            ? () {
                                debugPrint('Undo requested');
                                late final bool undone;
                                _safeSetState(() {
                                  undone = engine.undo();
                                  if (undone) {
                                    _resetAnimationState();
                                    _undoUsesRemaining--;
                                  }
                                });
                                if (undone) {
                                  _playSfx(_scope.audioService.playBooster,
                                      'booster');
                                  _debugValidateTiles('undo', engine);
                                }
                              }
                            : null,
                      ),
                      _Tray(
                        trayTiles: trayTiles,
                      ),
                    ],
                  ),
                );
              } catch (error, stackTrace) {
                debugPrint('Game build fallback: $error');
                debugPrint('$stackTrace');
                return const _FallbackGameBody();
              }
            },
          ),
        );
      },
    );
  }
}

class _FallbackGameScaffold extends StatelessWidget {
  const _FallbackGameScaffold({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _FallbackGameBody(message: message),
    );
  }
}

class _FallbackGameBody extends StatelessWidget {
  const _FallbackGameBody({
    this.message =
        'The board hit an invalid state. Please leave and reopen the level.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _BoosterBar extends StatelessWidget {
  const _BoosterBar({
    required this.onShuffle,
    required this.onHint,
    required this.onUndo,
    required this.undoRemaining,
    required this.hintRemaining,
    required this.shuffleRemaining,
  });

  final VoidCallback? onShuffle;
  final VoidCallback? onHint;
  final VoidCallback? onUndo;
  final int undoRemaining;
  final int hintRemaining;
  final int shuffleRemaining;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onUndo,
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text('Undo ($undoRemaining)'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onHint,
              icon: const Icon(Icons.pets_rounded),
              label: Text('Hint ($hintRemaining)'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onShuffle,
              icon: const Icon(Icons.shuffle_rounded),
              label: Text('Shuffle ($shuffleRemaining)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({required this.trayTiles});

  final List<Tile?> trayTiles;

  @override
  Widget build(BuildContext context) {
    final slots = List<Tile?>.from(trayTiles);
    final slotWidgets = <Widget>[];

    for (var index = 0; index < GameEngine.trayLimit; index++) {
      final tile = index < slots.length ? slots[index] : null;

      slotWidgets.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: tile == null
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  )
                : GameTileWidget(
                    key: ValueKey('tray_${tile.id}'),
                    tile: tile,
                    enabled: true,
                    highlighted: false,
                    trayTile: true,
                  ),
          ),
        ),
      );
    }

    return Container(
      height: 92,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Row(children: slotWidgets),
    );
  }
}
