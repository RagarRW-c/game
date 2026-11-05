// Campaign-only measurement. No IO, boosters, authoring, or production imports
// other than the real rules/data types. Policies never receive a full engine.
import 'dart:convert';
import 'dart:math' as math;

import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import '../../qa/support/geometry.dart';
import '../../qa/support/solver.dart';
import 'balance_metrics.dart' as existing;

typedef CampaignJson = Map<String, Object?>;

const campaignPriorityLevels = [
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  23,
  24,
  29,
  46,
  65,
  71,
  76,
  78,
  80,
  84,
  89,
  92,
  96,
  98,
];
const campaignWorlds = [
  'garden',
  'ocean',
  'candy',
  'space',
  'desert',
  'ice',
  'jungle',
  'volcano',
  'dream',
  'crystal',
];

String campaignFingerprint(List<int> bytes) {
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

enum CampaignPolicy { randomLegal, greedyMatch, visibleLookahead }

int campaignSeed(int level, String screen, CampaignPolicy policy, int seed) =>
    int.parse(
        campaignFingerprint(
            utf8.encode('campaign4c/v1|$level|$screen|${policy.name}|$seed')),
        radix: 16);

/// Versioned xorshift32; no SDK Random or String.hashCode dependency.
class CampaignRng {
  CampaignRng(int seed)
      : _state = (seed & 0xffffffff) == 0 ? 0x6d2b79f5 : seed & 0xffffffff;
  int _state;
  int nextUint32() {
    var x = _state;
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    return _state = x & 0xffffffff;
  }

  int nextInt(int bound) {
    if (bound <= 0 || bound > 0x7fffffff) throw ArgumentError.value(bound);
    final limit = 0x100000000 - (0x100000000 % bound);
    int draw;
    do {
      draw = nextUint32();
    } while (draw >= limit);
    return draw % bound;
  }

  void shuffle<T>(List<T> values) {
    for (var i = values.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final item = values[i];
      values[i] = values[j];
      values[j] = item;
    }
  }
}

Map<String, int> _counts(Iterable<Tile> tiles) {
  final result = <String, int>{};
  for (final tile in tiles) {
    result.update(tile.type, (n) => n + 1, ifAbsent: () => 1);
  }
  return result;
}

/// Cache only the immutable coverage DAG, using the authoritative overlap
/// predicate and paint order. All state transitions still go through tapTile.
class CampaignGraph {
  CampaignGraph(List<Tile> tiles, this.geometry)
      : ordered = GameEngine(tiles).renderedBoardTiles {
    for (var i = 0; i < ordered.length; i++) {
      final lower = ordered[i];
      blockers[lower.id] = {};
      for (final upper in ordered.skip(i + 1)) {
        if (!lower.overlaps(upper, geometry.board, geometry.tile)) continue;
        blockers[lower.id]!.add(upper.id);
        final a = lower.boardRect(geometry.board, geometry.tile);
        final intersection =
            a.intersect(upper.boardRect(geometry.board, geometry.tile));
        final ratio =
            intersection.width * intersection.height / (a.width * a.height);
        edges.add(
            {'lower': lower.id, 'upper': upper.id, 'covered_ratio': ratio});
        if (lower.layer == upper.layer) sameLayerEdges++;
      }
    }
    for (final tile in ordered.reversed) {
      depth[tile.id] = 1 +
          blockers[tile.id]!.fold<int>(0, (n, id) => math.max(n, depth[id]!));
    }
  }
  final QaGeometry geometry;
  final List<Tile> ordered;
  final blockers = <String, Set<String>>{};
  final depth = <String, int>{};
  final edges = <CampaignJson>[];
  int sameLayerEdges = 0;

  List<Tile> available(GameEngine engine) {
    final board = engine.boardTiles;
    final ids = board.map((t) => t.id).toSet();
    return board
        .where((t) => blockers[t.id]!.every((id) => !ids.contains(id)))
        .toList();
  }

  bool agreesWithEngine(GameEngine engine) {
    engine.updateBoardGeometry(geometry.board, geometry.tile);
    final legal = available(engine).map((t) => t.id).toSet();
    return engine.boardTiles
        .every((t) => legal.contains(t.id) == !engine.isTileCovered(t));
  }
}

/// The only input accepted by behavioral policies. Covered identities,
/// authoring indices, level number, witness and total inventory are absent.
/// All exposed tiles are conservatively considered readable; partially visible
/// blocked symbols are deliberately excluded rather than guessed.
class VisibleCampaignBoard {
  VisibleCampaignBoard._(this.exposed, this.tray, this.geometry);
  final List<Tile> exposed;
  final List<Tile> tray;
  final QaGeometry geometry;

  GameEngine _project() => GameEngine([...exposed, ...tray])
    ..tray = tray.map((t) => t.id).toList()
    ..updateBoardGeometry(geometry.board, geometry.tile);

  CampaignJson toJson() => {
        'exposed': [
          for (final t in exposed) [t.id, t.type, t.x, t.y]
        ],
        'tray': [
          for (final t in tray) [t.id, t.type]
        ],
      };
}

class CampaignObservation {
  CampaignObservation._(this.visible, this.actualIdByHandle);
  final VisibleCampaignBoard visible;
  final Map<String, String> actualIdByHandle;

  factory CampaignObservation.capture(GameEngine engine, CampaignGraph graph) {
    final exposed = graph.available(engine)
      ..sort((a, b) {
        final y = a.y.compareTo(b.y);
        return y != 0 ? y : a.x.compareTo(b.x);
      });
    final publicTiles = <Tile>[];
    final ids = <String, String>{};
    for (var i = 0; i < exposed.length; i++) {
      final t = exposed[i];
      final handle = 'visible_$i';
      ids[handle] = t.id;
      publicTiles.add(Tile(id: handle, type: t.type, x: t.x, y: t.y, layer: 0));
    }
    final tray = [
      for (var i = 0; i < engine.tray.length; i++)
        Tile(
            id: 'tray_$i',
            type: engine.tileById(engine.tray[i])!.type,
            x: 0,
            y: 0,
            layer: 0,
            state: TileState.tray)
    ];
    return CampaignObservation._(
        VisibleCampaignBoard._(List.unmodifiable(publicTiles),
            List.unmodifiable(tray), graph.geometry),
        Map.unmodifiable(ids));
  }
}

GameEngine _copyProjection(GameEngine engine, QaGeometry geometry) =>
    GameEngine(engine.tiles)
      ..tray = List.of(engine.tray)
      ..result = engine.result
      ..updateBoardGeometry(geometry.board, geometry.tile);

class _Move {
  _Move(this.tile, this.after, this.lost, this.trayMatches, this.exposedCount);
  final Tile tile;
  final int after, trayMatches, exposedCount;
  final bool lost;
}

List<_Move> _moves(GameEngine projection, QaGeometry geometry) {
  final trayCounts =
      _counts(projection.tray.map((id) => projection.tileById(id)!));
  final counts = _counts(projection.boardTiles);
  return [
    for (final tile in projection.boardTiles)
      if (!projection.isTileCovered(tile))
        _evaluateMove(projection, geometry, tile, trayCounts[tile.type] ?? 0,
            counts[tile.type]!)
  ];
}

_Move _evaluateMove(GameEngine engine, QaGeometry geometry, Tile tile,
    int trayMatches, int exposedCount) {
  final next = _copyProjection(engine, geometry);
  if (!next.tapTile(tile.id, geometry.board, geometry.tile)) {
    throw StateError('Visible projection rejected ${tile.id}');
  }
  return _Move(tile, next.tray.length, next.result == GameResult.lost,
      trayMatches, exposedCount);
}

int _greedyCompare(_Move a, _Move b) {
  if (a.lost != b.lost) return a.lost ? 1 : -1;
  if (a.after != b.after) return a.after.compareTo(b.after);
  if (a.trayMatches != b.trayMatches) {
    return b.trayMatches.compareTo(a.trayMatches);
  }
  return b.exposedCount.compareTo(a.exposedCount);
}

// Optional paired hooks receive sanitized public tiles only. Null preserves
// the historical RNG calls, traversal order and first-equal-leaf behavior.
typedef CampaignTieBreak = int Function(Tile a, Tile b, List<Tile> plannedPath);
typedef CampaignRankObserver = void Function(
    List<CampaignJson> ranked, List<Tile> plannedPath);

List<_Move> _rankedMoves(
    GameEngine engine, QaGeometry geometry, CampaignRng rng,
    {CampaignTieBreak? tieBreak,
    CampaignRankObserver? onRanked,
    List<Tile> plannedPath = const []}) {
  final moves = _moves(engine, geometry);
  if (tieBreak == null) rng.shuffle(moves);
  // Explicit tie indices: Dart sort stability is not part of the seed policy.
  final tie = {for (var i = 0; i < moves.length; i++) moves[i].tile.id: i};
  moves.sort((a, b) {
    final rank = _greedyCompare(a, b);
    return rank != 0
        ? rank
        : tieBreak != null
            ? tieBreak(a.tile, b.tile, plannedPath)
            : tie[a.tile.id]!.compareTo(tie[b.tile.id]!);
  });
  onRanked?.call([
    for (final m in moves)
      {
        'handle': m.tile.id,
        'lost': m.lost,
        'tray_after': m.after,
        'tray_matches': m.trayMatches,
        'exposed_same_type': m.exposedCount,
      }
  ], plannedPath);
  return moves;
}

class CampaignDecision {
  const CampaignDecision(this.handle,
      {this.nodes = 0, this.branchPruned = 0, this.budgetExhausted = false});
  final String? handle;
  final int nodes, branchPruned;
  final bool budgetExhausted;
}

class _PlanValue {
  _PlanValue(GameEngine engine, this.peak)
      : lost = engine.result == GameResult.lost,
        matched =
            engine.tiles.where((t) => t.state == TileState.matched).length,
        tray = engine.tray.length;
  final bool lost;
  final int matched, peak, tray;
  bool betterThan(_PlanValue other) {
    if (lost != other.lost) return !lost;
    if (matched != other.matched) return matched > other.matched;
    if (peak != other.peak) return peak < other.peak;
    return tray < other.tray;
  }
}

CampaignDecision decideCampaignMove(
    VisibleCampaignBoard view, CampaignPolicy policy, CampaignRng rng,
    {int lookaheadNodes = 84,
    CampaignTieBreak? tieBreak,
    CampaignRankObserver? onRanked}) {
  if (view.exposed.isEmpty) return const CampaignDecision(null);
  if (policy == CampaignPolicy.randomLegal) {
    if (tieBreak != null) {
      final ordered = List<Tile>.of(view.exposed)
        ..sort((a, b) => tieBreak(a, b, const []));
      return CampaignDecision(ordered.first.id);
    }
    return CampaignDecision(view.exposed[rng.nextInt(view.exposed.length)].id);
  }
  final projection = view._project();
  if (policy == CampaignPolicy.greedyMatch) {
    return CampaignDecision(_rankedMoves(projection, view.geometry, rng,
            tieBreak: tieBreak, onRanked: onRanked)
        .first
        .tile
        .id);
  }
  if (lookaheadNodes < 1) {
    return const CampaignDecision(null, budgetExhausted: true);
  }
  var nodes = 0, pruned = 0;
  var exhausted = false;
  _PlanValue? best;
  String? chosen;
  void visit(GameEngine state, int depth, int peak, String? root,
      List<Tile> plannedPath) {
    // 'won' here only means the CURRENTLY exposed set ran out. Never use it
    // as a victory reward or inspect a newly uncovered identity in lookahead.
    if (depth == 3 || state.result != GameResult.playing) {
      final value = _PlanValue(state, peak);
      if (best == null || value.betterThan(best!)) {
        best = value;
        chosen = root;
      }
      return;
    }
    final options = _rankedMoves(state, view.geometry, rng,
        tieBreak: tieBreak, onRanked: onRanked, plannedPath: plannedPath);
    pruned += math.max(0, options.length - 4);
    for (final option in options.take(4)) {
      if (nodes >= lookaheadNodes) {
        exhausted = true;
        return;
      }
      nodes++;
      final next = _copyProjection(state, view.geometry);
      if (!next.tapTile(
          option.tile.id, view.geometry.board, view.geometry.tile)) {
        throw StateError('Lookahead selected an invalid visible move');
      }
      visit(
          next,
          depth + 1,
          math.max(peak, next.tray.length),
          root ?? option.tile.id,
          tieBreak == null && onRanked == null
              ? const []
              : [...plannedPath, option.tile]);
    }
  }

  visit(projection, 0, projection.tray.length, null, const []);
  return CampaignDecision(chosen,
      nodes: nodes, branchPruned: pruned, budgetExhausted: exhausted);
}

/// The same tracer is used for a separate known witness and for policies.
/// Its privileged measurements are never passed to a policy.
CampaignJson _traceCampaign(LevelDefinition level, CampaignGraph graph,
    {CampaignPolicy? policy,
    int seed = 0,
    String screen = '',
    List<String>? witness,
    int? moveBudget,
    bool verifyCoverageEachMove = false}) {
  final engine = GameEngine(level.tiles, objective: level.objective)
    ..updateBoardGeometry(graph.geometry.board, graph.geometry.tile);
  final rngSeed =
      policy == null ? null : campaignSeed(level.level, screen, policy, seed);
  final rng = CampaignRng(rngSeed ?? 1);
  final budget = moveBudget ?? level.tiles.length;
  final path = <String>[];
  final choices = <int>[], occupancies = <int>[], losing = <int>[];
  var noMatch = 0,
      forced = 0,
      onlyOneSafe = 0,
      reliefStates = 0,
      reliefMoves = 0;
  var nodes = 0, pruned = 0, exhaustedDecisions = 0, transientPeak = 0;
  int? firstTriple;
  String? stopped;
  while (engine.result == GameResult.playing && path.length < budget) {
    if (verifyCoverageEachMove && !graph.agreesWithEngine(engine)) {
      stopped = 'COVERAGE_DISAGREEMENT';
      break;
    }
    final capture = CampaignObservation.capture(engine, graph);
    final view = capture.visible;
    if (view.exposed.isEmpty) {
      stopped = 'UNEXPECTED_NO_LEGAL_TILE';
      break;
    }
    final moves = _moves(view._project(), view.geometry);
    final fatalities = moves.where((m) => m.lost).length;
    final visibleCounts = _counts([...view.exposed, ...view.tray]);
    final relief =
        moves.where((m) => !m.lost && m.after < engine.tray.length).length;
    String? id;
    if (witness != null) {
      if (path.length < witness.length) id = witness[path.length];
    } else {
      final decision = decideCampaignMove(view, policy!, rng);
      nodes += decision.nodes;
      pruned += decision.branchPruned;
      if (decision.budgetExhausted) exhaustedDecisions++;
      id = capture.actualIdByHandle[decision.handle];
    }
    if (id == null) {
      stopped = 'NO_DECISION_WITHIN_BUDGET';
      break;
    }
    final before = engine.tray.length;
    final matchedBefore =
        engine.tiles.where((t) => t.state == TileState.matched).length;
    if (!engine.tapTile(id, graph.geometry.board, graph.geometry.tile)) {
      stopped = 'INVALID_MOVE';
      break;
    }
    if (!visibleCounts.values.any((n) => n >= 3)) noMatch++;
    if (moves.length == 1) forced++;
    if (moves.length - fatalities == 1) onlyOneSafe++;
    if (before >= 5 && relief > 0) {
      reliefStates++;
      reliefMoves += relief;
    }
    path.add(id);
    choices.add(moves.length);
    losing.add(fatalities);
    occupancies.add(engine.tray.length);
    transientPeak = math.max(transientPeak, before + 1);
    if (firstTriple == null &&
        engine.tiles.where((t) => t.state == TileState.matched).length >
            matchedBefore) {
      firstTriple = path.length;
    }
  }
  if (engine.result == GameResult.playing && stopped == null) {
    stopped = 'MOVE_BUDGET';
  }
  final outcome = stopped != null
      ? 'INCONCLUSIVE'
      : engine.result == GameResult.won
          ? 'WIN'
          : engine.result == GameResult.lost
              ? 'LOSS'
              : 'INCONCLUSIVE';
  final peak = occupancies.fold<int>(0, math.max);
  final mean = occupancies.isEmpty
      ? 0.0
      : occupancies.reduce((a, b) => a + b) / occupancies.length;
  return {
    'evidence': policy == null ? 'REPLAYED' : 'SIMULATED',
    'outcome': outcome,
    'stop_reason': stopped ?? engine.result.name,
    'invalid_move_count': stopped == 'INVALID_MOVE' ? 1 : 0,
    'unexpected_deadlock_count': stopped == 'UNEXPECTED_NO_LEGAL_TILE' ? 1 : 0,
    'seed_index': policy == null ? null : seed,
    'derived_seed_uint32': rngSeed,
    'strategy': policy?.name ?? 'constructive_witness_NOT_A_PLAYER',
    'information_model': policy == null ? 'known_witness' : 'exposed_only_v1',
    'omniscient': policy == null,
    'move_budget': budget,
    'decisions': path.length,
    'max_tray_after_resolution': peak,
    'max_tray_before_resolution': transientPeak,
    'mean_tray_after_resolution': mean,
    'average_tray_pressure': mean / GameEngine.trayLimit,
    'maximum_tray_pressure': peak / GameEngine.trayLimit,
    'moves_to_first_triple': firstTriple,
    'forced_single_choice_decisions': forced,
    'one_nonlosing_choice_decisions': onlyOneSafe,
    'states_without_visible_complete_set': noMatch,
    'immediate_losing_moves_encountered': losing.fold<int>(0, (a, b) => a + b),
    'states_with_losing_choices': losing.where((n) => n > 0).length,
    'high_pressure_immediate_relief_states': reliefStates,
    'high_pressure_immediate_relief_choices': reliefMoves,
    'lookahead_nodes': nodes,
    'lookahead_branch_options_pruned': pruned,
    'lookahead_budget_exhausted_decisions': exhaustedDecisions,
    'choices_by_decision': choices,
    'tray_after_by_decision': occupancies,
    'immediate_losing_choices_by_decision': losing,
    'path_ids': path,
    'final_engine_result': engine.result.name,
    'final_board_count': engine.boardTiles.length,
    'final_tray_count': engine.tray.length,
    'full_clearance': engine.boardTiles.isEmpty &&
        engine.tray.isEmpty &&
        engine.tiles.every((t) => t.state == TileState.matched),
    'objective_complete':
        level.objective == null ? null : engine.objectiveComplete,
  };
}

CampaignJson simulateCampaign(LevelDefinition level, CampaignGraph graph,
        CampaignPolicy policy, String screen, int seed,
        {int? moveBudget}) =>
    {
      'level': level.level,
      'screen': screen,
      ..._traceCampaign(level, graph,
          policy: policy, screen: screen, seed: seed, moveBudget: moveBudget),
    };

List<String> campaignInputIssues(LevelDefinition level) {
  final tiles = level.tiles;
  final counts = _counts(tiles);
  return [
    if (level.level < 1 || level.level > 100) 'INVALID_CAMPAIGN_LEVEL',
    if (tiles.isEmpty) 'EMPTY_BOARD',
    if (tiles.map((t) => t.id).toSet().length != tiles.length) 'DUPLICATE_IDS',
    if (tiles.any((t) =>
        t.id.isEmpty ||
        t.type.isEmpty ||
        !t.x.isFinite ||
        !t.y.isFinite ||
        t.layer < 0 ||
        t.state != TileState.board))
      'INVALID_TILE',
    if (counts.values.any((n) => n % 3 != 0)) 'INCOMPLETE_TRIPLE_INVENTORY',
    if (level.objective != null &&
        (level.objective!.target <= 0 ||
            (counts[level.objective!.type] ?? 0) < level.objective!.target))
      'OBJECTIVE_INVENTORY',
  ];
}

CampaignJson campaignBaseline(LevelDefinition level, QaScreen screen) {
  final g = screen.geometry(); // Campaign branch only.
  final issues = campaignInputIssues(level);
  final base = <String, Object?>{
    'level': level.level,
    'screen': screen.name,
    'world': level.level >= 1 && level.level <= 100
        ? campaignWorlds[(level.level - 1) ~/ 10]
        : null,
    'boss': level.level % 10 == 0,
    'board_size': [g.board.width, g.board.height],
    'tile_size': [g.tile.width, g.tile.height],
    'tile_count': level.tiles.length,
    'type_count': _counts(level.tiles).length,
    'layer_count': level.tiles.map((t) => t.layer).toSet().length,
    'issues': issues,
  };
  if (issues.isNotEmpty) {
    return {...base, 'status': 'INVALID_INPUT', 'witness_status': 'UNVERIFIED'};
  }
  final graph = CampaignGraph(level.tiles, g);
  final engine = GameEngine(level.tiles)..updateBoardGeometry(g.board, g.tile);
  final available = graph.available(engine);
  final initialTypes = _counts(available);
  final outside = [
    for (final t in level.tiles)
      if (t.boardRect(g.board, g.tile).left < 0 ||
          t.boardRect(g.board, g.tile).top < 0 ||
          t.boardRect(g.board, g.tile).right > g.board.width + 1e-6 ||
          t.boardRect(g.board, g.tile).bottom > g.board.height + 1e-6)
        t.id
  ];
  if (outside.isNotEmpty) issues.add('OUTSIDE_LOGICAL_BOARD');
  if (!graph.agreesWithEngine(engine)) issues.add('COVERAGE_DISAGREEMENT');
  final path = graph.ordered.reversed.map((t) => t.id).toList();
  // Existing authoritative replay, NOT a search and NOT a behavioral policy.
  final replay = const BoardSolver(maxNodes: 0)
      .replay(level.tiles, g.board, g.tile, path, objective: level.objective);
  final witness = _traceCampaign(level, graph,
      witness: path, screen: screen.name, verifyCoverageEachMove: true);
  final witnessed = replay &&
      witness['outcome'] == 'WIN' &&
      witness['full_clearance'] == true;
  if (!witnessed) issues.add('CONSTRUCTIVE_WITNESS_NOT_VERIFIED');
  return {
    ...base,
    'status': issues.isEmpty ? 'VALIDATED' : 'REVIEW_REQUIRED',
    'confirmed': {
      'evidence': 'CONFIRMED',
      'initial_exposed_tiles': available.length,
      'initial_exposed_ids': available.map((t) => t.id).toList(),
      'initial_exposed_types': initialTypes,
      'initial_visible_triples':
          initialTypes.values.fold<int>(0, (n, count) => n + count ~/ 3),
      'initial_blocked_fraction': 1 - available.length / level.tiles.length,
      'blocking_depth_tiles': graph.depth.values.reduce(math.max),
      'same_layer_blocking_edges': graph.sameLayerEdges,
      'cross_layer_blocking_edges': graph.edges.length - graph.sameLayerEdges,
      'logical_coverage_threshold': 0.03,
      'blocking_graph_fnv1a32':
          campaignFingerprint(utf8.encode(jsonEncode(graph.edges))),
      'blocking_dependencies_fnv1a32':
          campaignFingerprint(utf8.encode(jsonEncode([
        for (final e in graph.edges) [e['lower'], e['upper']]
      ]))),
      'smallest_blocking_overlap': graph.edges.isEmpty
          ? null
          : graph.edges
              .map((e) => e['covered_ratio'] as double)
              .reduce(math.min),
      'near_threshold_examples': graph.edges
          .where((e) => (e['covered_ratio'] as double) <= .04)
          .take(10)
          .toList(),
      'outside_board_ids': outside,
      ...existing.rectangleCoverage(
          level.tiles.map((t) => t.boardRect(g.board, g.tile)).toList(),
          g.board),
    },
    'witness_status': witnessed ? 'REPLAYED' : 'UNVERIFIED',
    'existing_solver_replay_passed': replay,
    'witness': witness,
  };
}
