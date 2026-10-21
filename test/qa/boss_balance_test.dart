import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/board_layout.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import 'support/boss_balance_expectations.dart';
import 'support/geometry.dart';
import 'support/solver.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _fingerprint(String text) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(text)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

Map<String, int> _inventory(Iterable<Tile> tiles) {
  final counts = <String, int>{};
  for (final tile in tiles) {
    counts.update(tile.type, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
}

Rect _bounds(List<Tile> tiles, QaGeometry g) => tiles
    .map((tile) => tile.boardRect(g.board, g.tile))
    .reduce((a, b) => a.expandToInclude(b));

void _replay(LevelDefinition level, QaGeometry g, List<String> path, int maxPeak) {
  final engine = GameEngine(level.tiles, objective: level.objective);
  expect(path.length, level.tiles.length);
  expect(path.toSet(), level.tiles.map((t) => t.id).toSet());
  var peak = 0;
  for (var i = 0; i < path.length; i++) {
    expect(engine.tapTile(path[i], g.board, g.tile), isTrue,
        reason: 'L${level.level}: rejected move $i (${path[i]})');
    peak = math.max(peak, engine.tray.length);
    expect(engine.result,
        i == path.length - 1 ? GameResult.won : GameResult.playing);
    expect(engine.tray.length, lessThan(GameEngine.trayLimit));
  }
  expect(peak, lessThanOrEqualTo(maxPeak));
  expect(engine.boardTiles, isEmpty);
  expect(engine.tray, isEmpty);
  expect(engine.tiles.every((t) => t.state == TileState.matched), isTrue);
  if (level.objective != null) expect(engine.objectiveComplete, isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final baseline = _read('test/qa/fixtures/boss_balance_before.json');
  final assets = (baseline['boss_assets'] as List).cast<Map<String, dynamic>>();
  final context = (baseline['context_levels'] as List).cast<Map<String, dynamic>>();
  const solver = BoardSolver(maxNodes: 0, timeLimit: Duration(seconds: 10));

  test('boss pass scope preserves all 90 normal campaign assets', () {
    expect(assets.map((a) => a['level']), List.generate(10, (i) => (i + 1) * 10));
    expect(bossPass1Coordinates.keys.toSet(), {70, 80});
    final inputs = baseline['normal_asset_lf_fingerprints'] as Map<String, dynamic>;
    expect(inputs, hasLength(90));
    for (final entry in inputs.entries) {
      // Git may change CRLF/LF on checkout; content edits must still fail.
      expect(_fingerprint(File(entry.key).readAsStringSync().replaceAll('\r\n', '\n')),
          entry.value, reason: 'Unapproved normal-level edit: ${entry.key}');
    }
  });

  for (final before in assets) {
    final id = before['level'] as int;
    final assetPath = 'assets/levels/level_${id.toString().padLeft(2, '0')}.json';
    final measured = context.singleWhere((row) => row['level'] == id);

    test('boss $id: exact identity, objective, inventory and approved edits', () {
      final expected = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
      for (final tile in (expected['tiles'] as List).cast<Map<String, dynamic>>()) {
        tile.addAll(bossPass1Coordinates[id]?[tile['id']] ?? <String, double>{});
      }
      final raw = _read(assetPath);
      expect(raw, expected); // Unchanged bosses must match the entire baseline.
      final level = LevelDefinition.fromJson(raw);
      final counts = _inventory(level.tiles);
      expect(level.level, id);
      expect(level.name, before['name']);
      expect(level.timeBonusSeconds, before['timeBonusSeconds']);
      expect(level.tiles.map((t) => t.id).toSet(), hasLength(level.tiles.length));
      expect(counts, _inventory(LevelDefinition.fromJson(before).tiles));
      expect(counts.values.every((n) => n > 0 && n % 3 == 0), isTrue);
      final catalog = tileCatalogForTheme(tileVisualThemeForLevel(id));
      expect(level.tiles.every((t) => catalog.containsKey(t.type)), isTrue);
      expect(raw['layoutPattern'], BoardLayouts.forLevel(id).name);
      expect(BoardLayouts.forLevel(id), BoardLayouts.worldPatterns[id ~/ 10 - 1].last);
      if (level.objective != null) {
        expect(level.objective!.type, before['objective']['type']);
        expect(level.objective!.target, before['objective']['target']);
        expect(level.objective!.target, greaterThan(0));
        expect(counts[level.objective!.type], greaterThanOrEqualTo(level.objective!.target));
      } else {
        expect(before['objective'], isNull);
      }
    });

    for (final screen in qaScreens) {
      test('boss $id / ${screen.name}: SOLVED with real tray and full clearance', () {
        final level = LevelDefinition.fromJson(_read(assetPath));
        final original = LevelDefinition.fromJson(before);
        final g = screen.geometry();
        final old = (measured['screens'] as List).cast<Map<String, dynamic>>()
            .singleWhere((row) => row['screen'] == screen.name);
        final engine = GameEngine(level.tiles)..updateBoardGeometry(g.board, g.tile);
        final available = engine.boardTiles.where((t) => !engine.isTileCovered(t)).toList();
        expect(available, isNotEmpty);
        expect(available.length, greaterThanOrEqualTo(old['geometry']['initial_playable'] as int));
        expect(_bounds(level.tiles, g), _bounds(original.tiles, g));
        for (final tile in level.tiles) {
          final rect = tile.boardRect(g.board, g.tile);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(g.board.width));
          expect(rect.bottom, lessThanOrEqualTo(g.board.height));
        }
        // A zero DFS budget still replays the authored candidate in the real
        // engine. If it no longer works, UNKNOWN fails; divisibility is no proof.
        final solution = solver.solve(level.tiles, g.board, g.tile, objective: level.objective);
        expect(solution.status, SolveStatus.solved, reason: solution.reason);
        expect(solver.replay(level.tiles, g.board, g.tile, solution.path,
            objective: level.objective), isTrue);
        _replay(level, g, solution.path,
            old['witness_metrics']['peak_tray_after_resolution'] as int);
      });

      if (bossPass1Openings.containsKey(id)) {
        test('boss $id / ${screen.name}: exposed opening has a safe continuation', () {
          final level = LevelDefinition.fromJson(_read(assetPath));
          final g = screen.geometry();
          final opening = bossPass1Openings[id]!;
          final engine = GameEngine(level.tiles)..updateBoardGeometry(g.board, g.tile);
          final reverse = engine.renderedBoardTiles.reversed.map((t) => t.id).toList();
          expect(opening.map((tileId) => engine.tileById(tileId)!.type).toSet(), hasLength(1));
          for (final tileId in opening) {
            expect(engine.isTileCovered(engine.tileById(tileId)!), isFalse);
          }
          for (final tileId in opening) {
            expect(engine.tapTile(tileId, g.board, g.tile), isTrue);
          }
          expect(engine.tray, isEmpty);
          expect(engine.boardTiles.length, level.tiles.length - 3);
          expect(engine.result, GameResult.playing);
          _replay(level, g, [...opening, ...reverse.where((tileId) => !opening.contains(tileId))], 6);
        });
      }
    }

    test('boss $id: progression, best stars, gold chest and final milestone', () async {
      SharedPreferences.setMockInitialValues({
        'highest_unlocked_level': id,
        'level_stars_$id': 2,
        'coins': 23,
        'total_xp': 100,
        // Isolate completion rewards from unrelated first-time achievements.
        for (final achievement in AchievementId.values) 'achievement_${achievement.name}': true,
      });
      final repository = ProgressRepository();
      await repository.unlockNextLevel(id);
      await repository.recordLevelCompleted(id, 3);
      expect(await repository.highestUnlockedLevel(), math.min(id + 1, LevelRepository.levelCount));
      expect(await repository.bestStarsForLevel(id), 3);
      expect((await repository.playerProfile()).totalXp, 250);
      expect(await repository.coins(), 23);
      expect(await repository.finalRewardUnlocked(), id == 100);
      final chest = await repository.grantChestForLevel(id);
      expect(chest.granted, isTrue);
      expect(chest.chest!.type, TreasureChestType.gold);
      // These are the unchanged screen's boss grant amounts, checked below.
      await repository.addXp(200);
      await repository.addCoins(350);
      expect((await repository.playerProfile()).totalXp, 450);
      expect(await repository.coins(), 373);
      await repository.recordLevelCompleted(id, 1);
      await repository.unlockNextLevel(id - 10);
      expect(await repository.bestStarsForLevel(id), 3);
      expect(await repository.highestUnlockedLevel(), math.min(id + 1, 100));
      expect(await repository.coins(), 373);
      if (id == 100) {
        expect((await repository.finalRewardSummary())!.levelsCompleted, 100);
      }
    });
  }

  test('boss reward constants and all ten themed identities remain unchanged', () {
    final source = File('lib/presentation/screens/game_screen.dart').readAsStringSync();
    for (final entry in {'_levelCompleteCoinReward': 50, '_bossCoinReward': 300, '_bossXpReward': 200}.entries) {
      final match = RegExp('static const int ${entry.key} = ([0-9]+);').firstMatch(source);
      expect(match, isNotNull);
      expect(int.parse(match!.group(1)!), entry.value);
    }
    final metadata = source.split('class _BossLevelInfo {').last.split('class _GameOverDialog').first;
    const worlds = ['Garden', 'Ocean', 'Candy', 'Space', 'Desert', 'Ice', 'Jungle', 'Volcano', 'Dream', 'Crystal'];
    for (var world = 0; world < worlds.length; world++) {
      final id = (world + 1) * 10;
      final definition = metadata.split('case $id:').last.split('case ').first;
      expect(definition, contains("bossTitle: '${worlds[world]} Boss'"));
      expect(definition, contains(id == 100
          ? "completeTitle: 'Final World Complete'" : "completeTitle: 'World Complete!'"));
    }
  });
}
