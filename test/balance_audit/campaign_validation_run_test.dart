// Opt-in experiment. A normal flutter test discovery skips this body entirely.
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/level.dart';

import '../qa/support/geometry.dart';
import 'support/campaign_validation.dart';
import 'support/campaign_validation_report.dart';

const _enabled = bool.fromEnvironment('CAMPAIGN_VALIDATE');
const _seedCount = int.fromEnvironment('CAMPAIGN_SEED_COUNT', defaultValue: 10);
const _selected = String.fromEnvironment('CAMPAIGN_LEVELS');

List<int> _behaviorLevels() {
  if (_seedCount < 1 || _seedCount > 10) {
    throw ArgumentError(
        'CAMPAIGN_SEED_COUNT must be 1..10; expansion is not supported.');
  }
  if (_selected.trim().isEmpty) return List.of(campaignPriorityLevels);
  final ids = _selected
      .split(',')
      .map((s) => int.parse(s.trim()))
      .toSet()
      .toList()
    ..sort();
  if (ids.isEmpty || ids.any((id) => !campaignPriorityLevels.contains(id))) {
    throw ArgumentError(
        'CAMPAIGN_LEVELS must be a subset of the documented 24 priority levels.');
  }
  return ids;
}

const _sourceFiles = [
  'pubspec.yaml',
  'pubspec.lock',
  'lib/domain/game_engine.dart',
  'lib/domain/game_result.dart',
  'lib/domain/tile.dart',
  'lib/domain/level.dart',
  'lib/domain/board_layout.dart',
  'lib/data/level_repository.dart',
  'lib/presentation/screens/game_screen.dart',
  'test/qa/support/geometry.dart',
  'test/qa/support/solver.dart',
  'test/balance_audit/support/balance_metrics.dart',
  'test/balance_audit/support/campaign_validation.dart',
  'test/balance_audit/support/campaign_validation_report.dart',
  'test/balance_audit/campaign_validation_run_test.dart',
  'test/balance_audit/campaign_validation_contract_test.dart',
  'test/balance_audit/CAMPAIGN_VALIDATION.md',
];

String _levelPath(int level) =>
    'assets/levels/level_${level.toString().padLeft(2, '0')}.json';

CampaignJson _fingerprints() => {
      for (final path in [
        ..._sourceFiles,
        for (var i = 1; i <= 100; i++) _levelPath(i)
      ])
        path: File(path).existsSync()
            ? campaignFingerprint(File(path).readAsBytesSync())
            : 'MISSING',
    };

String _git(List<String> args) {
  try {
    final result = Process.runSync('git', args);
    return result.exitCode == 0 ? '${result.stdout}'.trim() : 'UNAVAILABLE';
  } on ProcessException {
    return 'UNAVAILABLE';
  }
}

String _flutterVersion() {
  // flutter_tester lives beneath bin/cache/artifacts/engine. Read provenance
  // without launching Flutter or depending on its position on PATH.
  var directory = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final version = File('${directory.path}/bin/cache/flutter.version.json');
    if (version.existsSync()) return version.readAsStringSync().trim();
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  return 'UNAVAILABLE; retain local SDK version separately';
}

void main() {
  test('opt-in Campaign validation: 300 baselines and up to 2160 attempts',
      () async {
    final selected = _behaviorLevels();
    if (!File(_levelPath(1)).existsSync()) {
      throw StateError(
          'Run from the repository root; Campaign assets were not found.');
    }
    final started = DateTime.now().toUtc();
    final runId =
        '${started.toIso8601String().replaceAll(RegExp(r'[^0-9TZ]'), '')}-$pid';
    final output = Directory('qa/campaign_validation_runs/$runId');
    if (output.existsSync()) {
      throw StateError('Refusing to reuse run directory ${output.path}');
    }
    output.createSync(recursive: true);
    // Every artifact is new. Existing balance reports are never opened.
    final before = _fingerprints();
    final manifest = <String, Object?>{
      'schema': 'campaign-validation/v1',
      'run_id': runId,
      'status': 'RUNNING',
      'started_utc': started.toIso8601String(),
      'campaign_only': true,
      'planned_baseline_cases': 300,
      'planned_behavior_attempts': selected.length *
          qaScreens.length *
          CampaignPolicy.values.length *
          _seedCount,
      'behavior_levels': selected,
      'seed_count': _seedCount,
      'seed_indices': List.generate(_seedCount, (i) => i),
      'strategies': CampaignPolicy.values.map((p) => p.name).toList(),
      'screens': [
        for (final s in qaScreens)
          {
            'name': s.name,
            'size': [s.size.width, s.size.height],
            'safe_top': s.safeTop,
            'board': [s.geometry().board.width, s.geometry().board.height],
            'tile': [s.geometry().tile.width, s.geometry().tile.height],
          }
      ],
      'seed_policy':
          'FNV-1a32(UTF8(campaign4c/v1|level|screen|policy.name|seedIndex)); xorshift32; rejection-sampled nextInt; Fisher-Yates ties',
      'zero_rng_seed_replacement': '0x6d2b79f5',
      'move_budget':
          'initial tile count per attempt; only successful forward taps',
      'lookahead': {
        'depth': 3,
        'branch_cap': 4,
        'expanded_action_cap_per_decision': 84,
        'ranking':
            'real-engine one-step previews of all currently exposed candidates at each expanded state',
        'ranking_preview_bound_per_decision':
            'at most 21 * initially exposed count (plus measurement previews)'
      },
      'wall_budget_minutes': 30,
      'wall_budget_note':
          'Checked between cases; partial subset is machine-dependent. Individual decisions use deterministic budgets only.',
      'git_head': _git(['rev-parse', 'HEAD']),
      'scoped_worktree_status':
          _git(['status', '--short', '--', ..._sourceFiles, 'assets/levels']),
      'dart_runtime': Platform.version,
      'flutter_sdk_version_file': _flutterVersion(),
      'fingerprint_algorithm': 'FNV-1a32, non-cryptographic',
      'fingerprints_before': before,
      'human_fairness': 'UNVERIFIED',
    };
    final encoder = const JsonEncoder.withIndent('  ');
    void writeJson(String name, Object value) => File('${output.path}/$name')
        .writeAsStringSync('${encoder.convert(value)}\n');
    writeJson('manifest.json', manifest);
    final baselineSink = File('${output.path}/baseline.jsonl').openWrite();
    final attemptsSink = File('${output.path}/attempts.jsonl').openWrite();
    final baseline = <CampaignJson>[];
    final attempts = <CampaignJson>[];
    final problems = <String>[];
    final watch = Stopwatch()..start();
    var limited = false;
    Object? fatal;
    final levels = <int, LevelDefinition>{};
    bool outOfTime() => watch.elapsed >= const Duration(minutes: 30);
    try {
      for (var id = 1; id <= 100; id++) {
        if (outOfTime()) {
          limited = true;
          break;
        }
        try {
          final level = LevelDefinition.fromJson(
              jsonDecode(File(_levelPath(id)).readAsStringSync())
                  as Map<String, dynamic>);
          if (level.level != id) {
            throw FormatException('Expected level $id, found ${level.level}');
          }
          levels[id] = level;
        } catch (error) {
          problems.add('Level $id load failed: $error');
        }
        for (final screen in qaScreens) {
          CampaignJson row;
          try {
            final level = levels[id];
            row = level == null
                ? {
                    'level': id,
                    'screen': screen.name,
                    'status': 'ERROR',
                    'witness_status': 'UNVERIFIED',
                    'issues': ['LOAD_FAILED'],
                  }
                : campaignBaseline(level, screen);
          } catch (error) {
            row = {
              'level': id,
              'screen': screen.name,
              'status': 'ERROR',
              'witness_status': 'UNVERIFIED',
              'issues': ['$error']
            };
          }
          baseline.add(row);
          baselineSink.writeln(jsonEncode(row));
        }
        if (id % 10 == 0) {
          await baselineSink.flush();
          // Yield to the test runner without introducing simulation timing inputs.
          await Future<void>.delayed(Duration.zero);
          stdout.writeln('Campaign baseline: $id/100 levels');
        }
      }
      behaviorLoop:
      for (final id in selected) {
        for (final screen in qaScreens) {
          final level = levels[id];
          final base = baseline
              .where((b) => b['level'] == id && b['screen'] == screen.name)
              .firstOrNull;
          final confirmed = base?['confirmed'] as Map? ?? {};
          CampaignGraph? graph;
          String? graphError;
          if (level != null && campaignInputIssues(level).isEmpty) {
            try {
              graph = CampaignGraph(level.tiles, screen.geometry());
            } catch (error) {
              graphError = '$error';
            }
          }
          for (final policy in CampaignPolicy.values) {
            for (var seed = 0; seed < _seedCount; seed++) {
              if (outOfTime()) {
                limited = true;
                break behaviorLoop;
              }
              CampaignJson row;
              try {
                if (graph == null || level == null) {
                  throw StateError(graphError ?? 'INVALID_OR_MISSING_INPUT');
                }
                row = simulateCampaign(level, graph, policy, screen.name, seed);
              } catch (error) {
                row = {
                  'level': id,
                  'screen': screen.name,
                  'strategy': policy.name,
                  'seed_index': seed,
                  'derived_seed_uint32':
                      campaignSeed(id, screen.name, policy, seed),
                  'omniscient': false,
                  'evidence': 'UNVERIFIED',
                  'outcome': 'INCONCLUSIVE',
                  'stop_reason': 'HARNESS_OR_INPUT_ERROR',
                  'error': '$error',
                  'decisions': 0
                };
              }
              row['initial_exposed_tiles'] = confirmed['initial_exposed_tiles'];
              row['initial_visible_triples'] =
                  confirmed['initial_visible_triples'];
              attempts.add(row);
              attemptsSink.writeln(jsonEncode(row));
            }
            await attemptsSink.flush();
            await Future<void>.delayed(Duration.zero);
          }
        }
        stdout.writeln(
            'Campaign behavior: level $id; ${attempts.length} attempts recorded');
      }
    } catch (error, stack) {
      fatal = error;
      manifest['fatal_error'] = '$error';
      manifest['fatal_stack'] = '$stack';
    } finally {
      await baselineSink.close();
      await attemptsSink.close();
      final after = _fingerprints();
      final changed = [
        for (final path in before.keys)
          if (before[path] != after[path]) path
      ];
      final badBaseline =
          baseline.where((b) => b['status'] != 'VALIDATED').length;
      final badAttempts =
          attempts.where((a) => a['outcome'] == 'INCONCLUSIVE').length;
      manifest.addAll({
        'status': fatal != null
            ? 'FAILED'
            : limited
                ? 'PARTIAL'
                : 'COMPLETE',
        'measurement_health': fatal != null ||
                changed.isNotEmpty ||
                badBaseline > 0 ||
                badAttempts > 0
            ? 'REVIEW_REQUIRED'
            : 'OK',
        'finished_utc': DateTime.now().toUtc().toIso8601String(),
        'elapsed_seconds': watch.elapsedMilliseconds / 1000,
        'actual_baseline_cases': baseline.length,
        'actual_behavior_attempts': attempts.length,
        'baseline_cases_requiring_review': badBaseline,
        'inconclusive_attempts': badAttempts,
        'fingerprints_after': after,
        'inputs_changed_during_run': changed,
        'load_errors': problems,
        'wall_budget_reached': limited,
      });
      try {
        final summary = buildCampaignSummary(baseline, attempts);
        writeJson('summary.json', summary);
        File('${output.path}/report.md')
            .writeAsStringSync(campaignMarkdown(manifest, summary, baseline));
      } catch (error, stack) {
        manifest['status'] = 'FAILED';
        manifest['measurement_health'] = 'REVIEW_REQUIRED';
        manifest['report_error'] = '$error';
        manifest['report_stack'] = '$stack';
      } finally {
        writeJson('manifest.json', manifest);
      }
      stdout.writeln('Campaign validation artifacts: ${output.absolute.path}');
    }
    expect(manifest['status'], 'COMPLETE',
        reason:
            'Partial/failed artifacts are retained; inspect manifest.json.');
    expect(manifest['measurement_health'], 'OK',
        reason:
            'Inspect input, witness or inconclusive diagnostics; heuristic losses alone do not fail this gate.');
  },
      skip: !_enabled
          ? 'Opt in with --dart-define=CAMPAIGN_VALIDATE=true'
          : false,
      timeout: const Timeout(Duration(minutes: 35)));
}
