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

enum DailyChallengeId { completeLevel, matchTiles, useLuckyWheel }

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
  static const defaultFinalCode = '4286';

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

  Future<int?> claimDailyReward(DateTime now, {int reward = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(now);
    if (prefs.getString(_lastDailyRewardDateKey) == today) return null;
    final updated = (prefs.getInt(_coinsKey) ?? 0) + reward;
    await prefs.setString(_lastDailyRewardDateKey, today);
    await prefs.setInt(_coinsKey, updated);
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
