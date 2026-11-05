// Explicitly opt-in. No simulations or output writes during ordinary discovery.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/level.dart';

import '../qa/support/geometry.dart';
import 'support/campaign_paired.dart';
import 'support/campaign_paired_report.dart';
import 'support/campaign_validation.dart';

const _enabled = bool.fromEnvironment('CAMPAIGN_PAIRED_VALIDATE');
const _sources = [
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
  'test/balance_audit/support/campaign_paired.dart',
  'test/balance_audit/support/campaign_paired_report.dart',
  'test/balance_audit/campaign_paired_run_test.dart',
  'test/balance_audit/campaign_paired_contract_test.dart',
  'test/balance_audit/fixtures/campaign_historical_v1.json',
  'test/balance_audit/CAMPAIGN_PAIRED_VALIDATION.md',
];
String _levelPath(int level) =>
    'assets/levels/level_${level.toString().padLeft(2, '0')}.json';
List<String> get _inputs =>
    [..._sources, for (final l in pairedLevels) _levelPath(l)];
CampaignJson _fingerprints() => {
      for (final path in _inputs)
        path: campaignFingerprint(File(path).readAsBytesSync()),
    };

String _git(List<String> args) {
  try {
    final p = Process.runSync('git', args);
    return p.exitCode == 0 ? '${p.stdout}'.trim() : 'UNAVAILABLE';
  } on ProcessException {
    return 'UNAVAILABLE';
  }
}

Object _flutterVersion() {
  // Read installed provenance; never spawn a nested Flutter command.
  var directory = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final file = File('${directory.path}/bin/cache/flutter.version.json');
    if (file.existsSync()) return jsonDecode(file.readAsStringSync()) as Object;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  return 'UNAVAILABLE; retain the installed Flutter version separately';
}

void main() {
  test('opt-in paired Campaign: exactly 11 x 3 x 3 x 10 = 990 attempts', () {
    expect(
        pairedLevels.length *
            qaScreens.length *
            CampaignPolicy.values.length *
            pairedReplicas,
        pairedAttemptCount);
    expect(qaScreens.map((s) => s.name).toList(),
        ['small_320x568', 'medium_360x800', 'tall_412x915']);
    final before =
        _fingerprints(); // fail before writing if invoked outside root
    final started = DateTime.now().toUtc();
    final parent = Directory('qa/campaign_validation_runs')
      ..createSync(recursive: true);
    final stamp = started.toIso8601String().replaceAll(RegExp(r'[^0-9TZ]'), '');
    // Atomic unique-directory allocation; no preexisting run can be reused.
    final output = parent.createTempSync('paired-$stamp-$pid-');
    final runId = output.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final attempts = <CampaignJson>[];
    final geometries = <String, CampaignJson>{};
    final problems = <String>[];
    final manifest = <String, Object?>{
      'schema': 'campaign-paired-run/v1',
      'experiment_version': pairedVersion,
      'run_id': runId, 'status': 'RUNNING', 'measurement_health': 'PENDING',
      'started_utc': started.toIso8601String(),
      'scope': {
        'campaign_only': true,
        'production_gameplay_modified': false,
        'level_jsons_modified': false,
        'classic_endless_included': false,
        'endless_battle_included': false,
        'boosters_economy_ui_assets_modified': false,
        'historical_runs_modified': false,
        'note':
            'Read-only inputs; writes confined to this newly allocated run directory',
      },
      'historical_reference':
          '20261104T215452428949Z-25028; not rerun or edited',
      'git_head': _git(['rev-parse', 'HEAD']),
      'scoped_worktree_status': _git(['status', '--short', '--', ..._inputs]),
      'dart_version': Platform.version,
      'flutter_version': _flutterVersion(),
      'resolved_executable': Platform.resolvedExecutable,
      'platform': Platform.operatingSystem,
      'fingerprint_algorithm': 'FNV-1a32 (non-cryptographic)',
      'fingerprints_before': before,
      // Retain actual working inputs, including uncommitted tooling, so Git HEAD
      // plus an unavailable dirty tree is not the only reproduction material.
      'scoped_input_snapshots_utf8': {
        for (final path in _inputs) path: File(path).readAsStringSync(),
      },
      'paired_seed_policy': pairedSeedPolicy,
      'public_token_version':
          'type-normalized-position/v1; JSON strings; -0 normalized',
      'strategy_definitions': {
        'randomLegal/paired-ties-v1':
            'Minimum actual priority among legal public tokens; pseudorandom ranking; no avoidance of loss. Historical uniform nextInt policy retained separately.',
        'greedyMatch/paired-ties-v1':
            'One-step real-engine previews; nonloss, lower tray-after, more tray matches, more exposed same-type tiles; actual priority resolves equal score.',
        'visibleLookahead/paired-ties-v1':
            'Same greedy ranking per node; depth 3, first 4 children, <=84 expanded actions; score leaves by nonloss, more matched tiles, lower peak tray, lower final tray; retain first equal leaf. Actual priority at root; public hypothetical-path priority inside plan.',
      },
      'information_model':
          'exposed_only_v1; no future reveal prediction, partial visibility or persistent memory',
      'levels': pairedLevels,
      'replicas': List.generate(pairedReplicas, (i) => i),
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
      'planned_attempts': pairedAttemptCount,
      'planned_baseline_replays': 0,
      'automatic_expansion_or_retry': false,
      'budgets': {
        'replicas_per_cell': 10,
        'moves_per_attempt': 'initial tile count',
        'lookahead_depth': 3,
        'branch_cap': 4,
        'expanded_action_cap': 84,
        'ranking_previews':
            'at most 21 * initially exposed count, outside expansion cap; plus one public measurement preview per candidate',
        'wall_minutes': 30,
        'test_timeout_minutes': 35,
        'wall_guard':
            'Checked between attempts; partial cohort is machine-dependent and must not be treated as complete',
      },
      'decision_index':
          'zero-based actual tap index; hypothetical nodes never increment it',
      'high_risk_definition': 'tray occupancy >=6 before an actual decision',
      'human_fairness': 'UNVERIFIED',
      'reproduction_command':
          'flutter test test/balance_audit/campaign_paired_run_test.dart --dart-define=CAMPAIGN_PAIRED_VALIDATE=true --concurrency=1 --reporter=expanded',
    };
    void jsonFile(String name, Object value) =>
        File('${output.path}/$name').writeAsStringSync(
            '${const JsonEncoder.withIndent('  ').convert(value)}\n');
    jsonFile('manifest.json', manifest);
    final attemptsFile = File('${output.path}/paired_attempts.jsonl')
      ..writeAsStringSync('');
    final watch = Stopwatch()..start();
    var limited = false;
    Object? fatal;
    try {
      experiment:
      for (final id in pairedLevels) {
        final level = LevelDefinition.fromJson(
            jsonDecode(File(_levelPath(id)).readAsStringSync())
                as Map<String, dynamic>);
        final issues = campaignInputIssues(level);
        if (level.level != id || issues.isNotEmpty)
          throw StateError('Invalid Campaign input $id: $issues');
        for (final screen in qaScreens) {
          final graph = CampaignGraph(level.tiles, screen.geometry());
          geometries['$id|${screen.name}'] = pairedGeometry(graph);
          for (final policy in CampaignPolicy.values) {
            for (var replica = 0; replica < pairedReplicas; replica++) {
              if (watch.elapsed >= const Duration(minutes: 30)) {
                limited = true;
                break experiment;
              }
              CampaignJson row;
              try {
                row = simulatePairedCampaign(
                    level, graph, policy, screen.name, replica);
              } catch (error, stack) {
                row = {
                  ...pairedAttemptIdentity(id, screen.name, policy, replica),
                  'evidence': 'UNVERIFIED',
                  'outcome': 'INCONCLUSIVE',
                  'stop_reason': 'EXCEPTION',
                  'error': '$error',
                  'stack': '$stack',
                  'trace': <CampaignJson>[],
                };
              }
              attemptsFile.writeAsStringSync('${jsonEncode(row)}\n',
                  mode: FileMode.append, flush: true);
              attempts.add(row);
              if (row['outcome'] == 'INCONCLUSIVE')
                problems.add(
                    '$id/${screen.name}/${policy.name}/$replica: ${row['stop_reason']}');
            }
          }
        }
      }
    } catch (error, stack) {
      fatal = error;
      manifest['fatal_error'] = '$error';
      manifest['fatal_stack'] = '$stack';
    } finally {
      try {
        final after = _fingerprints();
        manifest['fingerprints_after'] = after;
        if (jsonEncode(before) != jsonEncode(after))
          problems.add('INPUTS_CHANGED_DURING_RUN');
      } catch (error) {
        problems.add('INPUT_RECHECK_FAILED: $error');
      }
      manifest.addAll({
        'status': fatal != null
            ? 'FAILED'
            : limited || attempts.length != pairedAttemptCount
                ? 'PARTIAL'
                : 'COMPLETE',
        'measurement_health': problems.isEmpty &&
                fatal == null &&
                !limited &&
                attempts.length == pairedAttemptCount
            ? 'OK'
            : 'REVIEW_REQUIRED',
        'actual_attempts': attempts.length,
        'finished_utc': DateTime.now().toUtc().toIso8601String(),
        'elapsed_seconds': watch.elapsedMilliseconds / 1000,
        'wall_guard_reached': limited,
        'problems': problems,
      });
      try {
        final summary = buildPairedSummary(attempts, geometries);
        jsonFile('paired_summary.json', summary);
        File('${output.path}/paired_report.md')
            .writeAsStringSync(pairedMarkdown(manifest, summary));
      } catch (error, stack) {
        manifest['status'] = 'FAILED';
        manifest['measurement_health'] = 'REVIEW_REQUIRED';
        manifest['report_error'] = '$error';
        manifest['report_stack'] = '$stack';
      } finally {
        jsonFile('manifest.json', manifest);
      }
    }
    // Heuristic losses are legitimate results, not test failures.
    expect(manifest['status'], 'COMPLETE',
        reason: 'Partial evidence retained at ${output.path}');
    expect(manifest['measurement_health'], 'OK',
        reason: 'Inspect ${output.path}/manifest.json');
  }, skip: !_enabled, timeout: const Timeout(Duration(minutes: 35)));
}
