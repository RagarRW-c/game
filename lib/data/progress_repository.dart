import 'package:shared_preferences/shared_preferences.dart';

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
    final next = (completedLevel + 1).clamp(1, 10);
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastDailySpinDateKey) != _dateKey(now);
  }

  Future<bool> markDailySpinClaimed(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(now);
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

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
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
