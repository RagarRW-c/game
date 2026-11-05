import '../data/level_repository.dart';
import '../data/progress_repository.dart';
import '../domain/level.dart';
import 'session.dart';

class PlaytestLevelRepository extends LevelRepository {
  PlaytestLevelRepository(this.levels, this.variant);
  final PlaytestLevels levels;
  final PlaytestVariant variant;

  @override
  Future<LevelDefinition> loadLevel(int level) async {
    if (level != 96) throw StateError('Only Level 96 is available.');
    return levels.create(variant);
  }
}

/// Implements, never extends, the disk-backed repository. The short whitelist
/// is deliberately inert; every unexpected operation fails closed.
class PlaytestProgress implements ProgressRepository {
  @override
  Future<int> coins() async => 0;
  @override
  Future<bool> vibrationEnabled() async => true;
  @override
  Future<int> extraHintBoosters() async => 0;
  @override
  Future<int> extraShuffleBoosters() async => 0;
  @override
  Future<int> extraUndoBoosters() async => 0;
  @override
  Future<void> recordMatchedTiles(int amount,
      {int? level, Iterable<String> tileTypes = const []}) async {}
  @override
  Future<List<PendingAchievementPopup>>
      consumePendingAchievementPopups() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'Production operation blocked: ${invocation.memberName}');
}
