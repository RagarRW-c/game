import 'dart:convert';

import '../../qa/support/geometry.dart';
import 'campaign_paired.dart';
import 'campaign_validation.dart';

bool _same(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);
List<CampaignJson> _trace(CampaignJson row) =>
    (row['trace'] as List? ?? []).cast<CampaignJson>();

CampaignJson _metrics(CampaignJson row) => {
      for (final key in [
        'outcome',
        'stop_reason',
        'decisions',
        'max_tray_after_resolution',
        'max_tray_before_resolution',
        'average_tray_pressure',
        'first_available_triple_decision',
        'first_immediate_triple_decision',
        'first_resolved_triple_decision',
        'first_high_risk_decision',
        'lookahead_nodes',
        'lookahead_branch_options_pruned',
        'lookahead_budget_exhausted_decisions',
      ])
        key: row[key],
    };

CampaignJson comparePairedAttempts(CampaignJson left, CampaignJson right) {
  for (final key in [
    'experiment_version',
    'level',
    'replica',
    'experiment_seed_uint32'
  ]) {
    if (left[key] == null || left[key] != right[key]) {
      throw ArgumentError('Unpaired $key');
    }
  }
  if (left['experiment_version'] != pairedVersion ||
      left['omniscient'] != false ||
      right['omniscient'] != false) {
    throw ArgumentError(
        'Only the current paired behavioral version is comparable');
  }
  final a = _trace(left), b = _trace(right);
  CampaignJson? firstLegal, firstMove, firstInventory;
  final differingDecisions = <CampaignJson>[];
  var sharedPrefix = true;
  final count = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < count; i++) {
    final x = a[i], y = b[i];
    final legalDiff = !_same(x['legal_tokens'], y['legal_tokens']) ||
        !_same(x['diagnostic_legal_ids'], y['diagnostic_legal_ids']);
    final moveDiff = x['chosen_token'] != y['chosen_token'] ||
        x['diagnostic_actual_chosen_id'] != y['diagnostic_actual_chosen_id'];
    final inventoryDiff =
        !_same(x['diagnostic_remaining_ids'], y['diagnostic_remaining_ids']) ||
            !_same(x['diagnostic_tray_ids'], y['diagnostic_tray_ids']);
    final relation = sharedPrefix && !inventoryDiff
        ? 'SHARED_ACTION_PREFIX'
        : 'POST_DIVERGENCE_DESCRIPTIVE_ONLY';
    CampaignJson event() => {
          'decision': i,
          'relation': relation,
          'same_remaining_and_tray_ids': !inventoryDiff,
          'left_legal_tokens': x['legal_tokens'],
          'right_legal_tokens': y['legal_tokens'],
          'left_diagnostic_legal_ids': x['diagnostic_legal_ids'],
          'right_diagnostic_legal_ids': y['diagnostic_legal_ids'],
          'left_chosen_token': x['chosen_token'],
          'right_chosen_token': y['chosen_token'],
          'left_diagnostic_chosen_id': x['diagnostic_actual_chosen_id'],
          'right_diagnostic_chosen_id': y['diagnostic_actual_chosen_id'],
          'left_tray_before': x['tray_before'],
          'right_tray_before': y['tray_before'],
          'interpretation': relation != 'SHARED_ACTION_PREFIX'
              ? 'Different histories; no same-state causal attribution'
              : legalDiff && left['screen'] != right['screen']
                  ? 'Structural geometry effect at a shared action prefix'
                  : moveDiff &&
                          !legalDiff &&
                          left['screen'] == right['screen'] &&
                          left['strategy'] != right['strategy']
                      ? 'Strategy decision difference on the same legal set'
                      : 'Inspect recorded geometry and public observations',
        };
    if (legalDiff) firstLegal ??= event();
    if (moveDiff) firstMove ??= event();
    if (inventoryDiff) firstInventory ??= event();
    if (legalDiff || moveDiff || inventoryDiff) {
      differingDecisions.add({
        'decision': i,
        'relation': relation,
        'legal_set_differs': legalDiff,
        'chosen_move_differs': moveDiff,
        'dynamic_inventory_differs': inventoryDiff,
      });
    }
    if (moveDiff || inventoryDiff) sharedPrefix = false;
  }
  return {
    'level': left['level'],
    'replica': left['replica'],
    'experiment_seed_uint32': left['experiment_seed_uint32'],
    'left_screen': left['screen'],
    'right_screen': right['screen'],
    'left_strategy': left['strategy'],
    'right_strategy': right['strategy'],
    'left': _metrics(left),
    'right': _metrics(right),
    'outcome_pair': '${left['outcome']}/${right['outcome']}',
    'first_divergent_legal_candidate_set': firstLegal,
    'first_divergent_chosen_move': firstMove,
    'first_divergent_dynamic_inventory': firstInventory,
    'differing_decisions': differingDecisions,
    'compared_decisions': count,
    'unmatched_tail': a.length == b.length
        ? null
        : {
            'first_unmatched_decision': count,
            'left_remaining_decisions': a.length - count,
            'right_remaining_decisions': b.length - count,
            'interpretation':
                'One trace ended; not a divergent legal set or chosen move',
          },
    'trace_comparison_status':
        left['outcome'] == 'INCONCLUSIVE' || right['outcome'] == 'INCONCLUSIVE'
            ? 'INCOMPLETE_EVIDENCE'
            : 'RESOLVED',
  };
}

CampaignJson _totals(List<CampaignJson> rows) => {
      'attempts': rows.length,
      'wins': rows.where((r) => r['outcome'] == 'WIN').length,
      'losses': rows.where((r) => r['outcome'] == 'LOSS').length,
      'inconclusive': rows.where((r) => r['outcome'] == 'INCONCLUSIVE').length,
    };

CampaignJson comparePairedGeometry(CampaignJson a, CampaignJson b) {
  Set<String> edges(CampaignJson g) => (g['blocking_edges'] as List)
      .map((e) => jsonEncode([e['lower'], e['upper']]))
      .toSet();
  final left = edges(a), right = edges(b);
  return {
    'evidence': 'CONFIRMED_STATIC_GEOMETRY',
    'same_blocking_dependencies':
        left.length == right.length && left.containsAll(right),
    'left_edge_count': left.length,
    'right_edge_count': right.length,
    'edges_only_left': left.difference(right).toList()..sort(),
    'edges_only_right': right.difference(left).toList()..sort(),
    'left_same_layer_edges': a['same_layer_edges'],
    'right_same_layer_edges': b['same_layer_edges'],
    'left_blocking_depth': a['blocking_depth_tiles'],
    'right_blocking_depth': b['blocking_depth_tiles'],
    'scope':
        'Initial intact board; independent of strategy and later divergent paths',
  };
}

String _key(int level, String screen, String policy, int replica) =>
    '$level|$screen|$policy|$replica';

CampaignJson buildPairedSummary(
    List<CampaignJson> attempts, Map<String, CampaignJson> geometries) {
  final indexed = <String, CampaignJson>{};
  for (final a in attempts) {
    if (a['experiment_version'] != pairedVersion ||
        a['omniscient'] != false ||
        !pairedLevels.contains(a['level']) ||
        !qaScreens.any((s) => s.name == a['screen']) ||
        !CampaignPolicy.values.any((p) => p.name == a['strategy']) ||
        a['replica'] is! int ||
        (a['replica'] as int) < 0 ||
        (a['replica'] as int) >= pairedReplicas ||
        !['WIN', 'LOSS', 'INCONCLUSIVE'].contains(a['outcome'])) {
      throw ArgumentError('Out-of-scope or invalid paired attempt');
    }
    final key = _key(a['level'] as int, a['screen'] as String,
        a['strategy'] as String, a['replica'] as int);
    if (indexed.containsKey(key)) throw ArgumentError('Duplicate attempt $key');
    indexed[key] = a;
  }
  final comparisons = <CampaignJson>[];
  void add(int level, String kind, String ls, String rs, String lp, String rp) {
    final pairs = <CampaignJson>[];
    final missing = <int>[];
    final left = <CampaignJson>[], right = <CampaignJson>[];
    for (var replica = 0; replica < pairedReplicas; replica++) {
      final a = indexed[_key(level, ls, lp, replica)];
      final b = indexed[_key(level, rs, rp, replica)];
      if (a != null) left.add(a);
      if (b != null) right.add(b);
      if (a == null || b == null) {
        missing.add(replica);
        continue;
      }
      pairs.add(comparePairedAttempts(a, b));
    }
    final ga = geometries['$level|$ls'], gb = geometries['$level|$rs'];
    comparisons.add({
      'level': level,
      'kind': kind,
      'left_screen': ls,
      'right_screen': rs,
      'left_strategy': lp,
      'right_strategy': rp,
      'left_totals': _totals(left),
      'right_totals': _totals(right),
      'paired_replicas': pairs.length,
      'missing_replica_pairs': missing,
      'outcome_matrix': {
        for (final x in ['WIN', 'LOSS', 'INCONCLUSIVE'])
          for (final y in ['WIN', 'LOSS', 'INCONCLUSIVE'])
            '$x/$y': pairs.where((p) => p['outcome_pair'] == '$x/$y').length,
      },
      'static_geometry':
          ga == null || gb == null ? null : comparePairedGeometry(ga, gb),
      'pairs': pairs,
    });
  }

  for (final level in pairedLevels) {
    for (final policy in CampaignPolicy.values) {
      for (final target in qaScreens.skip(1)) {
        add(level, 'screen', qaScreens.first.name, target.name, policy.name,
            policy.name);
      }
    }
    for (final screen in qaScreens) {
      for (final pair in [
        [CampaignPolicy.greedyMatch, CampaignPolicy.visibleLookahead],
        [CampaignPolicy.randomLegal, CampaignPolicy.greedyMatch],
        [CampaignPolicy.randomLegal, CampaignPolicy.visibleLookahead],
      ]) {
        add(level, 'strategy', screen.name, screen.name, pair[0].name,
            pair[1].name);
      }
    }
  }
  return {
    'experiment_version': pairedVersion,
    ..._totals(attempts),
    'planned_attempts': pairedAttemptCount,
    'complete_coverage': attempts.length == pairedAttemptCount,
    'human_fairness': 'UNVERIFIED',
    'comparisons': comparisons,
    'attempt_metrics': [
      for (final a in attempts)
        {
          'level': a['level'],
          'screen': a['screen'],
          'strategy': a['strategy'],
          'replica': a['replica'],
          ..._metrics(a),
        }
    ],
    'focus_level_evidence': [
      for (final a in attempts.where((a) => [84, 96].contains(a['level'])))
        {
          'level': a['level'],
          'screen': a['screen'],
          'strategy': a['strategy'],
          'replica': a['replica'],
          ..._metrics(a),
          'decisions_with_branch_pruning': _trace(a)
              .where((r) => (r['branch_options_pruned'] as int) > 0)
              .map((r) => r['decision'])
              .toList(),
          'decisions_with_newly_selectable_tiles': _trace(a)
              .where((r) =>
                  (r['newly_selectable_tokens_after_tap'] as List).isNotEmpty)
              .map((r) => r['decision'])
              .toList(),
        }
    ],
    'geometry': geometries,
  };
}

String pairedMarkdown(CampaignJson manifest, CampaignJson summary) {
  final out = StringBuffer('# Phase 4D-2 — paired Campaign validation\n\n')
    ..writeln(
        'Run `${manifest['run_id']}`; status **${manifest['status']}**; health **${manifest['measurement_health']}**.')
    ..writeln(
        '\n${summary['attempts']}/990 attempts: ${summary['wins']} wins, ${summary['losses']} losses, ${summary['inconclusive']} inconclusive.')
    ..writeln(
        '\nSeed policy: `$pairedSeedPolicy`. Experiment `$pairedVersion`.')
    ..writeln(
        '\nAll decision indices are zero-based, before the actual tap. Available triple = at least three of a type across tray + selectable tiles; immediate triple = one legal tap completes a triple. High risk = tray occupancy >= 6 before a decision. Pressure = occupancy / 7.')
    ..writeln(
        '\nStatic dependency differences are structural geometry evidence. A shared action prefix is not an assertion of identical geometry. After the first different chosen move, all aligned later decisions are descriptive comparisons of different histories; no same-state causal attribution is made. Missing trace tails are recorded separately.')
    ..writeln('\n## Controlled comparisons\n')
    ..writeln(
        '| Level | Comparison | Left W/L/I | Right W/L/I | Pairs | Static edges differ |')
    ..writeln('|---|---|---|---|---|---|');
  String totals(dynamic v) =>
      '${v['wins']}/${v['losses']}/${v['inconclusive']}';
  for (final c in summary['comparisons'] as List) {
    out.writeln(
        '| ${c['level']} | ${c['left_screen']} ${c['left_strategy']} → ${c['right_screen']} ${c['right_strategy']} | ${totals(c['left_totals'])} | ${totals(c['right_totals'])} | ${c['paired_replicas']}/10 | ${c['static_geometry'] == null ? 'unmeasured' : !c['static_geometry']['same_blocking_dependencies']} |');
  }
  out
    ..writeln('\n## Per-replica paired outcomes\n')
    ..writeln(
        'Full legal sets, chosen public tokens, ranking scores, hypothetical branch ordering, tray histories, and newly selectable tokens are in `paired_attempts.jsonl`. Exact first-divergence events, all differing decision indices, per-attempt first triples/high risk and geometry edge differences are in `paired_summary.json`. Null event means none observed in the compared prefix, not proof of agreement beyond an incomplete trace.\n')
    ..writeln(
        '| Level | Screens / strategies (left → right) | Replica | Outcomes | First legal difference | First move difference | Tray peaks | Mean pressure | First available triple | First high risk |')
    ..writeln('|---|---|---|---|---|---|---|---|---|---|');
  for (final c in summary['comparisons'] as List) {
    for (final p in c['pairs'] as List) {
      final l = p['left'], r = p['right'];
      Object event(dynamic e) =>
          e == null ? 'none observed' : '${e['decision']} ${e['relation']}';
      String metric(String key) => '${l[key] ?? 'none'} / ${r[key] ?? 'none'}';
      out.writeln(
          '| ${c['level']} | ${c['left_screen']} ${c['left_strategy']} → ${c['right_screen']} ${c['right_strategy']} | ${p['replica']} | ${p['outcome_pair']} | ${event(p['first_divergent_legal_candidate_set'])} | ${event(p['first_divergent_chosen_move'])} | ${metric('max_tray_after_resolution')} | ${metric('average_tray_pressure')} | ${metric('first_available_triple_decision')} | ${metric('first_high_risk_decision')} |');
    }
  }
  out
    ..writeln('\n## Strategy limitations and interpretation\n')
    ..writeln(
        'Planning is unchanged: depth 3, branch cap 4, 84 expanded actions, greedy-ordered children, first equal-scoring leaf retained. Root ranking uses actual priorities; deeper ranking uses separate public hypothetical-path priorities. Ranking previews are additional work outside the 84 expansion cap. The cap is the full 4+16+64 tree, not evidence that more nodes alone would help.')
    ..writeln(
        '\nNo hidden identities, future reveals, partial visibility or persistent player memory enter planning. Newly selectable tokens are measured only after actual taps; their informational value was unavailable to the preceding plan. Root and internal pruned candidates are recorded, but pruning counts do not prove an omitted move would win. Increasing depth cannot recover missing information.')
    ..writeln(
        '\nFor levels 84 and 96, inspect `focus_level_evidence` and each referenced decision ranking. Historical source evidence and bounded follow-up designs are in `test/balance_audit/CAMPAIGN_PAIRED_VALIDATION.md`. Bot losses are not estimates of human win rates or proof of unfairness.')
    ..writeln(
        '\nPaired priorities remove sequential RNG drift, not geometry confounding, greedy score differences, branch pruning, limited information, or divergence of later observations. Hash collisions use public token order; this is deterministic pseudorandom ranking, not a claim of exact uniformity or independent samples. No baseline reruns, balancing changes or sample expansion are performed.');
  return out.toString();
}
