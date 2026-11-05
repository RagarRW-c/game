import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/level.dart';

import '../qa/support/geometry.dart';
import 'support/campaign_paired.dart';
import 'support/campaign_validation.dart';
import 'support/level96_phase4d5.dart';
import 'support/level96_phase4d5_io.dart';
import 'support/level96_phase4d5_report.dart';
import 'support/level96_shadow.dart';
import 'support/level96_shadow_io.dart';

LevelDefinition _production() => LevelDefinition.fromJson(
    jsonDecode(File(shadow96Asset).readAsStringSync()) as Map<String, dynamic>);

List<CampaignJson> _reproduction() => [
      for (final s in qaScreens)
        for (final p in shadow96Policies)
          {'screen': s.name, 'strategy': p.name, 'replica': 24, 'passed': true}
    ];

// Synthetic report fixtures only. They are never gameplay simulations or saved
// as experimental evidence. Every terminal row has a full indexed trace/path.
CampaignJson _fixture(CampaignJson identity, {String? outcome, int? lossTap}) {
  final won = outcome == null
      ? (identity['variant'] == 'control_a'
          ? identity['replica'] == 30
          : (identity['replica'] as int) < 33)
      : outcome == 'WIN';
  final decisions =
      won ? 99 : lossTap ?? (identity['variant'] == 'control_a' ? 31 : 79);
  return {
    ...identity,
    'outcome': won ? 'WIN' : 'LOSS',
    'decisions': decisions,
    'first_resolved_triple_decision': 2,
    'first_high_risk_decision': 6,
    'final_board_count': 99 - decisions,
    'final_tray_count': won ? 0 : 7,
    'path_ids': List.generate(decisions, (i) => 'fixture_$i'),
    'stop_reason': 'SYNTHETIC_REPORT_FIXTURE_NOT_A_SIMULATION',
    'trace': <CampaignJson>[
      for (var i = 0; i < decisions; i++)
        {
          'decision': i,
          'diagnostic_actual_chosen_id': 'fixture_$i',
          'chosen_token': 'fixture_token_$i',
          'diagnostic_remaining_ids': ['fixture_$i'],
          'diagnostic_tray_ids': <String>[],
          'diagnostic_legal_ids': ['fixture_$i'],
          'legal_tokens': ['fixture_token_$i'],
          'rankings': <CampaignJson>[],
          'candidates': <CampaignJson>[],
          'tray_types_before': <String>[],
          'tray_before': i % 3,
          'tray_after': i == decisions - 1 ? (won ? 0 : 7) : (i + 1) % 3,
          'pressure_after': i % 2 == 0 ? 0 : 0.5,
          'high_risk': false,
          'immediate_losing_choices': 0,
          'newly_selectable_tokens_after_tap': <String>[],
        }
    ],
  };
}

void main() {
  late Phase5Reference reference;
  late CampaignJson before;
  setUpAll(() async {
    before = shadowFingerprints(phase5InputPaths());
    reference = await loadPhase5Reference();
  });
  tearDownAll(() {
    expect(shadowFingerprints(phase5InputPaths()), before,
        reason:
            'Contracts must not change production, tooling or historical evidence');
  });

  test(
      'required files and opt-in runner physically exist in this Flutter project',
      () {
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('name: triple_tile_adventure'));
    for (final path in phase5ToolInputs) {
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(File(path).lengthSync(), greaterThan(0));
    }
    final runner = File('test/balance_audit/level96_phase4d5_run_test.dart')
        .readAsStringSync();
    expect(
        runner, contains("bool.fromEnvironment('CAMPAIGN_LEVEL96_PHASE4D5')"));
    expect(runner, contains('skip: !phase5Enabled'));
  });

  test(
      'both arms independently derive from untouched production with exact swaps',
      () {
    final production = _production();
    final original = shadowCanonical(shadowLevelValue(production));
    final a = makePhase5Variant(production, 'control_a');
    final b = makePhase5Variant(production, 'candidate_b');
    expect(phase5VariantChecks(production, a, 'control_a')['passed'], isTrue);
    expect(phase5VariantChecks(production, b, 'candidate_b')['passed'], isTrue);
    expect(phase5VariantChecks(production, a, 'control_a')['changed_type_ids'],
        ['L96_T094', 'L96_T095']);
    expect(
        phase5VariantChecks(production, b, 'candidate_b')['changed_type_ids'],
        ['L96_T069', 'L96_T071', 'L96_T094', 'L96_T095']);
    expect(shadowLevelValue(a),
        shadowLevelValue(makeLevel96Candidate(production)));
    expect(shadowInventory(a), shadowInventory(production));
    expect(shadowInventory(b), shadowInventory(production));
    expect(a.tiles.length, 99);
    for (var i = 0; i < 99; i++) {
      expect(identical(a.tiles[i], b.tiles[i]), isFalse);
      expect(identical(a.tiles[i], production.tiles[i]), isFalse);
      expect(identical(b.tiles[i], production.tiles[i]), isFalse);
    }
    expect(() => a.tiles[0] = b.tiles[0], throwsUnsupportedError);
    expect(shadowCanonical(shadowLevelValue(production)), original);
    expect(b.tiles.first.state, production.tiles.first.state);
    expect(
        shadowFileFingerprint(File(shadow96Asset)), shadow96AssetFingerprint);
    expect(
        () =>
            makePhase5Variant(makeLevel96Candidate(production), 'candidate_b'),
        throwsStateError);
    expect(() => makePhase5Variant(production, 'wrong'), throwsArgumentError);
    expect(phase5VariantChecks(production, production, 'control_a')['passed'],
        isFalse);
  });

  test(
      'metadata and objectives are independently preserved and drift is rejected',
      () {
    final p = _production();
    final withObjective = LevelDefinition(
        level: 96,
        name: p.name,
        timeBonusSeconds: p.timeBonusSeconds,
        tiles: p.tiles,
        objective: const LevelObjective(type: 'heart', target: 3));
    final a = makePhase5Variant(withObjective, 'control_a');
    final b = makePhase5Variant(withObjective, 'candidate_b');
    expect(a.objective!.type, 'heart');
    expect(b.objective!.target, 3);
    expect(identical(withObjective.objective, a.objective), isFalse);
    expect(identical(a.objective, b.objective), isFalse);
    final changed = LevelDefinition(
        level: 96,
        name: 'changed',
        tiles: b.tiles,
        timeBonusSeconds: p.timeBonusSeconds,
        objective: b.objective);
    expect(phase5VariantChecks(withObjective, changed, 'candidate_b')['passed'],
        isFalse);
  });

  test(
      'all six original stored witnesses fully clear A and B with equal geometry',
      () {
    final p = _production();
    final gate = phase5WitnessGate(p, makePhase5Variant(p, 'control_a'),
        makePhase5Variant(p, 'candidate_b'), reference.witnesses);
    expect(gate['passed'], isTrue);
    expect(gate['independent_arms'], isTrue);
    expect((gate['screens'] as List).length, 3);
    for (final screen in gate['screens'] as List) {
      expect(screen['geometry_and_bounds_equal'], isTrue);
      for (final arm in ['control_a_replay', 'candidate_b_replay']) {
        expect(screen[arm]['replay_success'], isTrue);
        expect(screen[arm]['full_clearance'], isTrue);
        expect(screen[arm]['successful_moves'], 99);
        expect(screen[arm]['final_board_count'], 0);
        expect(screen[arm]['final_tray_count'], 0);
      }
    }
  });

  test(
      'malformed and illegal witnesses fail closed with all screen diagnostics',
      () {
    final p = _production(),
        a = makePhase5Variant(_production(), 'control_a'),
        b = makePhase5Variant(_production(), 'candidate_b');
    final key = qaScreens.first.name;
    final duplicate = [...reference.witnesses[key]!];
    duplicate[1] = duplicate[0];
    final invalid =
        phase5WitnessGate(p, a, b, {...reference.witnesses, key: duplicate});
    expect(invalid['passed'], isFalse);
    expect((invalid['screens'] as List).length, 3);
    expect(
        (invalid['screens'] as List).first['candidate_b_replay']
            ['failure_reason'],
        'WITNESS_IS_NOT_A_FULL_TILE_PERMUTATION');
    final illegal = [...reference.witnesses[key]!];
    final first = illegal[0];
    illegal[0] = illegal.last;
    illegal[illegal.length - 1] = first;
    final rejected =
        phase5WitnessGate(p, a, b, {...reference.witnesses, key: illegal});
    expect(rejected['passed'], isFalse);
    expect(
        (rejected['screens'] as List).first['candidate_b_replay']
            ['failure_state']['decision'],
        0);
  });

  test('pinned historical input integrity and drift/missing rejection', () {
    expect(reference.candidateRows.length, 180);
    expect(reference.sourceManifest['status'], 'COMPLETE');
    expect(reference.diagnosticManifest['measurement_health'], 'OK');
    phase5RequireReferenceHashes(before);
    final altered = {
      ...before,
      phase5ReferenceFingerprints.keys.first: 'altered'
    };
    expect(() => phase5RequireReferenceHashes(altered), throwsStateError);
    expect(() => phase5RequireReferenceHashes({}), throwsStateError);
    expect(phase5InputsUnchanged(before, {...before}), isTrue);
    expect(phase5InputsUnchanged(before, altered), isFalse);
    expect(phase5InputsUnchanged({'x': 'MISSING'}, {'x': 'MISSING'}), isFalse);
    expect(phase5InputsUnchanged({}, {}), isFalse);
  });

  test('A reproduces all six historical replica-24 candidate traces exactly',
      () {
    final checks = phase5ReproduceHistoricalControl(
        makePhase5Variant(_production(), 'control_a'), reference);
    expect(checks, hasLength(6));
    expect(phase5ReproductionPassed(checks), isTrue,
        reason: jsonEncode(checks));
    expect(phase5ReproductionPassed(List.filled(6, checks.first)), isFalse);
    expect(
        phase5ReproductionPassed([
          {...checks.first, 'passed': false},
          ...checks.skip(1)
        ]),
        isFalse);
    final badKey =
        reference.candidateRows.keys.firstWhere((k) => k.endsWith('|24'));
    final corrupt = Phase5Reference(reference.sourceManifest,
        reference.diagnosticManifest, reference.historical, {
      ...reference.candidateRows,
      badKey: {...reference.candidateRows[badKey]!, 'trace': <CampaignJson>[]}
    });
    final failed = phase5ReproduceHistoricalControl(
        makePhase5Variant(_production(), 'control_a'), corrupt);
    expect(phase5ReproductionPassed(failed), isFalse);
    expect(failed.where((c) => c['passed'] == false).single['different_fields'],
        contains('trace'));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('paired determinism and hidden extra swap use public opening data only',
      () {
    final p = _production();
    final gate = phase5PairedGate(
        makePhase5Variant(p, 'control_a'), makePhase5Variant(p, 'candidate_b'));
    expect(gate['passed'], isTrue);
    expect(gate['checks'], hasLength(18));
    for (final replica in [30, 44, 59]) {
      final priorities = PairedPriorities(96, replica, 0);
      for (final s in qaScreens) {
        for (final policy in shadow96Policies) {
          expect(
              pairedAttemptIdentity(
                  96, s.name, policy, replica)['experiment_seed_uint32'],
              priorities.experimentSeed);
        }
      }
      const token = '["heart","0.2","0.3"]';
      expect(priorities.priority(token),
          PairedPriorities(96, replica, 0).priority(token));
      expect(priorities.priority(token),
          isNot(priorities.priority(token, plannedPath: [token])));
    }
  });

  test(
      'fixed schedule has exactly 360 unique identities and only replicas 30-59',
      () {
    final schedule = phase5Schedule();
    expect(schedule, hasLength(360));
    expect(schedule.map(phase5Key).toSet(), hasLength(360));
    expect(schedule.map((r) => r['replica']).toSet(),
        {for (var i = 30; i <= 59; i++) i});
    expect(schedule.every((r) => r['cohort'] == phase5Cohort), isTrue);
    for (final arm in phase5Variants) {
      for (final s in qaScreens) {
        for (final p in shadow96Policies) {
          expect(
              schedule.where((r) =>
                  r['variant'] == arm &&
                  r['screen'] == s.name &&
                  r['strategy'] == p.name),
              hasLength(30));
        }
      }
    }
    for (final replica in [29, 60]) {
      expect(
          () => simulatePhase5(_production(), qaScreens.first,
              CampaignPolicy.greedyMatch, replica, 'control_a'),
          throwsArgumentError);
    }
    expect(
        () => simulatePhase5(_production(), qaScreens.first,
            CampaignPolicy.randomLegal, 30, 'control_a'),
        throwsArgumentError);
    final alteredScreen =
        QaScreen(qaScreens.first.name, qaScreens.first.size, 0);
    expect(
        () => simulatePhase5(_production(), alteredScreen,
            CampaignPolicy.greedyMatch, 30, 'control_a'),
        throwsArgumentError);
  });

  test(
      'wrapper adds only labels and preserves raw paired data without re-seeding',
      () {
    for (final replica in [30, 59]) {
      final raw = pairedAttemptIdentity(
          96, qaScreens.first.name, CampaignPolicy.greedyMatch, replica);
      final wrapped = phase5Wrap(raw, 'candidate_b');
      final stripped = {...wrapped}
        ..remove('phase4d5_version')
        ..remove('variant')
        ..remove('cohort');
      expect(stripped, raw);
      expect(raw.containsKey('variant'), isFalse);
      expect(
          () =>
              phase5Wrap({...raw, 'experiment_seed_uint32': 0}, 'candidate_b'),
          throwsArgumentError);
    }
  });

  test(
      'accounting rejects duplicates, old seeds, wrong cohorts and truncated traces',
      () {
    final rows = phase5Schedule().map(_fixture).toList();
    expect(phase5Accounting(rows)['complete'], isTrue);
    expect(phase5Accounting(rows.take(359).toList())['complete'], isFalse);
    expect(() => phase5Accounting([...rows, rows.first]), throwsArgumentError);
    for (final mutation in <CampaignJson>[
      {'replica': 29},
      {'cohort': 'holdout_10_29'},
      {'experiment_seed_uint32': 0},
      {'phase4d5_version': shadow96Version},
      {'trace': <CampaignJson>[]},
      {'outcome': 'invented'},
      {'final_tray_count': 7},
    ]) {
      expect(
          () => phase5Accounting([
                {...rows.first, ...mutation},
                ...rows.skip(1)
              ]),
          throwsArgumentError);
    }
  });

  test(
      'complete reports are deterministic and contain all pairs, cells and mixed numeric traces',
      () {
    final rows = phase5Schedule().map(_fixture).toList();
    CampaignJson summarize(List<CampaignJson> data) =>
        buildPhase5Summary(data, {'passed': true}, _reproduction(),
            executionComplete: true, inputsUnchanged: true);
    final summary = summarize(rows);
    expect(summary['evidence_complete'], isTrue);
    expect(summary['actual_attempts'], 360);
    expect(summary['paired_outcomes'], hasLength(180));
    expect(summary['strategy_pairs'], hasLength(180));
    expect(summary['cells'], hasLength(6));
    expect(summary['screens'], hasLength(3));
    expect(summary['strategies'], hasLength(2));
    expect(summary['recommendation'], 'ACCEPT FOR HUMAN REVIEW');
    expect(summary['production_change_authorized'], isFalse);
    expect(jsonEncode(summary), jsonEncode(summarize(rows.reversed.toList())));
    final markdown = phase5Markdown({
      'run_id': 'synthetic',
      'status': 'COMPLETE',
      'measurement_health': 'OK',
      'inputs_unchanged': true
    }, summary);
    expect(markdown, contains('360/360'));
    expect(markdown, contains('30–59'));
    expect(markdown, contains('ACCEPT FOR HUMAN REVIEW'));
    expect(phase5Aggregate([])['peak_tray_after_resolution'], isNull);
    expect((summary['candidate_b'] as Map)['peak_tray_after_resolution'],
        isA<int>());
    expect((summary['candidate_b'] as Map)['post_opening_mean_pressure'],
        isA<double>());
  });

  test(
      'partial, gate-failed, drifted and inconclusive evidence cannot be accepted',
      () {
    final rows = phase5Schedule().map(_fixture).toList();
    CampaignJson summary(List<CampaignJson> data,
            {CampaignJson? gate,
            bool unchanged = true,
            List<CampaignJson>? checks}) =>
        buildPhase5Summary(data, gate, checks ?? _reproduction(),
            executionComplete: true, inputsUnchanged: unchanged);
    expect(summary([], gate: {'passed': false})['recommendation'], 'REJECT');
    expect(summary([])['recommendation'], 'REVISE');
    expect(
        summary(rows.take(359).toList(),
            gate: {'passed': true})['recommendation'],
        'REVISE');
    expect(
        summary(rows,
            gate: {'passed': true}, unchanged: false)['recommendation'],
        'REVISE');
    expect(summary(rows, gate: {'passed': true}, checks: [])['recommendation'],
        'REVISE');
    final inconclusive = [
      {...rows.first, 'outcome': 'INCONCLUSIVE', 'trace': <CampaignJson>[]},
      ...rows.skip(1)
    ];
    expect(summary(inconclusive, gate: {'passed': true})['recommendation'],
        'REVISE');
    final partial = summary(rows.take(1).toList());
    expect(
        phase5Markdown({
          'run_id': 'partial',
          'status': 'PARTIAL',
          'measurement_health': 'REVIEW_REQUIRED'
        }, partial),
        contains('1/360'));
  });

  test('every predeclared acceptance safeguard is exercised independently', () {
    CampaignJson decide(
            {bool gate = true,
            bool measured = true,
            bool complete = true,
            bool opening = true,
            int gain = 2,
            int reduction = 3,
            bool screens = true,
            bool noIncrease = true,
            int regressions = 0,
            int earlier = 0,
            bool challenge = false}) =>
        phase5Recommendation(
            gateMeasured: measured,
            gatePassed: gate,
            complete: complete,
            openingPreserved: opening,
            winGain: gain,
            tap31Reduction: reduction,
            everyScreenGains: screens,
            noScreenTap31Increase: noIncrease,
            winRegressions: regressions,
            earlierLosses: earlier,
            challengeFlag: challenge);
    expect(decide()['recommendation'], 'ACCEPT FOR HUMAN REVIEW');
    expect(decide(gate: false)['recommendation'], 'REJECT');
    expect(decide(measured: false)['recommendation'], 'REVISE');
    expect(decide(complete: false)['recommendation'], 'REVISE');
    expect(decide(opening: false)['recommendation'], 'REJECT');
    expect(decide(gain: 0, reduction: 0)['recommendation'], 'REJECT');
    for (final result in [
      decide(gain: 0),
      decide(reduction: 0),
      decide(screens: false),
      decide(noIncrease: false),
      decide(regressions: 1),
      decide(earlier: 1),
      decide(challenge: true)
    ]) {
      expect(result['recommendation'], 'REVISE');
    }
  });

  test(
      'fresh output allocation preserves old evidence and rejects path traversal',
      () {
    final root = Directory.systemTemp.createTempSync('phase4d5-contract-');
    addTearDown(() => root.deleteSync(recursive: true));
    final old = File('${root.path}/historical.json')
      ..writeAsStringSync('sentinel');
    final first = Phase5Output.create(parent: root),
        second = Phase5Output.create(parent: root);
    expect(first.directory.path, isNot(second.directory.path));
    expect(first.runId, startsWith('phase4d5-level96-'));
    final rows = phase5Schedule().map(_fixture).toList();
    final summary = buildPhase5Summary(rows, {'passed': true}, _reproduction(),
        executionComplete: true, inputsUnchanged: true);
    final manifest = <String, Object?>{
      'run_id': first.runId,
      'status': 'COMPLETE',
      'measurement_health': 'OK'
    };
    first.writeJson('manifest.json', manifest);
    first.writeJson('summary.json', summary);
    first.report(phase5Markdown(manifest, summary));
    for (final r in rows) {
      first.append(r);
    }
    expect(
        first.directory.listSync().map((f) => f.uri.pathSegments.last).toSet(),
        {'manifest.json', 'attempts.jsonl', 'summary.json', 'report.md'});
    expect(File('${first.directory.path}/attempts.jsonl').readAsLinesSync(),
        hasLength(360));
    final fingerprint =
        shadowFileFingerprint(File('${first.directory.path}/summary.json'));
    second.writeJson('summary.json', summary);
    expect(shadowFileFingerprint(File('${second.directory.path}/summary.json')),
        fingerprint);
    expect(
        () => first.writeJson('../historical.json', {}), throwsArgumentError);
    expect(old.readAsStringSync(), 'sentinel');
  });
}
