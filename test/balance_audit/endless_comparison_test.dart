// Explicit local measurement. Keeps the completed audit reports untouched.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/domain/endless_board_generator.dart';
import 'package:triple_tile_adventure/domain/endless_difficulty.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import '../qa/support/geometry.dart';
import '../qa/support/pre_progression_endless_generator.dart';
import 'support/balance_metrics.dart';

Json _measure(List<Tile> tiles, QaGeometry geometry) => {
      'tile_count': tiles.length,
      'layer_count': tiles.map((t) => t.layer).toSet().length,
      'type_distribution': inventory(tiles),
      ...auditBoard(tiles, geometry, SearchBudget(0, 0)),
    };

String _identity(List<Tile> tiles) => jsonEncode([
      for (final t in tiles) [t.id, t.type, t.x, t.y, t.layer, t.state.name],
    ]);

String _number(Object? value) =>
    value is num ? value.toStringAsFixed(2) : 'UNKNOWN';

void main() {
  test('compare original, measured first pass and refined Endless boards', () {
    // This file is the immutable local measurement from the first pass. Keep
    // it in place; this runner writes new refinement outputs below.
    final firstPassFile = File('qa/endless_progression_results.json');
    if (!firstPassFile.existsSync()) {
      throw StateError('First-pass measurement missing: ${firstPassFile.path}');
    }
    final firstPass =
        jsonDecode(firstPassFile.readAsStringSync()) as Map<String, dynamic>;
    if (firstPass['status'] != 'PASS') {
      throw StateError('First-pass measurement is not PASS');
    }
    String sampleKey(
            Object? mode, Object? round, Object? seed, Object? screen) =>
        '$mode/$round/$seed/$screen';
    final measuredRows = <String, Map<String, dynamic>>{
      for (final row
          in (firstPass['samples'] as List).cast<Map<String, dynamic>>())
        sampleKey(row['seed_mode'], row['round'], row['seed'], row['screen']):
            row,
    };
    if (measuredRows.length != (firstPass['samples'] as List).length) {
      throw StateError('First-pass sample keys are not unique');
    }
    final rows = <Json>[];
    final issues = <String>[];
    final markdown =
        StringBuffer('''# Endless progression — local refinement measurements

Original: frozen pre_progression_endless_generator.dart (already booster-free).
First pass: saved qa/endless_progression_results.json, never overwritten here.
Refined: current EndlessBoardGenerator, measured with the same auditBoard rules.
Fresh generators use the same seed/theme; continuous runs use the same sequence.
Scores are diagnostic proxies, not measured human difficulty or optimal play.
Both favourable and unfavourable deltas are retained; UNKNOWN is not proof.

Values run original → first pass → refinement.

| Mode | Round | Seed | Screen | Tiles | Types | Available | Chain | Cross-layer edges | Same-layer edges | Tray peak | Mean choices | Score | Solver |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
''');

    void compare(
        int round,
        int seed,
        String mode,
        TileVisualTheme theme,
        List<Tile> oldTiles,
        List<Tile> newTiles,
        List<Tile> repeatedOld,
        List<Tile> repeatedNew) {
      final oldDeterministic = _identity(oldTiles) == _identity(repeatedOld);
      final newDeterministic = _identity(newTiles) == _identity(repeatedNew);
      if (!oldDeterministic || !newDeterministic) {
        issues.add('$mode/$round/$seed: seeded run did not reproduce');
      }
      if (round <= 13 && _identity(oldTiles) != _identity(newTiles)) {
        issues.add('$mode/$round/$seed: early board changed');
      }
      for (final screen in qaScreens) {
        final g = screen.geometry(endless: true);
        final before = _measure(oldTiles, g);
        final after = _measure(newTiles, g);
        final oldGeometry = before['geometry'] as Map;
        final geometry = after['geometry'] as Map;
        final oldWitness = before['witness_metrics'] as Map?;
        final witness = after['witness_metrics'] as Map?;
        final oldSolver = before['solver'] as Map;
        final solver = after['solver'] as Map;
        final key = '$mode/$round/$seed/${screen.name}';
        final measured = measuredRows[key];
        if (measured == null) {
          issues.add('$key: first-pass sample missing');
          continue;
        }
        final measuredBefore = measured['before'] as Map<String, dynamic>;
        final measuredAfter = measured['after'] as Map<String, dynamic>;
        final measuredGeometry = measuredAfter['geometry'] as Map;
        final measuredWitness = measuredAfter['witness_metrics'] as Map?;
        final measuredSolver = measuredAfter['solver'] as Map;
        if (before['tile_count'] != measuredBefore['tile_count'] ||
            before['layer_count'] != measuredBefore['layer_count'] ||
            jsonEncode(before['type_distribution']) !=
                jsonEncode(measuredBefore['type_distribution']) ||
            (before['difficulty_score'] as num).toDouble() !=
                (measuredBefore['difficulty_score'] as num).toDouble()) {
          issues
              .add('$key: frozen original no longer matches measured baseline');
        }
        for (final entry in {'before': before, 'after': after}.entries) {
          final result = entry.value['solver'] as Map;
          if (result['status'] != 'SOLVED' ||
              result['witness_replay_passed'] != true) {
            issues.add(
                '$key/${entry.key}: ${result['status']} ${result['reason']}');
          }
          for (final issue in entry.value['issues'] as List) {
            issues.add('$key/${entry.key}: $issue');
          }
        }
        final p = round >= 14 ? EndlessDifficulty.forRound(round) : null;
        if (p != null) {
          if (geometry['same_layer_blocking_edges'] != 0 ||
              (geometry['max_blocker_chain_tiles'] as int) > p.maxLayers ||
              (geometry['maximum_coincident_rectangle_depth'] as int) >
                  p.maxLayers ||
              (geometry['initial_playable'] as int) < p.topTiles) {
            issues.add('$key: readability contract failed');
          }
        }
        rows.add({
          'round': round,
          'seed': seed,
          'seed_mode': mode,
          'world': theme.name,
          'screen': screen.name,
          'stage': p?.stage,
          'kind': p?.kind.name ?? 'unchanged_early',
          'layout': p?.layout.name,
          'before_deterministic': oldDeterministic,
          'after_deterministic': newDeterministic,
          'early_exact_match':
              round <= 13 ? _identity(oldTiles) == _identity(newTiles) : null,
          'before': before,
          'first_pass': measuredAfter,
          'after': after,
          'score_delta_vs_original': before['difficulty_score'] is num &&
                  after['difficulty_score'] is num
              ? (after['difficulty_score'] as num) -
                  (before['difficulty_score'] as num)
              : null,
          'score_delta_vs_first_pass':
              measuredAfter['difficulty_score'] is num &&
                      after['difficulty_score'] is num
                  ? (after['difficulty_score'] as num) -
                      (measuredAfter['difficulty_score'] as num)
                  : null,
        });
        markdown.writeln('| $mode | $round | $seed | ${screen.name} | '
            '${oldTiles.length} → ${measuredAfter['tile_count']} → ${newTiles.length} | '
            '${inventory(oldTiles).length} → ${(measuredAfter['type_distribution'] as Map).length} → ${inventory(newTiles).length} | '
            '${oldGeometry['initial_playable']} → ${measuredGeometry['initial_playable']} → ${geometry['initial_playable']} | '
            '${oldGeometry['max_blocker_chain_tiles']} → ${measuredGeometry['max_blocker_chain_tiles']} → ${geometry['max_blocker_chain_tiles']} | '
            '${oldGeometry['cross_layer_blocking_edges']} → ${measuredGeometry['cross_layer_blocking_edges']} → ${geometry['cross_layer_blocking_edges']} | '
            '${oldGeometry['same_layer_blocking_edges']} → ${measuredGeometry['same_layer_blocking_edges']} → ${geometry['same_layer_blocking_edges']} | '
            '${oldWitness?['peak_tray_after_resolution']} → ${measuredWitness?['peak_tray_after_resolution']} → ${witness?['peak_tray_after_resolution']} | '
            '${_number(oldWitness?['mean_legal_choices'])} → ${_number(measuredWitness?['mean_legal_choices'])} → ${_number(witness?['mean_legal_choices'])} | '
            '${_number(before['difficulty_score'])} → ${_number(measuredAfter['difficulty_score'])} → ${_number(after['difficulty_score'])} | '
            '${oldSolver['status']} → ${measuredSolver['status']} → ${solver['status']} |');
      }
    }

    const rounds = [
      8,
      12,
      13,
      14,
      15,
      20,
      21,
      26,
      30,
      31,
      50,
      51,
      52,
      75,
      76,
      100,
      101
    ];
    for (final seed in [0, 1, 42, 2147483647]) {
      for (final round in rounds) {
        compare(
            round,
            seed,
            'fresh',
            TileVisualTheme.garden,
            PreProgressionEndlessBoardGenerator(random: Random(seed))
                .generate(round: round, theme: TileVisualTheme.garden),
            EndlessBoardGenerator(random: Random(seed))
                .generate(round: round, theme: TileVisualTheme.garden),
            PreProgressionEndlessBoardGenerator(random: Random(seed))
                .generate(round: round, theme: TileVisualTheme.garden),
            EndlessBoardGenerator(random: Random(seed))
                .generate(round: round, theme: TileVisualTheme.garden));
      }
    }
    for (final seed in [0, 42]) {
      final old = PreProgressionEndlessBoardGenerator(random: Random(seed));
      final current = EndlessBoardGenerator(random: Random(seed));
      final repeatedOld =
          PreProgressionEndlessBoardGenerator(random: Random(seed));
      final repeatedCurrent = EndlessBoardGenerator(random: Random(seed));
      for (var round = 1; round <= 101; round++) {
        final theme = TileVisualTheme.values[((round - 1) ~/ 3) % 10];
        final a = old.generate(round: round, theme: theme);
        final b = current.generate(round: round, theme: theme);
        final repeatedA = repeatedOld.generate(round: round, theme: theme);
        final repeatedB = repeatedCurrent.generate(round: round, theme: theme);
        if (rounds.contains(round)) {
          compare(round, seed, 'continuous', theme, a, b, repeatedA, repeatedB);
        }
      }
    }
    // Write all outcomes before asserting, including failures and UNKNOWN.
    final status = issues.isEmpty ? 'PASS' : 'FAIL';
    File('qa/endless_refinement_results.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
            'created_utc': DateTime.now().toUtc().toIso8601String(),
            'dart_runtime': Platform.version,
            'first_pass_source': firstPassFile.path,
            'first_pass_created_utc': firstPass['created_utc'],
            'status': status,
            'samples': rows,
            'issues': issues,
          })}\n',
    );
    markdown.writeln('\nOutcome: $status');
    for (final issue in issues) {
      markdown.writeln('- $issue');
    }
    File('qa/endless_refinement_results.md')
        .writeAsStringSync(markdown.toString());
    expect(rows, hasLength(rounds.length * 6 * qaScreens.length));
    expect(issues, isEmpty, reason: issues.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 30)));
}
