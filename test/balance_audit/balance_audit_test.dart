// Explicit local report-generation entry point. Outside test/qa intentionally.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/domain/board_layout.dart';
import 'package:triple_tile_adventure/domain/endless_board_generator.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import '../qa/support/geometry.dart';
import 'support/balance_metrics.dart';

const worldNames = ['garden', 'ocean', 'candy', 'space', 'desert', 'ice',
  'jungle', 'volcano', 'dream', 'crystal'];
const boundaryRounds = [
  1, 3, 4, 7, 8, 12, 13, 14, 15, 20, 21, 24, 25, 26,
  30, 31, 49, 50, 51, 52, 74, 75, 76, 100, 101,
];
const seeds = [0, 1, 42, 2147483647];
const beginMarker = '<!-- BALANCE_MEASUREMENTS_BEGIN -->';
const endMarker = '<!-- BALANCE_MEASUREMENTS_END -->';

int setting(String key, int fallback, int maximum) {
  final raw = Platform.environment[key];
  final value = raw == null ? fallback : int.parse(raw);
  if (value < 0 || value > maximum) throw ArgumentError('$key must be 0..$maximum');
  return value;
}

// Dependency-free reproducibility fingerprint, NOT a cryptographic hash.
String fingerprint(String text) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(text)) { hash = ((hash ^ byte) * 0x01000193) & 0xffffffff; }
  return hash.toRadixString(16).padLeft(8, '0');
}

String identity(List<Tile> tiles) => jsonEncode([
  for (final t in tiles) [t.id, t.type, t.x, t.y, t.layer, t.state.name],
]);
String shape(List<Tile> tiles) => jsonEncode([
  for (final t in tiles) [t.x, t.y, t.layer],
]);

void writeJson(String path, Json data) => File(path).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(data)}\n');

Json inputManifest() {
  final paths = <String>[
    'pubspec.yaml', 'pubspec.lock', 'tool/generate_mixed_level_layouts.dart',
    for (final root in ['assets/levels', 'lib', 'test/qa', 'test/balance_audit'])
      ...Directory(root).listSync(recursive: true).whereType<File>()
          .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.json'))
          .map((f) => f.path.replaceAll('\\', '/')),
  ]..sort();
  return {for (final path in paths) path: {
    'fnv1a32_utf8': fingerprint(File(path).readAsStringSync()),
    'bytes': File(path).lengthSync(),
  }};
}

Json describe(List<Tile> tiles, TileVisualTheme theme, SearchBudget budget,
    {LevelObjective? objective, bool endless = false}) {
  final issues = <String>[];
  final catalog = tileCatalogForTheme(theme);
  for (final t in tiles) {
    if (t.id.isEmpty || !catalog.containsKey(t.type)) issues.add('INVALID_ID_OR_TYPE:${t.id}');
  }
  if (objective != null && (objective.target <= 0 || !catalog.containsKey(objective.type))) {
    issues.add('INVALID_OBJECTIVE');
  }
  final screens = <Json>[];
  for (final screen in qaScreens) {
    try {
      screens.add({'screen': screen.name,
        ...auditBoard(tiles, screen.geometry(endless: endless), budget, objective: objective)});
    } catch (error) {
      screens.add({'screen': screen.name, 'solver': {'status': 'UNKNOWN'},
        'difficulty_score': null, 'issues': ['AUDIT_ERROR:$error']});
    }
  }
  for (final screen in screens) {
    issues.addAll((screen['issues'] as List).map((s) => '${screen['screen']}:$s'));
  }
  final statuses = screens.map((s) => (s['solver'] as Map)['status']).toSet();
  final scores = screens.map((s) => s['difficulty_score']).whereType<double>().toList();
  return {
    'tile_count': tiles.length, 'tile_type_count': inventory(tiles).length,
    'initial_type_distribution': inventory(tiles),
    'layer_count': tiles.map((t) => t.layer).toSet().length,
    'objective': objective == null ? null : {'type': objective.type, 'target': objective.target},
    'shape_fingerprint_fnv1a32': fingerprint(shape(tiles)),
    'tile_fingerprint_fnv1a32': fingerprint(identity(tiles)),
    'solver_status': statuses.contains('UNSOLVABLE') ? 'UNSOLVABLE' :
        statuses.length == 1 && statuses.contains('SOLVED') ? 'SOLVED' : 'UNKNOWN',
    'screens': screens,
    'difficulty_score': scores.length == qaScreens.length ? scores.reduce(max) : null,
    'difficulty_explanation': 'Maximum per-screen heuristic score; null if any screen lacks a verified witness. Inspect the six weighted terms and witness traces.',
    'identified_problems': issues,
    'recommended_action': issues.isNotEmpty
        ? 'Investigate listed issues before any rebalance; UNKNOWN is inconclusive.'
        : 'Review score, choice availability and tray pressure with human playtests; preserve the verified booster-free witness.',
  };
}

double? score(Json row) => row['difficulty_score'] as double?;

Json curveSummary(List<Json> rows) {
  final measured = rows.where((r) => score(r) != null).toList()
    ..sort((a, b) => score(b)!.compareTo(score(a)!));
  final adjacent = <Json>[];
  for (var i = 1; i < rows.length; i++) {
    final a = score(rows[i - 1]);
    final b = score(rows[i]);
    if (a == null || b == null) continue;
    adjacent.add({'from': rows[i - 1]['level'], 'to': rows[i]['level'],
      'delta': b - a, 'world_transition': i % 10 == 0,
      'review': b - a >= 10 ? 'SPIKE' : a - b >= 10 ? 'DROP' : 'WITHIN_HEURISTIC_BAND'});
  }
  final flat = <Json>[];
  for (var i = 0; i + 3 < rows.length; i++) {
    final window = rows.sublist(i, i + 4).map(score).whereType<double>().toList();
    if (window.length == 4 && window.reduce(max) - window.reduce(min) <= 3) {
      flat.add({'from': rows[i]['level'], 'through': rows[i + 3]['level'],
        'score_range': window.reduce(max) - window.reduce(min)});
    }
  }
  final worlds = <Json>[];
  final bosses = <Json>[];
  for (var world = 0; world < 10; world++) {
    final group = rows.sublist(world * 10, world * 10 + 10);
    final scores = group.map(score).whereType<double>().toList();
    final patterns = group.map((r) => r['layout_pattern']).whereType<String>().toSet();
    worlds.add({'world': worldNames[world], 'levels': group.map((r) => r['level']).toList(),
      'mean_score': scores.length == 10 ? scores.reduce((a, b) => a + b) / 10 : null,
      'score_min': scores.isEmpty ? null : scores.reduce(min),
      'score_max': scores.isEmpty ? null : scores.reduce(max),
      'measured_scores': scores.length, 'pattern_count': patterns.length,
      'solved': group.where((r) => r['solver_status'] == 'SOLVED').length});
    final boss = group.last;
    final neighbors = group.sublist(6, 9).map(score).whereType<double>().toList();
    final bossScore = score(boss);
    final previousBoss = world == 0 ? null : score(rows[world * 10 - 1]);
    bosses.add({'level': boss['level'], 'world': worldNames[world],
      'pattern': boss['layout_pattern'], 'solver_status': boss['solver_status'],
      'score': bossScore,
      'delta_from_previous_three_mean': bossScore != null && neighbors.length == 3
          ? bossScore - neighbors.reduce((a, b) => a + b) / 3 : null,
      'delta_from_previous_boss': bossScore != null && previousBoss != null ? bossScore - previousBoss : null});
  }
  return {'worlds': worlds, 'bosses': bosses, 'adjacent_levels': adjacent,
    'near_flat_four_level_windows': flat,
    'highest_heuristic_scores': [for (final r in measured.take(10))
      {'level': r['level'], 'world': r['world'], 'score': score(r)}],
    'investigate': [for (final r in rows)
      if ((r['identified_problems'] as List).isNotEmpty)
        {'level': r['level'], 'issues': r['identified_problems']}],
  };
}

void updateMarkdown(Json summary, List<Json> endless, SearchBudget budget) {
  final file = File('qa/BALANCE_AUDIT.md');
  final original = file.readAsStringSync();
  if (!original.contains(beginMarker) || !original.contains(endMarker)) {
    throw StateError('BALANCE_AUDIT.md measurement markers missing');
  }
  String value(Object? v) => v is double ? v.toStringAsFixed(2) : '${v ?? 'NOT MEASURED'}';
  final lines = <String>['', '### Local generated measurements', '',
    'Generated by the explicit balance audit. Scores are heuristic, not measured human difficulty.',
    'Search nodes consumed: ${budget.spent}/${budget.total}. Exact paths and statistics are in the JSON files.', '',
    '| World | Solved levels (all screens) | Mean score | Score range | Patterns |',
    '|---|---:|---:|---|---:|',
    for (final w in summary['worlds'] as List<Json>)
      '| ${w['world']} | ${w['solved']}/10 | ${value(w['mean_score'])} | ${value(w['score_min'])}–${value(w['score_max'])} | ${w['pattern_count']} |',
    '', '| Boss | Status | Score | Delta from preceding 3 | Delta from previous boss |',
    '|---|---|---:|---:|---:|',
    for (final b in summary['bosses'] as List<Json>)
      '| ${b['level']} | ${b['solver_status']} | ${value(b['score'])} | ${value(b['delta_from_previous_three_mean'])} | ${value(b['delta_from_previous_boss'])} |',
    '', '| Highest heuristic score | World | Score |', '|---|---|---:|',
    for (final r in summary['highest_heuristic_scores'] as List<Json>)
      '| ${r['level']} | ${r['world']} | ${value(r['score'])} |',
    '', '| Adjacent review candidate | Delta | Classification |', '|---|---:|---|',
    for (final r in summary['adjacent_levels'] as List<Json>)
      if (r['review'] != 'WITHIN_HEURISTIC_BAND' || r['world_transition'] == true)
        '| ${r['from']} → ${r['to']} | ${value(r['delta'])} | ${r['review']}${r['world_transition'] == true ? '; world boundary' : ''} |',
    '', '| Additional investigation | Findings |', '|---|---|',
    for (final r in summary['investigate'] as List<Json>)
      '| ${r['level']} | ${(r['issues'] as List).join('; ').replaceAll('|', '/')} |',
    '', 'Near-flat windows (heuristic range ≤3 over four levels): `${jsonEncode(summary['near_flat_four_level_windows'])}`.',
    '', 'Endless boards measured: ${endless.length}; SOLVED on all screens: ${endless.where((r) => r['solver_status'] == 'SOLVED').length}.',
    'The JSON distinguishes fresh-seed cases from continuous seeded runs and records reproducibility failures.', '',
  ];
  final start = original.indexOf(beginMarker) + beginMarker.length;
  final end = original.indexOf(endMarker, start);
  file.writeAsStringSync(original.substring(0, start) + lines.join('\n') + original.substring(end));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('prepare complete bounded campaign and Endless balance measurements', () {
    final budget = SearchBudget(setting('BALANCE_MAX_NODES', 0, 50000),
        setting('BALANCE_TOTAL_NODES', 200000, 1000000));
    final initialInputs = inputManifest();
    final metadata = <String, Object?>{
      'schema_version': 1, 'created_utc': DateTime.now().toUtc().toIso8601String(),
      'dart_runtime': Platform.version, 'inputs': initialInputs,
      'fingerprint_algorithm': 'FNV-1a32 of UTF-8 text, non-cryptographic',
      'max_nodes_per_board': budget.perBoard, 'max_nodes_entire_run': budget.total,
      'solver_policy': 'Existing BoardSolver; candidate replay then optional bounded DFS. Zero DFS nodes by default. UNKNOWN is never relabelled UNSOLVABLE.',
      'no_boosters': true,
    };
    final campaign = <Json>[];
    final endless = <Json>[];
    writeJson('qa/balance_campaign.json', {...metadata, 'status': 'RUNNING', 'levels': campaign});
    writeJson('qa/balance_endless.json', {...metadata, 'status': 'RUNNING', 'samples': endless});
    final globalIds = <String>{};
    for (var id = 1; id <= 100; id++) {
      final row = <String, Object?>{'level': id, 'world': worldNames[(id - 1) ~/ 10], 'boss': id % 10 == 0};
      try {
        final path = 'assets/levels/level_${id.toString().padLeft(2, '0')}.json';
        final raw = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
        final level = LevelDefinition.fromJson(raw);
        row.addAll({'asset': path, 'layout_pattern': raw['layoutPattern'],
          'time_bonus_metadata_seconds': level.timeBonusSeconds,
          ...describe(level.tiles, tileVisualThemeForLevel(id), budget, objective: level.objective)});
        final issues = row['identified_problems'] as List<String>;
        if (level.level != id) issues.add('ASSET_LEVEL_ID_MISMATCH');
        if (raw['layoutPattern'] != BoardLayouts.forLevel(id).name) issues.add('PATTERN_METADATA_DIFFERS_FROM_AUTHORING_PLAN');
        for (final tile in level.tiles) {
          if (!globalIds.add(tile.id)) issues.add('GLOBAL_DUPLICATE_TILE_ID:${tile.id}');
        }
      } catch (error) {
        row.addAll({'solver_status': 'UNKNOWN', 'difficulty_score': null,
          'identified_problems': ['ASSET_AUDIT_ERROR:$error'],
          'recommended_action': 'Repair audit input/exception before making balance claims.'});
      }
      campaign.add(row);
      writeJson('qa/balance_campaign.json', {...metadata, 'status': 'RUNNING', 'levels': campaign});
    }
    void sample(int round, int seed, TileVisualTheme theme, String mode,
        List<Tile> tiles, List<Tile> repeated) {
      final row = <String, Object?>{'round': round, 'seed': seed, 'world': theme.name,
        'seed_mode': mode, 'deterministic_reproduction': identity(tiles) == identity(repeated),
        ...describe(tiles, theme, budget, endless: true)};
      if (row['deterministic_reproduction'] != true) {
        (row['identified_problems'] as List<String>).add('NONDETERMINISTIC_SEEDED_OUTPUT');
      }
      endless.add(row);
      writeJson('qa/balance_endless.json', {...metadata, 'status': 'RUNNING', 'samples': endless});
    }
    for (final theme in TileVisualTheme.values) {
      final rounds = theme == TileVisualTheme.garden
          ? boundaryRounds : [1, 4, 8, 13, 20, 30, 50, 75, 100];
      final selectedSeeds = theme == TileVisualTheme.garden ? seeds : [0];
      for (final round in rounds) {
        for (final seed in selectedSeeds) {
          sample(round, seed, theme, 'fresh_generator_for_this_round',
            EndlessBoardGenerator(random: Random(seed)).generate(round: round, theme: theme),
            EndlessBoardGenerator(random: Random(seed)).generate(round: round, theme: theme));
        }
      }
    }
    for (final seed in [0, 42]) {
      final generator = EndlessBoardGenerator(random: Random(seed));
      final repeat = EndlessBoardGenerator(random: Random(seed));
      for (var round = 1; round <= 101; round++) {
        final theme = TileVisualTheme.values[((round - 1) ~/ 3) % 10];
        final tiles = generator.generate(round: round, theme: theme);
        final repeated = repeat.generate(round: round, theme: theme);
        if (boundaryRounds.contains(round)) sample(round, seed, theme,
            'continuous_rounds_1_to_101_default_theme_cycle', tiles, repeated);
      }
    }
    final summary = curveSummary(campaign);
    final inputsUnchanged = jsonEncode(initialInputs) == jsonEncode(inputManifest());
    final complete = {...metadata, 'status': inputsUnchanged ? 'MEASURED' : 'INVALIDATED_INPUTS_CHANGED',
      'nodes_spent': budget.spent, 'inputs_unchanged_during_run': inputsUnchanged};
    final shapeGroups = <String, List<String>>{};
    for (final row in endless) {
      shapeGroups.putIfAbsent(row['shape_fingerprint_fnv1a32'] as String, () => []).add(
        '${row['seed_mode']}/${row['world']}/r${row['round']}/s${row['seed']}');
    }
    writeJson('qa/balance_campaign.json', {...complete, 'levels': campaign, 'summary': summary});
    writeJson('qa/balance_endless.json', {...complete, 'samples': endless,
      'repeated_shape_fingerprints': {for (final e in shapeGroups.entries) if (e.value.length > 1) e.key: e.value},
      'repetition_caveat': 'Equal coordinates across fresh seeds/themes may be intentional palette reuse. FNV equality is a candidate, not cryptographic proof.',
      'unmeasured': ['Human win rates', 'All possible seeds', 'Non-immediate dead-end frequency', 'SDK-independent Random sequence stability'],
    });
    if (inputsUnchanged) updateMarkdown(summary, endless, budget);
    final problems = [...campaign, ...endless].expand((r) =>
        (r['identified_problems'] as List).where((s) => !s.toString().endsWith('SOLVABILITY_INCONCLUSIVE'))).toList();
    // Reports survive failures. UNKNOWN is disclosed, never hidden as a proof.
    expect(inputsUnchanged, isTrue, reason: 'Inputs changed; rerun on a stable tree');
    expect(problems, isEmpty, reason: 'See qa/balance_campaign.json and qa/balance_endless.json');
  }, timeout: const Timeout(Duration(minutes: 30)));
}
