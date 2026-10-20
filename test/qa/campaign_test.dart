import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/domain/board_layout.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/level.dart';

import 'support/geometry.dart';
import 'support/solver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audit every campaign JSON, authored layout, geometry and solvability',
      () {
    final problems = <String>[];
    final rows = <Map<String, Object?>>[];
    final globalTileIds = <String>{};
    final levelIds = <int>{};
    final patterns = <int, Set<String>>{};
    final signatures = <int, Set<String>>{};
    final expectedFiles = {
      for (var id = 1; id <= LevelRepository.levelCount; id++)
        'level_${id.toString().padLeft(2, '0')}.json',
    };
    final actualFiles = Directory('assets/levels')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    if (actualFiles.difference(expectedFiles).isNotEmpty ||
        expectedFiles.difference(actualFiles).isNotEmpty) {
      problems.add(
          'Campaign files differ: missing=${expectedFiles.difference(actualFiles)}, '
          'extra=${actualFiles.difference(expectedFiles)}');
    }

    for (var id = 1; id <= LevelRepository.levelCount; id++) {
      final issues = <String>[];
      final row = <String, Object?>{'level': id};
      void check(bool condition, String detail) {
        if (!condition) issues.add(detail);
      }

      try {
        final file =
            File('assets/levels/level_${id.toString().padLeft(2, '0')}.json');
        final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        // Use the production parser, then reject invalid values it accepts.
        final level = LevelDefinition.fromJson(raw);
        check(level.level == id && levelIds.add(level.level),
            'Invalid/duplicate level ID');
        check(level.name.trim().isNotEmpty, 'Empty name');
        check(level.timeBonusSeconds >= 0, 'Negative time bonus');
        check(level.tiles.isNotEmpty && level.tiles.length % 3 == 0,
            'Tile count must be positive and divisible by three');
        final catalog = tileCatalogForTheme(tileVisualThemeForLevel(id));
        final inventory = <String, int>{};
        for (final tile in level.tiles) {
          check(tile.id.trim().isNotEmpty && globalTileIds.add(tile.id),
              'Invalid/globally duplicate tile ID ${tile.id}');
          check(
              tileCatalog.containsKey(tile.type) &&
                  catalog.containsKey(tile.type),
              'Unknown tile type ${tile.type} (${tile.id})');
          check(tile.layer >= 0, 'Negative layer ${tile.id}');
          check(
              tile.x.isFinite &&
                  tile.y.isFinite &&
                  tile.x >= 0 &&
                  tile.x <= 1 &&
                  tile.y >= 0 &&
                  tile.y <= 1,
              'Invalid normalized origin ${tile.id}');
          inventory.update(tile.type, (n) => n + 1, ifAbsent: () => 1);
        }
        check(inventory.values.every((n) => n % 3 == 0),
            'Incomplete per-type triples (necessary, not proof of solvability)');
        final layers = level.tiles.map((t) => t.layer).toSet().toList()..sort();
        check(
            layers.isNotEmpty &&
                List.generate(layers.length, (i) => i).toString() ==
                    layers.toString(),
            'Layers must be contiguous from zero');
        final objective = level.objective;
        if (objective != null) {
          check(catalog.containsKey(objective.type), 'Unknown objective type');
          check(
              objective.target > 0 &&
                  objective.target <=
                      ((inventory[objective.type] ?? 0) ~/ 3) * 3,
              'Objective cannot be reached by matched tiles');
        }

        final world = (id - 1) ~/ 10;
        final pattern = raw['layoutPattern'];
        check(pattern == BoardLayouts.forLevel(id).name,
            'Pattern is inconsistent with the world/stage authoring policy');
        patterns.putIfAbsent(world, () => {}).add('$pattern');
        final coords =
            level.tiles.map((t) => '${t.layer}:${t.x}:${t.y}').toList()..sort();
        signatures.putIfAbsent(world, () => {}).add(coords.join('|'));
        // The generator's main() writes assets; never invoke it in QA. Call
        // only its pure layout and inventory helpers and compare read-only.
        final authored = BoardLayouts.compose(
            tileCount: level.tiles.length,
            layerCount: layers.length,
            pattern: BoardLayouts.forLevel(id),
            seed: id);
        final authoredTypes = clearableTileOrder(level.tiles.map((t) => t.type),
            random: Random(7919 * id),
            difficulty: id <= 10
                ? 2
                : id <= 30
                    ? 3
                    : 4);
        check(
            List.generate(level.tiles.length, (i) {
              final t = level.tiles[i];
              final p = authored[i];
              return t.x == p.x &&
                  t.y == p.y &&
                  t.layer == p.layer &&
                  t.type == authoredTypes[level.tiles.length - 1 - i];
            }).every((v) => v),
            'Asset differs from current deterministic authoring recipe');

        final geometryRows = <Map<String, Object?>>[];
        for (final screen in qaScreens) {
          final geometry = screen.geometry();
          final engine = GameEngine(level.tiles)
            ..updateBoardGeometry(geometry.board, geometry.tile);
          final ordered = engine.renderedBoardTiles;
          var sameLayer = 0;
          var crossLayer = 0;
          var uncovered = 0;
          for (var i = 0; i < ordered.length; i++) {
            final t = ordered[i];
            final rect = t.boardRect(geometry.board, geometry.tile);
            // The frame's border is outside the logical canvas. Assert tile
            // bounds against that canvas, which the widget suite also measures.
            check(
                rect.left >= 0 &&
                    rect.top >= 0 &&
                    rect.right <= geometry.board.width + 1e-6 &&
                    rect.bottom <= geometry.board.height + 1e-6,
                '${screen.name}: tile outside inner Stack: ${t.id}');
            var covered = false;
            for (var j = i + 1; j < ordered.length; j++) {
              if (!t.overlaps(ordered[j], geometry.board, geometry.tile)) {
                continue;
              }
              covered = true;
              if (t.layer == ordered[j].layer) {
                sameLayer++;
              } else {
                crossLayer++;
              }
            }
            check(engine.isTileCovered(t) == covered,
                '${screen.name}: engine/paint-order coverage mismatch ${t.id}');
            if (!covered) uncovered++;
          }
          check(uncovered > 0, '${screen.name}: no selectable initial tile');
          final solution = const BoardSolver().solve(
              level.tiles, geometry.board, geometry.tile,
              objective: objective);
          if (solution.status == SolveStatus.unsolvable) {
            issues.add('${screen.name}: UNSOLVABLE: ${solution.reason}');
          }
          geometryRows.add({
            'screen': screen.name,
            'uncovered': uncovered,
            'sameLayerOverlapEdges': sameLayer,
            'crossLayerOverlapEdges': crossLayer,
            'solver': solution.toJson(),
          });
        }
        row.addAll({
          'tiles': level.tiles.length,
          'layers': layers.length,
          'pattern': pattern,
          'screens': geometryRows
        });
      } catch (error, stack) {
        issues.add('Parsing/audit exception: $error');
        row['exception'] = stack.toString();
      }
      row['issues'] = issues;
      final unknown = (row['screens'] as List<Map<String, Object?>>? ?? []).any(
          (r) => (r['solver'] as Map<String, Object>)['status'] == 'UNKNOWN');
      row['status'] = issues.isNotEmpty
          ? 'FAIL'
          : unknown
              ? 'UNKNOWN'
              : 'PASS';
      rows.add(row);
      problems.addAll(issues.map((s) => 'L$id: $s'));
    }
    for (var world = 0; world < 10; world++) {
      final expected =
          BoardLayouts.worldPatterns[world].map((p) => p.name).toSet();
      if (patterns[world]?.containsAll(expected) != true ||
          (signatures[world]?.length ?? 0) < expected.length) {
        problems
            .add('World ${world + 1}: insufficient pattern/coordinate variety');
      }
    }
    final output = Directory('qa/results')..createSync(recursive: true);
    File('${output.path}/campaign.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'createdUtc': DateTime.now().toUtc().toIso8601String(),
        'scope': 'Read-only current working tree; taps only, no boosters',
        'solverMaxNodes': 50000,
        'solverMilliseconds': 500,
        'problems': problems,
        'levels': rows,
      }),
    );
    File('${output.path}/campaign.md').writeAsStringSync([
      '# Campaign QA results',
      '',
      'Generated from this run. PASS includes an engine-replayed solution.',
      '',
      '| Level | Status | Tiles | Pattern | Solver by screen | Issues |',
      '|---|---|---|---|---|---|',
      for (final r in rows)
        '| ${r['level']} | ${r['status']} | ${r['tiles'] ?? '?'} | ${r['pattern'] ?? '?'} | '
            '${(r['screens'] as List<Map<String, Object?>>? ?? []).map((s) => '${s['screen']}: ${(s['solver'] as Map)['status']}').join('<br>')} | '
            '${(r['issues'] as List).join('; ').replaceAll('|', '/')} |',
      '',
      ...problems,
    ].join('\n'));
    // UNKNOWN is retained separately and does not masquerade as a proof or a
    // defect. Proven invalid/unsolvable levels fail the check.
    expect(problems, isEmpty, reason: 'See qa/results/campaign.json');
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('production rootBundle repository loads all 100 campaign assets',
      () async {
    final repository = LevelRepository();
    for (var id = 1; id <= LevelRepository.levelCount; id++) {
      final level = await repository.loadLevel(id);
      expect(level.level, id, reason: 'Bundled asset L$id');
      expect(level.tiles, isNotEmpty);
    }
  });

  test('each world retains five ordinary patterns and a reserved unique boss',
      () {
    expect(LevelRepository.levelCount, 100);
    expect(BoardLayouts.worldPatterns.length, 10);
    final bosses = <BoardPattern>{};
    for (var world = 0; world < 10; world++) {
      final pool = BoardLayouts.worldPatterns[world];
      expect(pool.length, 6, reason: 'World ${world + 1}');
      expect(pool.toSet().length, 6);
      bosses.add(pool.last);
      for (var stage = 1; stage <= 9; stage++) {
        expect(BoardLayouts.forLevel(world * 10 + stage), isNot(pool.last));
      }
      expect(BoardLayouts.forLevel((world + 1) * 10), pool.last);
    }
    expect(bosses.length, 10);
  });

  test('boss definitions cover exactly the ten world finales', () {
    // Boss metadata is private UI data, not JSON. Limit this source contract to
    // that class; widget tests additionally check each rendered boss title.
    final source =
        File('lib/presentation/screens/game_screen.dart').readAsStringSync();
    final boss = source
        .split('class _BossLevelInfo {')
        .last
        .split('class _BossCompleteDialog')
        .first;
    final ids = RegExp(r'case (\d+):')
        .allMatches(boss)
        .map((m) => int.parse(m.group(1)!))
        .toList();
    expect(ids, List.generate(10, (i) => (i + 1) * 10));
    final definitions = RegExp(r'level: (\d+),')
        .allMatches(boss)
        .map((m) => int.parse(m.group(1)!))
        .toList();
    expect(definitions, ids);
  });
}
