import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/domain/endless_board_generator.dart';
import 'package:triple_tile_adventure/domain/endless_difficulty.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import 'support/engine_tap_oracle.dart';
import 'support/geometry.dart';
import 'support/legacy_endless_board_generator.dart';
import 'support/pre_progression_endless_generator.dart';
import 'support/solver.dart';

const rounds = [1, 3, 4, 7, 8, 12, 13, 100];
const seeds = [0, 1, 42];

void main() {
  for (final round in [8, 12]) {
    test(
        'legacy garden round $round seed 0 is genuinely impossible on small screen',
        () {
      final tiles = LegacyEndlessBoardGenerator(random: Random(0))
          .generate(round: round, theme: TileVisualTheme.garden);
      final g = qaScreens.first.geometry(endless: true);
      expect(tiles.length, 54);
      expect(engineCanClearWithoutBoosters(tiles, g.board, g.tile), isFalse,
          reason: 'Independent exhaustive search of real engine transitions');
      final result =
          const BoardSolver(maxNodes: 100000, timeLimit: Duration(seconds: 30))
              .solve(tiles, g.board, g.tile);
      expect(result.status, SolveStatus.unsolvable);
      expect(result.reason, 'Exhaustive tap search');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
        'garden round $round seed 0 has a booster-free engine-verified solution',
        () {
      final tiles = EndlessBoardGenerator(random: Random(0))
          .generate(round: round, theme: TileVisualTheme.garden);
      for (final screen in qaScreens) {
        final g = screen.geometry(endless: true);
        final solution = const BoardSolver().solve(tiles, g.board, g.tile);
        expect(solution.status, SolveStatus.solved, reason: screen.name);
        expect(solution.reason, 'Engine-replayed reverse paint order');
        final engine = GameEngine(tiles);
        var peakTray = 0;
        for (final id in solution.path) {
          expect(engine.tapTile(id, g.board, g.tile), isTrue,
              reason: '$id on ${screen.name}');
          expect(engine.result, isNot(GameResult.lost));
          expect(engine.tray.length, lessThan(GameEngine.trayLimit));
          peakTray = max(peakTray, engine.tray.length);
        }
        expect(peakTray, 6,
            reason: 'The four-type solution retains late-round tray pressure');
        expect(engine.result, GameResult.won);
        expect(engine.boardTiles, isEmpty);
        expect(engine.tray, isEmpty);
        expect(engine.tiles.every((t) => t.state == TileState.matched), isTrue);
      }
    });
  }

  test(
      'solution assignment preserves deterministic seeded layouts and inventories across a run',
      () {
    for (final theme in TileVisualTheme.values) {
      for (final seed in seeds) {
        final generator = EndlessBoardGenerator(random: Random(seed));
        final repeat = EndlessBoardGenerator(random: Random(seed));
        final legacy = LegacyEndlessBoardGenerator(random: Random(seed));
        final preProgression =
            PreProgressionEndlessBoardGenerator(random: Random(seed));
        for (final round in rounds) {
          final tiles = generator.generate(round: round, theme: theme);
          final repeated = repeat.generate(round: round, theme: theme);
          final original = legacy.generate(round: round, theme: theme);
          final baseline = preProgression.generate(round: round, theme: theme);
          final key = '${theme.name}/round=$round/seed=$seed';
          String shape(List<Tile> list) => list
              .map((t) => '${t.id}:${t.x}:${t.y}:${t.layer}:${t.state}')
              .join('|');
          // Preserve the historical solution-repair contract for every old
          // sample, including round 100. The approved progression intentionally
          // changes late geometry/inventory; its stronger bounds and exact
          // stage contracts are covered in endless_progression_test.dart.
          expect(shape(baseline), shape(original), reason: key);
          expect(baseline.map((t) => t.type).toList()..sort(),
              original.map((t) => t.type).toList()..sort(),
              reason: key);
          if (round <= 13) {
            expect(shape(tiles), shape(original), reason: key);
            expect(tiles.map((t) => t.type).toList(),
                baseline.map((t) => t.type).toList(),
                reason: key);
          } else {
            expect(shape(tiles), isNot(shape(original)), reason: key);
          }
          expect(shape(tiles), shape(repeated), reason: key);
          expect(tiles.map((t) => t.type).toList(),
              repeated.map((t) => t.type).toList(),
              reason: key);
        }
      }
    }
  });

  test('independent oracle never reports UNSOLVABLE after a budget cutoff', () {
    final tiles = LegacyEndlessBoardGenerator(random: Random(0))
        .generate(round: 8, theme: TileVisualTheme.garden);
    final g = qaScreens.first.geometry(endless: true);
    expect(
        () =>
            engineCanClearWithoutBoosters(tiles, g.board, g.tile, maxStates: 0),
        throwsStateError);
  });

  test(
      'independent oracle finds a legal booster-free solution through the engine',
      () {
    final tiles = List.generate(
        6,
        (i) => Tile(
              id: 'oracle_$i',
              type: i.isEven ? 'apple' : 'berry',
              x: 0.2,
              y: 0.2,
              layer: i,
            ));
    final g = qaScreens.first.geometry(endless: true);
    expect(engineCanClearWithoutBoosters(tiles, g.board, g.tile), isTrue);
  });

  test(
      'seeded Endless boards satisfy each difficulty profile and screen geometry',
      () {
    final problems = <String>[];
    final rows = <Map<String, Object?>>[];
    for (final theme in TileVisualTheme.values) {
      for (final round in rounds) {
        for (final seed in seeds) {
          final key = '${theme.name}/round=$round/seed=$seed';
          final issues = <String>[];
          void check(bool ok, String detail) {
            if (!ok) issues.add(detail);
          }

          final tiles = EndlessBoardGenerator(random: Random(seed))
              .generate(round: round, theme: theme);
          final again = EndlessBoardGenerator(random: Random(seed))
              .generate(round: round, theme: theme);
          String signature(List<Tile> ts) => ts
              .map((t) => '${t.id}:${t.type}:${t.x}:${t.y}:${t.layer}')
              .join('|');
          check(signature(tiles) == signature(again),
              'Seeded generator not reproducible');
          final later = round >= 14 ? EndlessDifficulty.forRound(round) : null;
          final minCount = later?.minTiles ??
              (round <= 3
                  ? 24
                  : round <= 7
                      ? 30
                      : round <= 12
                          ? 42
                          : 54);
          final maxCount = later?.maxTiles ??
              (round <= 3
                  ? 30
                  : round <= 7
                      ? 42
                      : round <= 12
                          ? 54
                          : 72);
          final minLayers = later?.minLayers ??
              (round <= 3
                  ? 2
                  : round <= 7
                      ? 3
                      : round <= 12
                          ? 4
                          : 5);
          final maxLayers = later?.maxLayers ??
              (round <= 7
                  ? 3
                  : round <= 12
                      ? 4
                      : 6);
          check(
              tiles.length >= minCount &&
                  tiles.length <= maxCount &&
                  tiles.length % 3 == 0,
              'Invalid tile count ${tiles.length}');
          check(tiles.map((t) => t.id).toSet().length == tiles.length,
              'Duplicate IDs');
          final layers = tiles.map((t) => t.layer).toSet().toList()..sort();
          check(
              layers.length >= minLayers &&
                  layers.length <= maxLayers &&
                  layers.toString() ==
                      List.generate(layers.length, (i) => i).toString(),
              'Invalid layer profile $layers');
          final counts = <String, int>{};
          for (final t in tiles) {
            check(tileCatalogForTheme(theme).containsKey(t.type),
                'Invalid theme type ${t.type}');
            check(
                t.state == TileState.board &&
                    t.id.startsWith('endless_${round}_'),
                'Invalid tile identity/state ${t.id}');
            check(
                t.x.isFinite &&
                    t.y.isFinite &&
                    t.x >= 0.02 &&
                    t.x <= 0.82 &&
                    t.y >= 0.02 &&
                    t.y <= 0.80,
                'Invalid origin ${t.id}');
            counts.update(t.type, (n) => n + 1, ifAbsent: () => 1);
          }
          check(counts.values.every((n) => n % 3 == 0),
              'Incomplete per-type triples');
          for (final screen in qaScreens) {
            final g = screen.geometry(endless: true);
            final engine = GameEngine(tiles)
              ..updateBoardGeometry(g.board, g.tile);
            check(engine.boardTiles.any((t) => !engine.isTileCovered(t)),
                '${screen.name}: no selectable tile');
            for (final t in tiles) {
              final rect = t.boardRect(g.board, g.tile);
              check(
                  rect.left >= 0 &&
                      rect.top >= 0 &&
                      rect.right <= g.board.width + 1e-6 &&
                      rect.bottom <= g.board.height + 1e-6,
                  '${screen.name}: tile outside inner Stack ${t.id}');
            }
            // Every sample must carry the construction's actual engine proof,
            // across all themes and screens, not just complete type triples.
            final path = engine.renderedBoardTiles.reversed
                .map((t) => t.id)
                .toList(growable: false);
            for (final id in path) {
              final accepted = engine.tapTile(id, g.board, g.tile);
              check(
                  accepted &&
                      engine.result != GameResult.lost &&
                      engine.tray.length < GameEngine.trayLimit,
                  '${screen.name}: guaranteed solution rejected at $id');
              if (!accepted || engine.result == GameResult.lost) break;
            }
            check(
                engine.result == GameResult.won &&
                    engine.boardTiles.isEmpty &&
                    engine.tray.isEmpty &&
                    engine.tiles.every((t) => t.state == TileState.matched),
                '${screen.name}: guaranteed solution did not fully clear the board');
          }
          rows.add({
            'sample': key,
            'tiles': tiles.length,
            'layers': layers.length,
            'status': issues.isEmpty ? 'PASS' : 'FAIL',
            'issues': issues
          });
          problems.addAll(issues.map((e) => '$key: $e'));
        }
      }
    }
    Directory('qa/results').createSync(recursive: true);
    File('qa/results/endless_validity.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ')
            .convert({'samples': rows, 'problems': problems}));
    expect(problems, isEmpty, reason: 'See qa/results/endless_validity.json');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('sampled Endless boards have verified booster-free solver witnesses',
      () {
    final rows = <Map<String, Object?>>[];
    final problems = <String>[];
    // Themes share the same type keys, so solve one theme at each profile
    // boundary/seed on every geometry; validity above covers all ten themes.
    for (final round in rounds) {
      for (final seed in seeds) {
        final tiles = EndlessBoardGenerator(random: Random(seed))
            .generate(round: round, theme: TileVisualTheme.garden);
        for (final screen in qaScreens) {
          final g = screen.geometry(endless: true);
          final result = const BoardSolver(
                  maxNodes: 10000, timeLimit: Duration(milliseconds: 200))
              .solve(tiles, g.board, g.tile);
          final key = 'garden/round=$round/seed=$seed/${screen.name}';
          rows.add({'sample': key, ...result.toJson()});
          if (result.status != SolveStatus.solved) {
            problems.add(
                '$key: ${result.status.name.toUpperCase()}: ${result.reason}');
          }
        }
      }
    }
    Directory('qa/results').createSync(recursive: true);
    File('qa/results/endless_solver.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'scope': 'Seeded samples only; tap-only, not all possible Endless boards',
      'solverMaxNodes': 10000,
      'solverMilliseconds': 200,
      'samples': rows,
      'problems': problems,
    }));
    expect(problems, isEmpty,
        reason:
            'See qa/results/endless_solver.json; all generated boards need a verified witness');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
