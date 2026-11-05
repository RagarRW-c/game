import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import '../qa/support/geometry.dart';
import 'support/campaign_paired.dart';
import 'support/campaign_validation.dart';
import 'support/level96_shadow.dart';
import 'support/level96_shadow_io.dart';
import 'support/level96_shadow_report.dart';

LevelDefinition _control() => LevelDefinition.fromJson(
    jsonDecode(File(shadow96Asset).readAsStringSync()) as Map<String, dynamic>);
CampaignJson _raw(CampaignJson row) => Map<String, Object?>.of(row)
  ..remove('shadow_experiment_version')
  ..remove('variant')
  ..remove('cohort');

CampaignJson _synthetic(
        String variant, String screen, CampaignPolicy policy, int replica,
        {String? outcome,
        int? firstTriple,
        List<CampaignJson> trace = const []}) =>
    {
      ...pairedAttemptIdentity(96, screen, policy, replica),
      'shadow_experiment_version': shadow96Version,
      'variant': variant,
      'cohort': replica < 10 ? 'overlap_0_9' : 'holdout_10_29',
      'outcome':
          outcome ?? (variant == 'control' || replica == 29 ? 'LOSS' : 'WIN'),
      'decisions': variant == 'control'
          ? 7
          : replica == 29
              ? 17
              : 99,
      'first_resolved_triple_decision':
          firstTriple ?? (variant == 'control' ? null : 2),
      'first_high_risk_decision': 6,
      'average_tray_pressure': 0.6,
      'trace': trace,
      'stop_reason': 'SYNTHETIC_REPORT_FIXTURE',
    };

CampaignJson _step(int index, List<String> ids, List<String> tokens,
        String chosenId, String token,
        {List<String> tray = const [],
        List<String> trayTypes = const [],
        List<String> reveal = const []}) =>
    {
      'decision': index,
      'diagnostic_legal_ids': ids,
      'legal_tokens': tokens,
      'diagnostic_remaining_ids': ids,
      'diagnostic_tray_ids': tray,
      'tray_types_before': trayTypes,
      'diagnostic_actual_chosen_id': chosenId,
      'chosen_token': token,
      'newly_selectable_tokens_after_tap': reveal,
      'tray_after': tray.length + 1,
      'pressure_after': (tray.length + 1) / 7,
      'high_risk': false,
      'immediate_losing_choices': 0,
    };

void main() {
  late Shadow96Reference reference;
  setUpAll(() async {
    reference = await loadShadow96Reference();
  });

  test(
      'production bytes remain unchanged; only two types change in an independent copy',
      () {
    final file = File(shadow96Asset),
        before = File(shadow96Asset).readAsBytesSync();
    expect(campaignFingerprint(before), shadow96AssetFingerprint);
    expect(shadowFileFingerprint(file), campaignFingerprint(before));
    final control = _control(),
        original = shadowCanonical(shadowLevelValue(_control()));
    final candidate = makeLevel96Candidate(control);
    final check = shadowCandidateChecks(control, candidate);
    expect(check['passed'], isTrue);
    expect(check['changed_type_ids'], ['L96_T094', 'L96_T095']);
    expect(check['inventory_equal'], isTrue);
    expect(check['tile_count_control'], 99);
    expect(candidate.tiles.singleWhere((t) => t.id == 'L96_T094').type, 'star');
    expect(
        candidate.tiles.singleWhere((t) => t.id == 'L96_T095').type, 'heart');
    expect(shadowCanonical(shadowLevelValue(control)), original);
    expect(control.objective?.type, candidate.objective?.type);
    expect(control.objective?.target, candidate.objective?.target);
    final withObjective = LevelDefinition(
        level: 96,
        name: control.name,
        timeBonusSeconds: control.timeBonusSeconds,
        tiles: control.tiles,
        objective: const LevelObjective(type: 'heart', target: 3));
    final copiedObjective = makeLevel96Candidate(withObjective);
    expect(copiedObjective.objective!.type, 'heart');
    expect(copiedObjective.objective!.target, 3);
    expect(
        identical(copiedObjective.objective, withObjective.objective), isFalse);
    final copied = shadowCanonical(shadowLevelValue(candidate));
    control.tiles[0] =
        control.tiles[0].copyWith(type: 'mutated_only_in_test_control');
    expect(shadowCanonical(shadowLevelValue(candidate)), copied);
    expect(() => candidate.tiles.removeLast(), throwsUnsupportedError);
    expect(file.readAsBytesSync(), before);
    expect(() => makeLevel96Candidate(candidate), throwsStateError);
  });

  test(
      'all six stored witnesses clear real engine; geometry, order and bounds are equal',
      () {
    final before = File(shadow96Asset).readAsBytesSync();
    final control = _control(), candidate = makeLevel96Candidate(_control());
    final gate = shadowSolvabilityGate(control, candidate, reference.witnesses);
    expect(gate['passed'], isTrue);
    expect((gate['screens'] as List).length, 3);
    for (final screen in gate['screens'] as List) {
      expect(screen['blocking_graph_equal'], isTrue);
      expect(screen['bounds_equal'], isTrue);
      expect(screen['control_bounds']['outside_ids'], isEmpty);
      expect(screen['candidate_bounds']['outside_ids'], isEmpty);
      for (final name in ['control_replay', 'candidate_replay']) {
        final replay = screen[name];
        expect(replay['replay_success'], isTrue);
        expect(replay['full_clearance'], isTrue);
        expect(replay['successful_moves'], 99);
        expect(replay['winning_moves'], reference.witnesses[screen['screen']]);
        expect(replay['final_tray_count'], 0);
        expect(replay['tray_peak_after_resolution'],
            lessThan(GameEngine.trayLimit));
      }
    }
    expect(File(shadow96Asset).readAsBytesSync(), before);
  });

  test(
      'invalid and illegal witnesses fail with diagnostics, never a replacement search',
      () {
    final control = _control(), screen = qaScreens.first;
    final original = reference.witnesses[screen.name]!;
    final malformed = [...original]..[1] = original.first;
    final invalid = replayShadowWitness(control, screen, malformed);
    expect(invalid['replay_success'], isFalse);
    expect(invalid['failure_reason'], 'WITNESS_IS_NOT_A_FULL_TILE_PERMUTATION');
    expect(invalid['successful_moves'], 0);
    final illegal = [...original];
    final first = illegal.first;
    illegal[0] = illegal.last;
    illegal[illegal.length - 1] = first;
    final rejected = replayShadowWitness(control, screen, illegal);
    expect(rejected['replay_success'], isFalse);
    expect(rejected['failure_reason'], 'REJECTED_WITNESS_TAP');
    expect((rejected['failure_state'] as Map)['decision'], 0);
    expect(rejected['winning_moves'], isNull);
    expect(rejected['evidence'], 'UNVERIFIED');
    final gate = shadowSolvabilityGate(control, makeLevel96Candidate(control),
        {...reference.witnesses, screen.name: illegal});
    expect(gate['passed'], isFalse);
    expect((gate['screens'] as List).length, 3,
        reason: 'Do not silently skip remaining gate evidence');
  });

  test('control replicas 0-9 reproduce all 60 stored paired-v1 complete traces',
      () {
    final control = _control();
    expect(reference.rows.length, 60);
    for (final screen in qaScreens)
      for (final policy in shadow96Policies)
        for (var replica = 0; replica < 10; replica++) {
          final actual = simulateLevel96Shadow(
              control, screen, policy, replica, 'control');
          final historical = reference
              .rows[shadowReferenceKey(screen.name, policy.name, replica)]!;
          final comparison = compareShadowControlReference(actual, historical);
          expect(comparison['passed'], isTrue,
              reason:
                  '${screen.name}/${policy.name}/$replica: ${comparison['different_fields']}');
          expect(comparison['trace_equal'], isTrue);
          expect(actual['outcome'], 'LOSS');
          expect(actual['decisions'], 7);
        }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('reference comparison detects trace drift even if outcomes match', () {
    final original = reference.rows.values.first;
    final wrapped = {
      ...original,
      'variant': 'control',
      'cohort': 'overlap_0_9',
      'shadow_experiment_version': shadow96Version
    };
    expect(compareShadowControlReference(wrapped, original)['passed'], isTrue);
    final altered = {...wrapped, 'trace': <CampaignJson>[]};
    final comparison = compareShadowControlReference(altered, original);
    expect(comparison['outcome_equal'], isTrue);
    expect(comparison['passed'], isFalse);
    expect(comparison['different_fields'], contains('trace'));
  });

  test(
      'shared visible tokens keep identical priorities across variants and holdout replicas',
      () {
    final control = _control(), candidate = makeLevel96Candidate(_control());
    for (final screen in qaScreens) {
      CampaignObservation observe(LevelDefinition level) =>
          CampaignObservation.capture(GameEngine(level.tiles),
              CampaignGraph(level.tiles, screen.geometry()));
      final a = observe(control), b = observe(candidate);
      expect(
          a.actualIdByHandle.values.toSet(), b.actualIdByHandle.values.toSet());
      expect(a.actualIdByHandle.values, contains('L96_T095'));
      expect(a.actualIdByHandle.values, isNot(contains('L96_T094')));
      final shared = a.visible.exposed
          .map(publicTileToken)
          .toSet()
          .intersection(b.visible.exposed.map(publicTileToken).toSet());
      expect(shared, isNotEmpty);
      for (final replica in [0, 9, 10, 29]) {
        final pa = PairedPriorities(96, replica, 0),
            pb = PairedPriorities(96, replica, 0);
        expect(pa.experimentSeed, pb.experimentSeed);
        for (final token in shared)
          expect(pa.priority(token), pb.priority(token));
        final ida = pairedAttemptIdentity(
            96, screen.name, CampaignPolicy.greedyMatch, replica);
        final idb = pairedAttemptIdentity(
            96, screen.name, CampaignPolicy.visibleLookahead, replica);
        expect(ida['experiment_seed_uint32'], idb['experiment_seed_uint32']);
      }
      expect(
          shadowCanonical(a.visible.exposed.map(publicTileToken).toList()),
          isNot(
              shadowCanonical(b.visible.exposed.map(publicTileToken).toList())),
          reason: 'The genuinely visible type change must remain observable');
    }
  });

  test('hidden changes and authoring IDs cannot influence exposed-only agents',
      () {
    final original = _control();
    final altered = LevelDefinition(
        level: 96,
        name: original.name,
        timeBonusSeconds: original.timeBonusSeconds,
        objective: original.objective,
        tiles: [
          for (final t in original.tiles)
            Tile(
                id: 'renamed_${t.id}',
                type: t.id == 'L96_T094' ? 'concealed_secret' : t.type,
                x: t.x,
                y: t.y,
                layer: t.layer,
                state: t.state)
        ]);
    for (final screen in qaScreens) {
      VisibleCampaignBoard view(LevelDefinition l) =>
          CampaignObservation.capture(GameEngine(l.tiles),
                  CampaignGraph(l.tiles, screen.geometry()))
              .visible;
      final a = view(original), b = view(altered);
      expect(a.toJson(), b.toJson());
      expect(jsonEncode(b.toJson()), isNot(contains('concealed_secret')));
      expect(jsonEncode(b.toJson()), isNot(contains('renamed_')));
      for (final policy in shadow96Policies) {
        const priorities = PairedPriorities(96, 29, 0);
        final x = decideCampaignMove(a, policy, NoPairedRng(),
            tieBreak: priorities.compare);
        final y = decideCampaignMove(b, policy, NoPairedRng(),
            tieBreak: priorities.compare);
        expect(x.handle, y.handle);
        expect(x.nodes, y.nodes);
        expect(x.branchPruned, y.branchPruned);
      }
    }
  });

  test(
      'candidate results repeat exactly and wrapper preserves the paired-v1 policy',
      () {
    final control = _control(), candidate = makeLevel96Candidate(control);
    final original = shadowCanonical(shadowLevelValue(control));
    for (final screen in qaScreens)
      for (final policy in shadow96Policies) {
        final first =
            simulateLevel96Shadow(candidate, screen, policy, 29, 'candidate');
        final second =
            simulateLevel96Shadow(candidate, screen, policy, 29, 'candidate');
        expect(jsonEncode(first), jsonEncode(second));
        final raw = simulatePairedCampaign(
            candidate,
            CampaignGraph(candidate.tiles, screen.geometry()),
            policy,
            screen.name,
            29);
        expect(_raw(first), raw);
        expect(first['experiment_seed_uint32'],
            PairedPriorities(96, 29, 0).experimentSeed);
      }
    expect(shadowCanonical(shadowLevelValue(control)), original);
    expect(
        () => simulateLevel96Shadow(
            control, qaScreens.first, CampaignPolicy.randomLegal, 0, 'control'),
        throwsArgumentError);
    expect(
        () => simulateLevel96Shadow(control, qaScreens.first,
            CampaignPolicy.greedyMatch, 30, 'candidate'),
        throwsArgumentError);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test(
      'type-only observations do not become false geometric or physical move differences',
      () {
    final a = _synthetic(
        'control', qaScreens.first.name, CampaignPolicy.greedyMatch, 0,
        trace: [
          _step(0, ['a', 'b', 'c'], ['heart@a', 'b', 'c'], 'a', 'heart@a',
              reveal: ['star@d']),
          _step(1, ['b', 'c'], ['b', 'c'], 'b', 'b',
              tray: ['a'], trayTypes: ['heart']),
          _step(2, ['c'], ['c'], 'c', 'c', tray: ['a', 'b']),
        ]);
    final b = _synthetic(
        'candidate', qaScreens.first.name, CampaignPolicy.greedyMatch, 0,
        trace: [
          _step(0, ['a', 'b', 'c'], ['star@a', 'b', 'c'], 'a', 'star@a',
              reveal: ['heart@d']),
          _step(1, ['b', 'c'], ['b', 'c'], 'c', 'c',
              tray: ['a'], trayTypes: ['star']),
          _step(2, ['b'], ['b'], 'b', 'b', tray: ['a', 'c']),
        ]);
    final pair = compareShadowPaths(a, b);
    expect((pair['first_different_public_legal_set'] as Map)['decision'], 0);
    expect((pair['first_different_chosen_public_token'] as Map)['decision'], 0);
    expect((pair['first_different_chosen_tile'] as Map)['decision'], 1);
    expect((pair['first_different_chosen_tile'] as Map)['relation'],
        'SHARED_PHYSICAL_TAP_PREFIX');
    expect((pair['first_different_physical_legal_set'] as Map)['decision'], 2);
    expect((pair['first_different_physical_legal_set'] as Map)['relation'],
        'POST_DIVERGENCE_DESCRIPTIVE_ONLY');
    expect(
        (pair['first_different_reveal_tokens']
            as Map)['reveal_comparison_scope'],
        'SAME_PHYSICAL_TAP_FROM_SHARED_PREFIX');
    final short = {
      ...b,
      'trace': (b['trace'] as List).take(1).toList(),
      'outcome': 'INCONCLUSIVE'
    };
    expect(compareShadowPaths(a, short)['first_different_chosen_tile'], isNull);
    expect(
        (compareShadowPaths(a, short)['unmatched_tail']
            as Map)['first_unmatched_decision'],
        1);
  });

  test('report numeric reductions handle nonempty integer and mixed traces',
      () {
    for (final occupancies in <List<int>>[
      [],
      [4],
      [4, 6, 5]
    ]) {
      final trace = <CampaignJson>[
        for (var i = 0; i < occupancies.length; i++)
          {
            ..._step(7 + i, ['tile_$i'], ['a@$i'], 'tile_$i', 'a@$i'),
            'tray_after': occupancies[i],
            'pressure_after': occupancies[i] / 7,
          },
      ];
      final row = _synthetic(
          'candidate', qaScreens.first.name, CampaignPolicy.greedyMatch, 0,
          trace: trace);
      final expectedPeak = occupancies.isEmpty
          ? null
          : occupancies.length == 1
              ? 4
              : 6;
      final expectedPressure = occupancies.isEmpty
          ? null
          : occupancies.length == 1
              ? 4 / 7
              : 5 / 7;
      final metrics = shadowAttemptMetrics(row);
      expect(metrics['post_opening_peak'], expectedPeak);
      if (expectedPressure == null) {
        expect(metrics['post_opening_mean_pressure'], isNull);
      } else {
        expect(metrics['post_opening_mean_pressure'],
            closeTo(expectedPressure, 1e-12));
        expect(metrics['post_opening_peak'], isA<int>());
      }

      // _aggregate passes a runtime List<int> of occupancies into _mean.
      // Exercise totals, screen/cohort aggregates and Markdown, not just the
      // per-attempt metrics, including the empty and singleton branches.
      final summary = buildShadow96Summary([row], null, [],
          executionComplete: false, inputsUnchanged: true);
      final aggregate = summary['candidate'] as Map;
      expect(aggregate['max_tray_after_resolution'], expectedPeak);
      if (expectedPressure == null) {
        expect(aggregate['decision_weighted_mean_pressure'], isNull);
      } else {
        expect(aggregate['decision_weighted_mean_pressure'],
            closeTo(expectedPressure, 1e-12));
        expect(aggregate['max_tray_after_resolution'], isA<int>());
      }
      expect(
          shadow96Markdown({
            'run_id': 'numeric-fixture',
            'status': 'PARTIAL',
            'measurement_health': 'REVIEW_REQUIRED'
          }, summary),
          contains('1/360 attempts'));
    }

    for (final pressures in <List<num>>[
      <int>[0, 1],
      <double>[0.25, 0.75],
      <num>[0, 0.5, 1],
    ]) {
      final row = _synthetic(
          'candidate', qaScreens.first.name, CampaignPolicy.greedyMatch, 0,
          trace: [
            for (var i = 0; i < pressures.length; i++)
              {
                ..._step(7 + i, ['tile_$i'], ['a@$i'], 'tile_$i', 'a@$i'),
                'pressure_after': pressures[i],
              },
          ]);
      expect(shadowAttemptMetrics(row)['post_opening_mean_pressure'], 0.5);
    }
  });

  test(
      'fixed report cohorts, holdouts, regressions and cautious recommendation',
      () {
    final rows = <CampaignJson>[
      for (final v in shadow96Variants)
        for (final s in qaScreens)
          for (final p in shadow96Policies)
            for (var r = 0; r < 30; r++) _synthetic(v, s.name, p, r)
    ];
    final reproduction = <CampaignJson>[
      for (final s in qaScreens)
        for (final p in shadow96Policies)
          for (var r = 0; r < 10; r++)
            {
              'screen': s.name,
              'strategy': p.name,
              'replica': r,
              'passed': true
            },
    ];
    CampaignJson summary(List<CampaignJson> attempts) =>
        buildShadow96Summary(attempts, {'passed': true}, reproduction,
            executionComplete: true, inputsUnchanged: true);
    final result = summary(rows);
    expect(result['actual_attempts'], 360);
    expect((result['paired_outcomes'] as List).length, 180);
    expect((result['strategy_pairs'] as List).length, 180);
    expect((result['cells'] as List).length, 18);
    expect(result['control_reproduction_passed'], isTrue);
    final duplicated = buildShadow96Summary(rows, {'passed': true},
        List<CampaignJson>.filled(60, reproduction.first),
        executionComplete: true, inputsUnchanged: true);
    expect(duplicated['control_reproduction_passed'], isFalse);
    expect(duplicated['recommendation'], 'REVISE');
    expect(result['opening_trap_removed_in_sample'], isTrue);
    expect(result['recommendation'], 'ACCEPT FOR HUMAN REVIEW');
    expect(result['production_change_authorized'], isFalse);
    expect((result['candidate'] as Map)['losses_after_opening'], 6);
    final cells = result['cells'] as List;
    expect(
        cells.every((c) =>
            c['control']['attempts'] ==
            (c['cohort'] == 'overlap_0_9'
                ? 10
                : c['cohort'] == 'holdout_10_29'
                    ? 20
                    : 30)),
        isTrue);
    final regressed = [...rows];
    final index = regressed
        .indexWhere((a) => a['variant'] == 'control' && a['replica'] == 29);
    regressed[index] = {...regressed[index], 'outcome': 'WIN'};
    final regression = summary(regressed);
    expect(regression['recommendation'], 'REVISE');
    expect(
        (regression['worse_cases'] as List).any((p) =>
            (p['worse_metric_flags'] as List)
                .contains('CONTROL_WIN_TO_CANDIDATE_LOSS')),
        isTrue);
    final partial = buildShadow96Summary(rows.take(1).toList(), null, [],
        executionComplete: false, inputsUnchanged: true);
    expect(partial['recommendation'], 'REVISE');
    expect(partial['opening_trap_removed_in_sample'], isNull);
    expect(() => summary([...rows, rows.first]), throwsArgumentError);
    final report = shadow96Markdown({
      'run_id': 'fixture',
      'status': 'COMPLETE',
      'measurement_health': 'OK',
      'inputs_unchanged': true
    }, result);
    expect(report, contains('holdout_10_29'));
    expect(report, contains('ACCEPT FOR HUMAN REVIEW'));
    expect(report, contains('Greedy versus lookahead'));
  });

  test(
      'recommendation rejects failed gates and no improvement; never equates wins with design quality',
      () {
    CampaignJson decide(
            {bool gate = true,
            bool complete = true,
            bool improve = true,
            bool removed = true,
            bool holdout = true,
            bool challenge = false}) =>
        shadowRecommendation(
            gatePassed: gate,
            gateMeasured: true,
            evidenceComplete: complete,
            regressions: 0,
            openingImproved: improve,
            openingRemoved: removed,
            holdoutGainEveryScreen: holdout,
            challengeReviewFlag: challenge);
    expect(decide(gate: false)['recommendation'], 'REJECT');
    expect(decide(improve: false)['recommendation'], 'REJECT');
    expect(decide(complete: false)['recommendation'], 'REVISE');
    expect(decide(challenge: true)['recommendation'], 'REVISE');
    expect(decide(holdout: false)['recommendation'], 'REVISE');
    expect(decide(removed: false)['recommendation'], 'REVISE');
  });

  test(
      'unique output allocation cannot overwrite previous runs or accept arbitrary paths',
      () {
    final parent =
        Directory.systemTemp.createTempSync('level96-shadow-contract-');
    addTearDown(() => parent.deleteSync(recursive: true));
    final old = Directory('${parent.path}/old-run')..createSync();
    final oldFile = File('${old.path}/manifest.json')
      ..writeAsStringSync('historical sentinel');
    final first = ShadowRunOutput.create(parent: parent),
        second = ShadowRunOutput.create(parent: parent);
    expect(first.directory.path, isNot(second.directory.path));
    first.writeJson('manifest.json', {'status': 'fixture'});
    first.appendAttempt({'fixture': true});
    first.writeJson('summary.json', {'fixture': true});
    first.writeReport('fixture');
    final names =
        first.directory.listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(names,
        {'manifest.json', 'attempts.jsonl', 'summary.json', 'report.md'});
    final before =
        File('${first.directory.path}/manifest.json').readAsBytesSync();
    second.writeJson('manifest.json', {'status': 'second'});
    expect(File('${first.directory.path}/manifest.json').readAsBytesSync(),
        before);
    expect(() => first.writeJson('../old-run/manifest.json', {}),
        throwsArgumentError);
    expect(oldFile.readAsStringSync(), 'historical sentinel');
  });
}
