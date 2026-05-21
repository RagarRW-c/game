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
import '../theme/game_theme.dart';
import '../widgets/game_tile.dart';
import '../widgets/game_ui.dart';
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
  final Set<String> _hintedTileIds = <String>{};
  int _undoUsesRemaining = _maxBoosterUses;
  int _hintUsesRemaining = _maxBoosterUses;
  int _shuffleUsesRemaining = _maxBoosterUses;
  bool _gameOverDialogShowing = false;
  bool _winDialogShowing = false;

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
      _gameOverDialogShowing = false;
      _winDialogShowing = false;
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
    _hintedTileIds.clear();
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
      _hintedTileIds.clear();
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
    engine.updateBoardGeometry(boardSize, tileSize);
    final hintIds = engine.findBestHintTileIds();
    if (hintIds.isEmpty) {
      debugPrint('Cat helper hint unavailable');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hint available')),
        );
      }
      return;
    }

    final beforeTrayIds = List<String>.from(engine.tray);
    debugPrint('Cat helper started: ids=${hintIds.join(',')}');
    late final bool collected;
    if (!_safeSetState(() {
      _hintedTileIds.clear();
      collected = engine.collectHintTileIds(hintIds);
      if (collected) _hintUsesRemaining--;
    })) {
      return;
    }
    _playSfx(_scope.audioService.playBooster, 'booster');

    if (!collected) {
      debugPrint('Cat helper aborted: hint tiles were not collected');
      _debugValidateTiles('cat-rejected', engine);
      if (engine.result == GameResult.lost) await _handleGameOver(level: level);
      return;
    }

    final removedIds =
        _matchedIdsAfterMove(beforeTrayIds, preferredIds: hintIds.toSet());
    debugPrint(
        'Cat helper tray insertion: ids=${hintIds.join(',')}, tray=${engine.tray.length}');
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
      builder: (_) => _GameOverDialog(
        onClose: () {
          _navigator.pop();
          _navigator.popUntil(ModalRoute.withName(MainMenuScreen.route));
        },
        onRestart: level == null
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
      ),
    );
    if (mounted) _gameOverDialogShowing = false;
  }

  Future<void> _handleWin() async {
    if (_winDialogShowing || !mounted) return;
    _winDialogShowing = true;
    final scope = _scope;
    await scope.progressRepository.unlockNextLevel(widget.level);
    if (!mounted) {
      _winDialogShowing = false;
      return;
    }
    _playSfx(scope.audioService.playWin, 'win');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WinScreen(
        level: widget.level,
        isFinalLevel: widget.level == LevelRepository.levelCount,
        tilesCleared: _engine?.tiles.length ?? 0,
        undoUsed: _maxBoosterUses - _undoUsesRemaining,
        hintUsed: _maxBoosterUses - _hintUsesRemaining,
        shuffleUsed: _maxBoosterUses - _shuffleUsesRemaining,
        onRestart: () {
          if (!mounted) return;
          _navigator.pop();
          _safeSetState(() {
            _engine = null;
            _resetAnimationState();
            _resetBoosterUses();
          });
        },
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
    if (mounted) _winDialogShowing = false;
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
          extendBodyBehindAppBar: true,
          body: LayoutBuilder(
            builder: (context, constraints) {
              try {
                final safeTop = MediaQuery.paddingOf(context).top;
                final boardHeight = constraints.maxHeight - safeTop - 238;
                final boardSize = Size(
                  constraints.maxWidth - 20,
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
                final hintedTileIds = Set<String>.from(_hintedTileIds);
                final maxLayer = renderedBoardTiles.isEmpty
                    ? 0
                    : renderedBoardTiles.map((tile) => tile.layer).reduce(max);
                return GameBackground(
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        GameHeader(
                          title: level.name,
                          onBack: () => Navigator.of(context).maybePop(),
                          trailing: GameBadge(
                            icon: Icons.track_changes_rounded,
                            child: Text(
                              '$boardCount left',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Container(
                              width: boardSize.width,
                              height: boardSize.height,
                              margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                              decoration: BoxDecoration(
                                gradient: GameGradients.board,
                                borderRadius: GameRadius.extraLargeRadius,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.66),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: GameColors.boardShadow
                                        .withValues(alpha: 0.28),
                                    blurRadius: 28,
                                    offset: const Offset(0, 14),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    blurRadius: 12,
                                    offset: const Offset(-3, -3),
                                  ),
                                ],
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            GameRadius.extraLargeRadius,
                                        boxShadow: [
                                          BoxShadow(
                                            color: GameColors.boardInnerShadow
                                                .withValues(alpha: 0.16),
                                            blurRadius: 28,
                                            spreadRadius: -14,
                                          ),
                                        ],
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
                                              highlighted: hintedTileIds
                                                  .contains(tile.id),
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
                                    _hintedTileIds.clear();
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

class _GameOverDialog extends StatelessWidget {
  const _GameOverDialog({
    required this.onClose,
    required this.onRestart,
  });

  final VoidCallback onClose;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    return GameDialogFrame(
      title: 'Game Over',
      onClose: onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              gradient: GameGradients.dangerButton,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: GameShadows.glow(GameColors.dangerRed),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: GameSpacing.lg),
          const Text(
            'Tray is full',
            textAlign: TextAlign.center,
            style: GameTextStyles.h2,
          ),
          const SizedBox(height: GameSpacing.xl),
          GameButton(
            label: 'Restart Level',
            icon: Icons.refresh_rounded,
            onPressed: onRestart,
            variant: GameButtonVariant.success,
          ),
          const SizedBox(height: GameSpacing.md),
          GameButton(
            label: 'Close',
            icon: Icons.close_rounded,
            onPressed: onClose,
            variant: GameButtonVariant.secondary,
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(
        GameSpacing.lg,
        GameSpacing.xs,
        GameSpacing.lg,
        GameSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _BoosterButton(
              onPressed: onUndo,
              icon: const Icon(Icons.arrow_back_rounded),
              label: 'Undo',
              remaining: undoRemaining,
            ),
          ),
          const SizedBox(width: GameSpacing.sm),
          Expanded(
            child: _BoosterButton(
              onPressed: onHint,
              icon: const Icon(Icons.pets_rounded),
              label: 'Hint',
              remaining: hintRemaining,
              accent: GameColors.secondaryPurple,
            ),
          ),
          const SizedBox(width: GameSpacing.sm),
          Expanded(
            child: _BoosterButton(
              onPressed: onShuffle,
              icon: const Icon(Icons.air_rounded),
              label: 'Shuffle',
              remaining: shuffleRemaining,
              accent: GameColors.primaryBlueLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoosterButton extends StatelessWidget {
  const _BoosterButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.remaining,
    this.accent = GameColors.accentGold,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final int remaining;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && remaining > 0;
    return AnimatedOpacity(
      duration: GameDurations.quick,
      opacity: enabled ? 1 : 0.46,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: GameRadius.largeRadius,
          child: Ink(
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: enabled
                    ? [accent, Color.lerp(accent, Colors.black, 0.18)!]
                    : const [GameColors.disabledTop, GameColors.disabledBottom],
              ),
              borderRadius: GameRadius.largeRadius,
              border: Border.all(color: Colors.white70, width: 2),
              boxShadow: GameShadows.medium(),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: IconTheme(
                    data: const IconThemeData(color: Colors.white, size: 28),
                    child: icon,
                  ),
                ),
                Positioned(
                  left: GameSpacing.sm,
                  right: GameSpacing.sm,
                  bottom: -7,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: GameSpacing.xs),
                    decoration: BoxDecoration(
                      color: GameColors.primaryBlueDark,
                      borderRadius: GameRadius.smallRadius,
                      border: Border.all(color: Colors.white54),
                      boxShadow: GameShadows.light(),
                    ),
                    child: Text(
                      '$label x$remaining',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: GameSpacing.xs),
            child: AnimatedSwitcher(
                duration: GameDurations.normal,
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: tile == null
                    ? const EmptyTraySlot(key: ValueKey('empty_slot'))
                    : PoppingGameTile(
                        key: ValueKey('tray_${tile.id}'),
                        tile: tile,
                        enabled: true,
                        highlighted: false,
                        trayTile: true,
                      )),
          ),
        ),
      );
    }

    return Container(
      height: 94,
      margin: const EdgeInsets.fromLTRB(
        GameSpacing.lg,
        GameSpacing.sm,
        GameSpacing.lg,
        GameSpacing.lg,
      ),
      padding: const EdgeInsets.all(GameSpacing.md),
      decoration: BoxDecoration(
        gradient: GameGradients.tray,
        borderRadius: GameRadius.extraLargeRadius,
        border: Border.all(color: Colors.white70, width: 3),
        boxShadow: [
          ...GameShadows.medium(),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Row(children: slotWidgets),
    );
  }
}
