import 'package:flutter/material.dart';

import '../../data/level_repository.dart';
import '../../domain/game_engine.dart';
import '../../domain/game_result.dart';
import '../../domain/level.dart';
import '../../domain/tile.dart';
import '../../main.dart';
import '../widgets/game_tile.dart';
import 'final_code_screen.dart';
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
  GameEngine? _engine;
  String? _hintedTileId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _levelFuture = AppScope.of(context).levelRepository.loadLevel(widget.level);
  }

  void _ensureEngine(LevelDefinition level) {
    _engine ??= GameEngine(level.tiles);
  }

  Size _tileSize(double width) {
    final side = (width * 0.16).clamp(50.0, 70.0).toDouble();
    return Size(side, side);
  }

  Future<void> _onTileTap(Tile tile, Size boardSize, Size tileSize) async {
    final scope = AppScope.of(context);
    final beforeTray = _engine!.tray.length;
    if (!_engine!.tapTile(tile.id, boardSize, tileSize)) return;
    setState(() => _hintedTileId = null);
    await scope.audioService.playTap();
    if (_engine!.tray.length < beforeTray + 1) await scope.audioService.playMatch();
    if (_engine!.result == GameResult.won) await _handleWin();
    if (_engine!.result == GameResult.lost) await scope.audioService.playLose();
  }

  Future<void> _handleWin() async {
    final scope = AppScope.of(context);
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
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onNext: () async {
          Navigator.pop(context);
          if (widget.level == LevelRepository.levelCount) {
            final code = await scope.progressRepository.finalCode();
            if (mounted) {
              await Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(builder: (_) => FinalCodeScreen(code: code)),
              );
            }
          } else if (mounted) {
            await Navigator.pushReplacementNamed(
              context,
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
              final sortedBoardTiles = engine.boardTiles.toList()
                ..sort((a, b) => a.layer.compareTo(b.layer));
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
                              for (final tile in sortedBoardTiles)
                                AnimatedPositioned(
                                  key: ValueKey(tile.id),
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutBack,
                                  left: tile.x * boardSize.width,
                                  top: tile.y * boardSize.height,
                                  width: tileSize.width,
                                  height: tileSize.height,
                                  child: GameTileWidget(
                                    tile: tile,
                                    enabled: engine.isUncovered(tile, boardSize, tileSize),
                                    highlighted: _hintedTileId == tile.id,
                                    onTap: () => _onTileTap(tile, boardSize, tileSize),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _BoosterBar(
                      onShuffle: () async {
                        setState(() => engine.shuffleBoard());
                        await AppScope.of(context).audioService.playBooster();
                      },
                      onHint: () async {
                        setState(() => _hintedTileId = engine.hint(boardSize, tileSize));
                        await AppScope.of(context).audioService.playBooster();
                      },
                      onUndo: engine.canUndo
                          ? () async {
                              setState(() => engine.undo());
                              await AppScope.of(context).audioService.playBooster();
                            }
                          : null,
                    ),
                    _Tray(engine: engine),
                    if (engine.result == GameResult.lost)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilledButton.icon(
                          onPressed: () => setState(() => _engine = GameEngine(level.tiles)),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Tray full! Try again'),
                        ),
                      ),
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
  const _BoosterBar({required this.onShuffle, required this.onHint, required this.onUndo});

  final VoidCallback onShuffle;
  final VoidCallback onHint;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(child: FilledButton.tonalIcon(onPressed: onShuffle, icon: const Icon(Icons.shuffle_rounded), label: const Text('Shuffle'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton.tonalIcon(onPressed: onHint, icon: const Icon(Icons.lightbulb_rounded), label: const Text('Hint'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton.tonalIcon(onPressed: onUndo, icon: const Icon(Icons.undo_rounded), label: const Text('Undo'))),
        ],
      ),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({required this.engine});

  final GameEngine engine;

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
          final hasTile = index < engine.tray.length;
          final tile = hasTile ? engine.tileById(engine.tray[index]) : null;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
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
                        key: ValueKey(tile.id),
                        tile: tile,
                        enabled: true,
                        highlighted: false,
                      ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
