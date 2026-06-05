import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tile_catalog.dart';
import '../../data/level_repository.dart';
import '../../data/progress_repository.dart';
import '../../domain/game_engine.dart';
import '../../domain/game_result.dart';
import '../../domain/level.dart';
import '../../domain/tile.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../theme/world_theme.dart';
import '../widgets/achievement_popup.dart';
import '../widgets/game_tile.dart';
import '../widgets/game_ui.dart';
import 'final_code_screen.dart';
import 'settings_screen.dart';
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
  static const int _boosterCoinCost = 150;
  static const int _levelCompleteCoinReward = 50;
  static const int _bossCoinReward = 300;
  static const int _bossXpReward = 200;

  late Future<LevelDefinition> _levelFuture;
  late AppScope _scope;
  late NavigatorState _navigator;
  GameEngine? _engine;
  final Set<String> _hintedTileIds = <String>{};
  int _undoUsesRemaining = _maxBoosterUses;
  int _hintUsesRemaining = _maxBoosterUses;
  int _shuffleUsesRemaining = _maxBoosterUses;
  int _undoUsedThisLevel = 0;
  int _hintUsedThisLevel = 0;
  int _shuffleUsedThisLevel = 0;
  int _coins = 0;
  int _extraHintBoosters = 0;
  int _extraShuffleBoosters = 0;
  int _extraUndoBoosters = 0;
  bool _vibrationEnabled = true;
  bool _gameOverDialogShowing = false;
  bool _winDialogShowing = false;
  bool _tutorialQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    _navigator = Navigator.of(context);
    _levelFuture = _scope.levelRepository.loadLevel(widget.level);
    unawaited(_loadPlayerState());
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
      _tutorialQueued = false;
      unawaited(_loadPlayerState());
    }
  }

  Future<void> _loadPlayerState() async {
    final coins = await _scope.progressRepository.coins();
    final vibration = await _scope.progressRepository.vibrationEnabled();
    final extraHintBoosters =
        await _scope.progressRepository.extraHintBoosters();
    final extraShuffleBoosters =
        await _scope.progressRepository.extraShuffleBoosters();
    final extraUndoBoosters =
        await _scope.progressRepository.extraUndoBoosters();
    if (!mounted) return;
    setState(() {
      _coins = coins;
      _vibrationEnabled = vibration;
      _extraHintBoosters = extraHintBoosters;
      _extraShuffleBoosters = extraShuffleBoosters;
      _extraUndoBoosters = extraUndoBoosters;
    });
  }

  void _ensureEngine(LevelDefinition level) {
    _engine ??= GameEngine(level.tiles, objective: level.objective);
  }

  void _queueLevelOneTutorial() {
    if (_tutorialQueued || widget.level != 1) return;
    _tutorialQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final seen = await _scope.progressRepository.levelOneTutorialSeen();
      if (!mounted || seen) return;
      final completed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _LevelOneTutorialDialog(),
      );
      if (!mounted || completed != true) return;
      await _scope.progressRepository.setLevelOneTutorialSeen();
    });
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

  void _haptic(Future<void> Function() feedback) {
    if (!_vibrationEnabled) return;
    unawaited(feedback());
  }

  void _showNotEnoughCoins() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not enough coins')),
    );
  }

  void _resetAnimationState() {
    _hintedTileIds.clear();
  }

  void _resetBoosterUses() {
    _undoUsesRemaining = _maxBoosterUses;
    _hintUsesRemaining = _maxBoosterUses;
    _shuffleUsesRemaining = _maxBoosterUses;
    _undoUsedThisLevel = 0;
    _hintUsedThisLevel = 0;
    _shuffleUsedThisLevel = 0;
  }

  Future<void> _recordMatchedTiles(
    int amount, {
    Iterable<String> tileTypes = const <String>[],
  }) async {
    await _scope.progressRepository.recordMatchedTiles(
      amount,
      level: widget.level,
      tileTypes: tileTypes,
    );
    final coins = await _scope.progressRepository.coins();
    if (mounted) setState(() => _coins = coins);
    if (mounted) {
      await showPendingAchievementPopups(context, _scope.progressRepository);
    }
  }

  Future<void> _recordBoosterUsed(BoosterKind kind) async {
    await _scope.progressRepository.recordBoosterUsed(kind);
    final coins = await _scope.progressRepository.coins();
    if (mounted) setState(() => _coins = coins);
    if (mounted) {
      await showPendingAchievementPopups(context, _scope.progressRepository);
    }
  }

  bool _canUseBooster(int freeUsesRemaining, int inventory) {
    return freeUsesRemaining > 0 || inventory > 0 || _coins >= _boosterCoinCost;
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
      _showNotEnoughCoins();
      return false;
    }
    if (mounted) setState(() => _coins -= _boosterCoinCost);
    return true;
  }

  String _boosterCostLabel(int freeUsesRemaining, int inventory) {
    if (freeUsesRemaining > 0) return 'x$freeUsesRemaining';
    if (inventory > 0) return '+$inventory';
    return '$_boosterCoinCost';
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

  void _debugTrayChange(
    String source,
    GameEngine engine, {
    Iterable<String> changedTileIds = const <String>[],
  }) {
    final visualTheme = tileVisualThemeForLevel(widget.level);
    final visualCatalog = tileCatalogForTheme(visualTheme);
    final trayTypeCounts = <String, int>{};

    for (final id in engine.tray) {
      final tile = engine.tileById(id);
      if (tile == null) continue;
      trayTypeCounts[tile.type] = (trayTypeCounts[tile.type] ?? 0) + 1;
    }

    for (final id in changedTileIds) {
      final tile = engine.tileById(id);
      if (tile == null) {
        debugPrint('Tray change [$source]: tile id=$id missing');
        continue;
      }
      final art = visualCatalog[tile.type];
      final displayType = tileLabelForTheme(visualTheme, tile.type);
      debugPrint(
        'Tray change [$source]: tile id=${tile.id}, type=${tile.type}, '
        'displayed=$displayType, iconCode=${art?.icon.codePoint}',
      );
    }

    final counts = trayTypeCounts.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(', ');
    debugPrint('Tray type counts [$source]: {$counts}');
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
    _haptic(HapticFeedback.lightImpact);

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
    _debugTrayChange(
      'tap',
      engine,
      changedTileIds: <String>{canonicalTile.id, ...matchedIds},
    );
    if (matchedIds.isNotEmpty) {
      debugPrint('Match removed: ids=${matchedIds.join(',')}');
      await _recordMatchedTiles(
        matchedIds.length,
        tileTypes: _tileTypesForIds(matchedIds),
      );
      _playSfx(_scope.audioService.playMatch, 'match');
      _haptic(HapticFeedback.mediumImpact);
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
    if (engine == null || engine.result != GameResult.playing) {
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
    debugPrint('Cat helper started: ids=${hintIds.join(',')}');
    late final bool collected;
    if (!_safeSetState(() {
      _hintedTileIds.clear();
      collected = engine.collectHintTileIds(hintIds);
      if (collected && usedFreeHint) _hintUsesRemaining--;
      if (collected) _hintUsedThisLevel++;
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
    _debugTrayChange(
      'hint',
      engine,
      changedTileIds: <String>{...hintIds, ...removedIds},
    );
    if (removedIds.isNotEmpty) {
      debugPrint('Match removed: ids=${removedIds.join(',')}');
      await _recordMatchedTiles(
        removedIds.length,
        tileTypes: _tileTypesForIds(removedIds),
      );
      _playSfx(_scope.audioService.playMatch, 'match');
      _haptic(HapticFeedback.mediumImpact);
    }
    unawaited(_recordBoosterUsed(BoosterKind.hint));
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

  Set<String> _tileTypesForIds(Iterable<String> ids) {
    final engine = _engine;
    if (engine == null) return const <String>{};
    return ids
        .map(engine.tileById)
        .whereType<Tile>()
        .map((tile) => tile.type)
        .toSet();
  }

  Future<bool> _useShuffle(GameEngine engine,
      {bool fromGameOver = false}) async {
    if (!fromGameOver && engine.result != GameResult.playing) return false;
    if (engine.boardTiles.length < 2) return false;
    final usedFreeShuffle = _shuffleUsesRemaining > 0;
    if (!await _payForBoosterIfNeeded(
      _shuffleUsesRemaining,
      _extraShuffleBoosters,
      _scope.progressRepository.useExtraShuffleBooster,
      () => _extraShuffleBoosters--,
    )) {
      return false;
    }

    debugPrint('Shuffle started');
    late final bool shuffled;
    if (!_safeSetState(() {
      _hintedTileIds.clear();
      if (fromGameOver && engine.result == GameResult.lost) {
        engine.result = GameResult.playing;
      }
      shuffled = engine.shuffleBoard();
      if (shuffled && usedFreeShuffle) _shuffleUsesRemaining--;
      if (shuffled) _shuffleUsedThisLevel++;
    })) {
      return false;
    }
    if (!shuffled) return false;
    _playSfx(_scope.audioService.playBooster, 'booster');
    unawaited(_recordBoosterUsed(BoosterKind.shuffle));
    _debugValidateTiles('shuffle', engine);
    debugPrint('Shuffle completed');
    return true;
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

    debugPrint('Undo requested');
    final beforeTrayIds = Set<String>.from(engine.tray);
    late final bool undone;
    _safeSetState(() {
      undone = engine.undo();
      if (undone) {
        _resetAnimationState();
        if (usedFreeUndo) _undoUsesRemaining--;
        _undoUsedThisLevel++;
      }
    });
    if (undone) {
      _playSfx(_scope.audioService.playBooster, 'booster');
      unawaited(_recordBoosterUsed(BoosterKind.undo));
      final afterTrayIds = Set<String>.from(engine.tray);
      final restoredIds = beforeTrayIds.difference(afterTrayIds);
      _debugTrayChange('undo', engine, changedTileIds: restoredIds);
      _debugValidateTiles('undo', engine);
    }
  }

  Future<void> _handleGameOver({required LevelDefinition? level}) async {
    if (_gameOverDialogShowing || !mounted) return;
    _gameOverDialogShowing = true;
    _playSfx(_scope.audioService.playLose, 'lose');
    _haptic(HapticFeedback.heavyImpact);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameOverDialog(
        canUseShuffle:
            _canUseBooster(_shuffleUsesRemaining, _extraShuffleBoosters),
        onBackToMap: () {
          _navigator.pop();
          if (_navigator.canPop()) _navigator.pop();
        },
        onUseShuffle: () async {
          final engine = _engine;
          if (engine == null) return;
          final shuffled = await _useShuffle(engine, fromGameOver: true);
          if (shuffled && mounted) _navigator.pop();
        },
        onRestart: level == null
            ? null
            : () {
                _navigator.pop();
                if (!mounted) return;
                _safeSetState(() {
                  _engine = GameEngine(level.tiles, objective: level.objective);
                  _resetAnimationState();
                  _resetBoosterUses();
                });
              },
      ),
    );
    if (mounted) _gameOverDialogShowing = false;
  }

  Future<void> _showPauseMenu(LevelDefinition level) async {
    await showDialog<void>(
      context: context,
      builder: (_) => GameDialogFrame(
        title: 'Paused',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameButton(
              label: 'Resume',
              icon: Icons.play_arrow_rounded,
              onPressed: () => _navigator.pop(),
              variant: GameButtonVariant.success,
            ),
            const SizedBox(height: GameSpacing.md),
            GameButton(
              label: 'Restart Level',
              icon: Icons.refresh_rounded,
              onPressed: () {
                _navigator.pop();
                if (!mounted) return;
                _safeSetState(() {
                  _engine = GameEngine(level.tiles, objective: level.objective);
                  _resetAnimationState();
                  _resetBoosterUses();
                });
              },
              variant: GameButtonVariant.gold,
            ),
            const SizedBox(height: GameSpacing.md),
            GameButton(
              label: 'Settings',
              icon: Icons.settings_rounded,
              onPressed: () {
                _navigator.pop();
                unawaited(
                  _navigator.pushNamed(SettingsScreen.route).then((_) {
                    if (mounted) unawaited(_loadPlayerState());
                  }),
                );
              },
            ),
            const SizedBox(height: GameSpacing.md),
            GameButton(
              label: 'Back to Map',
              icon: Icons.map_rounded,
              onPressed: () {
                _navigator.pop();
                if (_navigator.canPop()) _navigator.pop();
              },
              variant: GameButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWin() async {
    if (_winDialogShowing || !mounted) return;
    _winDialogShowing = true;
    final scope = _scope;
    final bossInfo = _BossLevelInfo.forLevel(widget.level);
    final undoUsed = _undoUsedThisLevel;
    final hintUsed = _hintUsedThisLevel;
    final shuffleUsed = _shuffleUsedThisLevel;
    final starsEarned = _starsForBoostersUsed(
      undoUsed: undoUsed,
      hintUsed: hintUsed,
      shuffleUsed: shuffleUsed,
    );
    await scope.progressRepository.unlockNextLevel(widget.level);
    await scope.progressRepository
        .recordLevelCompleted(widget.level, starsEarned);
    if (bossInfo != null) {
      await scope.progressRepository.addXp(_bossXpReward);
    }
    final coinsEarned =
        _levelCompleteCoinReward + (bossInfo == null ? 0 : _bossCoinReward);
    final updatedCoins = await scope.progressRepository.addCoins(coinsEarned);
    final chestGrant = await scope.progressRepository.grantChestForLevel(
      widget.level,
    );
    if (!mounted) {
      _winDialogShowing = false;
      return;
    }
    setState(() => _coins = updatedCoins);
    if (chestGrant.slotsFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chest slots full')),
      );
    } else if (chestGrant.chest != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${chestGrant.chest!.title} added')),
      );
    }
    _playSfx(scope.audioService.playWin, 'win');
    _haptic(HapticFeedback.heavyImpact);
    await showPendingAchievementPopups(context, scope.progressRepository);
    if (!mounted) return;

    if (bossInfo != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BossCompleteDialog(
          bossInfo: bossInfo,
          coinsEarned: _bossCoinReward,
          xpEarned: _bossXpReward,
          chestLabel: chestGrant.slotsFull
              ? 'Chest slots full'
              : chestGrant.chest?.title ?? 'Gold Chest',
          onContinue: () => _navigator.pop(),
        ),
      );
      if (!mounted) return;
      if (widget.level == LevelRepository.levelCount) {
        _winDialogShowing = false;
        await _navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const FinalCodeScreen(),
          ),
        );
        return;
      }
      _winDialogShowing = false;
      if (_navigator.canPop()) _navigator.pop();
      return;
    }

    if (widget.level == LevelRepository.levelCount) {
      _winDialogShowing = false;
      await _navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const FinalCodeScreen(),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WinScreen(
        level: widget.level,
        isFinalLevel: widget.level == LevelRepository.levelCount,
        tilesCleared: _engine?.tiles.length ?? 0,
        undoUsed: undoUsed,
        hintUsed: hintUsed,
        shuffleUsed: shuffleUsed,
        starsEarned: starsEarned,
        coinsEarned: coinsEarned,
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
          if (!mounted) return;
          await _navigator.pushReplacementNamed(
            GameScreen.route,
            arguments: widget.level + 1,
          );
        },
      ),
    );
    if (mounted) _winDialogShowing = false;
  }

  int _starsForBoostersUsed({
    required int undoUsed,
    required int hintUsed,
    required int shuffleUsed,
  }) {
    final total = undoUsed + hintUsed + shuffleUsed;
    if (total == 0) return 3;
    if (total <= 2) return 2;
    return 1;
  }

  String _gameHeaderTitle(LevelDefinition level) {
    return _BossLevelInfo.forLevel(widget.level)?.bossTitle ?? level.name;
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
        _queueLevelOneTutorial();
        final engine = _engine!;
        final visualTheme = tileVisualThemeForLevel(widget.level);
        final worldTheme = WorldThemes.forTileTheme(visualTheme);
        final visualCatalog = tileCatalogForTheme(
          visualTheme,
        );
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
                  worldTheme: worldTheme,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        GameHeader(
                          title: _gameHeaderTitle(level),
                          onBack: () => Navigator.of(context).maybePop(),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GameBadge(
                                icon: Icons.monetization_on_rounded,
                                gradient: GameGradients.badge,
                                child: Text(
                                  '$_coins',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: GameSpacing.sm),
                              GameBadge(
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
                              const SizedBox(width: GameSpacing.sm),
                              GameRoundIconButton(
                                icon: Icons.pause_rounded,
                                onPressed: () => _showPauseMenu(level),
                              ),
                            ],
                          ),
                        ),
                        if (level.objective != null) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              GameSpacing.lg,
                              0,
                              GameSpacing.lg,
                              GameSpacing.sm,
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _ObjectiveBadge(
                                objective: level.objective!,
                                progress: engine.objectiveProgress,
                                catalog: visualCatalog,
                                theme: visualTheme,
                              ),
                            ),
                          ),
                        ],
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
                                              catalog: visualCatalog,
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
                          worldTheme: worldTheme,
                          onShuffle: _canUseBooster(
                                  _shuffleUsesRemaining, _extraShuffleBoosters)
                              ? () => unawaited(_useShuffle(engine))
                              : null,
                          onHint: _canUseBooster(
                                  _hintUsesRemaining, _extraHintBoosters)
                              ? () => _useCatPowerUp(level, boardSize, tileSize)
                              : null,
                          undoLabel: _boosterCostLabel(
                              _undoUsesRemaining, _extraUndoBoosters),
                          hintLabel: _boosterCostLabel(
                              _hintUsesRemaining, _extraHintBoosters),
                          shuffleLabel: _boosterCostLabel(
                              _shuffleUsesRemaining, _extraShuffleBoosters),
                          onUndo: engine.canUndo &&
                                  _canUseBooster(
                                      _undoUsesRemaining, _extraUndoBoosters)
                              ? () => unawaited(_useUndo(engine))
                              : null,
                        ),
                        _Tray(
                          trayTiles: trayTiles,
                          catalog: visualCatalog,
                          worldTheme: worldTheme,
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

class _BossLevelInfo {
  const _BossLevelInfo({
    required this.level,
    required this.bossTitle,
    required this.completeTitle,
    required this.subtitle,
    required this.icon,
  });

  final int level;
  final String bossTitle;
  final String completeTitle;
  final String subtitle;
  final IconData icon;

  static _BossLevelInfo? forLevel(int level) {
    switch (level) {
      case 10:
        return const _BossLevelInfo(
          level: 10,
          bossTitle: 'Garden Boss',
          completeTitle: 'World Complete!',
          subtitle: 'New World Unlocked!',
          icon: Icons.local_florist_rounded,
        );
      case 20:
        return const _BossLevelInfo(
          level: 20,
          bossTitle: 'Ocean Boss',
          completeTitle: 'World Complete!',
          subtitle: 'New World Unlocked!',
          icon: Icons.water_rounded,
        );
      case 30:
        return const _BossLevelInfo(
          level: 30,
          bossTitle: 'Candy Boss',
          completeTitle: 'World Complete!',
          subtitle: 'New World Unlocked!',
          icon: Icons.icecream_rounded,
        );
      case 40:
        return const _BossLevelInfo(
          level: 40,
          bossTitle: 'Space Boss',
          completeTitle: 'Final World Complete',
          subtitle: 'Game Completed',
          icon: Icons.auto_awesome_rounded,
        );
      default:
        return null;
    }
  }
}

class _BossCompleteDialog extends StatelessWidget {
  const _BossCompleteDialog({
    required this.bossInfo,
    required this.coinsEarned,
    required this.xpEarned,
    required this.chestLabel,
    required this.onContinue,
  });

  final _BossLevelInfo bossInfo;
  final int coinsEarned;
  final int xpEarned;
  final String chestLabel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return GameDialogFrame(
      title: bossInfo.completeTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: GameGradients.badge,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: GameShadows.glow(GameColors.accentGold),
            ),
            child: Icon(
              bossInfo.icon,
              color: Colors.white,
              size: 54,
            ),
          ),
          const SizedBox(height: GameSpacing.md),
          Text(
            bossInfo.bossTitle,
            textAlign: TextAlign.center,
            style: GameTextStyles.h2.copyWith(fontSize: 28),
          ),
          const SizedBox(height: GameSpacing.xs),
          Text(
            bossInfo.subtitle,
            textAlign: TextAlign.center,
            style: GameTextStyles.body,
          ),
          const SizedBox(height: GameSpacing.lg),
          GameCard(
            padding: const EdgeInsets.all(GameSpacing.md),
            shadow: GameShadows.light(),
            borderColor: GameColors.borderBlue,
            child: Column(
              children: [
                _BossRewardRow(
                  icon: Icons.monetization_on_rounded,
                  label: 'Boss coins',
                  value: '+$coinsEarned',
                ),
                const SizedBox(height: GameSpacing.sm),
                _BossRewardRow(
                  icon: Icons.bolt_rounded,
                  label: 'Boss XP',
                  value: '+$xpEarned',
                ),
                const SizedBox(height: GameSpacing.sm),
                _BossRewardRow(
                  icon: Icons.inventory_2_rounded,
                  label: 'Chest',
                  value: chestLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: GameSpacing.xl),
          GameButton(
            label: bossInfo.level == LevelRepository.levelCount
                ? 'Final Reward'
                : 'Back to Map',
            icon: bossInfo.level == LevelRepository.levelCount
                ? Icons.pin_rounded
                : Icons.map_rounded,
            onPressed: onContinue,
            variant: GameButtonVariant.success,
          ),
        ],
      ),
    );
  }
}

class _BossRewardRow extends StatelessWidget {
  const _BossRewardRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: GameGradients.badge,
            borderRadius: GameRadius.mediumRadius,
            boxShadow: GameShadows.light(GameColors.accentGold),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: GameSpacing.md),
        Expanded(child: Text(label, style: GameTextStyles.body)),
        Text(
          value,
          textAlign: TextAlign.right,
          style: GameTextStyles.button.copyWith(color: GameColors.ink),
        ),
      ],
    );
  }
}

class _GameOverDialog extends StatelessWidget {
  const _GameOverDialog({
    required this.canUseShuffle,
    required this.onBackToMap,
    required this.onUseShuffle,
    required this.onRestart,
  });

  final bool canUseShuffle;
  final VoidCallback onBackToMap;
  final VoidCallback onUseShuffle;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    return GameDialogFrame(
      title: 'Game Over',
      onClose: onBackToMap,
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
            label: 'Restart',
            icon: Icons.refresh_rounded,
            onPressed: onRestart,
            variant: GameButtonVariant.success,
          ),
          const SizedBox(height: GameSpacing.md),
          GameButton(
            label: 'Use Shuffle',
            icon: Icons.air_rounded,
            onPressed: canUseShuffle ? onUseShuffle : null,
            variant: GameButtonVariant.gold,
          ),
          const SizedBox(height: GameSpacing.md),
          GameButton(
            label: 'Back to Map',
            icon: Icons.map_rounded,
            onPressed: onBackToMap,
            variant: GameButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;
}

class _LevelOneTutorialDialog extends StatefulWidget {
  const _LevelOneTutorialDialog();

  @override
  State<_LevelOneTutorialDialog> createState() =>
      _LevelOneTutorialDialogState();
}

class _LevelOneTutorialDialogState extends State<_LevelOneTutorialDialog> {
  static const _steps = <_TutorialStep>[
    _TutorialStep(
      icon: Icons.touch_app_rounded,
      text: 'Tap 3 matching tiles to clear them.',
    ),
    _TutorialStep(
      icon: Icons.inventory_2_rounded,
      text: 'Do not fill the tray.',
    ),
    _TutorialStep(
      icon: Icons.auto_fix_high_rounded,
      text: 'Use boosters if you get stuck.',
    ),
  ];

  int _index = 0;

  void _next() {
    if (_index >= _steps.length - 1) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_index];
    return GameDialogFrame(
      title: 'How to Play',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TutorialTip(icon: step.icon, text: step.text),
          const SizedBox(height: GameSpacing.md),
          Text(
            '${_index + 1}/${_steps.length}',
            style: GameTextStyles.caption,
          ),
          const SizedBox(height: GameSpacing.xl),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  label: 'Skip',
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.of(context).pop(true),
                  variant: GameButtonVariant.secondary,
                ),
              ),
              const SizedBox(width: GameSpacing.md),
              Expanded(
                child: GameButton(
                  label: 'Next',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _next,
                  variant: GameButtonVariant.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TutorialTip extends StatelessWidget {
  const _TutorialTip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      padding: const EdgeInsets.all(GameSpacing.md),
      shadow: GameShadows.light(),
      child: Row(
        children: [
          Icon(icon, color: GameColors.primaryBlue, size: 28),
          const SizedBox(width: GameSpacing.md),
          Expanded(child: Text(text, style: GameTextStyles.body)),
        ],
      ),
    );
  }
}

class _ObjectiveBadge extends StatelessWidget {
  const _ObjectiveBadge({
    required this.objective,
    required this.progress,
    required this.catalog,
    required this.theme,
  });

  final LevelObjective objective;
  final int progress;
  final Map<String, TileArt> catalog;
  final TileVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    final art = catalog[objective.type];
    final visibleProgress = progress.clamp(0, objective.target);
    final isComplete = visibleProgress >= objective.target;
    final label = tileLabelForTheme(theme, objective.type);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GameSpacing.md,
        vertical: GameSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient:
            isComplete ? GameGradients.successButton : GameGradients.darkBadge,
        borderRadius: GameRadius.largeRadius,
        border: Border.all(color: Colors.white30, width: 1.5),
        boxShadow: isComplete
            ? GameShadows.glow(GameColors.successGreen)
            : GameShadows.medium(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: GameGradients.goldButton,
              shape: BoxShape.circle,
              boxShadow: GameShadows.light(),
            ),
            child: Icon(
              isComplete
                  ? Icons.check_rounded
                  : art?.icon ?? Icons.flag_rounded,
              color: isComplete ? Colors.white : art?.color ?? Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: GameSpacing.sm),
          Text(
            '$label $visibleProgress/${objective.target}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoosterBar extends StatelessWidget {
  const _BoosterBar({
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
            child: _BoosterButton(
              onPressed: onUndo,
              icon: const Icon(Icons.arrow_back_rounded),
              label: 'Undo',
              badge: undoLabel,
              accent: worldTheme.boosterAccents[0],
            ),
          ),
          const SizedBox(width: GameSpacing.sm),
          Expanded(
            child: _BoosterButton(
              onPressed: onHint,
              icon: const Icon(Icons.pets_rounded),
              label: 'Hint',
              badge: hintLabel,
              accent: worldTheme.boosterAccents[1],
            ),
          ),
          const SizedBox(width: GameSpacing.sm),
          Expanded(
            child: _BoosterButton(
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

class _BoosterButton extends StatelessWidget {
  const _BoosterButton({
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

class _Tray extends StatelessWidget {
  const _Tray({
    required this.trayTiles,
    required this.catalog,
    required this.worldTheme,
  });

  final List<Tile?> trayTiles;
  final Map<String, TileArt> catalog;
  final WorldVisualTheme worldTheme;

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
                        catalog: catalog,
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
        gradient: worldTheme.trayGradient,
        borderRadius: GameRadius.extraLargeRadius,
        border: Border.all(
          color: worldTheme.secondaryAccent.withValues(alpha: 0.78),
          width: 3,
        ),
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
