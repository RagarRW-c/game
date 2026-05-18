import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

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
  late Future<LevelDefinition> _levelFuture;
  late AppScope _scope;
  late NavigatorState _navigator;
  GameEngine? _engine;
  String? _hintedTileId;
  String? _pickedUpTileId;
  Tile? _flyingTile;
  int _flyingTrayIndex = 0;
  bool _flightSettled = false;
  final Set<String> _catPulseTileIds = <String>{};
  final Set<String> _matchingTileIds = <String>{};
  final Map<String, Offset> _shuffleOffsets = <String, Offset>{};
  final Random _animationRandom = Random();
  bool _animatingAction = false;
  bool _gameOverDialogShowing = false;
  int _actionGeneration = 0;

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
      _actionGeneration++;
    }
  }

  @override
  void dispose() {
    _actionGeneration++;
    super.dispose();
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

  bool _isCurrentAction(int token) => mounted && token == _actionGeneration;

  void _playSfx(Future<void> Function() play, String cue) {
    unawaited(
      play().catchError((Object error, StackTrace stackTrace) {
        debugPrint('SFX $cue failed: $error');
      }),
    );
  }

  void _resetAnimationState() {
    _hintedTileId = null;
    _pickedUpTileId = null;
    _flyingTile = null;
    _flightSettled = false;
    _catPulseTileIds.clear();
    _matchingTileIds.clear();
    _shuffleOffsets.clear();
    _animatingAction = false;
  }

  Future<void> _onTileTap(
    LevelDefinition level,
    Tile tile,
    Size boardSize,
    Size tileSize,
  ) async {
    final engine = _engine;
    if (_animatingAction || engine == null || engine.result != GameResult.playing) {
      return;
    }

    final canonicalTile = engine.tileById(tile.id);
    if (canonicalTile == null ||
        canonicalTile.state != TileState.board ||
        engine.isTileCovered(canonicalTile)) {
      debugPrint('Tile selection ignored: id=${tile.id}, selectable=false');
      return;
    }

    final token = ++_actionGeneration;
    final beforeTrayIds = List<String>.from(engine.tray);
    debugPrint('Tile selection started: id=${canonicalTile.id}, tray=${beforeTrayIds.length}');

    if (!_safeSetState(() {
      _animatingAction = true;
      _pickedUpTileId = canonicalTile.id;
      _hintedTileId = null;
      _matchingTileIds.clear();
      _flyingTile = null;
      _flightSettled = false;
    })) {
      return;
    }
    _playSfx(_scope.audioService.playTap, 'tap');
    await Future<void>.delayed(const Duration(milliseconds: 115));
    if (!_isCurrentAction(token)) return;

    final moved = engine.tapTile(canonicalTile.id, boardSize, tileSize);
    if (!moved) {
      debugPrint('Tile selection aborted: id=${canonicalTile.id}, engine rejected move');
      _safeSetState(() {
        _pickedUpTileId = null;
        _animatingAction = false;
      });
      if (engine.result == GameResult.lost) {
        await _handleGameOver(level: level);
      }
      return;
    }

    final removedIds = _matchedIdsAfterMove(
      beforeTrayIds,
      collectedId: canonicalTile.id,
    );
    final flightTile = canonicalTile.copyWith(state: TileState.board);
    final trayIndex = beforeTrayIds.length.clamp(0, GameEngine.trayLimit - 1).toInt();
    debugPrint('Tray insertion: id=${canonicalTile.id}, slot=$trayIndex, tray=${engine.tray.length}');
    if (removedIds.isNotEmpty) {
      debugPrint('Match removal queued: ids=${removedIds.join(',')}');
    }

    if (!_safeSetState(() {
      _pickedUpTileId = null;
      _flyingTile = flightTile;
      _flyingTrayIndex = trayIndex;
      _flightSettled = false;
      _matchingTileIds
        ..clear()
        ..addAll(removedIds);
    })) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isCurrentAction(token) && _flyingTile?.id == canonicalTile.id) {
        _safeSetState(() => _flightSettled = true);
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 310));
    if (!_isCurrentAction(token)) return;

    if (_matchingTileIds.isNotEmpty) {
      _playSfx(_scope.audioService.playMatch, 'match');
    }
    debugPrint('Tile animation completed: id=${canonicalTile.id}');
    if (!_safeSetState(() {
      _matchingTileIds.clear();
      _flyingTile = null;
      _flightSettled = false;
      _animatingAction = false;
    })) {
      return;
    }

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
    if (_animatingAction || engine == null || engine.result != GameResult.playing) return;
    final catIds = _availableTripleIds(boardSize, tileSize);
    if (catIds == null) {
      final hintId = engine.hint(boardSize, tileSize);
      debugPrint('Cat helper hint: id=$hintId');
      _safeSetState(() => _hintedTileId = hintId);
      _playSfx(_scope.audioService.playBooster, 'booster');
      return;
    }

    final token = ++_actionGeneration;
    final beforeTrayIds = List<String>.from(engine.tray);
    debugPrint('Cat helper started: ids=${catIds.join(',')}');
    if (!_safeSetState(() {
      _animatingAction = true;
      _hintedTileId = null;
      _matchingTileIds.clear();
      _catPulseTileIds
        ..clear()
        ..addAll(catIds);
    })) {
      return;
    }
    _playSfx(_scope.audioService.playBooster, 'booster');
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!_isCurrentAction(token)) return;

    final collected = engine.collectAvailableTriple(boardSize, tileSize);
    if (!collected) {
      debugPrint('Cat helper aborted: no triple was collected');
      _safeSetState(() {
        _catPulseTileIds.clear();
        _animatingAction = false;
      });
      return;
    }

    final removedIds = _matchedIdsAfterMove(beforeTrayIds, preferredIds: catIds.toSet());
    debugPrint('Cat helper tray insertion: ids=${catIds.join(',')}, tray=${engine.tray.length}');
    if (removedIds.isNotEmpty) {
      debugPrint('Match removal queued: ids=${removedIds.join(',')}');
    }
    _safeSetState(() {
      _catPulseTileIds.clear();
      _matchingTileIds
        ..clear()
        ..addAll(removedIds);
    });
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!_isCurrentAction(token)) return;

    if (_matchingTileIds.isNotEmpty) {
      _playSfx(_scope.audioService.playMatch, 'match');
    }
    debugPrint('Cat helper animation completed');
    _safeSetState(() {
      _matchingTileIds.clear();
      _animatingAction = false;
    });
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
    return candidateIds.where((id) {
      final tile = engine.tileById(id);
      return tile != null &&
          tile.state == TileState.matched &&
          !afterTrayIds.contains(id);
    }).take(3).toSet();
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
        content: const Text('The tray is full. Restart the level or return to the menu.'),
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
                    _actionGeneration++;
                    _safeSetState(() {
                      _engine = GameEngine(level.tiles);
                      _resetAnimationState();
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
              MaterialPageRoute<void>(builder: (_) => FinalCodeScreen(code: code)),
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
    final canonicalTiles = List<Tile>.from(engine.tiles);
    final boardIds = canonicalTiles
        .where((tile) => tile.state == TileState.board)
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
    final visibleIds = <String>[
      ...List<String>.from(engine.tray),
      ...List<String>.from(_matchingTileIds),
    ]
        .where((id) => tilesById.containsKey(id) && seenIds.add(id))
        .take(GameEngine.trayLimit)
        .toList(growable: false);

    return List<Tile?>.generate(
      GameEngine.trayLimit,
      (index) => index < visibleIds.length ? tilesById[visibleIds[index]] : null,
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
            message: 'We could not load this level. Please go back and try again.',
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                final matchingTileIds = Set<String>.from(_matchingTileIds);
                final catPulseTileIds = Set<String>.from(_catPulseTileIds);
                final shuffleOffsets = Map<String, Offset>.from(_shuffleOffsets);
                final hintedTileId = _hintedTileId;
                final pickedUpTileId = _pickedUpTileId;
                final flyingTile = _flyingTile;
                final flightSettled = _flightSettled;
                final flyingTrayIndex = _flyingTrayIndex;
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
                                    color: Colors.white.withOpacity(0.34),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                              for (final tile in renderedBoardTiles)
                                AnimatedPositioned(
                                  key: ValueKey(tile.id),
                                  duration: Duration(
                                    milliseconds:
                                        shuffleOffsets.containsKey(tile.id)
                                            ? 190
                                            : 310,
                                  ),
                                  curve: shuffleOffsets.containsKey(tile.id)
                                      ? Curves.easeInOut
                                      : Curves.easeOutCubic,
                                  left: tile.x * boardSize.width +
                                      (shuffleOffsets[tile.id]?.dx ?? 0),
                                  top: tile.y * boardSize.height +
                                      (shuffleOffsets[tile.id]?.dy ?? 0),
                                  width: tileSize.width,
                                  height: tileSize.height,
                                  child: Builder(
                                    builder: (context) {
                                      final covered = coveredById[tile.id] ?? true;
                                      final depth = maxLayer == 0 ? 1.0 : tile.layer / maxLayer;
                                      final pulsing = catPulseTileIds.contains(tile.id);
                                      return IgnorePointer(
                                        ignoring: covered || _animatingAction,
                                        child: GameTileWidget(
                                          tile: tile,
                                          enabled: !covered,
                                          blocked: covered,
                                          depth: depth,
                                          pickedUp: pickedUpTileId == tile.id,
                                          highlighted: hintedTileId == tile.id || pulsing,
                                          matching: pulsing,
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
                              if (flyingTile != null)
                                AnimatedPositioned(
                                  key: ValueKey('flight_${flyingTile.id}'),
                                  duration: const Duration(milliseconds: 310),
                                  curve: Curves.easeInOutCubic,
                                  left: flightSettled
                                      ? 22 +
                                          (flyingTrayIndex *
                                              ((boardSize.width - 44) /
                                                  GameEngine.trayLimit))
                                      : flyingTile.x * boardSize.width,
                                  top: flightSettled
                                      ? boardSize.height + 62
                                      : (flyingTile.y * boardSize.height) - 8,
                                  width: tileSize.width,
                                  height: tileSize.height,
                                  child: IgnorePointer(
                                    child: GameTileWidget(
                                      tile: flyingTile,
                                      enabled: true,
                                      highlighted: true,
                                      pickedUp: !flightSettled,
                                      depth: 1,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _BoosterBar(
                      onShuffle: () async {
                        if (_animatingAction) return;
                        final token = ++_actionGeneration;
                        debugPrint('Shuffle started');
                        _safeSetState(() {
                          _animatingAction = true;
                          _hintedTileId = null;
                          _shuffleOffsets
                            ..clear()
                            ..addEntries(List<Tile>.from(engine.boardTiles).map((tile) {
                              final angle = _animationRandom.nextDouble() * pi * 2;
                              final distance = 14 + _animationRandom.nextDouble() * 22;
                              return MapEntry(
                                tile.id,
                                Offset(cos(angle) * distance, sin(angle) * distance),
                              );
                            }));
                        });
                        _playSfx(_scope.audioService.playBooster, 'booster');
                        await Future<void>.delayed(const Duration(milliseconds: 170));
                        if (!_isCurrentAction(token)) return;
                        _safeSetState(() {
                          engine.shuffleBoard();
                          _shuffleOffsets.clear();
                        });
                        await Future<void>.delayed(const Duration(milliseconds: 280));
                        if (_isCurrentAction(token)) {
                          debugPrint('Shuffle animation completed');
                          _safeSetState(() => _animatingAction = false);
                        }
                      },
                      onHint: () => _useCatPowerUp(level, boardSize, tileSize),
                      onUndo: engine.canUndo
                          ? () {
                              debugPrint('Undo requested');
                              _actionGeneration++;
                              _safeSetState(() {
                                engine.undo();
                                _resetAnimationState();
                              });
                              _playSfx(_scope.audioService.playBooster, 'booster');
                            }
                          : null,
                    ),
                    _Tray(
                      trayTiles: trayTiles,
                      matchingTileIds: matchingTileIds,
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
    this.message = 'The board hit an invalid state. Please leave and reopen the level.',
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
  });

  final VoidCallback onShuffle;
  final VoidCallback onHint;
  final VoidCallback? onUndo;

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
              label: const Text('Undo'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onHint,
              icon: const Icon(Icons.pets_rounded),
              label: const Text('Hint'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onShuffle,
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Shuffle'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({required this.trayTiles, required this.matchingTileIds});

  final List<Tile?> trayTiles;
  final Set<String> matchingTileIds;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Row(
        children: List.generate(GameEngine.trayLimit, (index) {
          final tile = index < trayTiles.length ? trayTiles[index] : null;
          final matching = tile != null && matchingTileIds.contains(tile.id);
          return Expanded(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(horizontal: matching ? 1 : 3),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                    reverseCurve: Curves.easeInOut,
                  );
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.72, end: 1).animate(curved),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.18),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    ),
                  );
                },
                child: tile == null
                    ? Container(
                        key: ValueKey('empty_$index'),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      )
                    : GameTileWidget(
                        key: ValueKey('${tile.id}_$matching'),
                        tile: tile,
                        enabled: true,
                        highlighted: false,
                        matching: matching,
                        trayTile: true,
                      ),
              ),
            ),
          );
          });
        }(),
      ),
    );
  }
}
