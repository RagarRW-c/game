import 'dart:math' as math;

import '../../qa/support/geometry.dart';
import 'campaign_validation.dart';

double? _mean(Iterable<num> values) {
  final list = values.toList();
  return list.isEmpty ? null : list.reduce((a, b) => a + b) / list.length;
}

CampaignJson _distribution(Iterable<num> values) {
  final list = values.toList()..sort();
  if (list.isEmpty) return {'count': 0, 'min': null, 'mean': null, 'max': null};
  final mean = _mean(list)!;
  return {
    'count': list.length,
    'min': list.first,
    'mean': mean,
    'max': list.last,
    'population_sd_of_fixed_sample': math.sqrt(
        list.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            list.length),
  };
}

CampaignJson _aggregate(List<CampaignJson> attempts) {
  final first = attempts.first;
  final wins = attempts.where((a) => a['outcome'] == 'WIN').length;
  final losses = attempts.where((a) => a['outcome'] == 'LOSS').length;
  final decisions =
      attempts.fold<int>(0, (n, a) => n + (a['decisions'] as int? ?? 0));
  final trays = attempts
      .expand(
          (a) => (a['tray_after_by_decision'] as List?)?.cast<num>() ?? <num>[])
      .toList();
  final peaks = attempts
      .map((a) => a['max_tray_after_resolution'])
      .whereType<num>()
      .toList();
  return {
    'level': first['level'],
    'screen': first['screen'],
    'strategy': first['strategy'],
    'evidence': attempts.any((a) => a['evidence'] == 'SIMULATED')
        ? 'SIMULATED'
        : 'UNVERIFIED',
    'unverified_attempts':
        attempts.where((a) => a['evidence'] == 'UNVERIFIED').length,
    'omniscient': false,
    'attempts': attempts.length,
    'wins': wins,
    'losses': losses,
    'inconclusive': attempts.length - wins - losses,
    'heuristic_completion_rate': wins / attempts.length,
    'completion_rate_resolved_only':
        wins + losses == 0 ? null : wins / (wins + losses),
    'seed_indices': attempts.map((a) => a['seed_index']).toList(),
    'derived_seeds_uint32':
        attempts.map((a) => a['derived_seed_uint32']).toList(),
    'seed_outcomes': [
      for (final a in attempts)
        {
          'seed': a['seed_index'],
          'outcome': a['outcome'],
          'stop_reason': a['stop_reason'],
          'decisions': a['decisions'],
          'peak': a['max_tray_after_resolution'],
        }
    ],
    'initial_exposed_tiles': first['initial_exposed_tiles'],
    'initial_visible_triples': first['initial_visible_triples'],
    'total_decisions': decisions,
    'maximum_tray_occupancy': peaks.isEmpty ? null : peaks.reduce(math.max),
    'average_tray_pressure_decision_weighted':
        trays.isEmpty ? null : _mean(trays)! / 7,
    'maximum_tray_pressure': peaks.isEmpty ? null : peaks.reduce(math.max) / 7,
    'peak_by_attempt': _distribution(peaks),
    'decisions_by_attempt':
        _distribution(attempts.map((a) => a['decisions']).whereType<num>()),
    'first_triple_moves_observed_only': _distribution(
        attempts.map((a) => a['moves_to_first_triple']).whereType<num>()),
    'attempts_without_completed_triple':
        attempts.where((a) => a['moves_to_first_triple'] == null).length,
    'available_choices': _distribution(attempts.expand(
        (a) => (a['choices_by_decision'] as List?)?.cast<num>() ?? <num>[])),
    for (final field in [
      'invalid_move_count',
      'unexpected_deadlock_count',
      'immediate_losing_moves_encountered',
      'states_with_losing_choices',
      'forced_single_choice_decisions',
      'one_nonlosing_choice_decisions',
      'states_without_visible_complete_set',
      'high_pressure_immediate_relief_states',
      'high_pressure_immediate_relief_choices',
      'lookahead_nodes',
      'lookahead_branch_options_pruned',
      'lookahead_budget_exhausted_decisions',
    ])
      field: attempts.fold<int>(0, (n, a) => n + (a[field] as int? ?? 0)),
  };
}

num? _delta(Object? from, Object? to) =>
    from is num && to is num ? to - from : null;

/// Descriptive flags, not calibrated difficulty ratings or human win rates.
CampaignJson buildCampaignSummary(
    List<CampaignJson> baseline, List<CampaignJson> attempts) {
  final buckets = <String, List<CampaignJson>>{};
  for (final a in attempts) {
    if (a['omniscient'] == true) {
      throw StateError('Witness entered behavioral aggregation');
    }
    buckets
        .putIfAbsent('${a['level']}|${a['screen']}|${a['strategy']}', () => [])
        .add(a);
  }
  final groups = buckets.values.map(_aggregate).toList();
  final byBase = {for (final b in baseline) '${b['level']}|${b['screen']}': b};
  final byGroup = {
    for (final g in groups) '${g['level']}|${g['screen']}|${g['strategy']}': g
  };
  CampaignJson compare(int from, String fromScreen, int to, String toScreen) {
    final a = byBase['$from|$fromScreen'];
    final b = byBase['$to|$toScreen'];
    final ac = a?['confirmed'] as Map? ?? {};
    final bc = b?['confirmed'] as Map? ?? {};
    final aw = a?['witness'] as Map? ?? {};
    final bw = b?['witness'] as Map? ?? {};
    final exposedDelta =
        _delta(ac['initial_exposed_tiles'], bc['initial_exposed_tiles']);
    final collapse = ac['initial_exposed_tiles'] is num &&
        bc['initial_exposed_tiles'] is num &&
        (bc['initial_exposed_tiles'] as num) <=
            (ac['initial_exposed_tiles'] as num) / 2 &&
        (exposedDelta ?? 0) <= -3;
    return {
      'from_level': from,
      'to_level': to,
      'from_screen': fromScreen,
      'to_screen': toScreen,
      'baseline_evidence': a?['confirmed'] != null && b?['confirmed'] != null
          ? 'CONFIRMED'
          : 'UNVERIFIED',
      'initial_exposed_delta': exposedDelta,
      'initial_visible_triples_delta':
          _delta(ac['initial_visible_triples'], bc['initial_visible_triples']),
      'blocking_depth_delta':
          _delta(ac['blocking_depth_tiles'], bc['blocking_depth_tiles']),
      'blocking_dependencies_changed': from != to ||
              ac['blocking_dependencies_fnv1a32'] == null ||
              bc['blocking_dependencies_fnv1a32'] == null
          ? null
          : ac['blocking_dependencies_fnv1a32'] !=
              bc['blocking_dependencies_fnv1a32'],
      'same_layer_edges_delta': _delta(
          ac['same_layer_blocking_edges'], bc['same_layer_blocking_edges']),
      'cross_layer_edges_delta': _delta(
          ac['cross_layer_blocking_edges'], bc['cross_layer_blocking_edges']),
      'witness_peak_delta': _delta(
          aw['max_tray_after_resolution'], bw['max_tray_after_resolution']),
      'witness_evidence': a?['witness_status'] == 'REPLAYED' &&
              b?['witness_status'] == 'REPLAYED'
          ? 'REPLAYED'
          : 'UNVERIFIED',
      'initial_choice_collapse_flag': collapse,
      'behavior': [
        for (final policy in CampaignPolicy.values)
          (() {
            final ga = byGroup['$from|$fromScreen|${policy.name}'];
            final gb = byGroup['$to|$toScreen|${policy.name}'];
            return <String, Object?>{
              'strategy': policy.name,
              'status': ga == null || gb == null
                  ? 'UNMEASURED'
                  : ga['evidence'] == 'UNVERIFIED' ||
                          gb['evidence'] == 'UNVERIFIED'
                      ? 'UNVERIFIED'
                      : 'SIMULATED',
              'from_inconclusive': ga?['inconclusive'],
              'to_inconclusive': gb?['inconclusive'],
              'from_attempts': ga?['attempts'] ?? 0,
              'to_attempts': gb?['attempts'] ?? 0,
              'completion_rate_delta': _delta(ga?['heuristic_completion_rate'],
                  gb?['heuristic_completion_rate']),
              'mean_pressure_delta': _delta(
                  ga?['average_tray_pressure_decision_weighted'],
                  gb?['average_tray_pressure_decision_weighted']),
              'maximum_tray_delta': _delta(
                  ga?['maximum_tray_occupancy'], gb?['maximum_tray_occupancy']),
            };
          })()
      ],
    };
  }

  final neighbors = [
    for (final screen in qaScreens)
      for (var level = 1; level < 100; level++)
        compare(level, screen.name, level + 1, screen.name)
  ];
  final screens = [
    for (var level = 1; level <= 100; level++)
      for (final target in qaScreens.skip(1))
        compare(level, qaScreens.first.name, level, target.name)
  ];
  final traceFlags = <CampaignJson>[];
  for (final a in attempts) {
    final choices = (a['choices_by_decision'] as List?)?.cast<int>() ?? <int>[];
    final drops = [
      for (var i = 1; i < choices.length; i++)
        if (choices[i] <= choices[i - 1] / 2 &&
            choices[i - 1] - choices[i] >= 3)
          {'decision': i + 1, 'from': choices[i - 1], 'to': choices[i]}
    ];
    if (drops.isNotEmpty ||
        (a['max_tray_after_resolution'] as num? ?? 0) >= 6) {
      traceFlags.add({
        'level': a['level'],
        'screen': a['screen'],
        'strategy': a['strategy'],
        'seed_index': a['seed_index'],
        'evidence': 'SIMULATED',
        'choice_collapses': drops,
        'peak': a['max_tray_after_resolution'],
        'outcome': a['outcome'],
      });
    }
  }
  return {
    'schema': 'campaign-validation/v1',
    'baseline_cases': baseline.length,
    'attempts': attempts.length,
    'baseline_status_counts': {
      for (final s in [
        'VALIDATED',
        'REVIEW_REQUIRED',
        'INVALID_INPUT',
        'ERROR'
      ])
        s: baseline.where((b) => b['status'] == s).length
    },
    'behavior_groups': groups,
    'first_ten_levels': [
      for (final b in baseline)
        if ((b['level'] as int) <= 10) b
    ],
    'neighbor_comparisons': neighbors,
    'requested_transitions':
        neighbors.where((n) => [2, 7, 10].contains(n['from_level'])).toList(),
    'world_beginnings': [
      for (final b in baseline)
        if ((b['level'] as int) % 10 == 1) b,
    ],
    'world_boundary_comparisons':
        neighbors.where((n) => (n['from_level'] as int) % 10 == 0).toList(),
    'boss_vs_previous_three_regular_levels': [
      for (var boss = 10; boss <= 100; boss += 10)
        for (final screen in qaScreens)
          for (var regular = boss - 3; regular < boss; regular++)
            compare(regular, screen.name, boss, screen.name)
    ],
    'screen_comparisons_small_to_medium_and_tall': screens,
    'witness_vs_behavior': [
      for (final group in groups)
        {
          'level': group['level'],
          'screen': group['screen'],
          'strategy': group['strategy'],
          'witness_status': byBase['${group['level']}|${group['screen']}']
              ?['witness_status'],
          'witness_peak': (byBase['${group['level']}|${group['screen']}']
              ?['witness'] as Map?)?['max_tray_after_resolution'],
          'heuristic_completion_rate': group['heuristic_completion_rate'],
          'heuristic_maximum_tray': group['maximum_tray_occupancy'],
        }
    ],
    'review_flags': {
      'definition':
          'Choices fall by at least 3 and at least 50%; high pressure means post-resolution tray >= 6. Descriptive flags only.',
      'initial_neighbor_collapses': neighbors
          .where((n) => n['initial_choice_collapse_flag'] == true)
          .toList(),
      'attempt_choice_collapses_or_high_pressure': traceFlags,
    },
    'human_fairness': {
      'evidence': 'UNVERIFIED',
      'reason': 'No real-player testing or calibrated human model.'
    },
  };
}

String campaignMarkdown(
    CampaignJson manifest, CampaignJson summary, List<CampaignJson> baseline) {
  String fmt(Object? n) => n is double ? n.toStringAsFixed(3) : '${n ?? "—"}';
  final text = StringBuffer()
    ..writeln('# Campaign difficulty validation')
    ..writeln(
        '\nRun: `${manifest['run_id']}` · status: **${manifest['status']}**')
    ..writeln(
        '\n${summary['baseline_cases']} baseline cases; ${summary['attempts']} behavioral attempts actually recorded. Planned: ${manifest['planned_baseline_cases']} / ${manifest['planned_behavior_attempts']}.')
    ..writeln(
        '\nCONFIRMED = inspected input/geometry; REPLAYED = engine witness; SIMULATED = exposed-only heuristic; UNVERIFIED = human fairness or unverified replay. A heuristic loss never proves unsolvability.')
    ..writeln('\n## Baseline by level and geometry')
    ..writeln(
        '\n| Level | Screen | Status | Exposed | Visible triples | Depth | Witness | Tray peak |')
    ..writeln('|---|---|---|---:|---:|---:|---|---:|');
  for (final b in baseline) {
    final c = b['confirmed'] as Map? ?? {};
    final w = b['witness'] as Map? ?? {};
    text.writeln(
        '| ${b['level']} | ${b['screen']} | ${b['status']} | ${fmt(c['initial_exposed_tiles'])} | ${fmt(c['initial_visible_triples'])} | ${fmt(c['blocking_depth_tiles'])} | ${b['witness_status']} | ${fmt(w['max_tray_after_resolution'])} |');
  }
  text
    ..writeln(
        '\n## Behavioral sample (heuristic completion rates, not human win rates)')
    ..writeln(
        '\n| Level | Screen | Strategy | Attempts | Win / loss / inconclusive | Completion | Mean pressure | Peak tray |')
    ..writeln('|---|---|---|---:|---|---:|---:|---:|');
  for (final g in (summary['behavior_groups'] as List).cast<Map>()) {
    text.writeln(
        '| ${g['level']} | ${g['screen']} | ${g['strategy']} | ${g['attempts']} | ${g['wins']} / ${g['losses']} / ${g['inconclusive']} | ${fmt(g['heuristic_completion_rate'])} | ${fmt(g['average_tray_pressure_decision_weighted'])} | ${fmt(g['maximum_tray_occupancy'])} |');
  }
  text
    ..writeln('\n## Requested transitions')
    ..writeln(
        '\n| Transition | Screen | Exposed delta | Triple delta | Depth delta | Witness peak delta | Behavioral coverage |')
    ..writeln('|---|---|---:|---:|---:|---:|---|');
  for (final n in (summary['requested_transitions'] as List).cast<Map>()) {
    final behavior = (n['behavior'] as List).cast<Map>();
    text.writeln(
        '| ${n['from_level']} → ${n['to_level']} | ${n['from_screen']} | ${fmt(n['initial_exposed_delta'])} | ${fmt(n['initial_visible_triples_delta'])} | ${fmt(n['blocking_depth_delta'])} | ${fmt(n['witness_peak_delta'])} | ${behavior.map((b) => "${b['strategy']}: ${b['status']} (Δ ${fmt(b['completion_rate_delta'])})").join('; ')} |');
  }
  final flags = summary['review_flags'] as Map;
  text
    ..writeln('\n## Review cues and limits')
    ..writeln('\n${flags['definition']}')
    ..writeln(
        '\nInitial neighboring choice collapses: ${(flags['initial_neighbor_collapses'] as List).length}. Attempts with a choice collapse or high tray pressure: ${(flags['attempt_choice_collapses_or_high_pressure'] as List).length}. Full identifiers and traces are in summary.json / attempts.jsonl.')
    ..writeln(
        '\nsummary.json also contains all 99 neighboring transitions on each screen, all world starts, every Boss versus its three preceding regular levels, and all small-to-medium/tall comparisons. Unmeasured behavioral pairs remain UNMEASURED (including 10→11 in the default sample).')
    ..writeln(
        '\nPressure averages weight completed decisions, including losing moves. First-triple averages exclude attempts with no triple; their count is separate. Missing/error attempts are inconclusive, never losses. Seed ranges and fixed-sample dispersion describe tie sensitivity only.')
    ..writeln(
        '\nThe witness proves existence only when replay succeeds. Strategies have no hidden identities, reveal predictions, memory, boosters or human error model. Relief counts immediate triple removals at tray >= 5; this is not proof of recovery after a mistake. Screen-specific seeds mix tie variation with geometry effects; static coverage comparisons isolate geometry.')
    ..writeln(
        '\nReview manifest.json for input fingerprints, SDK, budgets, incomplete execution and failures. FNV-1a fingerprints detect accidental changes; they are not cryptographic attestations. No automatic balancing is performed.');
  return text.toString();
}
