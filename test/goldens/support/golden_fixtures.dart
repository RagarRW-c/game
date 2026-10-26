import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/endless_board_generator.dart';
import 'package:triple_tile_adventure/domain/level.dart';

// Like the existing QA level fixture, synchronous local I/O avoids racing
// asset loading against the widget test's fake clock. Always parse fresh tiles.
class GoldenLevels extends LevelRepository {
  @override
  Future<LevelDefinition> loadLevel(int level) async =>
      LevelDefinition.fromJson(jsonDecode(File(
        'assets/levels/level_${level.toString().padLeft(2, '0')}.json',
      ).readAsStringSync()) as Map<String, dynamic>);
}

EndlessBoardGenerator goldenEndlessGenerator() =>
    EndlessBoardGenerator(random: Random(73129));

/// Only screenshot inputs are overridden. Other repository access is isolated
/// by SharedPreferences.setMockInitialValues in the harness.
class GoldenProgress extends ProgressRepository {
  GoldenProgress({this.highestLevel = 5});

  final int highestLevel;
  bool _chestOpened = false;

  @override
  Future<int> coins() async => 1250;
  @override
  Future<int> highestUnlockedLevel() async => highestLevel;
  @override
  Future<Map<int, int>> bestStarsByLevel(int startLevel, int endLevel) async =>
      {
        for (var level = startLevel;
            level <= endLevel && level < highestLevel;
            level++)
          level: 1 + (level % 3),
      };
  @override
  Future<int> bestEndlessScore() async => 12500;
  @override
  Future<bool> levelOneTutorialSeen() async => true;
  @override
  Future<bool> vibrationEnabled() async => false;
  @override
  Future<bool> dailyRewardAvailable(DateTime now) async => true;
  @override
  Future<bool> dailySpinAvailable(DateTime now) async => true;
  @override
  Future<DailySpinStatus> dailySpinStatus(DateTime now) async =>
      const DailySpinStatus(
        polishTodayKey: '2026-01-15',
        lastSpinDate: '2026-01-14',
        canSpin: true,
      );
  @override
  Future<DailyLoginStreakStatus> dailyLoginStreakStatus(DateTime now) async =>
      const DailyLoginStreakStatus(
        todayKey: '2026-01-15',
        lastClaimDate: '2026-01-15',
        currentStreak: 3,
        claimDay: 3,
        reward: 100,
        available: false,
      );
  @override
  Future<List<PendingAchievementPopup>>
      consumePendingAchievementPopups() async => [];

  @override
  Future<DailyChallengesState> dailyChallenges() async =>
      const DailyChallengesState(
        dateKey: '2026-01-15',
        bonusClaimed: false,
        challenges: [
          DailyChallengeEntry(
            definition: DailyChallengeDefinition(
              id: DailyChallengeId.completeTwoLevels,
              title: 'Complete 2 levels',
              target: 2,
              rewardType: DailyChallengeRewardType.coins,
              rewardAmount: 100,
              rewardLabel: '100 coins',
            ),
            progress: 2,
            claimed: false,
          ),
          DailyChallengeEntry(
            definition: DailyChallengeDefinition(
              id: DailyChallengeId.matchTiles,
              title: 'Match 60 tiles',
              target: 60,
              rewardType: DailyChallengeRewardType.hintBooster,
              rewardAmount: 1,
              rewardLabel: '+1 Hint',
            ),
            progress: 24,
            claimed: false,
          ),
          DailyChallengeEntry(
            definition: DailyChallengeDefinition(
              id: DailyChallengeId.useLuckyWheel,
              title: 'Spin the Lucky Wheel',
              target: 1,
              rewardType: DailyChallengeRewardType.coins,
              rewardAmount: 50,
              rewardLabel: '50 coins',
            ),
            progress: 1,
            claimed: true,
          ),
        ],
      );

  @override
  Future<List<TreasureChest>> treasureChests() async => [
        if (!_chestOpened)
          const _FrozenChest(
              'golden_ready', TreasureChestType.wood, Duration.zero),
        const _FrozenChest('golden_locked', TreasureChestType.silver,
            Duration(hours: 1, minutes: 23, seconds: 45)),
      ];

  @override
  Future<ChestOpenReward?> openTreasureChest(String chestId) async {
    if (chestId != 'golden_ready' || _chestOpened) return null;
    _chestOpened = true;
    return const ChestOpenReward(coins: 75, undo: 1, hint: 0, shuffle: 1);
  }
}

// The real card calls these methods with DateTime.now(). Freeze the model's
// answers so its countdown stays constant, even across the periodic rebuild.
class _FrozenChest extends TreasureChest {
  const _FrozenChest(String id, TreasureChestType type, this.timeLeft)
      : super(id: id, type: type, grantedAtMillis: 0, unlockAtMillis: 0);

  final Duration timeLeft;
  @override
  bool isUnlocked(DateTime now) => timeLeft == Duration.zero;
  @override
  Duration remaining(DateTime now) => timeLeft;
}

// Implements instead of extending: constructing GameAudioService creates
// native players. Implement the entire public interface explicitly so future
// API additions are compile errors instead of runtime noSuchMethod failures.
class GoldenAudio implements GameAudioService {
  @override
  Future<void> prepareTileFeedback() async {}
  @override
  void cancelPendingTileFeedback() {}

  // Match the deterministic default preferences and exercise the SFX dispatch
  // path. Enabling either setting never starts real audio in this test double.
  @override
  bool musicEnabled = true;
  @override
  bool sfxEnabled = true;

  @override
  Future<void> setMusicEnabled(bool enabled) async {
    musicEnabled = enabled;
  }

  @override
  Future<void> startMusic() async {}
  @override
  Future<void> startMenuMusic() async {}
  @override
  Future<void> startGameplayMusic() async {}
  @override
  Future<void> stopGameplayMusic() async {}
  @override
  Future<void> pauseMusicForBackground() async {}
  @override
  Future<void> resumeMusicFromBackground() async {}
  @override
  Future<void> playTap() async {}
  @override
  Future<void> playMatch() async {}
  @override
  Future<void> playWin() async {}
  @override
  Future<void> playLose() async {}
  @override
  Future<void> playBooster() async {}
  @override
  Future<void> playLevelComplete() async {}
  @override
  Future<void> playGameOver() async {}
  @override
  Future<void> playChestOpen() async {}
  @override
  Future<void> playLuckyWheelSpin() async {}
  @override
  Future<void> playWheelTick() async {}
  @override
  Future<void> playWheelStop() async {}
  @override
  Future<void> playWheelReveal() async {}
  @override
  Future<void> playWheelCollection() async {}
  @override
  Future<void> playAchievementUnlocked() async {}
  @override
  Future<void> playWorldUnlocked() async {}
  @override
  Future<void> dispose() async {}
}
