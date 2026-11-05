// Level 96 shadow-only experiment. No file IO and no alternative agent policy.
import 'dart:convert';
import 'dart:math' as math;

import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import '../../qa/support/geometry.dart';
import 'campaign_paired.dart';
import 'campaign_validation.dart';

const shadow96Version = 'campaign4d3/level96-shadow-v1';
const shadow96Asset = 'assets/levels/level_96.json';
const shadow96AssetFingerprint = '2b2b8578';
const shadow96Replicas = 30;
const shadow96Attempts = 360;
const shadow96Policies = [
  CampaignPolicy.greedyMatch,
  CampaignPolicy.visibleLookahead
];
const shadow96Variants = ['control', 'candidate'];
const shadow96Swap = {'L96_T094': 'star', 'L96_T095': 'heart'};
const shadow96OriginalTypes = {'L96_T094': 'heart', 'L96_T095': 'star'};

/// Canonical JSON comparison, including nested maps, independent of key order.
String shadowCanonical(Object? value) {
  Object? canonical(Object? v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(v[key])};
    }
    if (v is List) return v.map(canonical).toList();
    return v;
  }

  return jsonEncode(canonical(value));
}

Map<String, int> shadowInventory(LevelDefinition level) {
  final counts = <String, int>{};
  for (final tile in level.tiles) {
    counts.update(tile.type, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
}

CampaignJson shadowLevelValue(LevelDefinition level) => {
      'level': level.level,
      'name': level.name,
      'timeBonusSeconds': level.timeBonusSeconds,
      'objective': level.objective == null
          ? null
          : {
              'type': level.objective!.type,
              'target': level.objective!.target,
            },
      'tiles': [
        for (final t in level.tiles)
          {
            'id': t.id,
            'type': t.type,
            'x': t.x,
            'y': t.y,
            'layer': t.layer,
            'state': t.state.name,
          }
      ],
    };

LevelDefinition makeLevel96Candidate(LevelDefinition control) {
  if (control.level != 96 || campaignInputIssues(control).isNotEmpty) {
    throw ArgumentError('Only valid original Campaign level 96 is accepted');
  }
  for (final entry in shadow96OriginalTypes.entries) {
    final matches = control.tiles.where((t) => t.id == entry.key).toList();
    if (matches.length != 1 || matches.single.type != entry.value) {
      throw StateError(
          'Swap precondition failed for ${entry.key}: expected ${entry.value}');
    }
  }
  final candidate = LevelDefinition(
    level: control.level,
    name: control.name,
    timeBonusSeconds: control.timeBonusSeconds,
    objective: control.objective == null
        ? null
        : LevelObjective(
            type: control.objective!.type, target: control.objective!.target),
    tiles: List.unmodifiable([
      for (final t in control.tiles)
        Tile(
          id: t.id,
          type: shadow96Swap[t.id] ?? t.type,
          x: t.x,
          y: t.y,
          layer: t.layer,
          state: t.state,
        )
    ]),
  );
  if (shadowCandidateChecks(control, candidate)['passed'] != true) {
    throw StateError('Candidate invariant check failed');
  }
  return candidate;
}

CampaignJson shadowCandidateChecks(
    LevelDefinition control, LevelDefinition candidate) {
  final changed = <String>[];
  final violations = <String>[];
  if (identical(control, candidate) ||
      identical(control.tiles, candidate.tiles)) {
    violations.add('ALIASED_LEVEL_OR_TILE_LIST');
  }
  if (control.level != 96 ||
      candidate.level != 96 ||
      control.name != candidate.name ||
      control.timeBonusSeconds != candidate.timeBonusSeconds ||
      control.objective?.type != candidate.objective?.type ||
      control.objective?.target != candidate.objective?.target) {
    violations.add('LEVEL_METADATA_CHANGED');
  }
  if (control.tiles.length != candidate.tiles.length)
    violations.add('TILE_COUNT_CHANGED');
  for (var i = 0;
      i < math.min(control.tiles.length, candidate.tiles.length);
      i++) {
    final a = control.tiles[i], b = candidate.tiles[i];
    if (identical(a, b)) violations.add('ALIASED_TILE:${a.id}');
    if (a.id != b.id ||
        a.x != b.x ||
        a.y != b.y ||
        a.layer != b.layer ||
        a.state != b.state) {
      violations.add('NON_TYPE_FIELD_OR_ORDER_CHANGED:$i');
    }
    if (a.type != b.type) changed.add(a.id);
    if (b.type != (shadow96Swap[a.id] ?? a.type))
      violations.add('UNEXPECTED_TYPE:${a.id}');
  }
  changed.sort();
  final expected = shadow96Swap.keys.toList()..sort();
  if (shadowCanonical(changed) != shadowCanonical(expected))
    violations.add('NOT_EXACTLY_TWO_TYPES');
  final equalInventory = shadowCanonical(shadowInventory(control)) ==
      shadowCanonical(shadowInventory(candidate));
  if (!equalInventory) violations.add('INVENTORY_CHANGED');
  return {
    'passed': violations.isEmpty,
    'violations': violations,
    'changed_type_ids': changed,
    'tile_count_control': control.tiles.length,
    'tile_count_candidate': candidate.tiles.length,
    'inventory_equal': equalInventory,
    'control_inventory': shadowInventory(control),
    'candidate_inventory': shadowInventory(candidate),
    'non_type_fields_and_paint_order_equal':
        !violations.any((v) => v.startsWith('NON_TYPE')),
  };
}

CampaignJson shadowBounds(LevelDefinition level, QaGeometry g) => {
      'board': [g.board.width, g.board.height],
      'tile': [g.tile.width, g.tile.height],
      'outside_ids': [
        for (final t in level.tiles)
          if (t.boardRect(g.board, g.tile).left < 0 ||
              t.boardRect(g.board, g.tile).top < 0 ||
              t.boardRect(g.board, g.tile).right > g.board.width + 1e-6 ||
              t.boardRect(g.board, g.tile).bottom > g.board.height + 1e-6)
            t.id
      ],
      'rectangles': [
        for (final t in level.tiles)
          {
            'id': t.id,
            'rect': [
              t.boardRect(g.board, g.tile).left,
              t.boardRect(g.board, g.tile).top,
              t.boardRect(g.board, g.tile).right,
              t.boardRect(g.board, g.tile).bottom
            ],
          }
      ],
    };

/// Replays the *stored historical path*, not a newly solved/generated witness.
/// Every tap and coverage check uses the real engine. No booster or search call.
CampaignJson replayShadowWitness(
    LevelDefinition level, QaScreen screen, List<String> witness) {
  final g = screen.geometry();
  final graph = CampaignGraph(level.tiles, g);
  final engine = GameEngine(level.tiles, objective: level.objective)
    ..updateBoardGeometry(g.board, g.tile);
  final path = <String>[];
  final trace = <CampaignJson>[];
  final expectedIds = level.tiles.map((t) => t.id).toSet();
  final validPath = witness.length == level.tiles.length &&
      witness.toSet().length == witness.length &&
      witness.toSet().containsAll(expectedIds);
  String? failure = validPath ? null : 'WITNESS_IS_NOT_A_FULL_TILE_PERMUTATION';
  CampaignJson? failureState;
  var peak = 0, transientPeak = 0;
  if (validPath) {
    for (var i = 0; i < witness.length; i++) {
      final id = witness[i];
      final legal = graph.available(engine).map((t) => t.id).toList()..sort();
      final before = engine.tray.length;
      failureState = {
        'decision': i,
        'requested_id': id,
        'legal_ids': legal,
        'tray_ids': List<String>.of(engine.tray),
        'tray_types':
            engine.tray.map((id) => engine.tileById(id)!.type).toList(),
        'engine_result': engine.result.name,
        'remaining_board_count': engine.boardTiles.length,
      };
      if (!graph.agreesWithEngine(engine)) {
        failure = 'COVERAGE_DISAGREEMENT';
        break;
      }
      if (!engine.tapTile(id, g.board, g.tile)) {
        failure = 'REJECTED_WITNESS_TAP';
        break;
      }
      path.add(id);
      peak = math.max(peak, engine.tray.length);
      transientPeak = math.max(transientPeak, before + 1);
      trace.add({
        'decision': i,
        'id': id,
        'type': engine.tileById(id)!.type,
        'tray_before': before,
        'tray_after': engine.tray.length,
        'result': engine.result.name
      });
      if (engine.result == GameResult.lost) {
        failure = 'WITNESS_LOSS';
        break;
      }
      failureState = null;
    }
  }
  final cleared = engine.result == GameResult.won &&
      engine.boardTiles.isEmpty &&
      engine.tray.isEmpty &&
      engine.tiles.every((t) => t.state == TileState.matched) &&
      (level.objective == null || engine.objectiveComplete);
  if (failure == null && !cleared)
    failure = 'FULL_CLEARANCE_OR_OBJECTIVE_NOT_VERIFIED';
  return {
    'screen': screen.name,
    'replay_success': failure == null && cleared,
    'evidence': failure == null && cleared ? 'REPLAYED' : 'UNVERIFIED',
    'failure_reason': failure,
    'failure_state': failureState,
    'tile_count': level.tiles.length,
    'witness_path_ids': witness,
    'successful_moves': path.length,
    'winning_moves': cleared ? path : null,
    'tray_peak_after_resolution': peak,
    'tray_peak_before_resolution': transientPeak,
    'final_board_count': engine.boardTiles.length,
    'final_tray_count': engine.tray.length,
    'final_result': engine.result.name,
    'full_clearance': cleared,
    'trace': trace,
    'failure_interpretation': failure == null
        ? null
        : 'This stored witness failed. Investigate the exact first failure; no behavioral run, replacement search, or unsolvability claim is permitted.',
  };
}

CampaignJson shadowSolvabilityGate(LevelDefinition control,
    LevelDefinition candidate, Map<String, List<String>> historicalWitnesses) {
  final invariants = shadowCandidateChecks(control, candidate);
  final screens = <CampaignJson>[];
  for (final screen in qaScreens) {
    final witness = historicalWitnesses[screen.name];
    if (witness == null)
      throw StateError('Missing historical witness ${screen.name}');
    final a = pairedGeometry(CampaignGraph(control.tiles, screen.geometry()));
    final b = pairedGeometry(CampaignGraph(candidate.tiles, screen.geometry()));
    final ba = shadowBounds(control, screen.geometry()),
        bb = shadowBounds(candidate, screen.geometry());
    final controlReplay = replayShadowWitness(control, screen, witness);
    final candidateReplay = replayShadowWitness(candidate, screen, witness);
    final graphEqual = shadowCanonical(a) == shadowCanonical(b);
    final boundsEqual = shadowCanonical(ba) == shadowCanonical(bb);
    screens.add({
      'screen': screen.name,
      'blocking_graph_equal': graphEqual,
      'bounds_equal': boundsEqual,
      'control_geometry': a,
      'candidate_geometry': b,
      'control_bounds': ba,
      'candidate_bounds': bb,
      'control_replay': controlReplay,
      'candidate_replay': candidateReplay,
      'passed': graphEqual &&
          boundsEqual &&
          (ba['outside_ids'] as List).isEmpty &&
          (bb['outside_ids'] as List).isEmpty &&
          controlReplay['replay_success'] == true &&
          candidateReplay['replay_success'] == true,
    });
  }
  return {
    'passed': invariants['passed'] == true &&
        screens.every((s) => s['passed'] == true),
    'invariants': invariants,
    'screens': screens
  };
}

CampaignJson simulateLevel96Shadow(LevelDefinition level, QaScreen screen,
    CampaignPolicy policy, int replica, String variant) {
  if (level.level != 96 ||
      !shadow96Policies.contains(policy) ||
      replica < 0 ||
      replica >= 30 ||
      !shadow96Variants.contains(variant))
    throw ArgumentError('Outside fixed level 96 shadow cohort');
  // Variant is appended only AFTER the unchanged paired-v1 implementation.
  return {
    ...simulatePairedCampaign(
        level,
        CampaignGraph(level.tiles, screen.geometry()),
        policy,
        screen.name,
        replica),
    'shadow_experiment_version': shadow96Version,
    'variant': variant,
    'cohort': replica < 10 ? 'overlap_0_9' : 'holdout_10_29'
  };
}

CampaignJson compareShadowControlReference(
    CampaignJson actual, CampaignJson historical) {
  final raw = Map<String, Object?>.of(actual)
    ..remove('shadow_experiment_version')
    ..remove('variant')
    ..remove('cohort');
  final keys = {...raw.keys, ...historical.keys}.toList()..sort();
  final changed = [
    for (final key in keys)
      if (shadowCanonical(raw[key]) != shadowCanonical(historical[key]) ||
          raw.containsKey(key) != historical.containsKey(key))
        key
  ];
  return {
    'screen': actual['screen'],
    'strategy': actual['strategy'],
    'replica': actual['replica'],
    'passed': changed.isEmpty,
    'comparison': 'FULL_PAIRED_V1_ROW_INCLUDING_COMPLETE_TRACE',
    'outcome_equal': actual['outcome'] == historical['outcome'],
    'trace_equal': shadowCanonical(actual['trace']) ==
        shadowCanonical(historical['trace']),
    'different_fields': changed,
  };
}
