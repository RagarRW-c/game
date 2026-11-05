// Isolated Campaign experiment. Hidden diagnostics never enter decision hooks.
import 'dart:convert';
import 'dart:math' as math;

import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import 'campaign_validation.dart';

const pairedVersion = 'campaign4d2/paired-v1';
const pairedLevels = [3, 23, 29, 65, 71, 76, 78, 84, 92, 96, 98];
const pairedReplicas = 10;
const pairedAttemptCount = 990;
const pairedSeedPolicy = 'seed=FNV1a32(UTF8(JSON([version,level,replica]))); '
    'priority=FNV1a32(UTF8(JSON([version,level,replica,decision,domain,path,token]))); '
    'ascending unsigned priority, then token lexicographically; '
    'domain=actual with path=[] at root, plan with public hypothetical path otherwise; '
    'token=JSON([visible type,normalized x string,normalized y string]); '
    'no screen, strategy, handles, authoring IDs, hidden symbols or RNG state';

int _hash(Object value) =>
    int.parse(campaignFingerprint(utf8.encode(jsonEncode(value))), radix: 16);

/// x/y are the normalized top-left position already exposed by the historical
/// observation. No pixel rounding: preserve distinct positions and normalize -0.
String publicTileToken(Tile tile) => jsonEncode([
      tile.type,
      (tile.x == 0 ? 0.0 : tile.x).toString(),
      (tile.y == 0 ? 0.0 : tile.y).toString(),
    ]);

class PairedPriorities {
  const PairedPriorities(this.level, this.replica, this.decision);
  final int level, replica, decision;
  int get experimentSeed => _hash([pairedVersion, level, replica]);

  int priority(String token, {List<String> plannedPath = const []}) => _hash([
        pairedVersion,
        level,
        replica,
        decision,
        plannedPath.isEmpty ? 'actual' : 'plan',
        plannedPath,
        token,
      ]);

  int compare(Tile a, Tile b, List<Tile> plannedPath) {
    final left = publicTileToken(a), right = publicTileToken(b);
    final path = plannedPath.map(publicTileToken).toList();
    final order = priority(left, plannedPath: path)
        .compareTo(priority(right, plannedPath: path));
    return order == 0 ? left.compareTo(right) : order;
  }
}

/// Fail closed if any paired branch accidentally reintroduces sequential RNG.
class NoPairedRng extends CampaignRng {
  NoPairedRng() : super(1);
  @override
  int nextUint32() => throw StateError('RNG consumption in paired experiment');
  @override
  int nextInt(int bound) =>
      throw StateError('RNG consumption in paired experiment');
  @override
  void shuffle<T>(List<T> values) =>
      throw StateError('RNG consumption in paired experiment');
}

Map<String, int> _types(Iterable<Tile> tiles) {
  final result = <String, int>{};
  for (final tile in tiles) {
    result.update(tile.type, (n) => n + 1, ifAbsent: () => 1);
  }
  return result;
}

CampaignJson pairedAttemptIdentity(
        int level, String screen, CampaignPolicy policy, int replica) =>
    {
      'experiment_version': pairedVersion,
      'policy_version': '${policy.name}/paired-ties-v1',
      'level': level,
      'screen': screen,
      'strategy': policy.name,
      'replica': replica,
      'experiment_seed_uint32':
          PairedPriorities(level, replica, 0).experimentSeed,
      'information_model': 'exposed_only_v1',
      'omniscient': false,
    };

CampaignJson simulatePairedCampaign(LevelDefinition level, CampaignGraph graph,
    CampaignPolicy policy, String screen, int replica,
    {int? moveBudget}) {
  final engine = GameEngine(level.tiles, objective: level.objective)
    ..updateBoardGeometry(graph.geometry.board, graph.geometry.tile);
  final trace = <CampaignJson>[];
  final path = <String>[];
  final budget = moveBudget ?? level.tiles.length;
  String? stopped;
  int? firstAvailable, firstCompleting, firstHighRisk, firstResolved;
  var nodes = 0, pruned = 0, exhausted = 0, transientPeak = 0;
  while (engine.result == GameResult.playing && path.length < budget) {
    if (!graph.agreesWithEngine(engine)) {
      stopped = 'COVERAGE_DISAGREEMENT';
      break;
    }
    final capture = CampaignObservation.capture(engine, graph);
    final view = capture.visible;
    final tokens = {for (final t in view.exposed) t.id: publicTileToken(t)};
    if (tokens.isEmpty) {
      stopped = 'UNEXPECTED_NO_LEGAL_TILE';
      break;
    }
    // Coincident public candidates cannot be selected by an invisible fallback.
    // Such tiles cannot both be legal under the current positive-size geometry.
    if (tokens.values.toSet().length != tokens.length) {
      stopped = 'AMBIGUOUS_PUBLIC_TOKEN';
      break;
    }
    final index = path.length; // zero-based successful actual tap index
    final priorities = PairedPriorities(level.level, replica, index);
    final trayTypes = _types(view.tray);
    final visibleTypes = _types([...view.tray, ...view.exposed]);
    final complete =
        visibleTypes.keys.where((t) => visibleTypes[t]! >= 3).toList()..sort();
    final before = engine.tray.length;
    final candidates = <CampaignJson>[];
    for (final tile in view.exposed) {
      // Only sanitized, currently selectable tiles are previewed.
      final projected = GameEngine([...view.exposed, ...view.tray])
        ..tray = view.tray.map((t) => t.id).toList();
      if (!projected.tapTile(
          tile.id, graph.geometry.board, graph.geometry.tile)) {
        throw StateError('Public preview rejected ${tile.id}');
      }
      candidates.add({
        'token': tokens[tile.id],
        'priority_uint32': priorities.priority(tokens[tile.id]!),
        'tray_after': projected.tray.length,
        'immediate_loss': projected.result == GameResult.lost,
        'completes_triple': (trayTypes[tile.type] ?? 0) >= 2,
      });
    }
    candidates
        .sort((a, b) => (a['token'] as String).compareTo(b['token'] as String));
    if (complete.isNotEmpty) firstAvailable ??= index;
    if (candidates.any((c) => c['completes_triple'] == true))
      firstCompleting ??= index;
    if (before >= 6) firstHighRisk ??= index;
    final rankings = <CampaignJson>[];
    final decision = decideCampaignMove(view, policy, NoPairedRng(),
        tieBreak: priorities.compare, onRanked: (ranked, plannedPath) {
      rankings.add({
        'planned_path_tokens': plannedPath.map(publicTileToken).toList(),
        'domain': plannedPath.isEmpty ? 'actual' : 'plan',
        'branch_limit': policy == CampaignPolicy.visibleLookahead ? 4 : 1,
        'ranked': [
          for (var i = 0; i < ranked.length; i++)
            {
              'token': tokens[ranked[i]['handle']],
              'priority_uint32': priorities.priority(
                  tokens[ranked[i]['handle']]!,
                  plannedPath: plannedPath.map(publicTileToken).toList()),
              for (final key in [
                'lost',
                'tray_after',
                'tray_matches',
                'exposed_same_type'
              ])
                key: ranked[i][key],
              'within_branch_cap':
                  i < (policy == CampaignPolicy.visibleLookahead ? 4 : 1),
            }
        ],
      });
    });
    nodes += decision.nodes;
    pruned += decision.branchPruned;
    if (decision.budgetExhausted) exhausted++;
    final actualId = capture.actualIdByHandle[decision.handle];
    if (actualId == null) {
      stopped = 'NO_DECISION_WITHIN_BUDGET';
      break;
    }
    final remaining = engine.boardTiles.map((t) => t.id).toList()..sort();
    final actualTray = List<String>.of(engine.tray);
    final legalIds = capture.actualIdByHandle.values.toList()..sort();
    final matchedBefore =
        engine.tiles.where((t) => t.state == TileState.matched).length;
    if (!engine.tapTile(actualId, graph.geometry.board, graph.geometry.tile)) {
      stopped = 'INVALID_MOVE';
      break;
    }
    final resolved =
        engine.tiles.where((t) => t.state == TileState.matched).length >
            matchedBefore;
    if (resolved) firstResolved ??= index;
    transientPeak = math.max(transientPeak, before + 1);
    final nextCapture = CampaignObservation.capture(engine, graph);
    final oldLegalIds = capture.actualIdByHandle.values.toSet();
    // Diagnostic IDs detect a newly exposed physical tile even if its public
    // token equals the just-removed tile's token. Only post-tap public tokens
    // are reported; no future identity enters a priority or preceding plan.
    final newTokens = <String>[
      if (engine.result == GameResult.playing)
        for (final tile in nextCapture.visible.exposed)
          if (!oldLegalIds.contains(nextCapture.actualIdByHandle[tile.id]))
            publicTileToken(tile),
    ]..sort();
    trace.add({
      'decision': index,
      'legal_tokens': tokens.values.toList()..sort(),
      'candidates': candidates,
      'chosen_token': tokens[decision.handle],
      'tray_types_before': view.tray.map((t) => t.type).toList(),
      'tray_before': before,
      'tray_after': engine.tray.length,
      'pressure_before': before / GameEngine.trayLimit,
      'pressure_after': engine.tray.length / GameEngine.trayLimit,
      'available_triple_types': complete,
      'high_risk': before >= 6,
      'immediate_losing_choices':
          candidates.where((c) => c['immediate_loss'] == true).length,
      'resolved_triple': resolved,
      'lookahead_nodes': decision.nodes,
      'branch_options_pruned': decision.branchPruned,
      'budget_exhausted': decision.budgetExhausted,
      'rankings': rankings,
      'newly_selectable_tokens_after_tap': newTokens,
      // Instrumentation only. NEVER supplied to a strategy or priority function.
      'diagnostic_actual_chosen_id': actualId,
      'diagnostic_legal_ids': legalIds,
      'diagnostic_remaining_ids': remaining,
      'diagnostic_tray_ids': actualTray,
    });
    path.add(actualId);
  }
  if (engine.result == GameResult.playing && stopped == null)
    stopped = 'MOVE_BUDGET';
  final trays = trace.map((r) => r['tray_after'] as int).toList();
  return {
    ...pairedAttemptIdentity(level.level, screen, policy, replica),
    'evidence': 'SIMULATED',
    'outcome': stopped != null
        ? 'INCONCLUSIVE'
        : engine.result == GameResult.won
            ? 'WIN'
            : 'LOSS',
    'stop_reason': stopped ?? engine.result.name,
    'move_budget': budget,
    'decisions': path.length,
    'path_ids': path,
    'first_available_triple_decision': firstAvailable,
    'first_immediate_triple_decision': firstCompleting,
    'first_high_risk_decision': firstHighRisk,
    'first_resolved_triple_decision': firstResolved,
    'max_tray_after_resolution': trays.fold<int>(0, math.max),
    'max_tray_before_resolution': transientPeak,
    'average_tray_pressure': trays.isEmpty
        ? null
        : trays.reduce((a, b) => a + b) / trays.length / GameEngine.trayLimit,
    'lookahead_nodes': nodes,
    'lookahead_branch_options_pruned': pruned,
    'lookahead_budget_exhausted_decisions': exhausted,
    'final_engine_result': engine.result.name,
    'final_board_count': engine.boardTiles.length,
    'final_tray_count': engine.tray.length,
    'full_clearance': engine.boardTiles.isEmpty &&
        engine.tray.isEmpty &&
        engine.tiles.every((t) => t.state == TileState.matched),
    'objective_complete':
        level.objective == null ? null : engine.objectiveComplete,
    'trace': trace,
  };
}

/// Exact structural evidence on the untouched initial board, independent of
/// chosen paths. IDs/edges are privileged diagnostics, never agent inputs.
CampaignJson pairedGeometry(CampaignGraph graph) => {
      'board': [graph.geometry.board.width, graph.geometry.board.height],
      'tile': [graph.geometry.tile.width, graph.geometry.tile.height],
      'blocking_edges': graph.edges,
      'same_layer_edges': graph.sameLayerEdges,
      'blocking_depth_tiles': graph.depth.values.fold<int>(0, math.max),
    };
