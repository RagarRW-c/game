// Opt-in, fixed 360-attempt shadow experiment. No production asset writes.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/level.dart';

import '../qa/support/geometry.dart';
import 'support/campaign_paired.dart';
import 'support/campaign_validation.dart';
import 'support/level96_shadow.dart';
import 'support/level96_shadow_io.dart';
import 'support/level96_shadow_report.dart';

const _enabled = bool.fromEnvironment('CAMPAIGN_LEVEL96_SHADOW');

void main() {
  test('opt-in level 96 shadow: witness gates then fixed 360 paired attempts',
      () async {
    final output = ShadowRunOutput.create();
    final started = DateTime.now().toUtc();
    final watch = Stopwatch()..start();
    final attempts = <CampaignJson>[], reproduction = <CampaignJson>[];
    final problems = <String>[];
    final paths = [
      ...shadow96BehaviorInputs,
      ...shadow96ToolInputs,
      ...shadow96ReferenceFiles
    ];
    final before = shadowFingerprints(paths);
    CampaignJson? gate;
    var limited = false, inputsUnchanged = false, blocked = false;
    Object? fatal;
    final manifest = <String, Object?>{
      'schema': shadow96Version,
      'run_id': output.runId,
      'status': 'RUNNING',
      'measurement_health': 'PENDING',
      'started_utc': started.toIso8601String(),
      'level': 96,
      'control_definition':
          'Original assets/levels/level_96.json, byte fingerprint 2b2b8578',
      'candidate_definition': {
        'storage': 'IN_MEMORY_ONLY',
        'type_swap': {
          'L96_T094': {'from': 'heart', 'to': 'star'},
          'L96_T095': {'from': 'star', 'to': 'heart'}
        },
        'preserve':
            'all non-type fields, tile order/count, inventory, level metadata/objective, geometry'
      },
      'scope': {
        'campaign_level_96_only': true,
        'production_files_written': false,
        'level_assets_written': false,
        'rules_or_overlap_or_tray_changed': false,
        'boosters_rewards_economy_ui_audio_goldens_changed': false,
        'classic_endless_included': false,
        'endless_battle_included': false,
        'historical_results_written': false,
        'recommendation_authorizes_production_change': false
      },
      'git_head': shadowGit(['rev-parse', 'HEAD']),
      'scoped_worktree_status': shadowGit([
        'status',
        '--short',
        '--',
        ...shadow96BehaviorInputs,
        ...shadow96ToolInputs
      ]),
      'dart_version': Platform.version,
      'flutter_version': shadowFlutterVersion(),
      'paired_policy_version': pairedVersion,
      'paired_seed_policy': pairedSeedPolicy,
      'variant_in_seed_or_priority': false,
      'visibility': 'exposed_only_v1',
      'replica_indices': List.generate(30, (i) => i),
      'overlap_indices': List.generate(10, (i) => i),
      'holdout_indices': List.generate(20, (i) => i + 10),
      'strategies': shadow96Policies.map((p) => p.name).toList(),
      'strategy_definitions': {
        'greedyMatch':
            'Unchanged paired-v1 one-step greedy: nonloss, lower tray, more tray matches, more exposed same-type; stateless actual priority ties',
        'visibleLookahead':
            'Unchanged paired-v1 greedy-ranked tree: depth 3, 4 children, 84 expansions; survival/matches/peak/final tray; first equal leaf; actual priorities at root, separate plan path priorities inside',
      },
      'screens': [
        for (final s in qaScreens)
          {
            'name': s.name,
            'size': [s.size.width, s.size.height],
            'safe_top': s.safeTop,
            'board': [s.geometry().board.width, s.geometry().board.height],
            'tile': [s.geometry().tile.width, s.geometry().tile.height]
          }
      ],
      'planned_attempts': shadow96Attempts,
      'planned_witness_replays': 6,
      'budgets': {
        'replicas_per_variant_screen_strategy': 30,
        'moves': 'initial tile count',
        'lookahead_depth': 3,
        'branch_cap': 4,
        'expansions': 84,
        'wall_minutes': 30,
        'test_timeout_minutes': 35,
        'automatic_expansion_or_retry': false,
        'wall_guard': 'between attempts; partial coverage is machine-dependent'
      },
      'fingerprint_algorithm': 'FNV-1a32, non-cryptographic',
      'fingerprints_before': before,
      'input_snapshots_utf8': {
        for (final path in [...shadow96BehaviorInputs, ...shadow96ToolInputs])
          path: File(path).existsSync()
              ? File(path).readAsStringSync()
              : 'MISSING'
      },
      'reproduction_command':
          'flutter test test/balance_audit/level96_shadow_run_test.dart --dart-define=CAMPAIGN_LEVEL96_SHADOW=true --concurrency=1 --reporter=expanded',
      'recommendation_policy':
          'Gate failure REJECT; incomplete/drift/reproduction failure REVISE; control-win regressions REVISE; no opening improvement REJECT; otherwise require early triple in all 180 candidate attempts, no seven-tap losses, holdout win gain on each screen, and no all-30-wins cell for ACCEPT FOR HUMAN REVIEW; else REVISE. No human difficulty calibration implied.',
    };
    output.writeJson('manifest.json', manifest);
    try {
      if (before.values.contains('MISSING'))
        throw StateError('Required input or historical evidence missing');
      if (qaScreens.length != 3 ||
          shadow96Policies.length != 2 ||
          shadow96Replicas != 30 ||
          shadow96Attempts != 360) {
        throw StateError('Fixed experiment cohort changed');
      }
      final reference = await loadShadow96Reference();
      manifest['reference_evidence'] = reference.toJson();
      final control = LevelDefinition.fromJson(
          jsonDecode(File(shadow96Asset).readAsStringSync())
              as Map<String, dynamic>);
      final controlBefore = shadowCanonical(shadowLevelValue(control));
      final candidate = makeLevel96Candidate(control);
      final candidateBefore = shadowCanonical(shadowLevelValue(candidate));
      gate = shadowSolvabilityGate(control, candidate, reference.witnesses);
      manifest['solvability_gate'] = gate;
      output.writeJson('manifest.json', manifest);
      if (gate['passed'] != true) {
        blocked = true;
        problems.add(
            'SOLVABILITY_OR_INVARIANT_GATE_FAILED; inspect all six replay traces and first failure states');
      } else {
        experiment:
        for (final variant in shadow96Variants) {
          // All 180 control attempts, including 60 exact historical comparisons,
          // precede candidate attempts. They are part of the 360, not extra runs.
          if (variant == 'candidate' &&
              (reproduction.length != 60 ||
                  reproduction.any((r) => r['passed'] != true))) {
            blocked = true;
            problems.add('CONTROL_REPRODUCTION_GATE_FAILED');
            break;
          }
          final level = variant == 'control' ? control : candidate;
          for (final screen in qaScreens)
            for (final policy in shadow96Policies)
              for (var replica = 0; replica < 30; replica++) {
                if (watch.elapsed >= const Duration(minutes: 30)) {
                  limited = true;
                  break experiment;
                }
                CampaignJson row;
                try {
                  row = simulateLevel96Shadow(
                      level, screen, policy, replica, variant);
                } catch (error, stack) {
                  row = {
                    ...pairedAttemptIdentity(96, screen.name, policy, replica),
                    'shadow_experiment_version': shadow96Version,
                    'variant': variant,
                    'cohort': replica < 10 ? 'overlap_0_9' : 'holdout_10_29',
                    'outcome': 'INCONCLUSIVE',
                    'evidence': 'UNVERIFIED',
                    'stop_reason': 'EXCEPTION',
                    'error': '$error',
                    'stack': '$stack',
                    'trace': <CampaignJson>[]
                  };
                }
                output.appendAttempt(row);
                attempts.add(row);
                if (row['outcome'] == 'INCONCLUSIVE')
                  problems.add(
                      '$variant/${screen.name}/${policy.name}/$replica: ${row['stop_reason']}');
                if (variant == 'control' && replica < 10) {
                  final expected = reference.rows[
                      shadowReferenceKey(screen.name, policy.name, replica)]!;
                  final comparison =
                      compareShadowControlReference(row, expected);
                  reproduction.add(comparison);
                  if (comparison['passed'] != true)
                    problems.add(
                        'CONTROL_TRACE_MISMATCH: ${screen.name}/${policy.name}/$replica: ${comparison['different_fields']}');
                }
              }
        }
      }
      if (controlBefore != shadowCanonical(shadowLevelValue(control)) ||
          candidateBefore != shadowCanonical(shadowLevelValue(candidate))) {
        problems.add('IN_MEMORY_LEVEL_MUTATED_DURING_EXPERIMENT');
      }
    } catch (error, stack) {
      fatal = error;
      manifest['fatal_error'] = '$error';
      manifest['fatal_stack'] = '$stack';
    } finally {
      try {
        final after = shadowFingerprints(paths);
        manifest['fingerprints_after'] = after;
        inputsUnchanged = shadowCanonical(before) == shadowCanonical(after) &&
            !after.values.contains('MISSING');
        if (!inputsUnchanged) problems.add('INPUT_OR_HISTORICAL_FILE_CHANGED');
      } catch (error) {
        problems.add('INPUT_RECHECK_FAILED: $error');
      }
      final executionComplete =
          fatal == null && !blocked && !limited && attempts.length == 360;
      manifest.addAll({
        'status': fatal != null
            ? 'FAILED'
            : blocked
                ? 'GATE_FAILED'
                : executionComplete
                    ? 'COMPLETE'
                    : 'PARTIAL',
        'measurement_health':
            executionComplete && problems.isEmpty && inputsUnchanged
                ? 'OK'
                : 'REVIEW_REQUIRED',
        'actual_attempts': attempts.length,
        'inputs_unchanged': inputsUnchanged,
        'control_reproduction': reproduction,
        'problems': problems,
        'wall_guard_reached': limited,
        'finished_utc': DateTime.now().toUtc().toIso8601String(),
        'elapsed_seconds': watch.elapsedMilliseconds / 1000
      });
      try {
        final summary = buildShadow96Summary(attempts, gate, reproduction,
            executionComplete: executionComplete && problems.isEmpty,
            inputsUnchanged: inputsUnchanged);
        manifest['recommendation'] = summary['recommendation'];
        output.writeJson('summary.json', summary);
        output.writeReport(shadow96Markdown(manifest, summary));
      } catch (error, stack) {
        manifest['status'] = 'FAILED';
        manifest['measurement_health'] = 'REVIEW_REQUIRED';
        manifest['report_error'] = '$error';
        manifest['report_stack'] = '$stack';
        // Preserve the required artifact names even if reporting itself failed.
        output.writeJson('summary.json', {
          'evidence_complete': false,
          'recommendation': 'REVISE',
          'report_error': '$error'
        });
        output.writeReport(
            '# Level 96 shadow experiment failed\n\nRecommendation: REVISE measurement. Report error: $error\n\nInspect manifest.json and retained attempts. No production edit is authorized.\n');
      } finally {
        output.writeJson('manifest.json', manifest);
      }
    }
    expect(manifest['status'], 'COMPLETE',
        reason: 'Evidence retained at ${output.directory.path}');
    expect(manifest['measurement_health'], 'OK',
        reason: 'Inspect manifest and gate/reproduction diagnostics');
  }, skip: !_enabled, timeout: const Timeout(Duration(minutes: 35)));
}
