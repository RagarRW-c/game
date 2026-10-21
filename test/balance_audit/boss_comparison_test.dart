// Explicit local measurement entry point. Does not overwrite the original audit.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/level.dart';

import '../qa/support/boss_balance_expectations.dart';
import '../qa/support/geometry.dart';
import 'support/balance_metrics.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

double? _worst(List<Json> screens) {
  final scores = screens.map((s) => s['difficulty_score'] as num?).toList();
  return scores.any((score) => score == null)
      ? null : scores.map((score) => score!.toDouble()).reduce(math.max);
}

double? _mean(List<double?> values) => values.any((v) => v == null)
    ? null : values.fold<double>(0, (sum, v) => sum + v!) / values.length;
double? _delta(double? a, double? b) => a == null || b == null ? null : a - b;
String _number(num? value) => value?.toStringAsFixed(2) ?? 'UNKNOWN';

void main() {
  test('compare all bosses, preceding three levels and previous bosses', () {
    final baseline = _read('test/qa/fixtures/boss_balance_before.json');
    final beforeRows = (baseline['context_levels'] as List).cast<Map<String, dynamic>>();
    final afterRows = <int, Json>{};
    final issues = <String>[];
    final detail = StringBuffer('''
## Geometry and witness metrics

All values below are before → after. Context normal levels are measured too.

| Level | Screen | Available | Chain | Retained tray peak | Score | Solver |
|---|---|---|---|---|---|---|
''');
    for (final before in beforeRows) {
      final id = before['level'] as int;
      final path = before['asset'] as String;
      final raw = _read(path);
      final level = LevelDefinition.fromJson(raw);
      final screens = <Json>[];
      for (final screen in qaScreens) {
        final old = (before['screens'] as List).cast<Map<String, dynamic>>()
            .singleWhere((s) => s['screen'] == screen.name);
        final after = auditBoard(level.tiles, screen.geometry(), SearchBudget(0, 0),
            objective: level.objective);
        screens.add({'screen': screen.name, ...after});
        final geometry = after['geometry'] as Map;
        final solver = after['solver'] as Map;
        final witness = after['witness_metrics'] as Map?;
        final prefix = 'L$id / ${screen.name}';
        if (solver['status'] != 'SOLVED' || solver['witness_replay_passed'] != true) {
          issues.add('$prefix: ${solver['status']} — ${solver['reason']}');
        }
        for (final problem in after['issues'] as List) {
          issues.add('$prefix: $problem');
        }
        if (id % 10 == 0) {
          if ((geometry['initial_playable'] as int) < (old['geometry']['initial_playable'] as int)) {
            issues.add('$prefix: fewer legal opening selections');
          }
          if ((geometry['max_blocker_chain_tiles'] as int) > (old['geometry']['max_blocker_chain_tiles'] as int)) {
            issues.add('$prefix: longer maximum blocking chain');
          }
          if (witness != null && witness['peak_tray_after_resolution'] != old['witness_metrics']['peak_tray_after_resolution']) {
            issues.add('$prefix: original witness pressure changed');
          }
        }
        detail.writeln('| $id | ${screen.name} | '
            '${old['geometry']['initial_playable']} → ${geometry['initial_playable']} | '
            '${old['geometry']['max_blocker_chain_tiles']} → ${geometry['max_blocker_chain_tiles']} | '
            '${old['witness_metrics']['peak_tray_after_resolution']} → ${witness?['peak_tray_after_resolution'] ?? 'UNKNOWN'} | '
            '${_number(old['difficulty_score'] as num?)} → ${_number(after['difficulty_score'] as num?)} | ${solver['status']} |');
      }
      afterRows[id] = {
        'level': id, 'asset': path, 'after_asset': raw,
        'screens': screens, 'difficulty_score': _worst(screens),
      };
    }

    final comparisons = <Json>[];
    final markdown = StringBuffer('''# Boss balancing pass 1 — local before/after measurements

Original evidence: ${baseline['measured_utc']}.
This run uses the existing auditBoard metrics and actual GameEngine replay.
Scores are diagnostic proxies, not human difficulty estimates. Positive and
negative deltas are both retained. UNKNOWN is not accepted as solvability proof.
No boosters, ads, purchases or changes to the seven-slot tray.

| Boss | Changed | Score before → after | Delta vs preceding 3 before → after | Delta vs previous boss before → after |
|---|---|---|---|---|
''');
    for (var id = 10; id <= 100; id += 10) {
      final old = beforeRows.singleWhere((r) => r['level'] == id);
      final beforeScore = (old['difficulty_score'] as num).toDouble();
      final afterScore = afterRows[id]!['difficulty_score'] as double?;
      final beforeMean = _mean([
        for (var neighbor = id - 3; neighbor < id; neighbor++)
          (beforeRows.singleWhere((r) => r['level'] == neighbor)['difficulty_score'] as num).toDouble(),
      ]);
      final afterMean = _mean([
        for (var neighbor = id - 3; neighbor < id; neighbor++)
          afterRows[neighbor]!['difficulty_score'] as double?,
      ]);
      final beforePrevious = id == 10 ? null :
          (beforeRows.singleWhere((r) => r['level'] == id - 10)['difficulty_score'] as num).toDouble();
      final afterPrevious = id == 10 ? null : afterRows[id - 10]!['difficulty_score'] as double?;
      final beforeNeighborDelta = _delta(beforeScore, beforeMean);
      final afterNeighborDelta = _delta(afterScore, afterMean);
      final beforeBossDelta = _delta(beforeScore, beforePrevious);
      final afterBossDelta = _delta(afterScore, afterPrevious);
      comparisons.add({
        'level': id, 'changed': bossPass1Coordinates.containsKey(id),
        'score_before': beforeScore, 'score_after': afterScore,
        'delta_preceding_three_before': beforeNeighborDelta,
        'delta_preceding_three_after': afterNeighborDelta,
        'delta_previous_boss_before': beforeBossDelta,
        'delta_previous_boss_after': afterBossDelta,
      });
      markdown.writeln('| $id | ${bossPass1Coordinates.containsKey(id)} | '
          '${_number(beforeScore)} → ${_number(afterScore)} | '
          '${_number(beforeNeighborDelta)} → ${_number(afterNeighborDelta)} | '
          '${id == 10 ? 'N/A' : '${_number(beforeBossDelta)} → ${_number(afterBossDelta)}'} |');
    }
    markdown.write(detail);
    markdown.writeln('\nOutcome: ${issues.isEmpty ? 'PASS' : 'FAIL'}');
    for (final issue in issues) {
      markdown.writeln('- $issue');
    }
    // Persist failures and inconclusive statuses before asserting.
    File('qa/boss_balance_pass_1_results.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({
          'created_utc': DateTime.now().toUtc().toIso8601String(),
          'dart_runtime': Platform.version,
          'baseline': baseline,
          'after_levels': afterRows.values.toList(),
          'boss_comparisons': comparisons,
          'status': issues.isEmpty ? 'PASS' : 'FAIL',
          'issues': issues,
        })}\n');
    File('qa/boss_balance_pass_1_results.md').writeAsStringSync(markdown.toString());
    expect(afterRows, hasLength(40));
    expect(comparisons, hasLength(10));
    expect(issues, isEmpty, reason: issues.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
