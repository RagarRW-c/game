import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tile_catalog.dart';
import '../../data/progress_repository.dart';
import '../../domain/endless_board_generator.dart';
import '../../domain/game_engine.dart';
import '../../domain/game_result.dart';
import '../../domain/tile.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../theme/world_theme.dart';
import '../widgets/game_tile.dart';
import '../widgets/game_ui.dart';
import 'main_menu_screen.dart';

class EndlessScreen extends StatefulWidget {
  const EndlessScreen({super.key});

  static const route = '/endless';

  @override
  State<EndlessScreen> createState() => _EndlessScreenState();
}

class _EndlessScreenState extends State<EndlessScreen> {
  static const int _maxBoosterUses = 2;
  static const int _boosterCoinCost = 150;

  final EndlessBoardGenerator _generator = EndlessBoardGenerator();
  final Set<String> _hintedTileIds = <String>{};

  late AppScope _scope;
  GameEngine? _engine;
  TileVisualTheme? _selectedTheme;
  int _round = 1;
  int _score = 0;
  int _bestScore = 0;
  int _boardsCleared = 0;
  int _tilesMatched = 0;
  int _coins = 0;
  int _coinsEarned = 0;
  int _nextCoinReward = 1000;
  int _nextChestReward = 5000;
  int _undoUsesRemaining = _maxBoosterUses;
  int _hintUsesRemaining = _maxBoosterUses;
  int _shuffleUsesRemaining = _maxBoosterUses;
  int _extraHintBoosters = 0;
  int _extraShuffleBoosters = 0;
  int _extraUndoBoosters = 0;
  bool _vibrationEnabled = true;
  bool _boosterUsedThisBoard = false;
  bool _gameOverShowing = false;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    if (_loading) unawaited(_startRun());
  }

  Future<void> _startRun() async {
    final repository = _scope.progressRepository;
    final cosmetics = await repository.playerCosmetics();
    final bestScore = await repository.bestEndlessScore();
    final coins = await repository.coins();
    final vibration = await repository.vibrationEnabled();
    final extraHintBoosters = await repository.extraHintBoosters();
    final extraShuffleBoosters = await repository.extraShuffleBoosters();
    final extraUndoBoosters = await repository.extraUndoBoosters();
    if (!mounted) return;
    _selectedTheme = _themeFromCosmetics(cosmetics);
    setState(() {
      _round = 1;
      _score = 0;
      _bestScore = bestScore;
      _boardsCleared = 0;
      _tilesMatched = 0;
      _coins = coins;
      _coinsEarned = 0;
      _nextCoinReward = 1000;
      _nextChestReward = 5000;
      _extraHintBoosters = extraHintBoosters;
      _extraShuffleBoosters = extraShuffleBoosters;
      _extraUndoBoosters = extraUndoBoosters;
      _vibrationEnabled = vibration;
      _boosterUsedThisBoard = false;
      _gameOverShowing = false;
      _loading = false;
      _engine = _newEngineForRound(1);
      _resetBoardBoosters();
    });
  }

  TileVisualTheme? _themeFromCosmetics(PlayerCosmetics cosmetics) {
    switch (cosmetics.selectedBackground) {
      case ProgressRepository.profileBackgroundGarden:
        return TileVisualTheme.garden;
      case ProgressRepository.profileBackgroundOcean:
        return TileVisualTheme.ocean;
      case ProgressRepository.profileBackgroundCandy:
        return TileVisualTheme.candy;
      case ProgressRepository.profileBackgroundSpace:
        return TileVisualTheme.space;
    }
    switch (cosmetics.selectedFrame) {
      case ProgressRepository.avatarFrameGarden:
        return TileVisualTheme.garden;
      case ProgressRepository.avatarFrameOcean:
        return TileVisualTheme.ocean;
      case ProgressRepository.avatarFrameCandy:
        return TileVisualTheme.candy;
      case ProgressRepository.avatarFrameSpace:
        return TileVisualTheme.space;
    }
    return null;
  }

  TileVisualTheme _themeForRound(int round) {
    final selected = _selectedTheme;
    if (selected != null) return selected;
    const themes = TileVisualTheme.values;
    return themes[((round - 1) ~/ 3) % themes.length];
  }

  GameEngine _newEngineForRound(int round) {
    return GameEngine(
      _generator.generate(round: round, theme: _themeForRound(round)),
    );
  }

  int get _multiplier => 1 + (_boardsCleared ~/ 5);

  Size _tileSize(double width) {
    final side = (width * 0.16).clamp(48.0, 68.0).toDouble();
    return Size(side, side);
  }

  void _resetBoardBoosters() {
    _hintedTileIds.clear();
    _undoUsesRemaining = _maxBoosterUses;
    _hintUsesRemaining = _maxBoosterUses;
    _shuffleUsesRemaining = _maxBoosterUses;
  }

  bool _canUseBooster(int freeUsesRemaining, int inventory) {
    return freeUsesRemaining > 0 || inventory > 0 || _coins >= _boosterCoinCost;
  }

  String _boosterCostLabel(int freeUsesRemaining, int inventory) {
    if (freeUsesRemaining > 0) return 'x$freeUsesRemaining';
    if (inventory > 0) return '+$inventory';
    return '$_boosterCoinCost';
  }

  Future<bool> _payForBoosterIfNeeded(
    int freeUsesRemaining,
    int inventory,
    Future<bool> Function() useInventory,
    VoidCallback decrementInventory,
  ) async {
    if (freeUsesRemaining > 0) return true;
    if (inventory > 0) {
      final used = await useInventory();
      if (!used) return false;
      if (mounted) setState(decrementInventory);
      return true;
    }
    final spent = await _scope.progressRepository.spendCoins(_boosterCoinCost);
    if (!spent) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough coins')),
        );
      }
      return false;
    }
    if (mounted) setState(() => _coins -= _boosterCoinCost);
    return true;
  }

  void _playSfx(Future<void> Function() play, String cue) {
    unawaited(play().catchError((Object error, StackTrace stackTrace) {
      if (kDebugMode) debugPrint('Endless SFX $cue failed: $error');
    }));
  }

  void _haptic(Future<void> Function() feedback) {
    if (!_vibrationEnabled) return;
    unawaited(feedback());
  }

  void _addScore(int amount) {
    _score += amount * _multiplier;
  }

  Future<void> _handleScoreRewards() async {
    while (_score >= _nextCoinReward) {
      _coins = await _scope.progressRepository.addCoins(25);
      _coinsEarned += 25;
      _nextCoinReward += 1000;
    }
    while (_score >= _nextChestReward) {
      await _scope.progressRepository.grantEndlessSilverChest();
      _nextChestReward += 5000;
    }
  }

  Future<void> _onTileTap(
    Tile tile,
    Size boardSize,
    Size tileSize,
  ) async {
    final engine = _engine;
    if (engine == null || engine.result != GameResult.playing) return;
    final canonicalTile = engine.tileById(tile.id);
    if (canonicalTile == null ||
        !engine.isUncovered(canonicalTile, boardSize, tileSize)) {
      return;
    }
    final beforeTrayIds = List<String>.from(engine.tray);

    late final bool moved;
    setState(() {
      _hintedTileIds.clear();
      moved = engine.tapTile(canonicalTile.id, boardSize, tileSize);
      if (moved) _addScore(5);
    });
    _playSfx(_scope.audioService.playTap, 'tap');
    _haptic(HapticFeedback.lightImpact);

    if (!moved) {
      if (engine.result == GameResult.lost) await _handleGameOver();
      return;
    }

    final matchedIds = _matchedIdsAfterMove(beforeTrayIds, [canonicalTile.id]);
    if (matchedIds.isNotEmpty) {
      setState(() {
        _tilesMatched += matchedIds.length;
        _addScore(50);
      });
      _playSfx(_scope.audioService.playMatch, 'match');
      _haptic(HapticFeedback.mediumImpact);
    }
    await _handleScoreRewards();
    if (!mounted) return;
    if (engine.result == GameResult.won) await _handleBoardCleared();
    if (!mounted) return;
    if (engine.result == GameResult.lost) await _handleGameOver();
  }

  Set<String> _matchedIdsAfterMove(
    List<String> beforeTrayIds,
    Iterable<String> collectedIds,
  ) {
    final engine = _engine;
    if (engine == null) return <String>{};
    final afterTrayIds = engine.tray.toSet();
    return <String>{...beforeTrayIds, ...collectedIds}
        .where((tileId) {
          final tile = engine.tileById(tileId);
          return tile != null &&
              tile.state == TileState.matched &&
              !afterTrayIds.contains(tileId);
        })
        .take(3)
        .toSet();
  }

  Future<void> _handleBoardCleared() async {
    setState(() {
      _addScore(500);
      if (!_boosterUsedThisBoard) _addScore(250);
      _boardsCleared++;
      _round++;
      _engine = _newEngineForRound(_round);
      _boosterUsedThisBoard = false;
      _resetBoardBoosters();
    });
    _playSfx(_scope.audioService.playLevelComplete, 'level_complete');
    await _handleScoreRewards();
  }

  Future<void> _useHint(
    GameEngine engine,
    Size boardSize,
    Size tileSize,
  ) async {
    engine.updateBoardGeometry(boardSize, tileSize);
    final hintIds = engine.findBestHintTileIds();
    if (hintIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hint available')),
      );
      return;
    }
    final usedFreeHint = _hintUsesRemaining > 0;
    if (!await _payForBoosterIfNeeded(
      _hintUsesRemaining,
      _extraHintBoosters,
      _scope.progressRepository.useExtraHintBooster,
      () => _extraHintBoosters--,
    )) {
      return;
    }
    final beforeTrayIds = List<String>.from(engine.tray);
    late final bool collected;
    setState(() {
      _hintedTileIds.clear();
      collected = engine.collectHintTileIds(hintIds);
      if (collected && usedFreeHint) _hintUsesRemaining--;
      if (collected) _boosterUsedThisBoard = true;
    });
    if (!collected) {
      if (engine.result == GameResult.lost) await _handleGameOver();
      return;
    }
    final removedIds = _matchedIdsAfterMove(
      beforeTrayIds,
      hintIds,
    );
    if (removedIds.isNotEmpty) {
      setState(() {
        _tilesMatched += removedIds.length;
        _addScore(50);
      });
      _playSfx(_scope.audioService.playMatch, 'match');
    }
    _playSfx(_scope.audioService.playBooster, 'booster');
    unawaited(_scope.progressRepository.recordBoosterUsed(BoosterKind.hint));
    await _handleScoreRewards();
    if (!mounted) return;
    if (engine.result == GameResult.won) await _handleBoardCleared();
    if (!mounted) return;
    if (engine.result == GameResult.lost) await _handleGameOver();
  }

  Future<void> _useShuffle(GameEngine engine) async {
    if (engine.result != GameResult.playing || engine.boardTiles.length < 2) {
      return;
    }
    final usedFreeShuffle = _shuffleUsesRemaining > 0;
    if (!await _payForBoosterIfNeeded(
      _shuffleUsesRemaining,
      _extraShuffleBoosters,
      _scope.progressRepository.useExtraShuffleBooster,
      () => _extraShuffleBoosters--,
    )) {
      return;
    }
    late final bool shuffled;
    setState(() {
      _hintedTileIds.clear();
      shuffled = engine.shuffleBoard();
      if (shuffled && usedFreeShuffle) _shuffleUsesRemaining--;
      if (shuffled) _boosterUsedThisBoard = true;
    });
    if (!shuffled) return;
    _playSfx(_scope.audioService.playBooster, 'booster');
    unawaited(_scope.progressRepository.recordBoosterUsed(BoosterKind.shuffle));
  }

  Future<void> _useUndo(GameEngine engine) async {
    if (!engine.canUndo) return;
    final usedFreeUndo = _undoUsesRemaining > 0;
    if (!await _payForBoosterIfNeeded(
      _undoUsesRemaining,
      _extraUndoBoosters,
      _scope.progressRepository.useExtraUndoBooster,
      () => _extraUndoBoosters--,
    )) {
      return;
    }
    late final bool undone;
    setState(() {
      undone = engine.undo();
      if (undone) {
        _hintedTileIds.clear();
        if (usedFreeUndo) _undoUsesRemaining--;
        _boosterUsedThisBoard = true;
      }
    });
    if (!undone) return;
    _playSfx(_scope.audioService.playBooster, 'booster');
    unawaited(_scope.progressRepository.recordBoosterUsed(BoosterKind.undo));
  }

  Future<void> _handleGameOver() async {
    if (_gameOverShowing) return;
    _gameOverShowing = true;
    _playSfx(_scope.audioService.playGameOver, 'game_over');
    await _scope.progressRepository.recordEndlessRun(
      score: _score,
      boardsCleared: _boardsCleared,
      tilesMatched: _tilesMatched,
    );
    final bestScore = max(_bestScore, _score);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EndlessResultsDialog(
        finalScore: _score,
        bestScore: bestScore,
        boardsCleared: _boardsCleared,
        tilesMatched: _tilesMatched,
        coinsEarned: _coinsEarned,
        onTryAgain: () {
          Navigator.of(context).pop();
          setState(() => _loading = true);
          unawaited(_startRun());
        },
        onMainMenu: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
            MainMenuScreen.route,
            (route) => false,
          );
        },
      ),
    );
    if (mounted) {
      setState(() {
        _bestScore = bestScore;
        _gameOverShowing = false;
      });
    }
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
          if (!seenIds.add(tile.id)) return false;
          if (tile.state == TileState.matched) return false;
          if (trayIds.contains(tile.id)) return false;
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
    final coveredById = <String, bool>{};
    for (var index = 0; index < renderedBoardTiles.length; index++) {
      final tile = renderedBoardTiles[index];
      coveredById[tile.id] = renderedBoardTiles
          .skip(index + 1)
          .any((other) => tile.overlaps(other, boardSize, tileSize));
    }
    return coveredById;
  }

  List<Tile?> _traySnapshot(GameEngine engine) {
    final tilesById = <String, Tile>{
      for (final tile in List<Tile>.from(engine.tiles)) tile.id: tile,
    };
    return List<Tile?>.generate(
      GameEngine.trayLimit,
      (index) =>
          index < engine.tray.length ? tilesById[engine.tray[index]] : null,
      growable: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    if (_loading || engine == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final visualTheme = _themeForRound(_round);
    final worldTheme = WorldThemes.forTileTheme(visualTheme);
    final visualCatalog = tileCatalogForTheme(visualTheme);
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final safeTop = MediaQuery.paddingOf(context).top;
          final boardHeight = constraints.maxHeight - safeTop - 286;
          final boardSize = Size(
            constraints.maxWidth - 20,
            boardHeight.clamp(330.0, 600.0).toDouble(),
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
          final maxLayer = renderedBoardTiles.isEmpty
              ? 0
              : renderedBoardTiles.map((tile) => tile.layer).reduce(max);
          return GameBackground(
            worldTheme: worldTheme,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  GameHeader(
                    title: 'Endless Mode',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  _ScorePanel(
                    score: _score,
                    bestScore: max(_bestScore, _score),
                    round: _round,
                    boardsCleared: _boardsCleared,
                    multiplier: _multiplier,
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: boardSize.width,
                        height: boardSize.height,
                        margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          gradient: worldTheme.boardGradient,
                          borderRadius: GameRadius.extraLargeRadius,
                          border: Border.all(
                            color: worldTheme.secondaryAccent
                                .withValues(alpha: 0.72),
                            width: 2,
                          ),
                          boxShadow: GameShadows.medium(),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
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
                                            _hintedTileIds.contains(tile.id),
                                        catalog: visualCatalog,
                                        onTap: covered
                                            ? null
                                            : () => _onTileTap(
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
                  _EndlessBoosterBar(
                    worldTheme: worldTheme,
                    onShuffle: _canUseBooster(
                            _shuffleUsesRemaining, _extraShuffleBoosters)
                        ? () => unawaited(_useShuffle(engine))
                        : null,
                    onHint:
                        _canUseBooster(_hintUsesRemaining, _extraHintBoosters)
                            ? () =>
                                unawaited(_useHint(engine, boardSize, tileSize))
                            : null,
                    onUndo: engine.canUndo &&
                            _canUseBooster(
                                _undoUsesRemaining, _extraUndoBoosters)
                        ? () => unawaited(_useUndo(engine))
                        : null,
                    undoLabel: _boosterCostLabel(
                        _undoUsesRemaining, _extraUndoBoosters),
                    hintLabel: _boosterCostLabel(
                        _hintUsesRemaining, _extraHintBoosters),
                    shuffleLabel: _boosterCostLabel(
                      _shuffleUsesRemaining,
                      _extraShuffleBoosters,
                    ),
                  ),
                  _EndlessTray(
                    trayTiles: _traySnapshot(engine),
                    catalog: visualCatalog,
                    worldTheme: worldTheme,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({
    required this.score,
    required this.bestScore,
    required this.round,
    required this.boardsCleared,
    required this.multiplier,
  });

  final int score;
  final int bestScore;
  final int round;
  final int boardsCleared;
  final int multiplier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GameSpacing.lg),
      child: Wrap(
        spacing: GameSpacing.sm,
        runSpacing: GameSpacing.sm,
        alignment: WrapAlignment.center,
        children: [
          _ScoreBadge(
              icon: Icons.star_rounded, label: 'Score', value: '$score'),
          _ScoreBadge(
            icon: Icons.emoji_events_rounded,
            label: 'Best',
            value: '$bestScore',
          ),
          _ScoreBadge(
            icon: Icons.grid_view_rounded,
            label: 'Round',
            value: '$round',
          ),
          _ScoreBadge(
            icon: Icons.check_circle_rounded,
            label: 'Boards',
            value: '$boardsCleared',
          ),
          _ScoreBadge(
            icon: Icons.trending_up_rounded,
            label: 'x',
            value: '$multiplier',
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GameBadge(
      icon: icon,
      child: Text(
        '$label $value',
        style: GameTextStyles.caption.copyWith(color: Colors.white),
      ),
    );
  }
}

class _EndlessResultsDialog extends StatelessWidget {
  const _EndlessResultsDialog({
    required this.finalScore,
    required this.bestScore,
    required this.boardsCleared,
    required this.tilesMatched,
    required this.coinsEarned,
    required this.onTryAgain,
    required this.onMainMenu,
  });

  final int finalScore;
  final int bestScore;
  final int boardsCleared;
  final int tilesMatched;
  final int coinsEarned;
  final VoidCallback onTryAgain;
  final VoidCallback onMainMenu;

  @override
  Widget build(BuildContext context) {
    return GameDialogFrame(
      title: 'Endless Results',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ResultRow(label: 'Final score', value: '$finalScore'),
          _ResultRow(label: 'Best score', value: '$bestScore'),
          _ResultRow(label: 'Boards cleared', value: '$boardsCleared'),
          _ResultRow(label: 'Tiles matched', value: '$tilesMatched'),
          _ResultRow(label: 'Coins earned', value: '$coinsEarned'),
          const SizedBox(height: GameSpacing.xl),
          GameButton(
            label: 'Try Again',
            icon: Icons.replay_rounded,
            onPressed: onTryAgain,
            variant: GameButtonVariant.success,
          ),
          const SizedBox(height: GameSpacing.md),
          GameButton(
            label: 'Main Menu',
            icon: Icons.home_rounded,
            onPressed: onMainMenu,
            variant: GameButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GameSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GameTextStyles.body)),
          Text(value, style: GameTextStyles.button),
        ],
      ),
    );
  }
}

class _EndlessBoosterBar extends StatelessWidget {
  const _EndlessBoosterBar({
    required this.worldTheme,
    required this.onShuffle,
    required this.onHint,
    required this.onUndo,
    required this.undoLabel,
    required this.hintLabel,
    required this.shuffleLabel,
  });

  final VoidCallback? onShuffle;
  final VoidCallback? onHint;
  final VoidCallback? onUndo;
  final WorldVisualTheme worldTheme;
  final String undoLabel;
  final String hintLabel;
  final String shuffleLabel;

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
            child: _EndlessBoosterButton(
              onPressed: onUndo,
              icon: const Icon(Icons.arrow_back_rounded),
              label: 'Undo',
              badge: undoLabel,
              accent: worldTheme.boosterAccents[0],
            ),
          ),
          const SizedBox(width: GameSpacing.sm),
          Expanded(
            child: _EndlessBoosterButton(
              onPressed: onHint,
              icon: const Icon(Icons.pets_rounded),
              label: 'Hint',
              badge: hintLabel,
              accent: worldTheme.boosterAccents[1],
            ),
          ),
          const SizedBox(width: GameSpacing.sm),
          Expanded(
            child: _EndlessBoosterButton(
              onPressed: onShuffle,
              icon: const Icon(Icons.air_rounded),
              label: 'Shuffle',
              badge: shuffleLabel,
              accent: worldTheme.boosterAccents[2],
            ),
          ),
        ],
      ),
    );
  }
}

class _EndlessBoosterButton extends StatelessWidget {
  const _EndlessBoosterButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.badge,
    this.accent = GameColors.accentGold,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final String badge;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
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
                      '$label $badge',
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

class _EndlessTray extends StatelessWidget {
  const _EndlessTray({
    required this.trayTiles,
    required this.catalog,
    required this.worldTheme,
  });

  final List<Tile?> trayTiles;
  final Map<String, TileArt> catalog;
  final WorldVisualTheme worldTheme;

  @override
  Widget build(BuildContext context) {
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
        gradient: worldTheme.trayGradient,
        borderRadius: GameRadius.extraLargeRadius,
        border: Border.all(
          color: worldTheme.secondaryAccent.withValues(alpha: 0.78),
          width: 3,
        ),
        boxShadow: GameShadows.medium(),
      ),
      child: Row(
        children: [
          for (var index = 0; index < GameEngine.trayLimit; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: GameSpacing.xs),
                child: trayTiles[index] == null
                    ? const EmptyTraySlot()
                    : PoppingGameTile(
                        key: ValueKey('endless_tray_${trayTiles[index]!.id}'),
                        tile: trayTiles[index]!,
                        enabled: true,
                        highlighted: false,
                        catalog: catalog,
                        trayTile: true,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
