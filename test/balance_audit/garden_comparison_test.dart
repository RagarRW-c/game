// Opt-in report generation. Never run automatically by the full QA runner.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/level.dart';

import '../qa/support/geometry.dart';
import 'support/balance_metrics.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('measure Garden pass 1 against the frozen pre-pass evidence', () {
    final baseline = _read('test/qa/fixtures/garden_balance_before.json');
    final rows = <Json>[];
    final problems = <String>[];
    final markdown = StringBuffer('''# Garden balance pass 1 — local comparison

Before: frozen measured audit ${baseline['measured_utc']}.
After: this local run, with actual GameEngine witness replay on each geometry.
Scores are uncalibrated ranking proxies, not human difficulty or win rates.
No boosters. UNKNOWN and UNSOLVABLE are retained and fail this focused check.

| Level | Screen | Playable before → after | Chain before → after | Witness peak before → after | Score before → after | Status |
|---|---|---|---|---|---|---|
''');
    for (final entry in (baseline['levels'] as List).cast<Map<String, dynamic>>()) {
      final beforeAsset = entry['before'] as Map<String, dynamic>;
      final id = beforeAsset['level'] as int;
      final assetPath = 'assets/levels/level_${id.toString().padLeft(2, '0')}.json';
      final asset = _read(assetPath);
      final level = LevelDefinition.fromJson(asset);
      for (final screen in qaScreens) {
        final before = (entry['measured']['screens'] as List)
            .cast<Map<String, dynamic>>()
            .singleWhere((row) => row['screen'] == screen.name);
        final after = auditBoard(level.tiles, screen.geometry(), SearchBudget(0, 0),
            objective: level.objective);
        final oldGeometry = before['geometry'] as Map<String, dynamic>;
        final geometry = after['geometry'] as Map<String, Object?>;
        final solver = after['solver'] as Map<String, Object?>;
        final oldWitness = before['witness_metrics'] as Map<String, dynamic>;
        final witness = after['witness_metrics'] as Map<String, Object?>?;
        final oldScore = (before['difficulty_score'] as num).toDouble();
        final newScore = (after['difficulty_score'] as num?)?.toDouble();
        final prefix = 'L$id / ${screen.name}';
        if (solver['status'] != 'SOLVED' || solver['witness_replay_passed'] != true) {
          problems.add('$prefix: ${solver['status']} — ${solver['reason']}');
        }
        if ((geometry['initial_playable'] as int) <
            (oldGeometry['initial_playable'] as int)) {
          problems.add('$prefix: fewer initially playable tiles');
        }
        if ((geometry['max_blocker_chain_tiles'] as int) >
            (oldGeometry['max_blocker_chain_tiles'] as int)) {
          problems.add('$prefix: longer blocking chain');
        }
        // Scores are diagnostic evidence, not a pass/fail human difficulty
        // target. Retain positive deltas too; never tune or hide the metric.
        for (final issue in after['issues'] as List) {
          problems.add('$prefix: $issue');
        }
        rows.add({
          'level': id,
          'screen': screen.name,
          // Include exact assets so these measurements cannot be mistaken for
          // results of a later edit. The original report remains untouched.
          'before_asset': beforeAsset,
          'after_asset': asset,
          'before': before,
          'after': after,
          'score_delta': newScore == null ? null : newScore - oldScore,
        });
        markdown.writeln('| $id | ${screen.name} | '
            '${oldGeometry['initial_playable']} → ${geometry['initial_playable']} | '
            '${oldGeometry['max_blocker_chain_tiles']} → ${geometry['max_blocker_chain_tiles']} | '
            '${oldWitness['peak_tray_after_resolution']} → ${witness?['peak_tray_after_resolution'] ?? 'UNKNOWN'} | '
            '${oldScore.toStringAsFixed(2)} → ${newScore?.toStringAsFixed(2) ?? 'UNKNOWN'} | '
            '${solver['status']} |');
      }
    }
    markdown.writeln('\nOutcome: ${problems.isEmpty ? 'PASS' : 'FAIL'}');
    for (final problem in problems) {
      markdown.writeln('- $problem');
    }
    final output = <String, Object?>{
      'created_utc': DateTime.now().toUtc().toIso8601String(),
      'dart_runtime': Platform.version,
      'baseline_measured_utc': baseline['measured_utc'],
      'status': problems.isEmpty ? 'PASS' : 'FAIL',
      'problems': problems,
      'screens': rows,
    };
    // Write failures too, before asserting: no hidden UNKNOWN/UNSOLVABLE rows.
    File('qa/garden_balance_pass_1.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(output)}\n');
    File('qa/garden_balance_pass_1_results.md').writeAsStringSync(markdown.toString());
    expect(rows, hasLength(15));
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
