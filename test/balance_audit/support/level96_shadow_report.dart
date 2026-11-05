import 'dart:math' as math;

import '../../qa/support/geometry.dart';
import 'campaign_paired.dart';
import 'campaign_validation.dart';
import 'level96_shadow.dart';

List<CampaignJson> shadowTrace(CampaignJson row) =>
    (row['trace'] as List? ?? []).cast<CampaignJson>();
bool _same(Object? a, Object? b) => shadowCanonical(a) == shadowCanonical(b);
double? _mean(Iterable<num> values) {
  final list = values.toList();
  // A widened Iterable<num> may still produce a runtime List<int>. An explicit
  // double accumulator avoids reduce's reified element-type callback check.
  return list.isEmpty
      ? null
      : list.fold<double>(0.0, (sum, value) => sum + value) / list.length;
}

CampaignJson shadowAttemptMetrics(CampaignJson row) {
  final trace = shadowTrace(row);
  final later = trace.where((r) => (r['decision'] as int) >= 7).toList();
  final first = row['first_resolved_triple_decision'] as int?;
  return {
    for (final key in [
      'outcome',
      'stop_reason',
      'decisions',
      'final_board_count',
      'final_tray_count',
      'first_resolved_triple_decision',
      'first_available_triple_decision',
      'first_high_risk_decision',
      'max_tray_after_resolution',
      'max_tray_before_resolution',
      'average_tray_pressure'
    ])
      key: row[key],
    'first_completed_triple_tap': first == null ? null : first + 1,
    'completed_triple_by_tap_7': first != null && first < 7,
    'loss_after_exactly_7_taps':
        row['outcome'] == 'LOSS' && row['decisions'] == 7,
    'loss_after_opening':
        row['outcome'] == 'LOSS' && (row['decisions'] as int? ?? 0) > 7,
    'loss_after_any_completed_triple':
        row['outcome'] == 'LOSS' && first != null,
    'post_opening_decisions': later.length,
    'post_opening_mean_pressure':
        _mean(later.map((r) => r['pressure_after'] as num)),
    'post_opening_peak': later.isEmpty
        ? null
        : later
            .map((r) => r['tray_after'] as int)
            .reduce((int a, int b) => a > b ? a : b),
    'post_opening_high_risk_indices': later
        .where((r) => r['high_risk'] == true)
        .map((r) => r['decision'])
        .toList(),
    'post_opening_losing_choice_indices': later
        .where((r) => (r['immediate_losing_choices'] as int) > 0)
        .map((r) => r['decision'])
        .toList(),
    'reveal_decisions': trace
        .where(
            (r) => (r['newly_selectable_tokens_after_tap'] as List).isNotEmpty)
        .map((r) => r['decision'])
        .toList(),
    'loss_context': row['outcome'] != 'LOSS' || trace.isEmpty
        ? null
        : {
            for (final key in [
              'decision',
              'chosen_token',
              'diagnostic_actual_chosen_id',
              'tray_types_before',
              'tray_before',
              'tray_after',
              'legal_tokens',
              'immediate_losing_choices'
            ])
              key: trace.last[key],
          },
  };
}

/// Physical eligibility is separate from visible-token equality. Changing a
/// visible symbol is NOT a geometric eligibility change or a different tap ID.
CampaignJson compareShadowPaths(CampaignJson left, CampaignJson right) {
  if (left['experiment_version'] != pairedVersion ||
      left['level'] != 96 ||
      left['omniscient'] != false ||
      right['omniscient'] != false) {
    throw ArgumentError(
        'Only level 96 paired-v1 behavioral traces are comparable');
  }
  for (final key in [
    'experiment_version',
    'level',
    'replica',
    'experiment_seed_uint32',
    'screen'
  ]) {
    if (left[key] == null || left[key] != right[key])
      throw ArgumentError('Unpaired shadow $key');
  }
  final a = shadowTrace(left), b = shadowTrace(right);
  final n = math.min(a.length, b.length);
  final events = <CampaignJson>[];
  CampaignJson? firstLegal,
      firstPublic,
      firstMove,
      firstChosenPublic,
      firstReveal;
  var sharedPrefix = true;
  for (var i = 0; i < n; i++) {
    final x = a[i], y = b[i];
    final physicalLegal =
        !_same(x['diagnostic_legal_ids'], y['diagnostic_legal_ids']);
    final publicLegal = !_same(x['legal_tokens'], y['legal_tokens']);
    final move =
        x['diagnostic_actual_chosen_id'] != y['diagnostic_actual_chosen_id'];
    final publicMove = x['chosen_token'] != y['chosen_token'];
    final inventory =
        !_same(x['diagnostic_remaining_ids'], y['diagnostic_remaining_ids']) ||
            !_same(x['diagnostic_tray_ids'], y['diagnostic_tray_ids']);
    final reveal = !_same(x['newly_selectable_tokens_after_tap'],
        y['newly_selectable_tokens_after_tap']);
    final aligned = sharedPrefix && !inventory;
    final relation = aligned
        ? 'SHARED_PHYSICAL_TAP_PREFIX'
        : 'POST_DIVERGENCE_DESCRIPTIVE_ONLY';
    final event = <String, Object?>{
      'decision': i,
      'relation': relation,
      'physical_legal_set_differs': physicalLegal,
      'public_legal_tokens_differ': publicLegal,
      'chosen_physical_tile_differs': move,
      'chosen_public_token_differs': publicMove,
      'revealed_public_tokens_differ': reveal,
      'left_legal_ids': x['diagnostic_legal_ids'],
      'right_legal_ids': y['diagnostic_legal_ids'],
      'left_legal_tokens': x['legal_tokens'],
      'right_legal_tokens': y['legal_tokens'],
      'left_chosen_id': x['diagnostic_actual_chosen_id'],
      'right_chosen_id': y['diagnostic_actual_chosen_id'],
      'left_chosen_token': x['chosen_token'],
      'right_chosen_token': y['chosen_token'],
      'left_tray_types': x['tray_types_before'],
      'right_tray_types': y['tray_types_before'],
      'left_revealed_tokens': x['newly_selectable_tokens_after_tap'],
      'right_revealed_tokens': y['newly_selectable_tokens_after_tap'],
      'reveal_comparison_scope': aligned && !move
          ? 'SAME_PHYSICAL_TAP_FROM_SHARED_PREFIX'
          : 'DIFFERENT_CHOSEN_TAPS_OR_HISTORIES',
      'interpretation': !aligned
          ? 'Different histories; no identical-state causal comparison'
          : left['variant'] != right['variant']
              ? 'Symbol intervention at shared physical prefix; public state may already differ'
              : 'Strategy comparison at shared physical prefix',
    };
    if (physicalLegal) firstLegal ??= event;
    if (publicLegal) firstPublic ??= event;
    if (move) firstMove ??= event;
    if (publicMove) firstChosenPublic ??= event;
    if (reveal) firstReveal ??= event;
    if (physicalLegal ||
        publicLegal ||
        move ||
        publicMove ||
        inventory ||
        reveal) events.add(event);
    if (move || inventory) sharedPrefix = false;
  }
  return {
    'first_different_physical_legal_set': firstLegal,
    'first_different_public_legal_set': firstPublic,
    'first_different_chosen_tile': firstMove,
    'first_different_chosen_public_token': firstChosenPublic,
    'first_different_reveal_tokens': firstReveal,
    'divergent_decisions': events,
    'compared_decisions': n,
    'unmatched_tail': a.length == b.length
        ? null
        : {
            'first_unmatched_decision': n,
            'left_tail_length': a.length - n,
            'right_tail_length': b.length - n,
            'interpretation':
                'One attempt ended; no invented legal set or action'
          },
  };
}

CampaignJson _aggregate(List<CampaignJson> rows) {
  final metrics = rows.map(shadowAttemptMetrics).toList();
  final occupancies =
      rows.expand(shadowTrace).map((r) => r['tray_after'] as int).toList();
  final wins = rows.where((r) => r['outcome'] == 'WIN').length;
  return {
    'attempts': rows.length,
    'wins': wins,
    'losses': rows.where((r) => r['outcome'] == 'LOSS').length,
    'inconclusive': rows.where((r) => r['outcome'] == 'INCONCLUSIVE').length,
    'completion_rate': rows.isEmpty ? null : wins / rows.length,
    'completed_triple_by_tap_7':
        metrics.where((m) => m['completed_triple_by_tap_7'] == true).length,
    'seven_tap_losses':
        metrics.where((m) => m['loss_after_exactly_7_taps'] == true).length,
    'losses_after_opening':
        metrics.where((m) => m['loss_after_opening'] == true).length,
    'losses_after_completed_triple': metrics
        .where((m) => m['loss_after_any_completed_triple'] == true)
        .length,
    'decision_weighted_mean_pressure':
        occupancies.isEmpty ? null : _mean(occupancies)! / 7,
    'max_tray_after_resolution': occupancies.isEmpty
        ? null
        : occupancies.reduce((int a, int b) => a > b ? a : b),
    'first_completed_triple_taps': [
      for (final m in metrics) m['first_completed_triple_tap']
    ],
    'first_high_risk_decisions': [
      for (final m in metrics) m['first_high_risk_decision']
    ],
  };
}

String _key(String variant, String screen, String policy, int replica) =>
    '$variant|$screen|$policy|$replica';

CampaignJson shadowRecommendation(
    {required bool gatePassed,
    required bool gateMeasured,
    required bool evidenceComplete,
    required int regressions,
    required bool openingImproved,
    required bool openingRemoved,
    required bool holdoutGainEveryScreen,
    required bool challengeReviewFlag}) {
  String decision, reason;
  if (gateMeasured && !gatePassed) {
    decision = 'REJECT';
    reason =
        'Required invariant/witness gate failed. Reject this candidate for comparison until the recorded failure is investigated; this does not prove unsolvability.';
  } else if (!gateMeasured || !evidenceComplete) {
    decision = 'REVISE';
    reason =
        'Evidence incomplete, drifted or control reproduction failed. Repair measurement before drawing a balance conclusion.';
  } else if (regressions > 0) {
    decision = 'REVISE';
    reason =
        'At least one paired control win became a candidate loss; inspect regressions before human review.';
  } else if (!openingImproved) {
    decision = 'REJECT';
    reason =
        'The candidate did not reduce seven-tap losses and increase early completed triples in this fixed sample.';
  } else if (!openingRemoved ||
      !holdoutGainEveryScreen ||
      challengeReviewFlag) {
    decision = 'REVISE';
    reason =
        'Opening improvement alone is insufficient: inspect remaining opening failures, holdout completion by screen, and challenge screening flags.';
  } else {
    decision = 'ACCEPT FOR HUMAN REVIEW';
    reason =
        'Gates and exact reproduction passed; the sampled opening trap disappeared, holdout completions improved on each screen, and no win-to-loss regression was observed. Remaining losses still require review.';
  }
  return {
    'recommendation': decision,
    'reason': reason,
    'production_change_authorized': false,
    'human_fairness': 'UNVERIFIED',
    'challenge_caveat':
        'No calibrated difficulty target exists. Any 100%-winning screen/strategy cell flags possible over-easing for review, not proof of easy human play.'
  };
}

CampaignJson buildShadow96Summary(List<CampaignJson> attempts,
    CampaignJson? gate, List<CampaignJson> reproduction,
    {required bool executionComplete, required bool inputsUnchanged}) {
  final indexed = <String, CampaignJson>{};
  for (final row in attempts) {
    if (row['level'] != 96 ||
        row['experiment_version'] != pairedVersion ||
        row['shadow_experiment_version'] != shadow96Version ||
        row['omniscient'] != false ||
        !shadow96Variants.contains(row['variant']) ||
        !qaScreens.any((s) => s.name == row['screen']) ||
        !shadow96Policies.any((p) => p.name == row['strategy']) ||
        row['replica'] is! int ||
        (row['replica'] as int) < 0 ||
        (row['replica'] as int) >= 30 ||
        !['WIN', 'LOSS', 'INCONCLUSIVE'].contains(row['outcome']))
      throw ArgumentError('Invalid shadow cohort row');
    if (row['experiment_seed_uint32'] !=
        PairedPriorities(96, row['replica'] as int, 0).experimentSeed) {
      throw ArgumentError('Incorrect paired-v1 experiment seed');
    }
    final key = _key(row['variant'] as String, row['screen'] as String,
        row['strategy'] as String, row['replica'] as int);
    if (indexed.containsKey(key))
      throw ArgumentError('Duplicate shadow row $key');
    indexed[key] = row;
  }
  final cells = <CampaignJson>[], pairs = <CampaignJson>[];
  for (final screen in qaScreens) {
    for (final policy in shadow96Policies) {
      for (final cohort in ['overlap_0_9', 'holdout_10_29', 'all_0_29']) {
        final replicas = cohort == 'overlap_0_9'
            ? List.generate(10, (i) => i)
            : cohort == 'holdout_10_29'
                ? List.generate(20, (i) => i + 10)
                : List.generate(30, (i) => i);
        final control = <CampaignJson>[],
            candidate = <CampaignJson>[],
            cellPairs = <CampaignJson>[];
        final missing = <int>[];
        for (final replica in replicas) {
          final a = indexed[_key('control', screen.name, policy.name, replica)];
          final b =
              indexed[_key('candidate', screen.name, policy.name, replica)];
          if (a != null) control.add(a);
          if (b != null) candidate.add(b);
          if (a == null || b == null) {
            missing.add(replica);
            continue;
          }
          if (cohort != 'all_0_29') continue;
          final am = shadowAttemptMetrics(a), bm = shadowAttemptMetrics(b);
          final flags = <String>[
            if (a['outcome'] == 'WIN' && b['outcome'] == 'LOSS')
              'CONTROL_WIN_TO_CANDIDATE_LOSS',
            if (a['outcome'] == 'LOSS' &&
                b['outcome'] == 'LOSS' &&
                (b['decisions'] as int) < (a['decisions'] as int))
              'EARLIER_LOSS',
            if (am['completed_triple_by_tap_7'] == true &&
                bm['completed_triple_by_tap_7'] != true)
              'LOST_EARLY_TRIPLE',
            if (am['loss_after_exactly_7_taps'] != true &&
                bm['loss_after_exactly_7_taps'] == true)
              'NEW_SEVEN_TAP_LOSS',
            if (a['first_high_risk_decision'] is int &&
                b['first_high_risk_decision'] is int &&
                (b['first_high_risk_decision'] as int) <
                    (a['first_high_risk_decision'] as int))
              'EARLIER_HIGH_RISK',
            if (a['first_resolved_triple_decision'] is int &&
                b['first_resolved_triple_decision'] is int &&
                (b['first_resolved_triple_decision'] as int) >
                    (a['first_resolved_triple_decision'] as int))
              'LATER_FIRST_COMPLETED_TRIPLE',
            if (a['max_tray_after_resolution'] is num &&
                b['max_tray_after_resolution'] is num &&
                (b['max_tray_after_resolution'] as num) >
                    (a['max_tray_after_resolution'] as num))
              'HIGHER_TRAY_PEAK_PATH_DEPENDENT',
            if (a['average_tray_pressure'] is num &&
                b['average_tray_pressure'] is num &&
                (b['average_tray_pressure'] as num) >
                    (a['average_tray_pressure'] as num))
              'HIGHER_MEAN_PRESSURE_PATH_DEPENDENT',
          ];
          final pair = <String, Object?>{
            'screen': screen.name,
            'strategy': policy.name,
            'replica': replica,
            'cohort': replica < 10 ? 'overlap_0_9' : 'holdout_10_29',
            'outcome_pair': '${a['outcome']}/${b['outcome']}',
            'control': am,
            'candidate': bm,
            'worse_metric_flags': flags,
            ...compareShadowPaths(a, b),
          };
          pairs.add(pair);
          cellPairs.add(pair);
        }
        final ca = _aggregate(control), cb = _aggregate(candidate);
        cells.add({
          'screen': screen.name,
          'strategy': policy.name,
          'cohort': cohort,
          'control': ca,
          'candidate': cb,
          'missing_replica_pairs': missing,
          'wins_delta': (cb['wins'] as int) - (ca['wins'] as int),
          'completion_rate_delta': control.isEmpty || candidate.isEmpty
              ? null
              : (cb['completion_rate'] as double) -
                  (ca['completion_rate'] as double),
          if (cohort == 'all_0_29')
            'outcome_matrix': {
              for (final x in ['WIN', 'LOSS', 'INCONCLUSIVE'])
                for (final y in ['WIN', 'LOSS', 'INCONCLUSIVE'])
                  '$x/$y': cellPairs
                      .where((p) => p['outcome_pair'] == '$x/$y')
                      .length
            },
        });
      }
    }
  }
  final strategyPairs = <CampaignJson>[];
  for (final variant in shadow96Variants)
    for (final screen in qaScreens)
      for (var replica = 0; replica < 30; replica++) {
        final a = indexed[_key(variant, screen.name, 'greedyMatch', replica)];
        final b =
            indexed[_key(variant, screen.name, 'visibleLookahead', replica)];
        if (a != null && b != null)
          strategyPairs.add({
            'variant': variant,
            'screen': screen.name,
            'replica': replica,
            'greedy': shadowAttemptMetrics(a),
            'lookahead': shadowAttemptMetrics(b),
            ...compareShadowPaths(a, b)
          });
      }
  final control = attempts.where((a) => a['variant'] == 'control').toList();
  final candidate = attempts.where((a) => a['variant'] == 'candidate').toList();
  final ca = _aggregate(control), cb = _aggregate(candidate);
  final requiredReproductions = {
    for (final screen in qaScreens)
      for (final policy in shadow96Policies)
        for (var r = 0; r < 10; r++) '${screen.name}|${policy.name}|$r',
  };
  final recordedReproductions = {
    for (final r in reproduction)
      '${r['screen']}|${r['strategy']}|${r['replica']}',
  };
  final reproductionPassed = reproduction.length == 60 &&
      recordedReproductions.length == 60 &&
      recordedReproductions.containsAll(requiredReproductions) &&
      reproduction.every((r) => r['passed'] == true);
  final complete = executionComplete &&
      attempts.length == 360 &&
      attempts.every((a) => a['outcome'] != 'INCONCLUSIVE') &&
      gate?['passed'] == true &&
      inputsUnchanged &&
      reproductionPassed;
  final removed = complete &&
      cb['completed_triple_by_tap_7'] == 180 &&
      cb['seven_tap_losses'] == 0;
  final improved =
      (cb['seven_tap_losses'] as int) < (ca['seven_tap_losses'] as int) &&
          (cb['completed_triple_by_tap_7'] as int) >
              (ca['completed_triple_by_tap_7'] as int);
  final screenChanges = <CampaignJson>[];
  for (final screen in qaScreens) {
    final holdout = cells
        .where(
            (c) => c['screen'] == screen.name && c['cohort'] == 'holdout_10_29')
        .toList();
    screenChanges.add({
      'screen': screen.name,
      'holdout_wins_delta':
          holdout.fold<int>(0, (n, c) => n + (c['wins_delta'] as int)),
      'control':
          _aggregate(control.where((a) => a['screen'] == screen.name).toList()),
      'candidate': _aggregate(
          candidate.where((a) => a['screen'] == screen.name).toList())
    });
  }
  final challengeFlags = [
    for (final c in cells.where((c) => c['cohort'] == 'all_0_29'))
      if ((c['candidate'] as Map)['attempts'] == 30 &&
          (c['candidate'] as Map)['wins'] == 30)
        '${c['screen']}/${c['strategy']}: candidate won all 30 sampled attempts'
  ];
  final regressions = pairs
      .where((p) => (p['worse_metric_flags'] as List)
          .contains('CONTROL_WIN_TO_CANDIDATE_LOSS'))
      .length;
  return {
    'shadow_experiment_version': shadow96Version,
    'planned_attempts': 360,
    'actual_attempts': attempts.length,
    'evidence_complete': complete,
    'gate': gate,
    'control_reproduction_passed': reproductionPassed,
    'control_reproduction': reproduction,
    'control': ca,
    'candidate': cb,
    'cells': cells,
    'screen_changes': screenChanges,
    'paired_outcomes': pairs,
    'strategy_pairs': strategyPairs,
    'opening_trap_removed_in_sample': complete ? removed : null,
    'opening_definition':
        'A completed triple by tap 7 in every candidate attempt and zero seven-tap losses; no claim beyond the sampled exposed-only agents',
    'challenge_review_flags': challengeFlags,
    'worse_cases': pairs
        .where((p) => (p['worse_metric_flags'] as List).isNotEmpty)
        .toList(),
    'remaining_problematic_attempts': [
      for (final a in candidate.where((a) => a['outcome'] != 'WIN'))
        {
          'screen': a['screen'],
          'strategy': a['strategy'],
          'replica': a['replica'],
          ...shadowAttemptMetrics(a)
        }
    ],
    'new_risk_interpretation':
        'Later candidate losses reveal remaining difficulty on newly reached histories. They are not proof of newly introduced structural traps. Pressure comparisons also depend on path length.',
    ...shadowRecommendation(
        gatePassed: gate?['passed'] == true,
        gateMeasured: gate != null,
        evidenceComplete: complete,
        regressions: regressions,
        openingImproved: improved,
        openingRemoved: removed,
        holdoutGainEveryScreen:
            screenChanges.every((s) => (s['holdout_wins_delta'] as int) > 0),
        challengeReviewFlag: challengeFlags.isNotEmpty),
  };
}

String shadow96Markdown(CampaignJson manifest, CampaignJson summary) {
  final out = StringBuffer(
      '# Phase 4D-3 — Level 96 shadow balance experiment\n\n')
    ..writeln(
        'Run `${manifest['run_id']}`; **${manifest['status']}**; health **${manifest['measurement_health']}**.')
    ..writeln(
        '\nRecommendation: **${summary['recommendation']}**. ${summary['reason']}')
    ..writeln(
        '\nThis recommendation does not authorize a production edit. Human fairness and the desired challenge remain unverified.')
    ..writeln(
        '\nControl: unchanged level_96.json. Candidate: independent in-memory copy, L96_T094 heart→star and L96_T095 star→heart. All other fields, order, inventory, objectives and geometry must remain equal.')
    ..writeln(
        '\n${summary['actual_attempts']}/360 attempts. Paired-v1 namespace and policies are unchanged; variant never enters seed or priority. Replicas 0–9 overlap the fixed previous run; 10–29 are holdout observations.')
    ..writeln('\n## Gates and provenance\n')
    ..writeln(
        'Exact control reproduction: ${summary['control_reproduction_passed']}. Input stability: ${manifest['inputs_unchanged']}. Inspect manifest reference hashes/snapshots and summary full-row reproduction differences.');
  final gate = summary['gate'] as Map?;
  out.writeln('\nCandidate invariants: ${gate?['invariants']}.');
  out
    ..writeln(
        '\n| Screen | Control replay | Candidate replay | Post-resolution peaks C/A | Moves C/A | Graph equal | Bounds equal |')
    ..writeln('|---|---|---|---|---|---|---|');
  for (final g in (gate?['screens'] as List? ?? [])) {
    out.writeln(
        '| ${g['screen']} | ${g['control_replay']['replay_success']} | ${g['candidate_replay']['replay_success']} | ${g['control_replay']['tray_peak_after_resolution']} / ${g['candidate_replay']['tray_peak_after_resolution']} | ${g['control_replay']['successful_moves']} / ${g['candidate_replay']['successful_moves']} | ${g['blocking_graph_equal']} | ${g['bounds_equal']} |');
    if (g['passed'] != true)
      out.writeln(
          '\nGate failure: control ${g['control_replay']['failure_reason']} ${g['control_replay']['failure_state']}; candidate ${g['candidate_replay']['failure_reason']} ${g['candidate_replay']['failure_state']}. Behavioral comparison is blocked; failed witness is not an unsolvability proof.\n');
  }
  out
    ..writeln('\n## Outcomes by screen, strategy and cohort\n')
    ..writeln(
        '| Screen | Strategy | Cohort | Control W/L/I | Candidate W/L/I | Win delta | Seven-tap losses C/A | Early triples C/A |')
    ..writeln('|---|---|---|---|---|---|---|---|');
  String totals(dynamic r) =>
      '${r['wins']}/${r['losses']}/${r['inconclusive']}';
  for (final c in summary['cells'] as List) {
    out.writeln(
        '| ${c['screen']} | ${c['strategy']} | ${c['cohort']} | ${totals(c['control'])} | ${totals(c['candidate'])} | ${c['wins_delta']} | ${c['control']['seven_tap_losses']} / ${c['candidate']['seven_tap_losses']} | ${c['control']['completed_triple_by_tap_7']} / ${c['candidate']['completed_triple_by_tap_7']} |');
  }
  out
    ..writeln('\n## Opening and remaining difficulty\n')
    ..writeln(
        'Opening trap removed in the sampled cohort: **${summary['opening_trap_removed_in_sample'] ?? 'UNVERIFIED'}**. ${summary['opening_definition']}.')
    ..writeln(
        '\nCandidate losses after the opening: ${(summary['candidate'] as Map)['losses_after_opening']}; after any completed triple: ${(summary['candidate'] as Map)['losses_after_completed_triple']}. ${summary['new_risk_interpretation']}')
    ..writeln(
        '\nChallenge screening: ${summary['challenge_review_flags']}. More wins alone are not evidence of better design. The acceptance rule also requires opening improvement, holdout gains on every screen, no win-to-loss regression and no fully winning screen/strategy cell; these are screening rules, not a human difficulty calibration.')
    ..writeln(
        '\nPhysical legal IDs and public symbol/position tokens are compared separately. A type swap can change public legal tokens at decision zero without changing which tiles are selectable. Shared physical tap prefixes still have different symbol states. After different taps, later comparisons are descriptive only. Reveals are recorded after actual taps; they do not enter preceding plans.')
    ..writeln('\n## Every paired outcome\n')
    ..writeln(
        '| Screen | Strategy | Replica | C/A outcome | First legal IDs / public tokens | First chosen tile | First completed triple tap C/A | First high risk index C/A | Tray peak C/A | Mean pressure C/A | Worse metrics |')
    ..writeln('|---|---|---|---|---|---|---|---|---|---|---|');
  Object event(dynamic e) =>
      e == null ? 'none observed' : e['decision'] as Object;
  for (final p in summary['paired_outcomes'] as List) {
    final a = p['control'], b = p['candidate'];
    String metric(String k) => '${a[k] ?? 'none'} / ${b[k] ?? 'none'}';
    out.writeln(
        '| ${p['screen']} | ${p['strategy']} | ${p['replica']} | ${p['outcome_pair']} | ${event(p['first_different_physical_legal_set'])} / ${event(p['first_different_public_legal_set'])} | ${event(p['first_different_chosen_tile'])} | ${metric('first_completed_triple_tap')} | ${metric('first_high_risk_decision')} | ${metric('max_tray_after_resolution')} | ${metric('average_tray_pressure')} | ${p['worse_metric_flags']} |');
  }
  out
    ..writeln('\n## Greedy versus lookahead\n')
    ..writeln(
        '| Variant | Screen | Replica | Greedy / lookahead | First differing physical move |')
    ..writeln('|---|---|---|---|---|');
  for (final p in summary['strategy_pairs'] as List) {
    out.writeln(
        '| ${p['variant']} | ${p['screen']} | ${p['replica']} | ${p['greedy']['outcome']} / ${p['lookahead']['outcome']} | ${event(p['first_different_chosen_tile'])} |');
  }
  out
    ..writeln(
        '\nAll worse cases, terminal loss contexts, post-opening high-risk/losing-choice indices, reveal differences and unmatched tails are retained in summary.json. Full candidate sets, priorities, greedy rankings and lookahead branches are in attempts.jsonl. Null means not observed, never proof of agreement beyond a missing trace.')
    ..writeln(
        '\nLookahead remains depth 3, branch cap 4, expansion cap 84, exposed-only, without future reveal prediction, partial visibility or persistent memory. Unknown later traps require further evidence; no sample expansion or replacement solver is performed. All production files, level assets, prior runs and both Endless modes remain unchanged.');
  return out.toString();
}
