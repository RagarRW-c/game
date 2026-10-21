import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/endless_board_generator.dart';
import 'package:triple_tile_adventure/domain/endless_difficulty.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import 'support/geometry.dart';
import 'support/pre_progression_endless_generator.dart';
import 'support/solver.dart';

const _seeds = [0, 1, 42, 2147483647];
const _rounds = [
  1,
  3,
  4,
  7,
  8,
  12,
  13,
  14,
  15,
  19,
  20,
  21,
  24,
  25,
  26,
  30,
  31,
  49,
  50,
  51,
  52,
  74,
  75,
  76,
  99,
  100,
  101,
  1000,
];

String _signature(List<Tile> tiles) => tiles
    .map((t) => '${t.id}:${t.type}:${t.x}:${t.y}:${t.layer}:${t.state.name}')
    .join('|');

Map<String, int> _counts(List<Tile> tiles) {
  final counts = <String, int>{};
  for (final tile in tiles) {
    counts.update(tile.type, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('explicit later stages, challenge intervals and recovery contracts', () {
    // Independent design contract: min/max tiles, min/max layers, types, cap.
    const expectations = <int, List<int>>{
      14: [54, 60, 5, 5, 9, 10],
      20: [60, 60, 5, 5, 11, 6],
      21: [48, 54, 4, 4, 8, 12],
      25: [66, 66, 5, 5, 12, 6],
      26: [60, 66, 5, 5, 10, 9],
      30: [66, 66, 5, 5, 12, 6],
      31: [54, 60, 4, 4, 9, 12],
      49: [60, 66, 5, 5, 10, 9],
      50: [72, 72, 6, 6, 13, 6],
      51: [60, 66, 5, 5, 10, 12],
      52: [66, 72, 5, 6, 11, 8],
      74: [66, 72, 5, 6, 11, 8],
      75: [72, 72, 6, 6, 14, 6],
      76: [66, 72, 6, 6, 12, 8],
      100: [72, 72, 6, 6, 14, 6],
    };
    for (final entry in expectations.entries) {
      final p = EndlessDifficulty.forRound(entry.key);
      expect([
        p.minTiles,
        p.maxTiles,
        p.minLayers,
        p.maxLayers,
        p.typeCount,
        p.topTiles
      ], entry.value, reason: 'Round ${entry.key}');
    }
    for (var round = 14; round <= 200; round++) {
      final p = EndlessDifficulty.forRound(round);
      expect(
          p.kind,
          round % 10 == 1
              ? EndlessRoundKind.recovery
              : round % 5 == 0
                  ? EndlessRoundKind.challenge
                  : EndlessRoundKind.standard);
      expect(p.maxTiles, lessThanOrEqualTo(72));
      expect(p.maxLayers, lessThanOrEqualTo(6));
      expect(p.topTiles, lessThanOrEqualTo(16));
      for (var layers = p.minLayers; layers <= p.maxLayers; layers++) {
        final largestLowerLayer =
            ((p.maxTiles - p.topTiles) + layers - 2) ~/ (layers - 1);
        expect(largestLowerLayer, lessThanOrEqualTo(16),
            reason: 'No grid cell may repeat within a layer at round $round');
      }
    }
    expect(
        [15, 20, 25].map((r) => EndlessDifficulty.forRound(r).layout).toSet(),
        hasLength(3),
        reason: 'Challenge rounds must rotate their topology');
    final hardBatches = [14, 26, 52, 76].map((round) {
      final p = EndlessDifficulty.forRound(round);
      return List.generate(12, p.batchWidth).where((n) => n == 4).length;
    }).toList();
    expect(hardBatches, [4, 6, 9, 12]);
    expect(List.generate(12, EndlessDifficulty.forRound(21).batchWidth),
        everyElement(3));
    expect(List.generate(12, EndlessDifficulty.forRound(100).batchWidth),
        everyElement(4));
    for (final (standardRound, challengeRound, recoveryRound) in [
      (14, 15, 21),
      (26, 25, 31),
      (52, 50, 51),
      (76, 75, 81),
    ]) {
      final standard = EndlessDifficulty.forRound(standardRound);
      final challenge = EndlessDifficulty.forRound(challengeRound);
      final recovery = EndlessDifficulty.forRound(recoveryRound);
      expect(recovery.maxTiles, lessThan(standard.maxTiles));
      expect(recovery.maxLayers, lessThan(challenge.maxLayers));
      expect(recovery.typeCount, lessThan(standard.typeCount));
      expect(recovery.topTiles, greaterThan(challenge.topTiles));
      expect(recovery.batchWidth(0), lessThan(challenge.batchWidth(0)));
      expect(challenge.typeCount, greaterThan(standard.typeCount));
    }
  });

  test('all early rounds preserve exact seeded types, positions and RNG use',
      () {
    for (final seed in _seeds) {
      for (final theme in TileVisualTheme.values) {
        final current = EndlessBoardGenerator(random: Random(seed));
        final before =
            PreProgressionEndlessBoardGenerator(random: Random(seed));
        for (var round = 1; round <= 13; round++) {
          expect(_signature(current.generate(round: round, theme: theme)),
              _signature(before.generate(round: round, theme: theme)),
              reason: '${theme.name}/$seed/$round');
          // Check direct generation too, including the historic Garden 8/12.
          expect(
              _signature(EndlessBoardGenerator(random: Random(seed))
                  .generate(round: round, theme: theme)),
              _signature(
                  PreProgressionEndlessBoardGenerator(random: Random(seed))
                      .generate(round: round, theme: theme)));
        }
      }
    }
  });

  for (final round in _rounds) {
    test('round $round: all themes/seeds have bounded, booster-free boards',
        () {
      for (final seed in _seeds) {
        for (final theme in TileVisualTheme.values) {
          final tiles = EndlessBoardGenerator(random: Random(seed))
              .generate(round: round, theme: theme);
          final repeated = EndlessBoardGenerator(random: Random(seed))
              .generate(round: round, theme: theme);
          final key = '${theme.name}/$round/$seed';
          expect(_signature(tiles), _signature(repeated), reason: key);
          expect(tiles.map((t) => t.id).toSet(), hasLength(tiles.length));
          expect(tiles.length % 3, 0);
          final counts = _counts(tiles);
          expect(counts.values.every((n) => n % 3 == 0), isTrue);
          expect(counts.keys.every(tileCatalogForTheme(theme).containsKey),
              isTrue);
          expect(tiles.every((t) => t.state == TileState.board), isTrue);
          final p = round >= 14 ? EndlessDifficulty.forRound(round) : null;
          final layers = tiles.map((t) => t.layer).toSet();
          if (p != null) {
            expect(tiles.length, inInclusiveRange(p.minTiles, p.maxTiles));
            expect(layers.length, inInclusiveRange(p.minLayers, p.maxLayers));
            expect(layers,
                unorderedEquals(List.generate(layers.length, (i) => i)));
            expect(counts, hasLength(p.typeCount));
            expect(tiles.where((t) => t.layer == layers.length - 1),
                hasLength(p.topTiles));
          }
          for (final screen in qaScreens) {
            final g = screen.geometry(endless: true);
            final engine = GameEngine(tiles)
              ..updateBoardGeometry(g.board, g.tile);
            for (final tile in tiles) {
              final rect = tile.boardRect(g.board, g.tile);
              expect(rect.left, greaterThanOrEqualTo(0), reason: key);
              expect(rect.top, greaterThanOrEqualTo(0), reason: key);
              expect(rect.right, lessThanOrEqualTo(g.board.width), reason: key);
              expect(rect.bottom, lessThanOrEqualTo(g.board.height),
                  reason: key);
              if (p != null) {
                for (final other in tiles
                    .where((t) => t.layer == tile.layer && t.id != tile.id)) {
                  // Stronger than the engine's 3% blocking threshold: no
                  // positive-area same-layer intersections on any QA screen.
                  expect(
                      rect.overlaps(other.boardRect(g.board, g.tile)), isFalse,
                      reason: '$key/${screen.name}: ${tile.id}/${other.id}');
                }
              }
            }
            final painted = engine.renderedBoardTiles;
            var crossCellBlockingEdges = 0;
            for (var i = 0; i < painted.length; i++) {
              final covered = painted
                  .skip(i + 1)
                  .any((t) => painted[i].overlaps(t, g.board, g.tile));
              expect(engine.isTileCovered(painted[i]), covered);
              if (p != null && screen == qaScreens.first) {
                for (final other in painted.skip(i + 1)) {
                  if (other.layer != painted[i].layer &&
                      ((other.x - painted[i].x).abs() > 0.09 ||
                          (other.y - painted[i].y).abs() > 0.09) &&
                      painted[i].overlaps(other, g.board, g.tile)) {
                    crossCellBlockingEdges++;
                  }
                }
              }
            }
            if (p != null && screen == qaScreens.first) {
              expect(crossCellBlockingEdges, greaterThan(0),
                  reason:
                      '$key: layers must create readable neighboring-cell dependencies');
            }
            if (p != null) {
              expect(tiles.where((t) => !engine.isTileCovered(t)).length,
                  greaterThanOrEqualTo(p.topTiles));
              final covered = tiles.where(engine.isTileCovered).first;
              expect(engine.tapTile(covered.id, g.board, g.tile), isFalse);
              expect(engine.tray, isEmpty);
              expect(engine.tiles.every((t) => t.state == TileState.board),
                  isTrue);
            }
            final solved =
                const BoardSolver(maxNodes: 0).solve(tiles, g.board, g.tile);
            expect(solved.status, SolveStatus.solved,
                reason: '$key/${screen.name}');
            expect(solved.reason, 'Engine-replayed reverse paint order');
            expect(solved.path, hasLength(tiles.length));
            var peak = 0;
            for (final id in solved.path) {
              expect(engine.isTileCovered(engine.tileById(id)!), isFalse);
              expect(engine.tapTile(id, g.board, g.tile), isTrue);
              expect(engine.result, isNot(GameResult.lost));
              expect(engine.tray.length, lessThan(7));
              peak = max(peak, engine.tray.length);
            }
            if (p?.kind == EndlessRoundKind.recovery) expect(peak, 5);
            if (p?.kind == EndlessRoundKind.challenge) expect(peak, 6);
            expect(engine.result, GameResult.won);
            expect(engine.boardTiles, isEmpty);
            expect(engine.tray, isEmpty);
            expect(engine.tiles.every((t) => t.state == TileState.matched),
                isTrue);
          }
        }
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  test('continuous theme-rotated runs and round-one restarts reproduce', () {
    for (final seed in _seeds) {
      final a = EndlessBoardGenerator(random: Random(seed));
      final b = EndlessBoardGenerator(random: Random(seed));
      for (var round = 1; round <= 105; round++) {
        final theme = TileVisualTheme.values[((round - 1) ~/ 3) % 10];
        final tiles = a.generate(round: round, theme: theme);
        expect(_signature(tiles),
            _signature(b.generate(round: round, theme: theme)));
        for (final screen in qaScreens) {
          final g = screen.geometry(endless: true);
          expect(
              const BoardSolver(maxNodes: 0)
                  .solve(tiles, g.board, g.tile)
                  .status,
              SolveStatus.solved,
              reason: '$seed/$round/${screen.name}');
        }
      }
      // _startRun retains the generator and asks for round 1 again. It does
      // not reseed, restore an old board, or resume the highest played round.
      final restarted = a.generate(round: 1, theme: TileVisualTheme.garden);
      expect(_signature(restarted),
          _signature(b.generate(round: 1, theme: TileVisualTheme.garden)));
      expect(restarted.length, inInclusiveRange(24, 30));
      expect(restarted.every((t) => t.id.startsWith('endless_1_')), isTrue);
      for (final screen in qaScreens) {
        final g = screen.geometry(endless: true);
        expect(
            const BoardSolver(maxNodes: 0)
                .solve(restarted, g.board, g.tile)
                .status,
            SolveStatus.solved);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('stage generation and restart preserve saved progress and run totals',
      () async {
    SharedPreferences.setMockInitialValues({
      'level_stars_1': 3,
      'level_stars_100': 2,
      'coins': 1234,
      'total_xp': 800,
      'selected_profile_background': ProgressRepository.profileBackgroundOcean,
    });
    final repository = ProgressRepository();
    await repository.recordEndlessRun(
        score: 9000, boardsCleared: 12, tilesMatched: 450);
    final prefs = await SharedPreferences.getInstance();
    Map<String, Object?> snapshot() =>
        {for (final key in prefs.getKeys()) key: prefs.get(key)};
    final saved = snapshot();
    final generator = EndlessBoardGenerator(random: Random(42));
    for (final round in [14, 20, 30, 50, 75, 100, 1]) {
      generator.generate(round: round, theme: TileVisualTheme.garden);
    }
    expect(snapshot(), saved,
        reason: 'Generation must have no persistence side effects');
    expect(await ProgressRepository().bestEndlessScore(), 9000);
    await repository.recordEndlessRun(
        score: 500, boardsCleared: 1, tilesMatched: 24);
    expect(await ProgressRepository().bestEndlessScore(), 9000);
    expect(prefs.getInt('total_endless_runs'), 2);
    expect(prefs.getInt('total_endless_boards_cleared'), 13);
  });
}
