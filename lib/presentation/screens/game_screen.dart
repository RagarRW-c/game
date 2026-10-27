import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/foundation.dart';
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
import '../tile_feedback.dart';
import '../widgets/achievement_popup.dart';
import '../widgets/game_over_dialog.dart';
import '../widgets/game_tile.dart';
import '../widgets/game_tray.dart';
import '../widgets/tile_effects.dart';
import '../widgets/tile_face.dart';
import '../widgets/game_surfaces.dart';
import '../widgets/game_ui.dart';
import '../widgets/victory_video.dart';
import 'final_code_screen.dart';
import 'map_screen.dart';
import 'world_selection_screen.dart';
import 'settings_screen.dart';
import 'win_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen(
      {super.key, required this.level, this.victoryVideoControllerFactory});

  static const route = '/game';
  final int level;
  @visibleForTesting
  final VictoryVideoControllerFactory? victoryVideoControllerFactory;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with RouteAware {
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
  TrayFeedback? _trayFeedback;
  final _tileEffects = TileEffectsController();
  int _feedbackSerial = 0;
  bool _gameOverDialogShowing = false;
  bool _winDialogShowing = false;
  bool _tutorialQueued = false;
  PageRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    safelyPlayFeedback(_scope.audioService.prepareTileFeedback);
    _navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (_route == null && route is PageRoute<dynamic>) {
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
    _startLevelMusic();
    _levelFuture = _scope.levelRepository.loadLevel(widget.level);
    unawaited(_loadPlayerState());
  }

  @override
  void didPush() {
    _startLevelMusic();
  }

  @override
  void didPopNext() {
    _startLevelMusic();
  }

  void _startLevelMusic() {
    // An outgoing route may rebuild when isCurrent changes. It must not reclaim
    // music ownership from the level that was just pushed/replaced above it.
    if (!_winDialogShowing &&
        _engine?.result != GameResult.won &&
        (_route?.isCurrent ?? true)) {
      unawaited(_scope.audioService
          .startGameplayMusic(level: widget.level, owner: this));
    }
  }

  @override
  void dispose() {
    _tileEffects.dispose();
    final route = _route;
    if (route != null) appRouteObserver.unsubscribe(this);
    unawaited(_scope.audioService.stopGameplayMusic(owner: this));
    super.dispose();
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
      _startLevelMusic();
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
        if (kDebugMode) debugPrint('SFX $cue failed: $error');
      }),
    );
  }

  void _haptic(Future<void> Function() feedback) {
    if (!_vibrationEnabled) return;
    safelyPlayFeedback(feedback);
  }

  void _showNotEnoughCoins() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not enough coins')),
    );
  }

  void _resetAnimationState() {
    _tileEffects.clear();
    _hintedTileIds.clear();
    _trayFeedback = null;
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
      await showPendingAchievementPopups(
        context,
        _scope.progressRepository,
        onPopup: _scope.audioService.playAchievementUnlocked,
      );
    }
  }

  Future<void> _recordBoosterUsed(BoosterKind kind) async {
    await _scope.progressRepository.recordBoosterUsed(kind);
    final coins = await _scope.progressRepository.coins();
    if (mounted) setState(() => _coins = coins);
    if (mounted) {
      await showPendingAchievementPopups(
        context,
        _scope.progressRepository,
        onPopup: _scope.audioService.playAchievementUnlocked,
      );
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

  void _showMoveFeedback(
      List<String> before, Iterable<String> collected, Set<String> matchedIds,
      {TileFlightSource? source}) {
    final engine = _engine;
    if (!mounted || engine == null) return;
    setState(() {
      _trayFeedback = TrayFeedback(
          serial: ++_feedbackSerial,
          matched: matchedIds.isNotEmpty,
          before: before,
          collected: collected,
          matchedIds: matchedIds);
    });
    final audio = _scope.audioService;
    _tileEffects.cancelPendingAudio = audio.cancelPendingTileFeedback;
    final deferredMatch = _tileEffects.accepted(
        source: source,
        slot: before.length,
        tray: engine.tray,
        matchedIds: matchedIds,
        beforeTiles: [
          for (final id in before)
            if (engine.tileById(id) != null) engine.tileById(id)!,
        ],
        matchedTiles: [
          for (final id in [...before, ...collected])
            if (matchedIds.contains(id) && engine.tileById(id) != null)
              engine.tileById(id)!,
        ],
        matchedSlots: _trayFeedback!.slots,
        placement: trayPlacementForRound(widget.level),
        onMatchBurst: engine.result == GameResult.playing
            ? () => dispatchTileMatch(audio)
            : null);
    dispatchTileFeedback(
        audio: _scope.audioService,
        matched: matchedIds.isNotEmpty,
        deferMatch: deferredMatch,
        tapped: source != null || !deferredMatch,
        vibrationEnabled: _vibrationEnabled,
        terminal: engine.result != GameResult.playing);
  }

  Future<void> _onTileTap(
      LevelDefinition level, Tile tile, Size boardSize, Size tileSize,
      {TileFlightSource? source}) async {
    if (!mounted) return;
    final engine = _engine;
    if (engine == null || engine.result != GameResult.playing) {
      return;
    }

    final canonicalTile = engine.tileById(tile.id);
    if (canonicalTile == null ||
        !engine.isUncovered(canonicalTile, boardSize, tileSize)) {
      return;
    }

    final beforeTrayIds = List<String>.from(engine.tray);

    late final bool moved;
    if (!_safeSetState(() {
      _hintedTileIds.clear();
      moved = engine.tapTile(canonicalTile.id, boardSize, tileSize);
    })) {
      return;
    }
    if (!moved) {
      if (engine.result == GameResult.lost) {
        await _handleGameOver(level: level);
      }
      return;
    }

    final matchedIds = _matchedIdsAfterMove(
      beforeTrayIds,
      collectedId: canonicalTile.id,
    );
    _showMoveFeedback(beforeTrayIds, [canonicalTile.id], matchedIds,
        source: source);
    if (matchedIds.isNotEmpty) {
      await _recordMatchedTiles(
        matchedIds.length,
        tileTypes: _tileTypesForIds(matchedIds),
      );
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
    if (engine == null || engine.result != GameResult.playing) {
      return;
    }
    engine.updateBoardGeometry(boardSize, tileSize);
    final hintIds = engine.findBestHintTileIds();
    if (hintIds.isEmpty) {
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
    late final bool collected;
    if (!_safeSetState(() {
      _hintedTileIds.clear();
      collected = engine.collectHintTileIds(hintIds);
      if (collected && usedFreeHint) _hintUsesRemaining--;
      if (collected) _hintUsedThisLevel++;
    })) {
      return;
    }
    if (!collected) {
      if (engine.result == GameResult.lost) await _handleGameOver(level: level);
      return;
    }

    final removedIds =
        _matchedIdsAfterMove(beforeTrayIds, preferredIds: hintIds.toSet());
    if (removedIds.isNotEmpty) {
      _showMoveFeedback(beforeTrayIds, hintIds, removedIds);
      await _recordMatchedTiles(
        removedIds.length,
        tileTypes: _tileTypesForIds(removedIds),
      );
    } else {
      _playSfx(_scope.audioService.playBooster, 'booster');
    }
    unawaited(_recordBoosterUsed(BoosterKind.hint));
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

    late final bool shuffled;
    if (!_safeSetState(() {
      _hintedTileIds.clear();
      if (fromGameOver && engine.result == GameResult.lost) {
        engine.result = GameResult.playing;
      }
      shuffled = engine.shuffleBoard();
      if (shuffled) {
        _trayFeedback = null;
        _tileEffects.clear();
      }
      if (shuffled && usedFreeShuffle) _shuffleUsesRemaining--;
      if (shuffled) _shuffleUsedThisLevel++;
    })) {
      return false;
    }
    if (!shuffled) return false;
    _playSfx(_scope.audioService.playBooster, 'booster');
    unawaited(_recordBoosterUsed(BoosterKind.shuffle));
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
    }
  }

  Future<void> _handleGameOver({required LevelDefinition? level}) async {
    if (_gameOverDialogShowing || !mounted) return;
    _gameOverDialogShowing = true;
    _playSfx(_scope.audioService.playGameOver, 'game_over');
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
            const GameRewardEmblem(icon: Icons.pause_rounded),
            const SizedBox(height: GameSpacing.md),
            const Text('Ready when you are', style: GameTextStyles.body),
            const SizedBox(height: GameSpacing.lg),
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
    unawaited(scope.audioService.pauseGameplayMusicForVictory(owner: this));
    final bossInfo = _BossLevelInfo.forLevel(widget.level);
    final undoUsed = _undoUsedThisLevel;
    final hintUsed = _hintUsedThisLevel;
    final shuffleUsed = _shuffleUsedThisLevel;
    final starsEarned = _starsForBoostersUsed(
      undoUsed: undoUsed,
      hintUsed: hintUsed,
      shuffleUsed: shuffleUsed,
    );
    // Read the actual awarded XP for presentation; reward policy stays in the
    // repository and the existing boss grant below.
    final xpBefore = (await scope.progressRepository.playerProfile()).totalXp;
    await scope.progressRepository.unlockNextLevel(widget.level);
    await scope.progressRepository
        .recordLevelCompleted(widget.level, starsEarned);
    if (bossInfo != null) {
      await scope.progressRepository.addXp(_bossXpReward);
    }
    final xpEarned =
        (await scope.progressRepository.playerProfile()).totalXp - xpBefore;
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
    // Campaign completion stays silent until the victory track is approved.
    _haptic(HapticFeedback.heavyImpact);
    await showPendingAchievementPopups(
      context,
      scope.progressRepository,
      onPopup: scope.audioService.playAchievementUnlocked,
    );
    if (!mounted) return;

    if (bossInfo != null) {
      _playSfx(scope.audioService.playWorldUnlocked, 'world_unlock');
    }
    // A double tap during the dialog's reverse transition must not pop the
    // gameplay route or request the next level twice.
    var resultActionTaken = false;
    bool takeResultAction() {
      if (!mounted || resultActionTaken) return false;
      resultActionTaken = true;
      return true;
    }

    void returnToMap() {
      if (!takeResultAction()) return;
      final rootGame = _route?.isFirst ?? true;
      _navigator.pop(); // Victory dialog.
      if (rootGame) {
        // A directly opened game has no map underneath. Replace it rather
        // than popping the last route or leaving the completed board reachable.
        final world = gameWorlds.firstWhere((world) =>
            widget.level >= world.startLevel && widget.level <= world.endLevel);
        unawaited(_navigator.pushReplacement(MaterialPageRoute<void>(
            settings: const RouteSettings(name: MapScreen.route),
            builder: (_) => MapScreen(world: world))));
      } else {
        _navigator.pop(); // Existing campaign map/caller.
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) returnToMap();
          },
          child: WinScreen(
            videoControllerFactory: widget.victoryVideoControllerFactory,
            level: widget.level,
            isFinalLevel: widget.level == LevelRepository.levelCount,
            tilesCleared: _engine?.tiles.length ?? 0,
            undoUsed: undoUsed,
            hintUsed: hintUsed,
            shuffleUsed: shuffleUsed,
            starsEarned: starsEarned,
            coinsEarned: coinsEarned,
            xpEarned: xpEarned,
            chestLabel: chestGrant.slotsFull
                ? 'Chest slots full'
                : chestGrant.chest?.title,
            isBossLevel: bossInfo != null,
            bossTitle: bossInfo?.bossTitle,
            emblemIcon: bossInfo?.icon,
            milestoneTitle: bossInfo?.completeTitle,
            milestoneMessage: bossInfo?.subtitle,
            onRestart: () {
              if (!takeResultAction()) return;
              _navigator.pop();
              _safeSetState(() {
                _engine = null;
                _resetAnimationState();
                _resetBoosterUses();
              });
            },
            onMap: returnToMap,
            onNext: () async {
              if (!takeResultAction()) return;
              _navigator.pop();
              if (!mounted) return;
              if (widget.level == LevelRepository.levelCount) {
                await _navigator.pushReplacement(MaterialPageRoute<void>(
                  builder: (_) => const FinalCodeScreen(),
                ));
                return;
              }
              await _navigator.pushReplacementNamed(
                GameScreen.route,
                arguments: widget.level + 1,
              );
            },
          )),
    );
    if (mounted) {
      _winDialogShowing = false;
      _startLevelMusic(); // Replay only; a completed board cannot reclaim music.
    }
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
          if (tile == null) return false;
          if (!seenIds.add(id)) return false;
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
          if (kDebugMode) {
            debugPrint('Game build failed to load level: ${snapshot.error}');
          }
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
                final boardWidth =
                    (constraints.maxWidth - 20).clamp(0.0, 440.0).toDouble();
                final boardSize = Size(
                  boardWidth,
                  boardHeight.clamp(360.0, 620.0).toDouble(),
                );
                final tileSize = _tileSize(boardWidth + 20);
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
                  child: GameTileEffects(
                      controller: _tileEffects,
                      round: widget.level,
                      child: SafeArea(
                        child: Column(
                          children: [
                            // Scaled titles and wrapped counters can exceed the
                            // entire short-screen height. Bound only the HUD;
                            // scroll its full-size content instead of letting
                            // it overflow the tray/boosters or collapse the board.
                            // Ordinary HUDs retain their natural height.
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: (constraints.maxHeight -
                                        MediaQuery.paddingOf(context)
                                            .vertical) *
                                    .4,
                              ),
                              child: SingleChildScrollView(
                                key: const ValueKey('game_hud_scroll'),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GameHeader(
                                      title: _gameHeaderTitle(level),
                                      worldTheme: worldTheme,
                                      onBack: () =>
                                          Navigator.of(context).maybePop(),
                                      trailing: GameRoundIconButton(
                                        icon: Icons.pause_rounded,
                                        onPressed: () => _showPauseMenu(level),
                                      ),
                                    ),
                                    // The header Row measures non-flex actions at their
                                    // full width. Give statistics their own bounded Wrap
                                    // so long counters cannot crowd out the title/actions.
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        GameSpacing.lg,
                                        0,
                                        GameSpacing.lg,
                                        GameSpacing.sm,
                                      ),
                                      child: Wrap(
                                        spacing: GameSpacing.sm,
                                        runSpacing: GameSpacing.sm,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          GameBadge(
                                            icon: Icons.monetization_on_rounded,
                                            gradient: worldTheme.hudGradient,
                                            child: Text(
                                              '$_coins',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          GameBadge(
                                            icon: Icons.track_changes_rounded,
                                            gradient: worldTheme.hudGradient,
                                            child: Text(
                                              '$boardCount left',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
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
                                  ],
                                ),
                              ),
                            ),
                            if (trayPlacementForRound(widget.level) ==
                                TrayPlacement.top)
                              GameTray(
                                  trayTiles: trayTiles,
                                  feedback: _trayFeedback,
                                  effects: _tileEffects,
                                  catalog: visualCatalog,
                                  worldTheme: worldTheme),
                            Expanded(
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Container(
                                    // Container reserves its border as padding.
                                    // Frame it OUTSIDE the logical canvas so the
                                    // Stack and engine use the same dimensions.
                                    // FittedBox scales canvas + frame together.
                                    width: boardSize.width + 4,
                                    height: boardSize.height + 4,
                                    margin:
                                        const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                    decoration:
                                        boardSurfaceDecoration(worldTheme),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned.fill(
                                            child: GameBoardBackdrop(
                                                theme: worldTheme)),
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
                                                    coveredById[tile.id] ??
                                                        true;
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
                                                              source: _tileEffects
                                                                  .capture(
                                                                      context,
                                                                      tile,
                                                                      visualCatalog,
                                                                      depth),
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
                            ),
                            _BoosterBar(
                              worldTheme: worldTheme,
                              onShuffle: _canUseBooster(_shuffleUsesRemaining,
                                      _extraShuffleBoosters)
                                  ? () => unawaited(_useShuffle(engine))
                                  : null,
                              onHint: _canUseBooster(
                                      _hintUsesRemaining, _extraHintBoosters)
                                  ? () =>
                                      _useCatPowerUp(level, boardSize, tileSize)
                                  : null,
                              undoLabel: _boosterCostLabel(
                                  _undoUsesRemaining, _extraUndoBoosters),
                              hintLabel: _boosterCostLabel(
                                  _hintUsesRemaining, _extraHintBoosters),
                              shuffleLabel: _boosterCostLabel(
                                  _shuffleUsesRemaining, _extraShuffleBoosters),
                              onUndo: engine.canUndo &&
                                      _canUseBooster(_undoUsesRemaining,
                                          _extraUndoBoosters)
                                  ? () => unawaited(_useUndo(engine))
                                  : null,
                            ),
                            if (trayPlacementForRound(widget.level) ==
                                TrayPlacement.bottom)
                              GameTray(
                                effects: _tileEffects,
                                trayTiles: trayTiles,
                                feedback: _trayFeedback,
                                catalog: visualCatalog,
                                worldTheme: worldTheme,
                              ),
                          ],
                        ),
                      )),
                );
              } catch (error, stackTrace) {
                if (kDebugMode) {
                  debugPrint('Game build fallback: $error');
                  debugPrint('$stackTrace');
                }
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
          completeTitle: 'World Complete!',
          subtitle: 'New World Unlocked!',
          icon: Icons.auto_awesome_rounded,
        );
      case 50:
        return const _BossLevelInfo(
          level: 50,
          bossTitle: 'Desert Boss',
          completeTitle: 'World Complete!',
          subtitle: 'New World Unlocked!',
          icon: Icons.wb_sunny_rounded,
        );
      case 60:
        return const _BossLevelInfo(
          level: 60,
          bossTitle: 'Ice Boss',
          completeTitle: 'World Complete!',
          subtitle: 'New World Unlocked!',
          icon: Icons.ac_unit_rounded,
        );
      case 70:
        return const _BossLevelInfo(
          level: 70,
          bossTitle: 'Jungle Boss',
          completeTitle: 'World Complete!',
          subtitle: 'New World Unlocked!',
          icon: Icons.forest_rounded,
        );
      case 80:
        return const _BossLevelInfo(
          level: 80,
          bossTitle: 'Volcano Boss',
          completeTitle: 'World Complete!',
          subtitle: 'New World Unlocked!',
          icon: Icons.local_fire_department_rounded,
        );
      case 90:
        return const _BossLevelInfo(
          level: 90,
          bossTitle: 'Dream Boss',
          completeTitle: 'World Complete!',
          subtitle: 'New World Unlocked!',
          icon: Icons.cloud_rounded,
        );
      case 100:
        return const _BossLevelInfo(
          level: 100,
          bossTitle: 'Crystal Boss',
          completeTitle: 'Final World Complete',
          subtitle: 'Game Completed',
          icon: Icons.diamond_rounded,
        );
      default:
        return null;
    }
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
    return GameOverDialog(
      canUseShuffle: canUseShuffle,
      onBackToMap: onBackToMap,
      onUseShuffle: onUseShuffle,
      onRestart: onRestart,
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
      key: const ValueKey('game_objective'),
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
            child: !isComplete && (art?.hasIllustratedSymbol ?? false)
                ? TileSymbol(art: art!, blocked: false)
                : Icon(
                    isComplete
                        ? Icons.check_rounded
                        : art?.icon ?? Icons.flag_rounded,
                    color:
                        isComplete ? Colors.white : art?.color ?? Colors.white,
                    size: 19,
                  ),
          ),
          const SizedBox(width: GameSpacing.sm),
          Flexible(
            child: Text(
              '$label $visibleProgress/${objective.target}',
              key: const ValueKey('game_objective_label'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
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
            child: GameBoosterButton(
              onPressed: onUndo,
              icon: const Icon(Icons.arrow_back_rounded),
              label: 'Undo',
              badge: undoLabel,
              accent: worldTheme.boosterAccents[0],
            ),
          ),
          const SizedBox(width: GameSpacing.sm),
          Expanded(
            child: GameBoosterButton(
              onPressed: onHint,
              icon: const Icon(Icons.pets_rounded),
              label: 'Hint',
              badge: hintLabel,
              accent: worldTheme.boosterAccents[1],
            ),
          ),
          const SizedBox(width: GameSpacing.sm),
          Expanded(
            child: GameBoosterButton(
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
