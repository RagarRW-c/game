import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailySpinStatus {
  const DailySpinStatus({
    required this.polishTodayKey,
    required this.lastSpinDate,
    required this.canSpin,
  });

  final String polishTodayKey;
  final String? lastSpinDate;
  final bool canSpin;
}

class DailyLoginStreakStatus {
  const DailyLoginStreakStatus({
    required this.todayKey,
    required this.lastClaimDate,
    required this.currentStreak,
    required this.claimDay,
    required this.reward,
    required this.available,
  });

  final String todayKey;
  final String? lastClaimDate;
  final int currentStreak;
  final int claimDay;
  final int reward;
  final bool available;
}

class DailyLoginStreakClaim {
  const DailyLoginStreakClaim({
    required this.status,
    required this.coins,
  });

  final DailyLoginStreakStatus status;
  final int coins;
}

enum DailyChallengeId { completeLevel, matchTiles, useLuckyWheel }

enum BoosterKind { undo, hint, shuffle }

enum AchievementId {
  firstMatch,
  firstWin,
  gardenWorld,
  oceanWorld,
  candyWorld,
  spaceWorld,
  luckyPlayer,
  boosterMaster,
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.reward,
  });

  final AchievementId id;
  final String name;
  final String description;
  final int reward;
}

class AchievementState {
  const AchievementState({
    required this.definition,
    required this.unlocked,
  });

  final AchievementDefinition definition;
  final bool unlocked;
}

class PendingAchievementPopup {
  const PendingAchievementPopup({required this.definition});

  final AchievementDefinition definition;
}

class GameStatistics {
  const GameStatistics({
    required this.levelsCompleted,
    required this.totalTilesMatched,
    required this.totalCoinsEarned,
    required this.totalBoostersUsed,
    required this.hintsUsed,
    required this.shufflesUsed,
    required this.undosUsed,
    required this.luckyWheelSpins,
    required this.bestStarsTotal,
  });

  final int levelsCompleted;
  final int totalTilesMatched;
  final int totalCoinsEarned;
  final int totalBoostersUsed;
  final int hintsUsed;
  final int shufflesUsed;
  final int undosUsed;
  final int luckyWheelSpins;
  final int bestStarsTotal;
}

class FinalRewardSummary {
  const FinalRewardSummary({
    required this.code,
    required this.totalStars,
    required this.levelsCompleted,
    required this.achievementsUnlocked,
  });

  final String code;
  final int totalStars;
  final int levelsCompleted;
  final int achievementsUnlocked;
}

class DailyChallengesState {
  const DailyChallengesState({
    required this.dateKey,
    required this.completedLevels,
    required this.matchedTiles,
    required this.luckyWheelUsed,
    required this.completeLevelClaimed,
    required this.matchTilesClaimed,
    required this.luckyWheelClaimed,
  });

  final String dateKey;
  final int completedLevels;
  final int matchedTiles;
  final bool luckyWheelUsed;
  final bool completeLevelClaimed;
  final bool matchTilesClaimed;
  final bool luckyWheelClaimed;

  bool isComplete(DailyChallengeId id) {
    switch (id) {
      case DailyChallengeId.completeLevel:
        return completedLevels >= 1;
      case DailyChallengeId.matchTiles:
        return matchedTiles >= 30;
      case DailyChallengeId.useLuckyWheel:
        return luckyWheelUsed;
    }
  }

  bool isClaimed(DailyChallengeId id) {
    switch (id) {
      case DailyChallengeId.completeLevel:
        return completeLevelClaimed;
      case DailyChallengeId.matchTiles:
        return matchTilesClaimed;
      case DailyChallengeId.useLuckyWheel:
        return luckyWheelClaimed;
    }
  }
}

class ProgressRepository {
  static const _highestLevelKey = 'highest_unlocked_level';
  static const _musicKey = 'music_enabled';
  static const _sfxKey = 'sfx_enabled';
  static const _vibrationKey = 'vibration_enabled';
  static const _codeKey = 'final_code';
  static const _coinsKey = 'coins';
  static const _lastDailyRewardDateKey = 'last_daily_reward_date';
  static const _dailyLoginStreakKey = 'daily_login_streak';
  static const _dailyLoginLastClaimDateKey = 'daily_login_last_claim_date';
  static const _lastDailySpinDateKey = 'last_daily_spin_date';
  static const _levelOneTutorialSeenKey = 'level_one_tutorial_seen';
  static const _extraHintBoostersKey = 'extra_hint_boosters';
  static const _extraShuffleBoostersKey = 'extra_shuffle_boosters';
  static const _extraUndoBoostersKey = 'extra_undo_boosters';
  static const _dailyChallengeDateKey = 'daily_challenge_date';
  static const _dailyChallengeCompletedLevelsKey =
      'daily_challenge_completed_levels';
  static const _dailyChallengeMatchedTilesKey = 'daily_challenge_matched_tiles';
  static const _dailyChallengeLuckyWheelUsedKey =
      'daily_challenge_lucky_wheel_used';
  static const _dailyChallengeLevelClaimedKey = 'daily_challenge_level_claimed';
  static const _dailyChallengeTilesClaimedKey = 'daily_challenge_tiles_claimed';
  static const _dailyChallengeWheelClaimedKey = 'daily_challenge_wheel_claimed';
  static const _levelStarsPrefix = 'level_stars_';
  static const _achievementPrefix = 'achievement_';
  static const _pendingAchievementPopupIdsKey = 'pending_achievement_popup_ids';
  static const _collectionPrefix = 'collection_';
  static const _statsLevelsCompletedKey = 'stats_levels_completed';
  static const _statsTilesMatchedKey = 'stats_tiles_matched';
  static const _statsCoinsEarnedKey = 'stats_coins_earned';
  static const _statsBoostersUsedKey = 'stats_boosters_used';
  static const _statsHintsUsedKey = 'stats_hints_used';
  static const _statsShufflesUsedKey = 'stats_shuffles_used';
  static const _statsUndosUsedKey = 'stats_undos_used';
  static const _statsLuckyWheelSpinsKey = 'stats_lucky_wheel_spins';
  static const _finalRewardUnlockedKey = 'final_reward_unlocked';
  static const defaultFinalCode = '4286';

  static const _dailyLoginRewards = <int, int>{
    1: 50,
    2: 75,
    3: 100,
    4: 125,
    5: 150,
    6: 200,
    7: 300,
  };

  static const _collectionTileTypes = <String>{
    'apple',
    'banana',
    'berry',
    'carrot',
    'star',
  };

  static const achievementsCatalog = <AchievementDefinition>[
    AchievementDefinition(
      id: AchievementId.firstMatch,
      name: 'First Match',
      description: 'Clear your first set of 3 matching tiles.',
      reward: 50,
    ),
    AchievementDefinition(
      id: AchievementId.firstWin,
      name: 'First Win',
      description: 'Complete your first level.',
      reward: 100,
    ),
    AchievementDefinition(
      id: AchievementId.gardenWorld,
      name: 'Complete Garden World',
      description: 'Complete Level 10.',
      reward: 300,
    ),
    AchievementDefinition(
      id: AchievementId.oceanWorld,
      name: 'Complete Ocean World',
      description: 'Complete Level 20.',
      reward: 400,
    ),
    AchievementDefinition(
      id: AchievementId.candyWorld,
      name: 'Complete Candy World',
      description: 'Complete Level 30.',
      reward: 500,
    ),
    AchievementDefinition(
      id: AchievementId.spaceWorld,
      name: 'Complete Space World',
      description: 'Complete Level 40.',
      reward: 700,
    ),
    AchievementDefinition(
      id: AchievementId.luckyPlayer,
      name: 'Lucky Player',
      description: 'Use the Lucky Wheel 7 times.',
      reward: 250,
    ),
    AchievementDefinition(
      id: AchievementId.boosterMaster,
      name: 'Booster Master',
      description: 'Use 25 boosters.',
      reward: 250,
    ),
  ];

  String _normalizeFinalCode(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.padLeft(4, '0').substring(0, 4);
  }

  Future<int> highestUnlockedLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highestLevelKey) ?? 1;
  }

  Future<void> unlockNextLevel(int completedLevel) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_highestLevelKey) ?? 1;
    final next = (completedLevel + 1).clamp(1, 40);
    if (next > current) await prefs.setInt(_highestLevelKey, next);
  }

  Future<bool> musicEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_musicKey) ?? true;
  }

  Future<bool> sfxEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sfxKey) ?? true;
  }

  Future<bool> vibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vibrationKey) ?? true;
  }

  Future<void> setMusicEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicKey, enabled);
  }

  Future<void> setSfxEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sfxKey, enabled);
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationKey, enabled);
  }

  Future<int> coins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_coinsKey) ?? 0;
  }

  Future<int> addCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = (prefs.getInt(_coinsKey) ?? 0) + amount;
    await prefs.setInt(_coinsKey, updated);
    await _incrementInt(prefs, _statsCoinsEarnedKey, amount);
    return updated;
  }

  Future<bool> spendCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_coinsKey) ?? 0;
    if (current < amount) return false;
    await prefs.setInt(_coinsKey, current - amount);
    return true;
  }

  Future<bool> dailyRewardAvailable(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastDailyRewardDateKey) != _dateKey(now);
  }

  Future<DailyLoginStreakStatus> dailyLoginStreakStatus(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    return _dailyLoginStreakStatusFromPrefs(prefs, now);
  }

  Future<DailyLoginStreakClaim?> claimDailyLoginStreak(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final status = _dailyLoginStreakStatusFromPrefs(prefs, now);
    if (!status.available) return null;

    final updatedCoins = (prefs.getInt(_coinsKey) ?? 0) + status.reward;
    await prefs.setString(_dailyLoginLastClaimDateKey, status.todayKey);
    await prefs.setInt(_dailyLoginStreakKey, status.claimDay);
    await prefs.setInt(_coinsKey, updatedCoins);
    await _incrementInt(prefs, _statsCoinsEarnedKey, status.reward);

    return DailyLoginStreakClaim(
      status: DailyLoginStreakStatus(
        todayKey: status.todayKey,
        lastClaimDate: status.todayKey,
        currentStreak: status.claimDay,
        claimDay: status.claimDay,
        reward: status.reward,
        available: false,
      ),
      coins: updatedCoins,
    );
  }

  Future<int?> claimDailyReward(DateTime now, {int reward = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(now);
    if (prefs.getString(_lastDailyRewardDateKey) == today) return null;
    final updated = (prefs.getInt(_coinsKey) ?? 0) + reward;
    await prefs.setString(_lastDailyRewardDateKey, today);
    await prefs.setInt(_coinsKey, updated);
    await _incrementInt(prefs, _statsCoinsEarnedKey, reward);
    return updated;
  }

  Future<bool> dailySpinAvailable(DateTime now) async {
    final status = await dailySpinStatus(now);
    debugPrint('polishTodayKey=${status.polishTodayKey}');
    debugPrint('lastSpinDate=${status.lastSpinDate}');
    debugPrint('canSpin=${status.canSpin}');
    return status.canSpin;
  }

  Future<DailySpinStatus> dailySpinStatus(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _polishDateKey(now);
    final lastSpinDate = prefs.getString(_lastDailySpinDateKey);
    return DailySpinStatus(
      polishTodayKey: today,
      lastSpinDate: lastSpinDate,
      canSpin: lastSpinDate != today,
    );
  }

  Future<bool> markDailySpinClaimed(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _polishDateKey(now);
    if (prefs.getString(_lastDailySpinDateKey) == today) return false;
    await prefs.setString(_lastDailySpinDateKey, today);
    return true;
  }

  Future<int> extraHintBoosters() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_extraHintBoostersKey) ?? 0;
  }

  Future<int> extraShuffleBoosters() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_extraShuffleBoostersKey) ?? 0;
  }

  Future<int> extraUndoBoosters() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_extraUndoBoostersKey) ?? 0;
  }

  Future<int> addExtraHintBoosters(int amount) async {
    return _addInventory(_extraHintBoostersKey, amount);
  }

  Future<int> addExtraShuffleBoosters(int amount) async {
    return _addInventory(_extraShuffleBoostersKey, amount);
  }

  Future<int> addExtraUndoBoosters(int amount) async {
    return _addInventory(_extraUndoBoostersKey, amount);
  }

  Future<bool> useExtraHintBooster() async {
    return _spendInventory(_extraHintBoostersKey);
  }

  Future<bool> useExtraShuffleBooster() async {
    return _spendInventory(_extraShuffleBoostersKey);
  }

  Future<bool> useExtraUndoBooster() async {
    return _spendInventory(_extraUndoBoostersKey);
  }

  Future<bool> levelOneTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_levelOneTutorialSeenKey) ?? false;
  }

  Future<void> setLevelOneTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_levelOneTutorialSeenKey, true);
  }

  Future<DailyChallengesState> dailyChallenges() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyChallengesForToday(prefs);
    return _dailyChallengesFromPrefs(prefs);
  }

  Future<DailyChallengesState> recordDailyLevelCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyChallengesForToday(prefs);
    final current = prefs.getInt(_dailyChallengeCompletedLevelsKey) ?? 0;
    await prefs.setInt(
      _dailyChallengeCompletedLevelsKey,
      current + 1,
    );
    return _dailyChallengesFromPrefs(prefs);
  }

  Future<DailyChallengesState> recordDailyMatchedTiles(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyChallengesForToday(prefs);
    final current = prefs.getInt(_dailyChallengeMatchedTilesKey) ?? 0;
    await prefs.setInt(_dailyChallengeMatchedTilesKey, current + amount);
    return _dailyChallengesFromPrefs(prefs);
  }

  Future<DailyChallengesState> recordDailyLuckyWheelUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyChallengesForToday(prefs);
    await prefs.setBool(_dailyChallengeLuckyWheelUsedKey, true);
    return _dailyChallengesFromPrefs(prefs);
  }

  Future<void> recordMatchedTiles(
    int amount, {
    int? level,
    Iterable<String> tileTypes = const <String>[],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyChallengesForToday(prefs);
    await _incrementInt(prefs, _dailyChallengeMatchedTilesKey, amount);
    await _incrementInt(prefs, _statsTilesMatchedKey, amount);
    if (level != null) {
      await _recordCollectionMatches(prefs, level, tileTypes);
    }
    await _unlockAchievements(prefs, const [AchievementId.firstMatch]);
  }

  Future<void> recordLevelCompleted(int level, int stars) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyChallengesForToday(prefs);
    await _incrementInt(prefs, _dailyChallengeCompletedLevelsKey, 1);
    await _incrementInt(prefs, _statsLevelsCompletedKey, 1);
    await saveBestStarsForLevel(level, stars, prefs: prefs);

    final achievementIds = <AchievementId>[AchievementId.firstWin];
    if (level >= 10) achievementIds.add(AchievementId.gardenWorld);
    if (level >= 20) achievementIds.add(AchievementId.oceanWorld);
    if (level >= 30) achievementIds.add(AchievementId.candyWorld);
    if (level >= 40) achievementIds.add(AchievementId.spaceWorld);
    await _unlockAchievements(prefs, achievementIds);
    if (level >= 40) await prefs.setBool(_finalRewardUnlockedKey, true);
  }

  Future<void> recordBoosterUsed(BoosterKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    await _incrementInt(prefs, _statsBoostersUsedKey, 1);
    switch (kind) {
      case BoosterKind.undo:
        await _incrementInt(prefs, _statsUndosUsedKey, 1);
        break;
      case BoosterKind.hint:
        await _incrementInt(prefs, _statsHintsUsedKey, 1);
        break;
      case BoosterKind.shuffle:
        await _incrementInt(prefs, _statsShufflesUsedKey, 1);
        break;
    }
    if ((prefs.getInt(_statsBoostersUsedKey) ?? 0) >= 25) {
      await _unlockAchievements(prefs, const [AchievementId.boosterMaster]);
    }
  }

  Future<void> recordLuckyWheelSpin() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyChallengesForToday(prefs);
    await prefs.setBool(_dailyChallengeLuckyWheelUsedKey, true);
    await _incrementInt(prefs, _statsLuckyWheelSpinsKey, 1);
    if ((prefs.getInt(_statsLuckyWheelSpinsKey) ?? 0) >= 7) {
      await _unlockAchievements(prefs, const [AchievementId.luckyPlayer]);
    }
  }

  Future<int> bestStarsForLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_levelStarsKey(level)) ?? 0;
  }

  Future<Map<int, int>> bestStarsByLevel(int startLevel, int endLevel) async {
    final prefs = await SharedPreferences.getInstance();
    return <int, int>{
      for (var level = startLevel; level <= endLevel; level++)
        level: prefs.getInt(_levelStarsKey(level)) ?? 0,
    };
  }

  Future<void> saveBestStarsForLevel(
    int level,
    int stars, {
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final key = _levelStarsKey(level);
    final current = resolvedPrefs.getInt(key) ?? 0;
    if (stars > current) await resolvedPrefs.setInt(key, stars);
  }

  Future<List<AchievementState>> achievements() async {
    final prefs = await SharedPreferences.getInstance();
    return achievementsCatalog
        .map(
          (definition) => AchievementState(
            definition: definition,
            unlocked: prefs.getBool(_achievementKey(definition.id)) ?? false,
          ),
        )
        .toList();
  }

  Future<List<PendingAchievementPopup>>
      consumePendingAchievementPopups() async {
    final prefs = await SharedPreferences.getInstance();
    final ids =
        prefs.getStringList(_pendingAchievementPopupIdsKey) ?? const <String>[];
    if (ids.isEmpty) return const <PendingAchievementPopup>[];

    await prefs.setStringList(_pendingAchievementPopupIdsKey, const <String>[]);
    return ids
        .map(_achievementIdFromName)
        .whereType<AchievementId>()
        .map(
          (id) => PendingAchievementPopup(
            definition: _achievementDefinition(id),
          ),
        )
        .toList();
  }

  Future<Set<String>> discoveredCollectionKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((key) => key.startsWith(_collectionPrefix))
        .where((key) => prefs.getBool(key) ?? false)
        .map((key) => key.substring(_collectionPrefix.length))
        .toSet();
  }

  Future<GameStatistics> statistics() async {
    final prefs = await SharedPreferences.getInstance();
    return GameStatistics(
      levelsCompleted: prefs.getInt(_statsLevelsCompletedKey) ?? 0,
      totalTilesMatched: prefs.getInt(_statsTilesMatchedKey) ?? 0,
      totalCoinsEarned: prefs.getInt(_statsCoinsEarnedKey) ?? 0,
      totalBoostersUsed: prefs.getInt(_statsBoostersUsedKey) ?? 0,
      hintsUsed: prefs.getInt(_statsHintsUsedKey) ?? 0,
      shufflesUsed: prefs.getInt(_statsShufflesUsedKey) ?? 0,
      undosUsed: prefs.getInt(_statsUndosUsedKey) ?? 0,
      luckyWheelSpins: prefs.getInt(_statsLuckyWheelSpinsKey) ?? 0,
      bestStarsTotal: _bestStarsTotal(prefs),
    );
  }

  Future<bool> finalRewardUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_finalRewardUnlockedKey) ?? false;
  }

  Future<void> unlockFinalReward() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_finalRewardUnlockedKey, true);
  }

  Future<FinalRewardSummary?> finalRewardSummary() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_finalRewardUnlockedKey) ?? false)) return null;
    final achievementsUnlocked = achievementsCatalog
        .where((definition) =>
            prefs.getBool(_achievementKey(definition.id)) ?? false)
        .length;
    return FinalRewardSummary(
      code: await finalCode(),
      totalStars: _bestStarsTotal(prefs),
      levelsCompleted: 40,
      achievementsUnlocked: achievementsUnlocked,
    );
  }

  Future<int?> claimDailyChallenge(DailyChallengeId id) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyChallengesForToday(prefs);
    final state = _dailyChallengesFromPrefs(prefs);
    if (!state.isComplete(id) || state.isClaimed(id)) return null;

    await prefs.setBool(_dailyChallengeClaimedKey(id), true);
    return addCoins(_dailyChallengeReward(id));
  }

  Future<String> finalCode() async {
    const compileTimeCode = String.fromEnvironment(
      'FINAL_CODE',
      defaultValue: defaultFinalCode,
    );
    final prefs = await SharedPreferences.getInstance();
    return _normalizeFinalCode(prefs.getString(_codeKey) ?? compileTimeCode);
  }

  Future<void> setFinalCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeKey, _normalizeFinalCode(code));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highestLevelKey, 1);
    await prefs.setBool(_finalRewardUnlockedKey, false);
  }

  Future<void> _ensureDailyChallengesForToday(SharedPreferences prefs) async {
    final today = _polishDateKey(DateTime.now());
    if (prefs.getString(_dailyChallengeDateKey) == today) return;
    await prefs.setString(_dailyChallengeDateKey, today);
    await prefs.setInt(_dailyChallengeCompletedLevelsKey, 0);
    await prefs.setInt(_dailyChallengeMatchedTilesKey, 0);
    await prefs.setBool(_dailyChallengeLuckyWheelUsedKey, false);
    await prefs.setBool(_dailyChallengeLevelClaimedKey, false);
    await prefs.setBool(_dailyChallengeTilesClaimedKey, false);
    await prefs.setBool(_dailyChallengeWheelClaimedKey, false);
  }

  DailyChallengesState _dailyChallengesFromPrefs(SharedPreferences prefs) {
    return DailyChallengesState(
      dateKey: prefs.getString(_dailyChallengeDateKey) ??
          _polishDateKey(DateTime.now()),
      completedLevels: prefs.getInt(_dailyChallengeCompletedLevelsKey) ?? 0,
      matchedTiles: prefs.getInt(_dailyChallengeMatchedTilesKey) ?? 0,
      luckyWheelUsed: prefs.getBool(_dailyChallengeLuckyWheelUsedKey) ?? false,
      completeLevelClaimed:
          prefs.getBool(_dailyChallengeLevelClaimedKey) ?? false,
      matchTilesClaimed: prefs.getBool(_dailyChallengeTilesClaimedKey) ?? false,
      luckyWheelClaimed: prefs.getBool(_dailyChallengeWheelClaimedKey) ?? false,
    );
  }

  int _dailyChallengeReward(DailyChallengeId id) {
    switch (id) {
      case DailyChallengeId.completeLevel:
        return 100;
      case DailyChallengeId.matchTiles:
        return 75;
      case DailyChallengeId.useLuckyWheel:
        return 50;
    }
  }

  String _dailyChallengeClaimedKey(DailyChallengeId id) {
    switch (id) {
      case DailyChallengeId.completeLevel:
        return _dailyChallengeLevelClaimedKey;
      case DailyChallengeId.matchTiles:
        return _dailyChallengeTilesClaimedKey;
      case DailyChallengeId.useLuckyWheel:
        return _dailyChallengeWheelClaimedKey;
    }
  }

  String _levelStarsKey(int level) => '$_levelStarsPrefix$level';

  String _achievementKey(AchievementId id) => '$_achievementPrefix${id.name}';

  AchievementDefinition _achievementDefinition(AchievementId id) {
    return achievementsCatalog.firstWhere((definition) => definition.id == id);
  }

  AchievementId? _achievementIdFromName(String name) {
    for (final id in AchievementId.values) {
      if (id.name == name) return id;
    }
    return null;
  }

  Future<void> _unlockAchievements(
    SharedPreferences prefs,
    Iterable<AchievementId> ids,
  ) async {
    for (final id in ids) {
      final key = _achievementKey(id);
      if (prefs.getBool(key) ?? false) continue;
      await prefs.setBool(key, true);
      final reward = _achievementDefinition(id).reward;
      final updatedCoins = (prefs.getInt(_coinsKey) ?? 0) + reward;
      await prefs.setInt(_coinsKey, updatedCoins);
      await _incrementInt(prefs, _statsCoinsEarnedKey, reward);
      await _queueAchievementPopup(prefs, id);
      debugPrint('Achievement unlocked: ${id.name}, reward=$reward');
    }
  }

  Future<void> _queueAchievementPopup(
    SharedPreferences prefs,
    AchievementId id,
  ) async {
    final pending =
        prefs.getStringList(_pendingAchievementPopupIdsKey) ?? const <String>[];
    if (pending.contains(id.name)) return;
    await prefs.setStringList(
      _pendingAchievementPopupIdsKey,
      <String>[...pending, id.name],
    );
  }

  Future<void> _recordCollectionMatches(
    SharedPreferences prefs,
    int level,
    Iterable<String> tileTypes,
  ) async {
    final world = _collectionWorldForLevel(level);
    for (final tileType in tileTypes.toSet()) {
      if (!_collectionTileTypes.contains(tileType)) continue;
      await prefs.setBool(_collectionKey(world, tileType), true);
    }
  }

  Future<void> _incrementInt(
    SharedPreferences prefs,
    String key,
    int amount,
  ) async {
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + amount);
  }

  int _bestStarsTotal(SharedPreferences prefs) {
    var total = 0;
    for (var level = 1; level <= 40; level++) {
      total += prefs.getInt(_levelStarsKey(level)) ?? 0;
    }
    return total;
  }

  DailyLoginStreakStatus _dailyLoginStreakStatusFromPrefs(
    SharedPreferences prefs,
    DateTime now,
  ) {
    final today = _dateKey(now.toLocal());
    final lastClaimDate = prefs.getString(_dailyLoginLastClaimDateKey);
    final currentStreak = prefs.getInt(_dailyLoginStreakKey) ?? 0;
    if (lastClaimDate == today) {
      final day = currentStreak.clamp(1, 7).toInt();
      return DailyLoginStreakStatus(
        todayKey: today,
        lastClaimDate: lastClaimDate,
        currentStreak: currentStreak,
        claimDay: day,
        reward: _dailyLoginRewards[day]!,
        available: false,
      );
    }

    final nextDay = _isYesterday(lastClaimDate, today)
        ? (currentStreak + 1).clamp(1, 7).toInt()
        : 1;
    return DailyLoginStreakStatus(
      todayKey: today,
      lastClaimDate: lastClaimDate,
      currentStreak: currentStreak,
      claimDay: nextDay,
      reward: _dailyLoginRewards[nextDay]!,
      available: true,
    );
  }

  bool _isYesterday(String? lastDateKey, String todayKey) {
    if (lastDateKey == null) return false;
    final lastDate = DateTime.tryParse(lastDateKey);
    final today = DateTime.tryParse(todayKey);
    if (lastDate == null || today == null) return false;
    return today.difference(lastDate).inDays == 1;
  }

  String _collectionWorldForLevel(int level) {
    if (level <= 10) return 'garden';
    if (level <= 20) return 'ocean';
    if (level <= 30) return 'candy';
    return 'space';
  }

  String _collectionKey(String world, String tileType) {
    return '$_collectionPrefix${world}_$tileType';
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _polishDateKey(DateTime instant) {
    return _dateKey(_toPolishLocalTime(instant));
  }

  DateTime _toPolishLocalTime(DateTime instant) {
    final utc = instant.toUtc();
    final offsetHours = _isPolishSummerTime(utc) ? 2 : 1;
    return utc.add(Duration(hours: offsetHours));
  }

  bool _isPolishSummerTime(DateTime utc) {
    final year = utc.year;
    final starts = DateTime.utc(year, 3, _lastSundayOfMonth(year, 3), 1);
    final ends = DateTime.utc(year, 10, _lastSundayOfMonth(year, 10), 1);
    return !utc.isBefore(starts) && utc.isBefore(ends);
  }

  int _lastSundayOfMonth(int year, int month) {
    final nextMonth =
        month == 12 ? DateTime.utc(year + 1, 1) : DateTime.utc(year, month + 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1));
    return lastDay.day - (lastDay.weekday % DateTime.daysPerWeek);
  }

  Future<int> _addInventory(String key, int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = (prefs.getInt(key) ?? 0) + amount;
    await prefs.setInt(key, updated);
    return updated;
  }

  Future<bool> _spendInventory(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(key) ?? 0;
    if (current <= 0) return false;
    await prefs.setInt(key, current - 1);
    return true;
  }
}
