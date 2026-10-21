// Opt-in audit code only. Never imported by the game or ordinary QA suite.
import 'dart:math' as math;
import 'dart:ui';

import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import '../../qa/support/geometry.dart';
import '../../qa/support/solver.dart';

typedef Json = Map<String, Object?>;

Map<String, int> inventory(Iterable<Tile> tiles) {
  final result = <String, int>{};
  for (final t in tiles) {
    result.update(t.type, (n) => n + 1, ifAbsent: () => 1);
  }
  return Map.fromEntries(result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
}

/// Bounds all DFS calls across campaign and Endless together. Reverse-order
/// candidate replay is O(n) engine moves, independent of the DFS node budget.
class SearchBudget {
  SearchBudget(this.perBoard, this.total);
  final int perBoard;
  final int total;
  int spent = 0;
  int get next => math.min(perBoard, math.max(0, total - spent));
}

/// Geometric union and maximum coincident rectangle depth by an exact slab
/// sweep. This measures all positive-area intersections, not the engine's 3%
/// blocking threshold. Touching edges do not add depth.
Json rectangleCoverage(List<Rect> rects, Size board) {
  final xs = rects.expand((r) => [r.left, r.right]).toSet().toList()..sort();
  var area = 0.0;
  var peak = 0;
  for (var i = 0; i + 1 < xs.length; i++) {
    final x = (xs[i] + xs[i + 1]) / 2;
    final events = <(double, int)>[];
    for (final r in rects) {
      if (r.left < x && r.right > x) {
        events.add((r.top, 1));
        events.add((r.bottom, -1));
      }
    }
    events.sort((a, b) {
      final y = a.$1.compareTo(b.$1);
      return y != 0 ? y : a.$2.compareTo(b.$2);
    });
    var depth = 0;
    var previous = 0.0;
    var unionY = 0.0;
    for (final event in events) {
      if (depth > 0) unionY += event.$1 - previous;
      depth += event.$2;
      peak = math.max(peak, depth);
      previous = event.$1;
    }
    area += (xs[i + 1] - xs[i]) * unionY;
  }
  final bounds = rects.reduce((a, b) => a.expandToInclude(b));
  final boundingArea = bounds.width * bounds.height;
  return {
    'union_area': area,
    'board_occupied_fraction': area / (board.width * board.height),
    'bounding_box': [bounds.left, bounds.top, bounds.right, bounds.bottom],
    'union_to_bounding_box': area / boundingArea,
    'tile_area_to_bounding_box': rects.fold<double>(0, (n, r) => n + r.width * r.height) / boundingArea,
    'maximum_coincident_rectangle_depth': peak,
  };
}

/// Produces measurements, a bounded solver result, and an engine-replayed
/// witness trace. No random player simulation or recursive dead-end sampling.
Json auditBoard(List<Tile> tiles, QaGeometry g, SearchBudget budget,
    {LevelObjective? objective}) {
  if (tiles.isEmpty || tiles.map((t) => t.id).toSet().length != tiles.length ||
      tiles.any((t) => !t.x.isFinite || !t.y.isFinite || t.layer < 0 ||
          t.state != TileState.board)) {
    throw StateError('Invalid starting tiles; measurements would be misleading');
  }
  final engine = GameEngine(tiles)..updateBoardGeometry(g.board, g.tile);
  final ordered = engine.renderedBoardTiles;
  final blockers = <String, Set<String>>{for (final t in ordered) t.id: {}};
  final adjacency = <String, Set<String>>{for (final t in ordered) t.id: {}};
  var same = 0;
  var cross = 0;
  final overlappingLayers = <int>{};
  for (var i = 0; i < ordered.length; i++) {
    for (var j = i + 1; j < ordered.length; j++) {
      if (!ordered[i].overlaps(ordered[j], g.board, g.tile)) continue;
      blockers[ordered[i].id]!.add(ordered[j].id);
      adjacency[ordered[i].id]!.add(ordered[j].id);
      adjacency[ordered[j].id]!.add(ordered[i].id);
      if (ordered[i].layer == ordered[j].layer) {
        same++;
      } else {
        cross++;
        overlappingLayers.addAll([ordered[i].layer, ordered[j].layer]);
      }
    }
  }
  final chain = <String, int>{};
  for (final t in ordered.reversed) {
    chain[t.id] = 1 + blockers[t.id]!.fold<int>(0, (v, id) => math.max(v, chain[id]!));
  }
  final initial = ordered.where((t) => blockers[t.id]!.isEmpty).toList();
  final coverageAgrees = ordered.every((t) => engine.isTileCovered(t) == blockers[t.id]!.isNotEmpty);
  final seen = <String>{};
  final components = <int>[];
  for (final t in ordered) {
    if (seen.contains(t.id)) continue;
    final pending = [t.id];
    var size = 0;
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (!seen.add(id)) continue;
      size++;
      pending.addAll(adjacency[id]!.where((id) => !seen.contains(id)));
    }
    components.add(size);
  }
  components.sort();
  final rects = ordered.map((t) => t.boardRect(g.board, g.tile)).toList();
  final outside = [for (var i = 0; i < rects.length; i++)
    if (rects[i].left < 0 || rects[i].top < 0 ||
        rects[i].right > g.board.width + 1e-6 || rects[i].bottom > g.board.height + 1e-6)
      ordered[i].id];
  final counts = inventory(tiles);
  final strictEquivalent = counts.values.every((n) => n % 3 == 0) &&
      (objective == null || (counts[objective.type] ?? 0) >= objective.target);
  final allowedNodes = budget.next;
  final solver = BoardSolver(maxNodes: allowedNodes,
      // Node count is the practical, repeatable cutoff; emergency wall guard
      // still returns UNKNOWN and is disclosed separately in every row.
      timeLimit: const Duration(hours: 1));
  final watch = Stopwatch()..start();
  final solution = solver.solve(tiles, g.board, g.tile, objective: objective);
  watch.stop();
  budget.spent += solution.nodes;
  final issues = <String>[];
  if (!coverageAgrees) issues.add('BLOCKER_MODEL_ENGINE_DISAGREEMENT');
  if (outside.isNotEmpty) issues.add('TILES_OUTSIDE_LOGICAL_BOARD');
  if (!strictEquivalent) issues.add('STRICT_CLEARANCE_DIFFERS_FROM_ENGINE_WIN');
  if (solution.status == SolveStatus.unsolvable) issues.add('STRICT_CLEARANCE_UNSOLVABLE');
  if (solution.status == SolveStatus.unknown) issues.add('SOLVABILITY_INCONCLUSIVE');

  final trace = <Json>[];
  bool? replayPassed;
  Json? pathMetrics;
  double? score;
  Json? scoreTerms;
  if (solution.status == SolveStatus.solved) {
    final state = GameEngine(tiles, objective: objective);
    var peak = 0;
    var transientPeak = 0;
    var legalTotal = 0;
    var forced = 0;
    var fatalTotal = 0;
    var pressureTotal = 0;
    var passed = true;
    for (final id in solution.path) {
      final remaining = state.boardTiles.map((t) => t.id).toSet();
      final legal = ordered.where((t) => remaining.contains(t.id) &&
          blockers[t.id]!.every((b) => !remaining.contains(b))).toList();
      final trayTypes = inventory(state.tray.map((id) => state.tileById(id)!));
      final before = state.tray.length;
      final immediateLosses = legal.where((t) =>
          before + ((trayTypes[t.type] ?? 0) == 2 ? -2 : 1) >= GameEngine.trayLimit).length;
      legalTotal += legal.length;
      fatalTotal += immediateLosses;
      if (legal.length == 1) forced++;
      transientPeak = math.max(transientPeak, before + 1);
      if (!state.tapTile(id, g.board, g.tile) || state.result == GameResult.lost) {
        passed = false;
        break;
      }
      peak = math.max(peak, state.tray.length);
      pressureTotal += state.tray.length;
      trace.add({'id': id, 'legal_choices': legal.length,
        'immediate_losing_choices': immediateLosses,
        'tray_before': before, 'tray_after_resolution': state.tray.length});
    }
    replayPassed = passed && state.result == GameResult.won &&
        state.boardTiles.isEmpty && state.tray.isEmpty &&
        state.tiles.every((t) => t.state == TileState.matched) &&
        (objective == null || state.objectiveComplete);
    if (!replayPassed) issues.add('WITNESS_REPLAY_DISAGREEMENT');
    if (replayPassed) {
      final meanLegal = legalTotal / trace.length;
      final forcedRate = forced / trace.length;
      pathMetrics = {
        'peak_tray_after_resolution': peak,
        'peak_tray_before_resolution': transientPeak,
        'mean_tray_after_resolution': pressureTotal / trace.length,
        'minimum_safe_capacity_margin': 6 - peak,
        'mean_legal_choices': meanLegal,
        'forced_single_choice_steps': forced,
        'forced_single_choice_fraction': forcedRate,
        'immediate_losing_choices_total': fatalTotal,
        'legal_choices_total': legalTotal,
        'immediate_losing_choice_fraction': fatalTotal / legalTotal,
        'minimum_required_peak_tray': 'NOT MEASURED',
        'non_immediate_dead_end_rate': 'NOT MEASURED',
        'player_win_rate': 'NOT MEASURED',
      };
      double unit(num value) => value.toDouble().clamp(0.0, 1.0);
      // A transparent, uncalibrated ranking proxy; never a measured win rate.
      scoreTerms = {
        'workload_10': 10 * unit(tiles.length / 108),
        'type_diversity_15': 15 * unit(counts.length / 15),
        'initial_blocking_20': 20 * (1 - initial.length / tiles.length),
        'blocker_chain_15': 15 * unit((chain.values.reduce(math.max) - 1) / 12),
        'witness_tray_pressure_25': 25 * unit(peak / 6),
        'witness_choice_scarcity_15': 15 / meanLegal,
      };
      score = scoreTerms.values.fold<double>(0, (sum, v) => sum + (v as double));
    }
  }
  return {
    'board_size': [g.board.width, g.board.height],
    'tile_size': [g.tile.width, g.tile.height],
    'geometry': {
      'layer_labels': tiles.map((t) => t.layer).toSet().toList()..sort(),
      'layers_in_cross_layer_blocking': overlappingLayers.toList()..sort(),
      'overlapping_layer_count': overlappingLayers.length,
      'initial_playable': initial.length,
      'initial_playable_ids': initial.map((t) => t.id).toList(),
      'initial_playable_types': inventory(initial),
      'initial_blocked': tiles.length - initial.length,
      'same_layer_blocking_edges': same, 'cross_layer_blocking_edges': cross,
      'max_direct_blockers': blockers.values.map((v) => v.length).reduce(math.max),
      'max_blocker_chain_tiles': chain.values.reduce(math.max),
      'blocking_component_sizes': components,
      'initial_coverage_matches_engine': coverageAgrees,
      'outside_board_ids': outside,
      ...rectangleCoverage(rects, g.board),
    },
    'solver': {
      ...solution.toJson(),
      if (replayPassed == false) 'status': 'UNKNOWN',
      'criterion': 'FULL_CLEARANCE_AND_OBJECTIVE',
      'criterion_equivalent_to_engine_win_for_this_inventory': strictEquivalent,
      'engine_win_status': replayPassed == false ? 'UNKNOWN' : replayPassed == true ? 'SOLVED' :
          strictEquivalent ? solution.status.name.toUpperCase() : 'UNKNOWN',
      'max_nodes': allowedNodes, 'emergency_wall_seconds': 3600,
      'observed_milliseconds': watch.elapsedMilliseconds,
      'witness_replay_passed': replayPassed,
      'proof_scope': 'This initial board and geometry; taps only; no boosters',
    },
    'witness_metrics': pathMetrics,
    'witness_trace': trace,
    'difficulty_score': score,
    'difficulty_terms': scoreTerms,
    'difficulty_explanation': 'Uncalibrated 0-100 ranking proxy, based on geometry and one verified path. Not minimum tray pressure, human win rate, or proof of forced choices off that path.',
    'issues': issues,
  };
}
