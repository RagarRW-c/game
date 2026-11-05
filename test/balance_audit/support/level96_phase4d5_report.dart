import '../../qa/support/geometry.dart';
import 'campaign_validation.dart';
import 'level96_phase4d5.dart';
import 'level96_phase4d5_io.dart';
import 'level96_shadow.dart';
import 'level96_shadow_report.dart';

// Frozen before observing any 30-59 outcomes. These are review gates, not a
// calibrated human difficulty target or a statistical significance claim.
const phase5AcceptanceRules = {
  'version': 'phase4d5-acceptance-v1',
  'gate_failure': 'REJECT; no experimental attempts',
  'incomplete_drift_or_unverified': 'REVISE measurement',
  'opening_requirement':
      'All 180 B attempts first triple at tap 3; zero B losses at or before tap 7',
  'accept_win_gain':
      'B wins strictly exceed A overall and on each of three screens',
  'accept_target_cluster':
      'B tap-31 losses strictly fewer overall; no screen increases tap-31 losses',
  'accept_regressions':
      'Zero A-win/B-loss pairs and zero paired earlier B losses when both lose',
  'challenge_screen':
      'Any B screen/strategy cell with 30/30 wins requires REVISE for challenge review',
  'no_measured_gain':
      'REJECT when B wins do not increase and tap-31 losses do not decrease',
  'otherwise': 'REVISE; inspect mixed effects and cluster migration',
  'accept_label': 'ACCEPT FOR HUMAN REVIEW',
  'human_win_rate':
      'UNVERIFIED; bot rates are descriptive, paired and correlated',
  'production_change_authorized': false,
  'automatic_budget_expansion_or_candidate_tuning': false,
};

CampaignJson phase5Aggregate(List<CampaignJson> rows) {
  final occupancies =
      rows.expand(shadowTrace).map((s) => s['tray_after'] as int).toList();
  final later = rows
      .expand(shadowTrace)
      .where((s) => (s['decision'] as int) >= 7)
      .toList();
  double? mean(Iterable<num> items) {
    final list = items.toList();
    return list.isEmpty
        ? null
        : list.fold<double>(0.0, (sum, x) => sum + x) / list.length;
  }

  final lossTaps = <String, int>{};
  for (final row in rows.where((r) => r['outcome'] == 'LOSS')) {
    final tap = '${row['decisions']}';
    lossTaps.update(tap, (n) => n + 1, ifAbsent: () => 1);
  }
  final taps = lossTaps.keys.toList()
    ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  final wins = rows.where((r) => r['outcome'] == 'WIN').length;
  return {
    'attempts': rows.length,
    'wins': wins,
    'losses': rows.where((r) => r['outcome'] == 'LOSS').length,
    'inconclusive': rows.where((r) => r['outcome'] == 'INCONCLUSIVE').length,
    'bot_completion_rate': rows.isEmpty ? null : wins / rows.length,
    'loss_taps': {for (final t in taps) t: lossTaps[t]},
    'tap31_losses': lossTaps['31'] ?? 0,
    'first_triple_at_tap3':
        rows.where((r) => r['first_resolved_triple_decision'] == 2).length,
    'losses_at_or_before_tap7': rows
        .where((r) => r['outcome'] == 'LOSS' && (r['decisions'] as int) <= 7)
        .length,
    'seven_tap_losses': lossTaps['7'] ?? 0,
    'decision_weighted_mean_pressure': mean(occupancies.map((x) => x / 7)),
    'post_opening_mean_pressure':
        mean(later.map((s) => s['pressure_after'] as num)),
    'peak_tray_after_resolution': occupancies.isEmpty
        ? null
        : occupancies.reduce((int a, int b) => a > b ? a : b),
    'lookahead_budget_exhausted_decisions': rows.fold<int>(0,
        (n, r) => n + (r['lookahead_budget_exhausted_decisions'] as int? ?? 0)),
  };
}

CampaignJson phase5Recommendation(
    {required bool gateMeasured,
    required bool gatePassed,
    required bool complete,
    required bool openingPreserved,
    required int winGain,
    required int tap31Reduction,
    required bool everyScreenGains,
    required bool noScreenTap31Increase,
    required int winRegressions,
    required int earlierLosses,
    required bool challengeFlag}) {
  String decision, reason;
  if (gateMeasured && !gatePassed) {
    decision = 'REJECT';
    reason = 'Required correctness gate failed; no unsolvability inference.';
  } else if (!gateMeasured || !complete) {
    decision = 'REVISE';
    reason = 'Incomplete or unhealthy measurement; no balance conclusion.';
  } else if (!openingPreserved) {
    decision = 'REJECT';
    reason = 'The established tap-3 opening behavior regressed.';
  } else if (winGain <= 0 && tap31Reduction <= 0) {
    decision = 'REJECT';
    reason =
        'Neither total completion nor the targeted tap-31 cluster improved.';
  } else if (winGain > 0 &&
      tap31Reduction > 0 &&
      everyScreenGains &&
      noScreenTap31Increase &&
      winRegressions == 0 &&
      earlierLosses == 0 &&
      !challengeFlag) {
    decision = 'ACCEPT FOR HUMAN REVIEW';
    reason =
        'All predeclared descriptive improvement and regression checks passed; human fairness remains unverified.';
  } else {
    decision = 'REVISE';
    reason =
        'Mixed effects, paired regressions, uneven screen gains or a challenge-review flag.';
  }
  return {
    'recommendation': decision,
    'reason': reason,
    'production_change_authorized': false,
    'human_fairness': 'UNVERIFIED'
  };
}

CampaignJson buildPhase5Summary(List<CampaignJson> attempts, CampaignJson? gate,
    List<CampaignJson> reproduction,
    {required bool executionComplete, required bool inputsUnchanged}) {
  final accounting = phase5Accounting(attempts);
  final rows = [...attempts]
    ..sort((a, b) => phase5Key(a).compareTo(phase5Key(b)));
  final indexed = {for (final row in rows) phase5Key(row): row};
  final totals = {
    for (final v in phase5Variants)
      v: phase5Aggregate(rows.where((r) => r['variant'] == v).toList())
  };
  final cells = <CampaignJson>[],
      screens = <CampaignJson>[],
      strategies = <CampaignJson>[];
  for (final s in qaScreens) {
    screens.add({
      'screen': s.name,
      for (final v in phase5Variants)
        v: phase5Aggregate(rows
            .where((r) => r['variant'] == v && r['screen'] == s.name)
            .toList())
    });
    for (final p in shadow96Policies) {
      cells.add({
        'screen': s.name,
        'strategy': p.name,
        'cohort': phase5Cohort,
        for (final v in phase5Variants)
          v: phase5Aggregate(rows
              .where((r) =>
                  r['variant'] == v &&
                  r['screen'] == s.name &&
                  r['strategy'] == p.name)
              .toList())
      });
    }
  }
  for (final p in shadow96Policies) {
    strategies.add({
      'strategy': p.name,
      for (final v in phase5Variants)
        v: phase5Aggregate(rows
            .where((r) => r['variant'] == v && r['strategy'] == p.name)
            .toList())
    });
  }
  final pairs = <CampaignJson>[], strategyPairs = <CampaignJson>[];
  for (final s in qaScreens) {
    for (final p in shadow96Policies) {
      for (var r = 30; r <= 59; r++) {
        final a = indexed['control_a|${s.name}|${p.name}|$r'];
        final b = indexed['candidate_b|${s.name}|${p.name}|$r'];
        if (a == null || b == null) continue;
        pairs.add({
          'screen': s.name,
          'strategy': p.name,
          'replica': r,
          'control_a': shadowAttemptMetrics(a),
          'candidate_b': shadowAttemptMetrics(b),
          'win_to_loss': a['outcome'] == 'WIN' && b['outcome'] == 'LOSS',
          'earlier_candidate_loss': a['outcome'] == 'LOSS' &&
              b['outcome'] == 'LOSS' &&
              (b['decisions'] as int) < (a['decisions'] as int),
          'path_comparison': compareShadowPaths(a, b)
        });
      }
    }
    for (final v in phase5Variants) {
      for (var r = 30; r <= 59; r++) {
        final a = indexed['$v|${s.name}|greedyMatch|$r'];
        final b = indexed['$v|${s.name}|visibleLookahead|$r'];
        if (a == null || b == null) continue;
        strategyPairs.add({
          'variant': v,
          'screen': s.name,
          'replica': r,
          'greedy_outcome': a['outcome'],
          'lookahead_outcome': b['outcome'],
          'path_comparison': compareShadowPaths(a, b)
        });
      }
    }
  }
  final a = totals['control_a']!, b = totals['candidate_b']!;
  final reproductionPassed = phase5ReproductionPassed(reproduction);
  final complete = executionComplete &&
      inputsUnchanged &&
      accounting['complete'] == true &&
      reproductionPassed &&
      rows.every((r) => ['WIN', 'LOSS'].contains(r['outcome']));
  final winRegressions = pairs.where((p) => p['win_to_loss'] == true).length;
  final earlier =
      pairs.where((p) => p['earlier_candidate_loss'] == true).length;
  final screenGains = screens.every((s) =>
      (s['candidate_b'] as Map)['wins'] > (s['control_a'] as Map)['wins']);
  final noScreenIncrease = screens.every((s) =>
      (s['candidate_b'] as Map)['tap31_losses'] <=
      (s['control_a'] as Map)['tap31_losses']);
  final challenge = cells.any((c) => (c['candidate_b'] as Map)['wins'] == 30);
  final opening =
      b['first_triple_at_tap3'] == 180 && b['losses_at_or_before_tap7'] == 0;
  return {
    'schema': phase5Version,
    ...accounting,
    'evidence_complete': complete,
    'cohort': phase5Cohort,
    'replica_indices': List.generate(30, (i) => i + 30),
    'acceptance_rules': phase5AcceptanceRules,
    'correctness_gate': gate,
    'historical_reproduction_passed': reproductionPassed,
    ...totals,
    'cells': cells,
    'screens': screens,
    'strategies': strategies,
    'paired_outcomes': pairs,
    'strategy_pairs': strategyPairs,
    'win_gain': (b['wins'] as int) - (a['wins'] as int),
    'tap31_loss_reduction':
        (a['tap31_losses'] as int) - (b['tap31_losses'] as int),
    'win_to_loss_regressions': winRegressions,
    'earlier_paired_losses': earlier,
    'every_screen_gains': screenGains,
    'no_screen_tap31_increase': noScreenIncrease,
    'opening_preserved': complete ? opening : null,
    'challenge_review_flag': challenge,
    'worse_cases': pairs
        .where((p) =>
            p['win_to_loss'] == true || p['earlier_candidate_loss'] == true)
        .toList(),
    'cluster_interpretation':
        'Loss tap counts are descriptive clusters, not proof of identical physical states or unsolvability.',
    ...phase5Recommendation(
        gateMeasured: gate != null,
        gatePassed: gate?['passed'] == true,
        complete: complete,
        openingPreserved: opening,
        winGain: (b['wins'] as int) - (a['wins'] as int),
        tap31Reduction: (a['tap31_losses'] as int) - (b['tap31_losses'] as int),
        everyScreenGains: screenGains,
        noScreenTap31Increase: noScreenIncrease,
        winRegressions: winRegressions,
        earlierLosses: earlier,
        challengeFlag: challenge),
  };
}

String phase5Markdown(CampaignJson manifest, CampaignJson summary) {
  final lines = <String>[
    '# Phase 4D-5 — Level 96 second shadow A/B',
    '',
    'Run: `${manifest['run_id']}`. Status: **${manifest['status']}**. Measurement health: **${manifest['measurement_health']}**.',
    '',
    '${summary['actual_attempts']}/360 attempts. Replicas **30–59**, cohort `$phase5Cohort`; 3 Campaign geometries × 2 unchanged paired-v1 strategies × 30 replicas × 2 arms.',
    '',
    'A: production-derived copy with T094 heart→star, T095 star→heart. B: independently production-derived copy with those swaps plus T071 banana→heart, T069 heart→banana. No production edit.',
    '',
    'Recommendation: **${summary['recommendation']}**. ${summary['reason']}',
    '',
    '## Screen / strategy results',
    '',
    '| Screen | Strategy | A wins / N | B wins / N | A loss taps | B loss taps |',
    '|---|---|---:|---:|---|---|'
  ];
  for (final cell in (summary['cells'] as List).cast<CampaignJson>()) {
    final a = cell['control_a'] as Map, b = cell['candidate_b'] as Map;
    lines.add(
        '| ${cell['screen']} | ${cell['strategy']} | ${a['wins']}/${a['attempts']} | ${b['wins']}/${b['attempts']} | ${a['loss_taps']} | ${b['loss_taps']} |');
  }
  lines.addAll([
    '',
    '## Predeclared checks',
    '',
    'Win gain: ${summary['win_gain']}; tap-31 loss reduction: ${summary['tap31_loss_reduction']}; A-win/B-loss regressions: ${summary['win_to_loss_regressions']}; earlier paired B losses: ${summary['earlier_paired_losses']}.',
    '',
    'Opening preserved: ${summary['opening_preserved']}; gain on every screen: ${summary['every_screen_gains']}; no screen tap-31 increase: ${summary['no_screen_tap31_increase']}; challenge flag: ${summary['challenge_review_flag']}.',
    '',
    'Historical reproduction: ${summary['historical_reproduction_passed']}. Correctness gate: ${(summary['correctness_gate'] as Map?)?['passed']}. Inputs unchanged: ${manifest['inputs_unchanged']}.',
    '',
    for (final rule in phase5AcceptanceRules.entries)
      '- **${rule.key}**: ${rule.value}',
    '',
    '## Evidence and limitations',
    '',
    'attempts.jsonl contains complete decision traces, public rankings and analyst-only diagnostics. summary.json contains all 180 A/B comparisons when complete, 180 within-arm strategy comparisons, all six cells, three screens, two strategies, pressure metrics, failure histograms and paired regressions. Comparisons distinguish public symbol changes from physical move changes and mark different-history comparisons.',
    '',
    'The six original stored winning witnesses are replayed in the real engine before any new-cohort attempt. Six replica-24 historical A regressions are separate preflight checks, never mixed into the 360 new attempts. No replacement witness search or automatic retry is allowed.',
    '',
    'Replicas 0–29 were discovery data, excluded from the new cohort. Replicas 30–59 are a fixed confirmation sample; pairs across policies/screens are correlated. Bot success is not a human win rate. A 30/30 winning cell is only a review flag, not proof of excessive ease. Losses at the same tap are not necessarily the same physical state. A failed witness does not establish unsolvability.',
    '',
    'No production change is authorized by this report. Inspect cluster migration, late traps, screen effects and human readability before any gameplay decision.',
    ''
  ]);
  return lines.join('\n');
}
