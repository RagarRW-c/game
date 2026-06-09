import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum TreasureChestType { wood, silver, gold }

class TreasureChest {
  const TreasureChest({
    required this.id,
    required this.type,
    required this.grantedAtMillis,
    required this.unlockAtMillis,
  });

  final String id;
  final TreasureChestType type;
  final int grantedAtMillis;
  final int unlockAtMillis;

  bool isUnlocked(DateTime now) => now.millisecondsSinceEpoch >= unlockAtMillis;

  Duration remaining(DateTime now) {
    final remainingMillis = unlockAtMillis - now.millisecondsSinceEpoch;
    return Duration(milliseconds: remainingMillis < 0 ? 0 : remainingMillis);
  }

  String get title {
    switch (type) {
      case TreasureChestType.wood:
        return 'Wood Chest';
      case TreasureChestType.silver:
        return 'Silver Chest';
      case TreasureChestType.gold:
        return 'Gold Chest';
    }
  }
}

class ChestGrantResult {
  const ChestGrantResult({
    required this.granted,
    required this.slotsFull,
    this.chest,
  });

  final bool granted;
  final bool slotsFull;
  final TreasureChest? chest;
}

class ChestOpenReward {
  const ChestOpenReward({
    required this.coins,
    required this.undo,
    required this.hint,
    required this.shuffle,
  });

  final int coins;
  final int undo;
  final int hint;
  final int shuffle;
}

class ChestOpenNowResult {
  const ChestOpenNowResult({
    required this.opened,
    required this.notEnoughCoins,
    this.reward,
  });

  final bool opened;
  final bool notEnoughCoins;
  final ChestOpenReward? reward;
}

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

enum DailyChallengeId {
  completeTwoLevels,
  matchTiles,
  useLuckyWheel,
  openChest,
  earnCoins,
  useBooster,
  completeBossLevel,
}

enum DailyChallengeRewardType {
  coins,
  hintBooster,
  shuffleBooster,
  silverChest,
  goldChest,
}

class DailyChallengeDefinition {
  const DailyChallengeDefinition({
    required this.id,
    required this.title,
    required this.target,
    required this.rewardType,
    required this.rewardAmount,
    required this.rewardLabel,
  });

  final DailyChallengeId id;
  final String title;
  final int target;
  final DailyChallengeRewardType rewardType;
  final int rewardAmount;
  final String rewardLabel;
}

class DailyChallengeEntry {
  const DailyChallengeEntry({
    required this.definition,
    required this.progress,
    required this.claimed,
  });

  final DailyChallengeDefinition definition;
  final int progress;
  final bool claimed;

  bool get complete => progress >= definition.target;
  int get cappedProgress =>
      progress > definition.target ? definition.target : progress;
}

class DailyChallengeClaimResult {
  const DailyChallengeClaimResult({
    required this.claimed,
    required this.coins,
    required this.message,
  });

  final bool claimed;
  final int coins;
  final String? message;
}

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

class PlayerProfileSummary {
  const PlayerProfileSummary({
    required this.playerLevel,
    required this.totalXp,
    required this.coins,
    required this.totalStars,
    required this.levelsCompleted,
    required this.achievementsUnlocked,
    required this.achievementsTotal,
    required this.collectionUnlocked,
    required this.collectionTotal,
    required this.luckyWheelSpins,
    required this.dailyStreak,
    required this.totalBoostersUsed,
    required this.totalTilesMatched,
  });

  final int playerLevel;
  final int totalXp;
  final int coins;
  final int totalStars;
  final int levelsCompleted;
  final int achievementsUnlocked;
  final int achievementsTotal;
  final int collectionUnlocked;
  final int collectionTotal;
  final int luckyWheelSpins;
  final int dailyStreak;
  final int totalBoostersUsed;
  final int totalTilesMatched;
}

class PlayerCosmetics {
  const PlayerCosmetics({
    required this.selectedFrame,
    required this.selectedBackground,
    required this.selectedBadge,
    required this.unlockedFrames,
    required this.unlockedBackgrounds,
    required this.unlockedBadges,
  });

  final String? selectedFrame;
  final String? selectedBackground;
  final String? selectedBadge;
  final Set<String> unlockedFrames;
  final Set<String> unlockedBackgrounds;
  final Set<String> unlockedBadges;

  bool frameUnlocked(String id) => unlockedFrames.contains(id);
  bool backgroundUnlocked(String id) => unlockedBackgrounds.contains(id);
  bool badgeUnlocked(String id) => unlockedBadges.contains(id);
}

class DailyChallengesState {
  const DailyChallengesState({
    required this.dateKey,
    required this.challenges,
    required this.bonusClaimed,
  });

  final String dateKey;
  final List<DailyChallengeEntry> challenges;
  final bool bonusClaimed;

  bool isComplete(DailyChallengeId id) {
    return challenges
        .where((challenge) => challenge.definition.id == id)
        .any((challenge) => challenge.complete);
  }

  bool isClaimed(DailyChallengeId id) {
    return challenges
        .where((challenge) => challenge.definition.id == id)
        .any((challenge) => challenge.claimed);
  }

  bool get allClaimed =>
      challenges.isNotEmpty &&
      challenges.every((challenge) => challenge.claimed);

  bool get bonusAvailable => allClaimed && !bonusClaimed;
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
  static const _dailyChallengeIdsKey = 'daily_challenge_ids';
  static const _dailyChallengeClaimedIdsKey = 'daily_challenge_claimed_ids';
  static const _dailyChallengeBonusClaimedKey = 'daily_challenge_bonus_claimed';
  static const _dailyChallengeCompletedLevelsKey =
      'daily_challenge_completed_levels';
  static const _dailyChallengeMatchedTilesKey = 'daily_challenge_matched_tiles';
  static const _dailyChallengeLuckyWheelUsedKey =
      'daily_challenge_lucky_wheel_used';
  static const _dailyChallengeOpenedChestsKey = 'daily_challenge_opened_chests';
  static const _dailyChallengeCoinsEarnedKey = 'daily_challenge_coins_earned';
  static const _dailyChallengeBoostersUsedKey = 'daily_challenge_boosters_used';
  static const _dailyChallengeBossLevelsKey = 'daily_challenge_boss_levels';
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
  static const _treasureChestsKey = 'treasure_chests';
  static const _totalXpKey = 'total_xp';
  static const _selectedAvatarFrameKey = 'selected_avatar_frame';
  static const _selectedProfileBackgroundKey = 'selected_profile_background';
  static const _selectedProfileBadgeKey = 'selected_profile_badge';
  static const defaultFinalCode = '4286';

  static const avatarFrameGarden = 'garden_frame';
  static const avatarFrameOcean = 'ocean_frame';
  static const avatarFrameCandy = 'candy_frame';
  static const avatarFrameSpace = 'space_frame';
  static const profileBackgroundGarden = 'garden_theme';
  static const profileBackgroundOcean = 'ocean_theme';
  static const profileBackgroundCandy = 'candy_theme';
  static const profileBackgroundSpace = 'space_theme';
  static const badgeWorldConqueror = 'world_conqueror';
  static const badgeLuckyPlayer = 'lucky_player';
  static const badgeCollector = 'collector';
  static const badgeThreeStarMaster = 'three_star_master';

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

  static const dailyChallengeCatalog = <DailyChallengeDefinition>[
    DailyChallengeDefinition(
      id: DailyChallengeId.completeTwoLevels,
      title: 'Complete 2 levels',
      target: 2,
      rewardType: DailyChallengeRewardType.coins,
      rewardAmount: 150,
      rewardLabel: '150 coins',
    ),
    DailyChallengeDefinition(
      id: DailyChallengeId.matchTiles,
      title: 'Match 30 tiles',
      target: 30,
      rewardType: DailyChallengeRewardType.coins,
      rewardAmount: 100,
      rewardLabel: '100 coins',
    ),
    DailyChallengeDefinition(
      id: DailyChallengeId.useLuckyWheel,
      title: 'Use Lucky Wheel',
      target: 1,
      rewardType: DailyChallengeRewardType.coins,
      rewardAmount: 75,
      rewardLabel: '75 coins',
    ),
    DailyChallengeDefinition(
      id: DailyChallengeId.openChest,
      title: 'Open 1 Chest',
      target: 1,
      rewardType: DailyChallengeRewardType.coins,
      rewardAmount: 100,
      rewardLabel: '100 coins',
    ),
    DailyChallengeDefinition(
      id: DailyChallengeId.earnCoins,
      title: 'Earn 100 coins',
      target: 100,
      rewardType: DailyChallengeRewardType.hintBooster,
      rewardAmount: 1,
      rewardLabel: '+1 Hint',
    ),
    DailyChallengeDefinition(
      id: DailyChallengeId.useBooster,
      title: 'Use 1 Booster',
      target: 1,
      rewardType: DailyChallengeRewardType.shuffleBooster,
      rewardAmount: 1,
      rewardLabel: '+1 Shuffle',
    ),
    DailyChallengeDefinition(
      id: DailyChallengeId.completeBossLevel,
      title: 'Complete 1 Boss Level',
      target: 1,
      rewardType: DailyChallengeRewardType.goldChest,
      rewardAmount: 1,
      rewardLabel: 'Gold Chest',
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
    await _ensureDailyChallengesForToday(prefs);
    final updated = (prefs.getInt(_coinsKey) ?? 0) + amount;
    await prefs.setInt(_coinsKey, updated);
    await _incrementInt(prefs, _statsCoinsEarnedKey, amount);
    await _incrementInt(prefs, _dailyChallengeCoinsEarnedKey, amount);
    return updated;
  }

  Future<void> addXp(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await _incrementInt(prefs, _totalXpKey, amount);
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
    await _ensureDailyChallengesForToday(prefs);
    await _incrementInt(prefs, _dailyChallengeCoinsEarnedKey, status.reward);

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
    await _ensureDailyChallengesForToday(prefs);
    await _incrementInt(prefs, _dailyChallengeCoinsEarnedKey, reward);
    return updated;
  }

  Future<bool> dailySpinAvailable(DateTime now) async {
    final status = await dailySpinStatus(now);
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
    if (level % 10 == 0) {
      await _incrementInt(prefs, _dailyChallengeBossLevelsKey, 1);
    }
    await _incrementInt(prefs, _statsLevelsCompletedKey, 1);
    await _incrementInt(prefs, _totalXpKey, stars == 3 ? 150 : 100);
    await saveBestStarsForLevel(level, stars, prefs: prefs);

    final achievementIds = <AchievementId>[AchievementId.firstWin];
    if (level >= 10) achievementIds.add(AchievementId.gardenWorld);
    if (level >= 20) achievementIds.add(AchievementId.oceanWorld);
    if (level >= 30) achievementIds.add(AchievementId.candyWorld);
    if (level >= 40) achievementIds.add(AchievementId.spaceWorld);
    await _unlockAchievements(prefs, achievementIds);
    if (level >= 40) await prefs.setBool(_finalRewardUnlockedKey, true);
  }

  Future<ChestGrantResult> grantChestForLevel(int level) async {
    return _grantChestByType(_chestTypeForLevel(level), idSuffix: '$level');
  }

  Future<ChestGrantResult> _grantChestByType(
    TreasureChestType type, {
    String? idSuffix,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final chests = _chestsFromPrefs(prefs);
    if (chests.length >= 3) {
      return const ChestGrantResult(granted: false, slotsFull: true);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final chest = TreasureChest(
      id: '${now}_${idSuffix ?? type.name}',
      type: type,
      grantedAtMillis: now,
      unlockAtMillis: now + _chestUnlockDuration(type).inMilliseconds,
    );
    await _saveChests(prefs, <TreasureChest>[...chests, chest]);
    return ChestGrantResult(granted: true, slotsFull: false, chest: chest);
  }

  Future<List<TreasureChest>> treasureChests() async {
    final prefs = await SharedPreferences.getInstance();
    return _chestsFromPrefs(prefs);
  }

  Future<ChestOpenReward?> openTreasureChest(String chestId) async {
    final prefs = await SharedPreferences.getInstance();
    final chests = _chestsFromPrefs(prefs);
    final index = chests.indexWhere((chest) => chest.id == chestId);
    if (index == -1) return null;
    final chest = chests[index];
    if (!chest.isUnlocked(DateTime.now())) return null;

    final reward = _rollChestReward(chest.type);
    final updatedChests = <TreasureChest>[...chests]..removeAt(index);
    await _saveChests(prefs, updatedChests);
    await _ensureDailyChallengesForToday(prefs);
    await _incrementInt(prefs, _dailyChallengeOpenedChestsKey, 1);
    await addCoins(reward.coins);
    if (reward.undo > 0) await addExtraUndoBoosters(reward.undo);
    if (reward.hint > 0) await addExtraHintBoosters(reward.hint);
    if (reward.shuffle > 0) await addExtraShuffleBoosters(reward.shuffle);
    return reward;
  }

  Future<ChestOpenNowResult> openTreasureChestNow(String chestId) async {
    final prefs = await SharedPreferences.getInstance();
    final chests = _chestsFromPrefs(prefs);
    final index = chests.indexWhere((chest) => chest.id == chestId);
    if (index == -1) {
      return const ChestOpenNowResult(opened: false, notEnoughCoins: false);
    }

    final chest = chests[index];
    final cost = instantUnlockCost(chest.type);
    final currentCoins = prefs.getInt(_coinsKey) ?? 0;
    if (currentCoins < cost) {
      return const ChestOpenNowResult(opened: false, notEnoughCoins: true);
    }

    await prefs.setInt(_coinsKey, currentCoins - cost);
    final reward = _rollChestReward(chest.type);
    final updatedChests = <TreasureChest>[...chests]..removeAt(index);
    await _saveChests(prefs, updatedChests);
    await _ensureDailyChallengesForToday(prefs);
    await _incrementInt(prefs, _dailyChallengeOpenedChestsKey, 1);
    await addCoins(reward.coins);
    if (reward.undo > 0) await addExtraUndoBoosters(reward.undo);
    if (reward.hint > 0) await addExtraHintBoosters(reward.hint);
    if (reward.shuffle > 0) await addExtraShuffleBoosters(reward.shuffle);
    return ChestOpenNowResult(
      opened: true,
      notEnoughCoins: false,
      reward: reward,
    );
  }

  int instantUnlockCost(TreasureChestType type) {
    switch (type) {
      case TreasureChestType.wood:
        return 50;
      case TreasureChestType.silver:
        return 100;
      case TreasureChestType.gold:
        return 200;
    }
  }

  Future<void> recordBoosterUsed(BoosterKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyChallengesForToday(prefs);
    await _incrementInt(prefs, _dailyChallengeBoostersUsedKey, 1);
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

  Future<PlayerProfileSummary> playerProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final totalXp = prefs.getInt(_totalXpKey) ?? 0;
    final achievementsUnlocked = achievementsCatalog
        .where((definition) =>
            prefs.getBool(_achievementKey(definition.id)) ?? false)
        .length;
    final collectionUnlocked = prefs
        .getKeys()
        .where((key) => key.startsWith(_collectionPrefix))
        .where((key) => prefs.getBool(key) ?? false)
        .length;
    final streakStatus = _dailyLoginStreakStatusFromPrefs(
      prefs,
      DateTime.now(),
    );
    final dailyStreak = streakStatus.available
        ? (streakStatus.claimDay - 1).clamp(0, 7).toInt()
        : streakStatus.currentStreak;

    return PlayerProfileSummary(
      playerLevel: (totalXp ~/ 500) + 1,
      totalXp: totalXp,
      coins: prefs.getInt(_coinsKey) ?? 0,
      totalStars: _bestStarsTotal(prefs),
      levelsCompleted: prefs.getInt(_statsLevelsCompletedKey) ?? 0,
      achievementsUnlocked: achievementsUnlocked,
      achievementsTotal: achievementsCatalog.length,
      collectionUnlocked: collectionUnlocked,
      collectionTotal: 20,
      luckyWheelSpins: prefs.getInt(_statsLuckyWheelSpinsKey) ?? 0,
      dailyStreak: dailyStreak,
      totalBoostersUsed: prefs.getInt(_statsBoostersUsedKey) ?? 0,
      totalTilesMatched: prefs.getInt(_statsTilesMatchedKey) ?? 0,
    );
  }

  Future<PlayerCosmetics> playerCosmetics() async {
    final prefs = await SharedPreferences.getInstance();
    final cosmetics = _playerCosmeticsFromPrefs(prefs);
    await _clearLockedCosmeticSelections(prefs, cosmetics);
    return _playerCosmeticsFromPrefs(prefs);
  }

  Future<bool> selectAvatarFrame(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final cosmetics = _playerCosmeticsFromPrefs(prefs);
    if (!cosmetics.frameUnlocked(id)) return false;
    await prefs.setString(_selectedAvatarFrameKey, id);
    return true;
  }

  Future<bool> selectProfileBackground(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final cosmetics = _playerCosmeticsFromPrefs(prefs);
    if (!cosmetics.backgroundUnlocked(id)) return false;
    await prefs.setString(_selectedProfileBackgroundKey, id);
    return true;
  }

  Future<bool> selectProfileBadge(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final cosmetics = _playerCosmeticsFromPrefs(prefs);
    if (!cosmetics.badgeUnlocked(id)) return false;
    await prefs.setString(_selectedProfileBadgeKey, id);
    return true;
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
    final result = await claimDailyChallengeReward(id);
    return result.claimed ? result.coins : null;
  }

  Future<DailyChallengeClaimResult> claimDailyChallengeReward(
    DailyChallengeId id,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyChallengesForToday(prefs);
    final state = _dailyChallengesFromPrefs(prefs);
    final activeIds = state.challenges.map((entry) => entry.definition.id);
    if (!activeIds.contains(id)) {
      return DailyChallengeClaimResult(
        claimed: false,
        coins: prefs.getInt(_coinsKey) ?? 0,
        message: 'Challenge is not active today',
      );
    }
    if (!state.isComplete(id) || state.isClaimed(id)) {
      return DailyChallengeClaimResult(
        claimed: false,
        coins: prefs.getInt(_coinsKey) ?? 0,
        message: null,
      );
    }

    final definition = _dailyChallengeDefinition(id);
    final rewardResult = await _grantDailyChallengeReward(prefs, definition);
    if (!rewardResult.claimed) return rewardResult;
    final claimedIds =
        prefs.getStringList(_dailyChallengeClaimedIdsKey) ?? const <String>[];
    await prefs.setStringList(
      _dailyChallengeClaimedIdsKey,
      <String>{...claimedIds, id.name}.toList(),
    );
    return DailyChallengeClaimResult(
      claimed: true,
      coins: rewardResult.coins,
      message: rewardResult.message,
    );
  }

  Future<DailyChallengeClaimResult> claimDailyChallengeBonus() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyChallengesForToday(prefs);
    final state = _dailyChallengesFromPrefs(prefs);
    if (!state.bonusAvailable) {
      return DailyChallengeClaimResult(
        claimed: false,
        coins: prefs.getInt(_coinsKey) ?? 0,
        message: null,
      );
    }
    final chestGrant = await _grantChestByType(TreasureChestType.silver);
    if (chestGrant.slotsFull) {
      return DailyChallengeClaimResult(
        claimed: false,
        coins: prefs.getInt(_coinsKey) ?? 0,
        message: 'Chest slots full',
      );
    }
    final coins = await addCoins(300);
    await prefs.setBool(_dailyChallengeBonusClaimedKey, true);
    return DailyChallengeClaimResult(
      claimed: true,
      coins: coins,
      message: 'Bonus claimed',
    );
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

  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final music = prefs.getBool(_musicKey);
    final sfx = prefs.getBool(_sfxKey);
    final vibration = prefs.getBool(_vibrationKey);
    final finalCode = prefs.getString(_codeKey);
    await prefs.clear();
    if (music != null) await prefs.setBool(_musicKey, music);
    if (sfx != null) await prefs.setBool(_sfxKey, sfx);
    if (vibration != null) await prefs.setBool(_vibrationKey, vibration);
    if (finalCode != null) await prefs.setString(_codeKey, finalCode);
  }

  Future<void> reset() => resetProgress();

  Future<void> debugUnlockAllWorlds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highestLevelKey, 40);
  }

  Future<int> debugAddCoins() => addCoins(1000);

  Future<void> debugResetDailySpin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastDailySpinDateKey);
  }

  Future<void> debugResetDailyChallenges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dailyChallengeDateKey);
    await _ensureDailyChallengesForToday(prefs);
  }

  Future<void> _ensureDailyChallengesForToday(SharedPreferences prefs) async {
    final today = _dateKey(DateTime.now().toLocal());
    if (prefs.getString(_dailyChallengeDateKey) == today) return;
    final challengeIds = _dailyChallengeIdsForDate(today);
    await prefs.setString(_dailyChallengeDateKey, today);
    await prefs.setStringList(
      _dailyChallengeIdsKey,
      challengeIds.map((id) => id.name).toList(),
    );
    await prefs.setStringList(_dailyChallengeClaimedIdsKey, const <String>[]);
    await prefs.setBool(_dailyChallengeBonusClaimedKey, false);
    await prefs.setInt(_dailyChallengeCompletedLevelsKey, 0);
    await prefs.setInt(_dailyChallengeMatchedTilesKey, 0);
    await prefs.setBool(_dailyChallengeLuckyWheelUsedKey, false);
    await prefs.setInt(_dailyChallengeOpenedChestsKey, 0);
    await prefs.setInt(_dailyChallengeCoinsEarnedKey, 0);
    await prefs.setInt(_dailyChallengeBoostersUsedKey, 0);
    await prefs.setInt(_dailyChallengeBossLevelsKey, 0);
  }

  DailyChallengesState _dailyChallengesFromPrefs(SharedPreferences prefs) {
    final dateKey =
        prefs.getString(_dailyChallengeDateKey) ?? _dateKey(DateTime.now());
    final ids = _activeDailyChallengeIds(prefs, dateKey);
    final claimedIds =
        (prefs.getStringList(_dailyChallengeClaimedIdsKey) ?? const <String>[])
            .toSet();
    return DailyChallengesState(
      dateKey: dateKey,
      challenges: [
        for (final id in ids)
          DailyChallengeEntry(
            definition: _dailyChallengeDefinition(id),
            progress: _dailyChallengeProgress(prefs, id),
            claimed: claimedIds.contains(id.name),
          ),
      ],
      bonusClaimed: prefs.getBool(_dailyChallengeBonusClaimedKey) ?? false,
    );
  }

  List<DailyChallengeId> _activeDailyChallengeIds(
    SharedPreferences prefs,
    String dateKey,
  ) {
    final storedIds = prefs.getStringList(_dailyChallengeIdsKey);
    final ids = storedIds
            ?.map(_dailyChallengeIdFromName)
            .whereType<DailyChallengeId>()
            .toList() ??
        const <DailyChallengeId>[];
    if (ids.length == 3) return ids;
    return _dailyChallengeIdsForDate(dateKey);
  }

  List<DailyChallengeId> _dailyChallengeIdsForDate(String dateKey) {
    final ids = DailyChallengeId.values.toList();
    var seed = 0;
    for (final unit in dateKey.codeUnits) {
      seed = (seed * 31 + unit) & 0x7fffffff;
    }
    for (var index = ids.length - 1; index > 0; index--) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final swapIndex = seed % (index + 1);
      final current = ids[index];
      ids[index] = ids[swapIndex];
      ids[swapIndex] = current;
    }
    return ids.take(3).toList(growable: false);
  }

  DailyChallengeId? _dailyChallengeIdFromName(String name) {
    for (final id in DailyChallengeId.values) {
      if (id.name == name) return id;
    }
    return null;
  }

  DailyChallengeDefinition _dailyChallengeDefinition(DailyChallengeId id) {
    return dailyChallengeCatalog.firstWhere(
      (definition) => definition.id == id,
    );
  }

  int _dailyChallengeProgress(SharedPreferences prefs, DailyChallengeId id) {
    switch (id) {
      case DailyChallengeId.completeTwoLevels:
        return prefs.getInt(_dailyChallengeCompletedLevelsKey) ?? 0;
      case DailyChallengeId.matchTiles:
        return prefs.getInt(_dailyChallengeMatchedTilesKey) ?? 0;
      case DailyChallengeId.useLuckyWheel:
        return prefs.getBool(_dailyChallengeLuckyWheelUsedKey) ?? false ? 1 : 0;
      case DailyChallengeId.openChest:
        return prefs.getInt(_dailyChallengeOpenedChestsKey) ?? 0;
      case DailyChallengeId.earnCoins:
        return prefs.getInt(_dailyChallengeCoinsEarnedKey) ?? 0;
      case DailyChallengeId.useBooster:
        return prefs.getInt(_dailyChallengeBoostersUsedKey) ?? 0;
      case DailyChallengeId.completeBossLevel:
        return prefs.getInt(_dailyChallengeBossLevelsKey) ?? 0;
    }
  }

  Future<DailyChallengeClaimResult> _grantDailyChallengeReward(
    SharedPreferences prefs,
    DailyChallengeDefinition definition,
  ) async {
    switch (definition.rewardType) {
      case DailyChallengeRewardType.coins:
        final coins = await addCoins(definition.rewardAmount);
        return DailyChallengeClaimResult(
          claimed: true,
          coins: coins,
          message: null,
        );
      case DailyChallengeRewardType.hintBooster:
        await addExtraHintBoosters(definition.rewardAmount);
        return DailyChallengeClaimResult(
          claimed: true,
          coins: prefs.getInt(_coinsKey) ?? 0,
          message: null,
        );
      case DailyChallengeRewardType.shuffleBooster:
        await addExtraShuffleBoosters(definition.rewardAmount);
        return DailyChallengeClaimResult(
          claimed: true,
          coins: prefs.getInt(_coinsKey) ?? 0,
          message: null,
        );
      case DailyChallengeRewardType.silverChest:
        final result = await _grantChestByType(TreasureChestType.silver);
        return DailyChallengeClaimResult(
          claimed: result.granted,
          coins: prefs.getInt(_coinsKey) ?? 0,
          message: result.slotsFull ? 'Chest slots full' : null,
        );
      case DailyChallengeRewardType.goldChest:
        final result = await _grantChestByType(TreasureChestType.gold);
        return DailyChallengeClaimResult(
          claimed: result.granted,
          coins: prefs.getInt(_coinsKey) ?? 0,
          message: result.slotsFull ? 'Chest slots full' : null,
        );
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
      await _ensureDailyChallengesForToday(prefs);
      await _incrementInt(prefs, _dailyChallengeCoinsEarnedKey, reward);
      await _incrementInt(prefs, _totalXpKey, 75);
      await _queueAchievementPopup(prefs, id);
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
      final key = _collectionKey(world, tileType);
      if (prefs.getBool(key) ?? false) continue;
      await prefs.setBool(key, true);
      await _incrementInt(prefs, _totalXpKey, 20);
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

  PlayerCosmetics _playerCosmeticsFromPrefs(SharedPreferences prefs) {
    final unlockedFrames = _unlockedAvatarFrames(prefs);
    final unlockedBackgrounds = _unlockedProfileBackgrounds(prefs);
    final unlockedBadges = _unlockedProfileBadges(prefs);
    final selectedFrame = prefs.getString(_selectedAvatarFrameKey);
    final selectedBackground = prefs.getString(_selectedProfileBackgroundKey);
    final selectedBadge = prefs.getString(_selectedProfileBadgeKey);

    return PlayerCosmetics(
      selectedFrame:
          unlockedFrames.contains(selectedFrame) ? selectedFrame : null,
      selectedBackground: unlockedBackgrounds.contains(selectedBackground)
          ? selectedBackground
          : null,
      selectedBadge:
          unlockedBadges.contains(selectedBadge) ? selectedBadge : null,
      unlockedFrames: unlockedFrames,
      unlockedBackgrounds: unlockedBackgrounds,
      unlockedBadges: unlockedBadges,
    );
  }

  Future<void> _clearLockedCosmeticSelections(
    SharedPreferences prefs,
    PlayerCosmetics cosmetics,
  ) async {
    if (prefs.getString(_selectedAvatarFrameKey) != cosmetics.selectedFrame) {
      await prefs.remove(_selectedAvatarFrameKey);
    }
    if (prefs.getString(_selectedProfileBackgroundKey) !=
        cosmetics.selectedBackground) {
      await prefs.remove(_selectedProfileBackgroundKey);
    }
    if (prefs.getString(_selectedProfileBadgeKey) != cosmetics.selectedBadge) {
      await prefs.remove(_selectedProfileBadgeKey);
    }
  }

  Set<String> _unlockedAvatarFrames(SharedPreferences prefs) {
    final unlocked = <String>{};
    if (_achievementUnlocked(prefs, AchievementId.gardenWorld)) {
      unlocked.add(avatarFrameGarden);
    }
    if (_achievementUnlocked(prefs, AchievementId.oceanWorld)) {
      unlocked.add(avatarFrameOcean);
    }
    if (_achievementUnlocked(prefs, AchievementId.candyWorld)) {
      unlocked.add(avatarFrameCandy);
    }
    if (_achievementUnlocked(prefs, AchievementId.spaceWorld)) {
      unlocked.add(avatarFrameSpace);
    }
    return unlocked;
  }

  Set<String> _unlockedProfileBackgrounds(SharedPreferences prefs) {
    final unlocked = <String>{};
    if (_achievementUnlocked(prefs, AchievementId.gardenWorld)) {
      unlocked.add(profileBackgroundGarden);
    }
    if (_achievementUnlocked(prefs, AchievementId.oceanWorld)) {
      unlocked.add(profileBackgroundOcean);
    }
    if (_achievementUnlocked(prefs, AchievementId.candyWorld)) {
      unlocked.add(profileBackgroundCandy);
    }
    if (_achievementUnlocked(prefs, AchievementId.spaceWorld)) {
      unlocked.add(profileBackgroundSpace);
    }
    return unlocked;
  }

  Set<String> _unlockedProfileBadges(SharedPreferences prefs) {
    final unlocked = <String>{};
    final allWorldsComplete =
        _achievementUnlocked(prefs, AchievementId.gardenWorld) &&
            _achievementUnlocked(prefs, AchievementId.oceanWorld) &&
            _achievementUnlocked(prefs, AchievementId.candyWorld) &&
            _achievementUnlocked(prefs, AchievementId.spaceWorld);
    if (allWorldsComplete) unlocked.add(badgeWorldConqueror);
    if (_achievementUnlocked(prefs, AchievementId.luckyPlayer)) {
      unlocked.add(badgeLuckyPlayer);
    }
    if (_collectionUnlockedCount(prefs) >= 20) unlocked.add(badgeCollector);
    if (_bestStarsTotal(prefs) >= 120) unlocked.add(badgeThreeStarMaster);
    return unlocked;
  }

  bool _achievementUnlocked(SharedPreferences prefs, AchievementId id) {
    return prefs.getBool(_achievementKey(id)) ?? false;
  }

  int _collectionUnlockedCount(SharedPreferences prefs) {
    return prefs
        .getKeys()
        .where((key) => key.startsWith(_collectionPrefix))
        .where((key) => prefs.getBool(key) ?? false)
        .length;
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

  TreasureChestType _chestTypeForLevel(int level) {
    if (level % 10 == 0) return TreasureChestType.gold;
    if (level % 5 == 0) return TreasureChestType.silver;
    return TreasureChestType.wood;
  }

  Duration _chestUnlockDuration(TreasureChestType type) {
    switch (type) {
      case TreasureChestType.wood:
        return const Duration(minutes: 30);
      case TreasureChestType.silver:
        return const Duration(hours: 2);
      case TreasureChestType.gold:
        return const Duration(hours: 8);
    }
  }

  ChestOpenReward _rollChestReward(TreasureChestType type) {
    final random = Random();
    switch (type) {
      case TreasureChestType.wood:
        return ChestOpenReward(
          coins: 30 + random.nextInt(51),
          undo: random.nextInt(100) < 18 ? 1 : 0,
          hint: 0,
          shuffle: 0,
        );
      case TreasureChestType.silver:
        final boosterRoll = random.nextInt(100);
        return ChestOpenReward(
          coins: 80 + random.nextInt(101),
          undo: 0,
          hint: boosterRoll < 30 ? 1 : 0,
          shuffle: boosterRoll >= 30 && boosterRoll < 60 ? 1 : 0,
        );
      case TreasureChestType.gold:
        return ChestOpenReward(
          coins: 200 + random.nextInt(301),
          undo: random.nextInt(100) < 35 ? 1 : 0,
          hint: random.nextInt(100) < 35 ? 1 : 0,
          shuffle: random.nextInt(100) < 35 ? 1 : 0,
        );
    }
  }

  List<TreasureChest> _chestsFromPrefs(SharedPreferences prefs) {
    final values = prefs.getStringList(_treasureChestsKey) ?? const <String>[];
    return values.map(_chestFromString).whereType<TreasureChest>().toList();
  }

  TreasureChest? _chestFromString(String value) {
    final parts = value.split('|');
    if (parts.length != 4) return null;
    TreasureChestType? type;
    for (final candidate in TreasureChestType.values) {
      if (candidate.name == parts[1]) type = candidate;
    }
    final grantedAt = int.tryParse(parts[2]);
    final unlockAt = int.tryParse(parts[3]);
    if (type == null || grantedAt == null || unlockAt == null) return null;
    return TreasureChest(
      id: parts[0],
      type: type,
      grantedAtMillis: grantedAt,
      unlockAtMillis: unlockAt,
    );
  }

  Future<void> _saveChests(
    SharedPreferences prefs,
    List<TreasureChest> chests,
  ) async {
    await prefs.setStringList(
      _treasureChestsKey,
      chests
          .map((chest) =>
              '${chest.id}|${chest.type.name}|${chest.grantedAtMillis}|${chest.unlockAtMillis}')
          .toList(),
    );
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
