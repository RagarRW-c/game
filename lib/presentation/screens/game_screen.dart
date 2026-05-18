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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    _navigator = Navigator.of(context);
    _levelFuture = _scope.levelRepository.loadLevel(widget.level);
  }

  void _ensureEngine(LevelDefinition level) {
    _engine ??= GameEngine(level.tiles);
  }

  Size _tileSize(double width) {
    final side = (width * 0.16).clamp(50.0, 70.0).toDouble();
    return Size(side, side);
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
    if (_animatingAction) return;
    final scope = _scope;
    final beforeTrayIds = List<String>.from(_engine!.tray);

    setState(() {
      _animatingAction = true;
      _pickedUpTileId = tile.id;
      _hintedTileId = null;
    });
    await scope.audioService.playTap();
    await Future<void>.delayed(const Duration(milliseconds: 115));
    if (!mounted) return;

    final moved = _engine!.tapTile(tile.id, boardSize, tileSize);
    if (!moved) {
      setState(() {
        _pickedUpTileId = null;
        _animatingAction = false;
      });
      return;
    }

    _showMatchRemovalIfNeeded(beforeTrayIds, tile.id);
    setState(() {
      _pickedUpTileId = null;
      _flyingTile = tile;
      _flyingTrayIndex = beforeTrayIds.length
          .clamp(0, GameEngine.trayLimit - 1)
          .toInt();
      _flightSettled = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _flyingTile?.id == tile.id) {
        setState(() => _flightSettled = true);
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;

    if (_matchingTileIds.isNotEmpty) await scope.audioService.playMatch();
    if (!mounted) return;
    setState(() {
      _matchingTileIds.clear();
      _flyingTile = null;
      _flightSettled = false;
      _animatingAction = false;
    });
    if (_engine!.result == GameResult.won) await _handleWin();
    if (!mounted) return;
    if (_engine!.result == GameResult.lost) await _handleGameOver(level: level);
  }

  Future<void> _useCatPowerUp(
    LevelDefinition level,
    Size boardSize,
    Size tileSize,
  ) async {
    if (_animatingAction) return;
    final scope = _scope;
    final catIds = _availableTripleIds(boardSize, tileSize);
    if (catIds == null) {
      setState(() => _hintedTileId = _engine!.hint(boardSize, tileSize));
      await scope.audioService.playBooster();
      return;
    }

    final beforeTrayIds = List<String>.from(_engine!.tray);
    setState(() {
      _animatingAction = true;
      _hintedTileId = null;
      _catPulseTileIds
        ..clear()
        ..addAll(catIds);
    });
    await scope.audioService.playBooster();
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;

    final collected = _engine!.collectAvailableTriple(boardSize, tileSize);
    if (!collected) {
      setState(() {
        _catPulseTileIds.clear();
        _animatingAction = false;
      });
      return;
    }

    _showMatchRemovalIfNeeded(beforeTrayIds, null, preferredIds: catIds.toSet());
    setState(() => _catPulseTileIds.clear());
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    await scope.audioService.playMatch();
    if (!mounted) return;
    setState(() {
      _matchingTileIds.clear();
      _animatingAction = false;
    });
    if (_engine!.result == GameResult.won) await _handleWin();
    if (!mounted) return;
    if (_engine!.result == GameResult.lost) await _handleGameOver(level: level);
  }

  List<String>? _availableTripleIds(Size boardSize, Size tileSize) {
    _engine!.updateBoardGeometry(boardSize, tileSize);
    final idsByType = <String, List<String>>{};
    for (final tile in _engine!.renderedBoardTiles.reversed) {
      if (_engine!.isTileCovered(tile)) continue;
      idsByType.putIfAbsent(tile.type, () => <String>[]).add(tile.id);
    }
    for (final ids in idsByType.values) {
      if (ids.length >= 3) return ids.take(3).toList();
    }
    return null;
  }

  void _showMatchRemovalIfNeeded(
    List<String> beforeTrayIds,
    String? collectedId, {
    Set<String>? preferredIds,
  }) {
    if (!mounted) return;
    final afterTrayIds = _engine!.tray.toSet();
    final candidateIds = <String>{
      ...beforeTrayIds,
      if (collectedId != null) collectedId,
    };
    if (preferredIds != null) candidateIds.addAll(preferredIds);
    final removedIds = candidateIds
        .where((id) => !afterTrayIds.contains(id))
        .toSet();
    if (removedIds.length >= 3) {
      setState(() {
        _matchingTileIds
          ..clear()
          ..addAll(removedIds.take(3));
      });
    }
  }

  Future<void> _handleGameOver({required LevelDefinition? level}) async {
    if (_gameOverDialogShowing || !mounted) return;
    _gameOverDialogShowing = true;
    final audioService = _scope.audioService;
    await audioService.playLose();
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
                    setState(() {
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
    await scope.audioService.playWin();
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LevelDefinition>(
      future: _levelFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final level = snapshot.data!;
        _ensureEngine(level);
        final engine = _engine!;

        return Scaffold(
          appBar: AppBar(
            title: Text(level.name),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: Text(
                    '${engine.boardTiles.length} left',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final boardHeight = constraints.maxHeight - 156;
              final boardSize = Size(
                constraints.maxWidth,
                boardHeight.clamp(360.0, 620.0).toDouble(),
              );
              final tileSize = _tileSize(constraints.maxWidth);
              engine.updateBoardGeometry(boardSize, tileSize);
              final renderedBoardTiles = engine.renderedBoardTiles;
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
                                        _shuffleOffsets.containsKey(tile.id)
                                            ? 190
                                            : 310,
                                  ),
                                  curve: _shuffleOffsets.containsKey(tile.id)
                                      ? Curves.easeInOut
                                      : Curves.easeOutCubic,
                                  left: tile.x * boardSize.width +
                                      (_shuffleOffsets[tile.id]?.dx ?? 0),
                                  top: tile.y * boardSize.height +
                                      (_shuffleOffsets[tile.id]?.dy ?? 0),
                                  width: tileSize.width,
                                  height: tileSize.height,
                                  child: Builder(
                                    builder: (context) {
                                      final covered = engine.isTileCovered(tile);
                                      final depth = maxLayer == 0 ? 1.0 : tile.layer / maxLayer;
                                      final pulsing = _catPulseTileIds.contains(tile.id);
                                      return IgnorePointer(
                                        ignoring: covered || _animatingAction,
                                        child: GameTileWidget(
                                          tile: tile,
                                          enabled: !covered,
                                          blocked: covered,
                                          depth: depth,
                                          pickedUp: _pickedUpTileId == tile.id,
                                          highlighted: _hintedTileId == tile.id || pulsing,
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
                              if (_flyingTile != null)
                                AnimatedPositioned(
                                  key: ValueKey('flight_${_flyingTile!.id}'),
                                  duration: const Duration(milliseconds: 310),
                                  curve: Curves.easeInOutCubic,
                                  left: _flightSettled
                                      ? 22 +
                                          (_flyingTrayIndex *
                                              ((boardSize.width - 44) /
                                                  GameEngine.trayLimit))
                                      : _flyingTile!.x * boardSize.width,
                                  top: _flightSettled
                                      ? boardSize.height + 62
                                      : (_flyingTile!.y * boardSize.height) - 8,
                                  width: tileSize.width,
                                  height: tileSize.height,
                                  child: IgnorePointer(
                                    child: GameTileWidget(
                                      tile: _flyingTile!,
                                      enabled: true,
                                      highlighted: true,
                                      pickedUp: !_flightSettled,
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
                        setState(() {
                          _animatingAction = true;
                          _hintedTileId = null;
                          _shuffleOffsets
                            ..clear()
                            ..addEntries(engine.boardTiles.map((tile) {
                              final angle = _animationRandom.nextDouble() * pi * 2;
                              final distance = 14 + _animationRandom.nextDouble() * 22;
                              return MapEntry(
                                tile.id,
                                Offset(cos(angle) * distance, sin(angle) * distance),
                              );
                            }));
                        });
                        await _scope.audioService.playBooster();
                        if (!mounted) return;
                        await Future<void>.delayed(const Duration(milliseconds: 170));
                        if (!mounted) return;
                        setState(() {
                          engine.shuffleBoard();
                          _shuffleOffsets.clear();
                        });
                        await Future<void>.delayed(const Duration(milliseconds: 280));
                        if (mounted) setState(() => _animatingAction = false);
                      },
                      onHint: () => _useCatPowerUp(level, boardSize, tileSize),
                      onUndo: engine.canUndo
                          ? () async {
                              setState(() {
                                engine.undo();
                                _resetAnimationState();
                              });
                              await _scope.audioService.playBooster();
                            }
                          : null,
                    ),
                    _Tray(engine: engine, matchingTileIds: _matchingTileIds),
                  ],
                ),
              );
            },
          ),
        );
      },
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
  const _Tray({required this.engine, required this.matchingTileIds});

  final GameEngine engine;
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
          final visibleTray = <String>[...engine.tray, ...matchingTileIds]
              .take(GameEngine.trayLimit)
              .toList();
          final hasTile = index < visibleTray.length;
          final tile = hasTile ? engine.tileById(visibleTray[index]) : null;
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
        }),
      ),
    );
  }
}
