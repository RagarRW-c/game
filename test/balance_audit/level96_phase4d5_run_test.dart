// Opt-in only. A plain flutter test command skips the experiment entirely.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/level.dart';

import 'support/campaign_paired.dart';
import 'support/campaign_validation.dart';
import 'support/level96_phase4d5.dart';
import 'support/level96_phase4d5_io.dart';
import 'support/level96_phase4d5_report.dart';
import 'support/level96_shadow.dart';
import 'support/level96_shadow_io.dart';
import '../qa/support/geometry.dart';

const phase5Enabled = bool.fromEnvironment('CAMPAIGN_LEVEL96_PHASE4D5');
const phase5RunCommand =
    'flutter test test/balance_audit/level96_phase4d5_run_test.dart '
    '--no-pub --dart-define=CAMPAIGN_LEVEL96_PHASE4D5=true --concurrency=1 --reporter=expanded';

void main() {
  test('Phase 4D-5: correctness gates then 360 paired attempts, replicas 30-59',
      () async {
    final output = Phase5Output.create();
    final watch = Stopwatch()..start();
    final attempts = <CampaignJson>[], reproductions = <CampaignJson>[];
    final problems = <String>[];
    final paths = phase5InputPaths();
    CampaignJson before = {}, after = {};
    CampaignJson? gate;
    var blocked = false, limited = false, inputsUnchanged = false;
    Object? fatal;
    final manifest = <String, Object?>{
      'schema': phase5Version,
      'run_id': output.runId,
      'status': 'RUNNING',
      'measurement_health': 'PENDING',
      'started_utc': DateTime.now().toUtc().toIso8601String(),
      'level': 96,
      'planned_attempts': phase5Attempts,
      'actual_attempts': 0,
      'cohort': phase5Cohort,
      'replica_indices': List.generate(30, (i) => i + 30),
      'variants': phase5Variants,
      'type_changes_from_production': phase5Swaps,
      'derivation':
          'Independent deep copies of untouched production Level 96 for both arms',
      'strategies': shadow96Policies.map((p) => p.name).toList(),
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
      'paired_policy_version': pairedVersion,
      'paired_seed_policy': pairedSeedPolicy,
      'visibility': 'exposed_only_v1',
      'variant_in_seed_or_priority': false,
      'acceptance_rules': phase5AcceptanceRules,
      'planned_witness_replays': 6,
      'planned_historical_reproductions': 6,
      'historical_reproduction_replica': 24,
      'preflight_counted_in_new_attempts': false,
      'budgets': {
        'replicas_per_cell': 30,
        'moves': 'initial tile count',
        'lookahead_depth': 3,
        'branch_cap': 4,
        'expansions': 84,
        'wall_minutes': 30,
        'test_timeout_minutes': 35,
        'automatic_retry_or_expansion': false,
        'wall_guard': 'between attempts'
      },
      'fingerprint_algorithm':
          'FNV-1a32, non-cryptographic, same as historical methodology',
      'reproduction_command': phase5RunCommand,
      'production_files_written': false,
      'historical_results_written': false,
      'gameplay_rules_changed': false,
      'endless_modes_included': false,
      'production_change_authorized': false,
      'dart_version': Platform.version,
      'flutter_version': shadowFlutterVersion(),
      'git_head': shadowGit(['rev-parse', 'HEAD']),
      'scoped_worktree_status': shadowGit([
        'status',
        '--short',
        '--',
        ...shadow96BehaviorInputs,
        ...phase5ToolInputs
      ]),
    };
    output.writeJson('manifest.json', manifest);
    try {
      before = shadowFingerprints(paths);
      manifest['fingerprints_before'] = before;
      if (before.values.contains('MISSING')) {
        throw StateError('Missing required input');
      }
      phase5RequireReferenceHashes(before);
      manifest['input_snapshots_utf8'] = {
        for (final path in {
          ...shadow96BehaviorInputs,
          ...shadow96ToolInputs,
          ...phase5ToolInputs
        })
          path: File(path).readAsStringSync(),
      };
      if (phase5Schedule().length != 360 ||
          qaScreens.length != 3 ||
          shadow96Policies.length != 2) {
        throw StateError('Fixed cohort changed');
      }
      final reference = await loadPhase5Reference();
      manifest['reference_evidence'] = reference.toJson();
      final production = LevelDefinition.fromJson(
          jsonDecode(File(shadow96Asset).readAsStringSync())
              as Map<String, dynamic>);
      final a = makePhase5Variant(production, 'control_a');
      final b = makePhase5Variant(production, 'candidate_b');
      final models = [production, a, b];
      final modelBefore =
          models.map((l) => shadowCanonical(shadowLevelValue(l))).toList();
      bool modelsIntact() =>
          shadowCanonical(modelBefore) ==
          shadowCanonical(
              models.map((l) => shadowCanonical(shadowLevelValue(l))).toList());
      final witness = phase5WitnessGate(production, a, b, reference.witnesses);
      final paired = phase5PairedGate(a, b);
      if (witness['passed'] == true && paired['passed'] == true) {
        reproductions.addAll(phase5ReproduceHistoricalControl(a, reference));
      }
      gate = {
        'passed': witness['passed'] == true &&
            paired['passed'] == true &&
            phase5ReproductionPassed(reproductions) &&
            modelsIntact(),
        'witness_and_invariants': witness,
        'deterministic_paired': paired,
        'historical_control_reproduction': reproductions,
        'models_unchanged_after_preflight': modelsIntact()
      };
      manifest['correctness_gate'] = gate;
      output.writeJson('manifest.json', manifest);
      if (gate['passed'] != true) {
        blocked = true;
        problems
            .add('CORRECTNESS_GATE_FAILED; no new-cohort attempts permitted');
      } else {
        // Exactly this predeclared schedule. No tuning, resampling or retries.
        for (final identity in phase5Schedule()) {
          if (watch.elapsed >= const Duration(minutes: 30)) {
            limited = true;
            problems.add('WALL_GUARD_REACHED');
            break;
          }
          final screen =
              qaScreens.singleWhere((s) => s.name == identity['screen']);
          final policy = shadow96Policies
              .singleWhere((p) => p.name == identity['strategy']);
          final arm = identity['variant'] as String;
          CampaignJson row;
          try {
            row = simulatePhase5(arm == 'control_a' ? a : b, screen, policy,
                identity['replica'] as int, arm);
          } catch (error, stack) {
            row = {
              ...identity,
              'outcome': 'INCONCLUSIVE',
              'evidence': 'UNVERIFIED',
              'stop_reason': 'EXCEPTION',
              'error': '$error',
              'stack': '$stack',
              'trace': <CampaignJson>[]
            };
          }
          output.append(row);
          attempts.add(row);
          if (!modelsIntact()) {
            problems.add('IN_MEMORY_MODEL_MUTATED');
            break;
          }
          if (!['WIN', 'LOSS'].contains(row['outcome'])) {
            problems.add('UNVERIFIED_ATTEMPT:${phase5Key(row)}');
            break;
          }
        }
      }
      if (!modelsIntact()) problems.add('IN_MEMORY_MODEL_MUTATED');
    } catch (error, stack) {
      fatal = error;
      manifest['fatal_error'] = '$error';
      manifest['fatal_stack'] = '$stack';
    } finally {
      try {
        after = shadowFingerprints(paths);
        inputsUnchanged = phase5InputsUnchanged(before, after);
        if (!inputsUnchanged) {
          problems.add('INPUT_OR_HISTORICAL_EVIDENCE_CHANGED');
        }
      } catch (error) {
        problems.add('INPUT_RECHECK_FAILED:$error');
      }
      final executionComplete = fatal == null &&
          !blocked &&
          !limited &&
          attempts.length == phase5Attempts &&
          problems.isEmpty &&
          inputsUnchanged;
      manifest.addAll({
        'status': fatal != null
            ? 'FAILED'
            : blocked
                ? 'GATE_FAILED'
                : executionComplete
                    ? 'COMPLETE'
                    : 'PARTIAL',
        'measurement_health': executionComplete ? 'OK' : 'REVIEW_REQUIRED',
        'actual_attempts': attempts.length,
        'fingerprints_after': after,
        'inputs_unchanged': inputsUnchanged,
        'historical_control_reproduction': reproductions,
        'problems': problems,
        'wall_guard_reached': limited,
        'finished_utc': DateTime.now().toUtc().toIso8601String(),
        'elapsed_seconds': watch.elapsedMilliseconds / 1000
      });
      try {
        final summary = buildPhase5Summary(attempts, gate, reproductions,
            executionComplete: executionComplete,
            inputsUnchanged: inputsUnchanged);
        manifest['recommendation'] = summary['recommendation'];
        output.writeJson('summary.json', summary);
        output.report(phase5Markdown(manifest, summary));
        manifest['artifact_fingerprints'] = shadowFingerprints([
          for (final name in ['attempts.jsonl', 'summary.json', 'report.md'])
            '${output.directory.path}/$name'
        ]);
      } catch (error, stack) {
        manifest.addAll({
          'status': 'FAILED',
          'measurement_health': 'REVIEW_REQUIRED',
          'recommendation': 'REVISE',
          'report_error': '$error',
          'report_stack': '$stack'
        });
        output.writeJson('summary.json', {
          'evidence_complete': false,
          'actual_attempts': attempts.length,
          'recommendation': 'REVISE',
          'report_error': '$error'
        });
        output.report(
            '# Phase 4D-5 reporting failure\n\nREVISE measurement. Error: $error\n'
            '\nRetained attempts and manifest contain diagnostics. No production change authorized.\n');
      } finally {
        output.writeJson('manifest.json', manifest);
      }
    }
    expect(manifest['status'], 'COMPLETE',
        reason: 'Evidence: ${output.directory.path}');
    expect(manifest['measurement_health'], 'OK',
        reason: 'Inspect preserved gates and diagnostics');
  }, skip: !phase5Enabled, timeout: const Timeout(Duration(minutes: 35)));
}
