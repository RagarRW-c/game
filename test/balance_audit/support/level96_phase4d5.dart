// Phase 4D-5 only. Reuse paired-v1 and the real-engine stored-witness replay.
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import '../../qa/support/geometry.dart';
import 'campaign_paired.dart';
import 'campaign_validation.dart';
import 'level96_shadow.dart';

const phase5Version = 'campaign4d5/level96-second-shadow-v1';
const phase5Cohort = 'unseen_30_59';
const phase5Variants = ['control_a', 'candidate_b'];
const phase5Attempts = 360;
const phase5FirstReplica = 30;
const phase5LastReplica = 59;
const phase5OriginalTypes = {
  ...shadow96OriginalTypes,
  'L96_T071': 'banana',
  'L96_T069': 'heart',
};
const phase5Swaps = {
  'control_a': shadow96Swap,
  'candidate_b': {
    ...shadow96Swap,
    'L96_T071': 'heart',
    'L96_T069': 'banana',
  },
};

/// Both arms are fresh tile-by-tile copies of the untouched production model.
/// Passing Control A into this factory is an error, even when building B.
LevelDefinition makePhase5Variant(LevelDefinition production, String variant) {
  final swaps = phase5Swaps[variant];
  if (swaps == null ||
      production.level != 96 ||
      campaignInputIssues(production).isNotEmpty) {
    throw ArgumentError('Expected original valid Level 96 and a fixed arm');
  }
  for (final e in phase5OriginalTypes.entries) {
    final matches = production.tiles.where((t) => t.id == e.key).toList();
    if (matches.length != 1 || matches.single.type != e.value) {
      throw StateError('Original type precondition failed: ${e.key}');
    }
  }
  final result = LevelDefinition(
    level: production.level,
    name: production.name,
    timeBonusSeconds: production.timeBonusSeconds,
    objective: production.objective == null
        ? null
        : LevelObjective(
            type: production.objective!.type,
            target: production.objective!.target),
    tiles: List.unmodifiable([
      for (final t in production.tiles)
        Tile(
            id: t.id,
            type: swaps[t.id] ?? t.type,
            x: t.x,
            y: t.y,
            layer: t.layer,
            state: t.state),
    ]),
  );
  if (phase5VariantChecks(production, result, variant)['passed'] != true) {
    throw StateError('Variant invariants failed');
  }
  return result;
}

CampaignJson phase5VariantChecks(
    LevelDefinition production, LevelDefinition variant, String arm) {
  final swaps = phase5Swaps[arm];
  if (swaps == null) throw ArgumentError('Unknown arm');
  final problems = <String>[];
  final expected = shadowLevelValue(production);
  expected['tiles'] = [
    for (final t in production.tiles)
      {
        'id': t.id,
        'type': swaps[t.id] ?? t.type,
        'x': t.x,
        'y': t.y,
        'layer': t.layer,
        'state': t.state.name,
      }
  ];
  if (shadowCanonical(expected) != shadowCanonical(shadowLevelValue(variant))) {
    problems.add('UNEXPECTED_MODEL_CHANGE');
  }
  if (identical(production, variant) ||
      identical(production.tiles, variant.tiles) ||
      variant.tiles.any((b) => production.tiles.any((a) => identical(a, b)))) {
    problems.add('ALIASED_INPUT');
  }
  final inventoryEqual = shadowCanonical(shadowInventory(production)) ==
      shadowCanonical(shadowInventory(variant));
  if (!inventoryEqual) problems.add('INVENTORY_CHANGED');
  final changed = [
    for (var i = 0;
        i < production.tiles.length && i < variant.tiles.length;
        i++)
      if (production.tiles[i].type != variant.tiles[i].type)
        production.tiles[i].id
  ]..sort();
  final expectedIds = swaps.keys.toList()..sort();
  if (shadowCanonical(changed) != shadowCanonical(expectedIds)) {
    problems.add('WRONG_CHANGED_IDS');
  }
  return {
    'passed': problems.isEmpty,
    'problems': problems,
    'arm': arm,
    'changed_type_ids': changed,
    'inventory_equal': inventoryEqual,
    'inventory': shadowInventory(variant),
    'tile_count': variant.tiles.length
  };
}

CampaignJson phase5WitnessGate(LevelDefinition production, LevelDefinition a,
    LevelDefinition b, Map<String, List<String>> witnesses) {
  final checks = [
    phase5VariantChecks(production, a, 'control_a'),
    phase5VariantChecks(production, b, 'candidate_b')
  ];
  final independent = !identical(a, b) &&
      !identical(a.tiles, b.tiles) &&
      !a.tiles.any((x) => b.tiles.any((y) => identical(x, y)));
  final screens = <CampaignJson>[];
  for (final screen in qaScreens) {
    final path = witnesses[screen.name];
    if (path == null) throw StateError('Missing original stored witness');
    final geometry = [
      for (final l in [production, a, b])
        pairedGeometry(CampaignGraph(l.tiles, screen.geometry()))
    ];
    final bounds = [
      for (final l in [production, a, b]) shadowBounds(l, screen.geometry())
    ];
    final equal = geometry.every(
            (g) => shadowCanonical(g) == shadowCanonical(geometry.first)) &&
        bounds.every(
            (g) => shadowCanonical(g) == shadowCanonical(bounds.first)) &&
        bounds.every((g) => (g['outside_ids'] as List).isEmpty);
    final ar = replayShadowWitness(a, screen, path);
    final br = replayShadowWitness(b, screen, path);
    screens.add({
      'screen': screen.name,
      'geometry_and_bounds_equal': equal,
      'geometry': geometry.first,
      'bounds': bounds.first,
      'control_a_replay': ar,
      'candidate_b_replay': br,
      'passed':
          equal && ar['replay_success'] == true && br['replay_success'] == true
    });
  }
  return {
    'passed': independent &&
        checks.every((x) => x['passed'] == true) &&
        screens.every((x) => x['passed'] == true),
    'independent_arms': independent,
    'variant_checks': checks,
    'screens': screens,
    'witness_policy':
        'Original stored paths only; no search or replacement on failure'
  };
}

/// This schedule is the entire experiment, not a sampling or retry mechanism.
List<CampaignJson> phase5Schedule() => [
      for (final arm in phase5Variants)
        for (final screen in qaScreens)
          for (final policy in shadow96Policies)
            for (var r = phase5FirstReplica; r <= phase5LastReplica; r++)
              {
                ...pairedAttemptIdentity(96, screen.name, policy, r),
                'phase4d5_version': phase5Version,
                'variant': arm,
                'cohort': phase5Cohort,
              },
    ];

String phase5Key(CampaignJson row) =>
    '${row['variant']}|${row['screen']}|${row['strategy']}|${row['replica']}';

CampaignJson phase5Wrap(CampaignJson raw, String arm) {
  if (!phase5Variants.contains(arm) ||
      raw['level'] != 96 ||
      raw['experiment_version'] != pairedVersion ||
      raw['omniscient'] != false ||
      raw['replica'] is! int ||
      (raw['replica'] as int) < phase5FirstReplica ||
      (raw['replica'] as int) > phase5LastReplica ||
      !shadow96Policies.any((p) => p.name == raw['strategy']) ||
      !qaScreens.any((s) => s.name == raw['screen']) ||
      raw['experiment_seed_uint32'] !=
          PairedPriorities(96, raw['replica'] as int, 0).experimentSeed) {
    throw ArgumentError('Outside the predeclared Phase 4D-5 cohort');
  }
  return {
    ...raw,
    'phase4d5_version': phase5Version,
    'variant': arm,
    'cohort': phase5Cohort
  };
}

CampaignJson simulatePhase5(LevelDefinition level, QaScreen screen,
    CampaignPolicy policy, int replica, String arm) {
  // Validate identity BEFORE invoking the unchanged simulator.
  phase5Wrap(pairedAttemptIdentity(96, screen.name, policy, replica), arm);
  if (level.level != 96 || !qaScreens.contains(screen)) {
    throw ArgumentError('Unapproved level or Campaign geometry');
  }
  return phase5Wrap(
      simulatePairedCampaign(
          level,
          CampaignGraph(level.tiles, screen.geometry()),
          policy,
          screen.name,
          replica),
      arm);
}

CampaignJson phase5Accounting(List<CampaignJson> attempts) {
  final expected = {for (final row in phase5Schedule()) phase5Key(row): row};
  final seen = <String>{};
  for (final row in attempts) {
    final key = phase5Key(row), identity = expected[phase5Key(row)];
    if (identity == null ||
        !seen.add(key) ||
        identity.entries.any((e) => row[e.key] != e.value)) {
      throw ArgumentError(
          'Duplicate, out-of-cohort or mismatched paired identity: $key');
    }
    if (!['WIN', 'LOSS', 'INCONCLUSIVE'].contains(row['outcome'])) {
      throw ArgumentError('Invalid outcome: $key');
    }
    if (row['outcome'] != 'INCONCLUSIVE') {
      final trace = row['trace'],
          path = row['path_ids'],
          decisions = row['decisions'];
      if (trace is! List ||
          path is! List ||
          decisions is! int ||
          decisions < 1 ||
          decisions > 99 ||
          trace.length != decisions ||
          path.length != decisions ||
          path.toSet().length != decisions ||
          (row['outcome'] == 'WIN' &&
              (decisions != 99 ||
                  row['final_board_count'] != 0 ||
                  row['final_tray_count'] != 0)) ||
          (row['outcome'] == 'LOSS' && row['final_tray_count'] != 7)) {
        throw ArgumentError(
            'Incomplete trace or inconsistent terminal result: $key');
      }
      for (var i = 0; i < trace.length; i++) {
        final step = trace[i] as Map;
        if (step['decision'] != i ||
            step['diagnostic_actual_chosen_id'] != path[i] ||
            step['legal_tokens'] is! List ||
            step['rankings'] is! List ||
            step['candidates'] is! List) {
          throw ArgumentError('Incomplete decision trace: $key/$i');
        }
      }
    }
  }
  return {
    'complete': seen.length == phase5Attempts,
    'actual_attempts': seen.length,
    'planned_attempts': phase5Attempts,
    'missing_keys': expected.keys.where((k) => !seen.contains(k)).toList()
  };
}

/// B's two extra symbols are hidden at the opening. Compare public observations
/// and single decisions only: this gate does not play any 30-59 attempt.
CampaignJson phase5PairedGate(LevelDefinition a, LevelDefinition b) {
  final checks = <CampaignJson>[];
  for (final screen in qaScreens) {
    VisibleCampaignBoard view(LevelDefinition l) => CampaignObservation.capture(
            GameEngine(l.tiles), CampaignGraph(l.tiles, screen.geometry()))
        .visible;
    final av = view(a), bv = view(b);
    final observationsEqual =
        shadowCanonical(av.toJson()) == shadowCanonical(bv.toJson());
    for (final policy in shadow96Policies) {
      for (final replica in [30, 44, 59]) {
        final priorities = PairedPriorities(96, replica, 0);
        CampaignJson choose(VisibleCampaignBoard v) {
          final d = decideCampaignMove(v, policy, NoPairedRng(),
              tieBreak: priorities.compare);
          return {
            'handle': d.handle,
            'nodes': d.nodes,
            'pruned': d.branchPruned,
            'budget_exhausted': d.budgetExhausted
          };
        }

        final first = choose(av), repeat = choose(av), other = choose(bv);
        checks.add({
          'screen': screen.name,
          'strategy': policy.name,
          'replica': replica,
          'experiment_seed_uint32': priorities.experimentSeed,
          'passed': observationsEqual &&
              shadowCanonical(first) == shadowCanonical(repeat) &&
              shadowCanonical(first) == shadowCanonical(other),
          'observations_equal': observationsEqual,
          'a': first,
          'a_repeat': repeat,
          'b': other
        });
      }
    }
  }
  return {
    'passed': checks.length == 18 && checks.every((c) => c['passed'] == true),
    'checks': checks,
    'scope': 'Single opening decisions only; no new-cohort trajectory executed'
  };
}
