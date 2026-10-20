import '../../data/progress_repository.dart';
import '../../data/level_repository.dart';

/// Read-only presentation snapshot. Unlocks and stars remain repository-owned.
class AdventureProgress {
  const AdventureProgress({
    required this.highestUnlockedLevel,
    required this.starsByLevel,
  });

  final int highestUnlockedLevel;
  final Map<int, int> starsByLevel;

  static Future<AdventureProgress> load(ProgressRepository repository) async {
    final highest = await repository.highestUnlockedLevel();
    final stars =
        await repository.bestStarsByLevel(1, LevelRepository.levelCount);
    return AdventureProgress(
      highestUnlockedLevel: highest,
      starsByLevel: Map.unmodifiable(stars),
    );
  }

  bool isUnlocked(int level) => level <= highestUnlockedLevel;
  bool isCompleted(int level) =>
      isUnlocked(level) &&
      (level < highestUnlockedLevel || (starsByLevel[level] ?? 0) > 0);
  bool isCurrent(int level) =>
      level == highestUnlockedLevel && !isCompleted(level);

  int completedIn(int start, int end) => [
        for (var level = start; level <= end; level++) level
      ].where(isCompleted).length;
}
