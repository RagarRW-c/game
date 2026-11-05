import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import '../qa/support/geometry.dart';
import 'support/campaign_validation.dart';
import 'support/campaign_validation_report.dart';

const _geometry = QaGeometry(Size(1000, 1000), Size(20, 20));
LevelDefinition _level(List<Tile> tiles, {LevelObjective? objective}) =>
    LevelDefinition(
        level: 1,
        name: 'Contract fixture',
        timeBonusSeconds: 0,
        tiles: tiles,
        objective: objective);
Tile _tile(int i, String type, {double? x, double y = 0, int layer = 0}) =>
    Tile(id: 't$i', type: type, x: x ?? i * .05, y: y, layer: layer);

void main() {
  test('versioned RNG has known vectors and no SDK hash dependency', () {
    final rng = CampaignRng(1);
    expect(List.generate(5, (_) => rng.nextUint32()),
        [270369, 67634689, 2647435461, 307599695, 2398689233]);
    expect(campaignFingerprint(utf8.encode('hello')), '4f9f2cab');
    expect(CampaignRng(0).nextUint32(), CampaignRng(0x6d2b79f5).nextUint32());
    final a = CampaignRng(42), b = CampaignRng(42);
    expect(List.generate(50, (_) => a.nextInt(7)),
        List.generate(50, (_) => b.nextInt(7)));
    expect(() => a.nextInt(0), throwsArgumentError);
    expect(campaignSeed(1, 'small', CampaignPolicy.randomLegal, 0),
        isNot(campaignSeed(1, 'small', CampaignPolicy.randomLegal, 1)));
    expect(campaignPriorityLevels.length, 24);
    expect(campaignPriorityLevels.toSet().length, 24);
  });

  test('Campaign QA geometries retain the screen layout inputs', () {
    final expected = [
      [300.0, 360.0, 51.2],
      [340.0, 538.0, 57.6],
      [392.0, 620.0, 65.92],
    ];
    for (var i = 0; i < qaScreens.length; i++) {
      final g = qaScreens[i].geometry();
      expect(g.board.width, expected[i][0]);
      expect(g.board.height, expected[i][1]);
      expect(g.tile.width, closeTo(expected[i][2], 1e-10));
      expect(g.tile.height, g.tile.width);
    }
  });

  test('coverage cache includes same-layer paint order at exactly 3 percent',
      () {
    const g = QaGeometry(Size(100, 100), Size(100, 100));
    for (final x in [.9699, .97, .9701, 1.0]) {
      final tiles = [_tile(0, 'a', x: 0), _tile(1, 'a', x: x)];
      final graph = CampaignGraph(tiles, g);
      final engine = GameEngine(tiles)..updateBoardGeometry(g.board, g.tile);
      expect(graph.agreesWithEngine(engine), isTrue);
      expect(graph.sameLayerEdges, x <= .97 ? 1 : 0);
      expect(graph.available(engine).length, x <= .97 ? 1 : 2);
      expect(engine.tapTile('t1', g.board, g.tile), isTrue);
      expect(graph.agreesWithEngine(engine), isTrue);
      expect(graph.available(engine).map((t) => t.id), ['t0']);
    }
  });

  test('baseline replays the existing witness and records real tray resolution',
      () {
    final level =
        _level(List.generate(6, (i) => _tile(i, i < 3 ? 'a' : 'b', x: 0)));
    final result = campaignBaseline(level, qaScreens.first);
    final c = result['confirmed'] as Map;
    final w = result['witness'] as Map;
    expect(result['status'], 'VALIDATED');
    expect(result['witness_status'], 'REPLAYED');
    expect(result['existing_solver_replay_passed'], isTrue);
    expect(c['initial_exposed_tiles'], 1);
    expect(c['initial_visible_triples'], 0);
    expect(c['blocking_depth_tiles'], 6);
    expect(c['same_layer_blocking_edges'], 15);
    expect(w['outcome'], 'WIN');
    expect(w['full_clearance'], isTrue);
    expect(w['max_tray_after_resolution'], 2);
    expect(w['max_tray_before_resolution'], 3);
    expect(w['moves_to_first_triple'], 3);
    expect(w['forced_single_choice_decisions'], 6);
    expect(w['omniscient'], isTrue);
  });

  test('hidden identities and authoring IDs never reach a strategy', () {
    List<Tile> board(String secret, String prefix) => [
          Tile(id: '${prefix}_secret', type: secret, x: 0, y: 0, layer: 0),
          Tile(id: '${prefix}_top', type: 'a', x: 0, y: 0, layer: 1),
          Tile(id: '${prefix}_other', type: 'b', x: .1, y: 0, layer: 0),
        ];
    final first = board('concealed_A', 'authoring_A');
    final second = board('concealed_B', 'authoring_B');
    final a = CampaignObservation.capture(
        GameEngine(first), CampaignGraph(first, _geometry));
    final b = CampaignObservation.capture(
        GameEngine(second), CampaignGraph(second, _geometry));
    expect(a.visible.toJson(), b.visible.toJson());
    expect(jsonEncode(a.visible.toJson()), isNot(contains('concealed')));
    expect(jsonEncode(a.visible.toJson()), isNot(contains('authoring')));
    expect(a.visible.exposed.length, 2);
    for (final policy in CampaignPolicy.values) {
      final da = decideCampaignMove(a.visible, policy, CampaignRng(19));
      final db = decideCampaignMove(b.visible, policy, CampaignRng(19));
      expect(da.handle, db.handle);
      expect(da.nodes, db.nodes);
      expect(da.nodes, lessThanOrEqualTo(4),
          reason:
              'Only the two currently exposed tiles can be expanded, never the hidden tile.');
      expect(a.actualIdByHandle[da.handle], isNot(contains('secret')));
    }
  });

  test(
      'greedy and lookahead choose a real resolving triple over immediate loss',
      () {
    final tiles = [
      _tile(0, 'a'),
      _tile(1, 'a'),
      _tile(2, 'b'),
      _tile(3, 'c'),
      _tile(4, 'd'),
      _tile(5, 'e'),
      _tile(6, 'a'),
      _tile(7, 'z'),
    ];
    final engine = GameEngine(tiles);
    for (var i = 0; i < 6; i++) {
      expect(engine.tapTile('t$i', _geometry.board, _geometry.tile), isTrue);
    }
    expect(engine.tray.length, 6);
    final observation =
        CampaignObservation.capture(engine, CampaignGraph(tiles, _geometry));
    for (final policy in [
      CampaignPolicy.greedyMatch,
      CampaignPolicy.visibleLookahead
    ]) {
      final decision =
          decideCampaignMove(observation.visible, policy, CampaignRng(5));
      expect(observation.actualIdByHandle[decision.handle], 't6');
    }
    expect(engine.tapTile('t6', _geometry.board, _geometry.tile), isTrue);
    expect(engine.tray.length, 4);
    expect(engine.result, GameResult.playing);
  });

  test('lookahead bounds and move cutoff remain inconclusive, not a loss proof',
      () {
    final tiles = List.generate(12, (i) => _tile(i, 'type${i % 4}'));
    final graph = CampaignGraph(tiles, _geometry);
    final view = CampaignObservation.capture(GameEngine(tiles), graph).visible;
    final full = decideCampaignMove(
        view, CampaignPolicy.visibleLookahead, CampaignRng(1));
    expect(full.handle, isNotNull);
    expect(full.nodes, 84);
    expect(full.branchPruned, greaterThan(0));
    final zero = decideCampaignMove(
        view, CampaignPolicy.visibleLookahead, CampaignRng(1),
        lookaheadNodes: 0);
    expect(zero.handle, isNull);
    expect(zero.budgetExhausted, isTrue);
    final short = decideCampaignMove(
        view, CampaignPolicy.visibleLookahead, CampaignRng(1),
        lookaheadNodes: 3);
    expect(short.nodes, 3);
    expect(short.budgetExhausted, isTrue);
    expect(short.handle, isNotNull);
    final result = simulateCampaign(
        _level(tiles), graph, CampaignPolicy.randomLegal, 'fixture', 0,
        moveBudget: 1);
    expect(result['outcome'], 'INCONCLUSIVE');
    expect(result['stop_reason'], 'MOVE_BUDGET');
    expect(result['decisions'], 1);
  });

  test('behavioral completion follows engine win, not strict solver clearance',
      () {
    final tiles = [_tile(0, 'a')];
    final result = simulateCampaign(
        _level(tiles, objective: const LevelObjective(type: 'a', target: 3)),
        CampaignGraph(tiles, _geometry),
        CampaignPolicy.randomLegal,
        'fixture',
        0);
    expect(result['outcome'], 'WIN');
    expect(result['full_clearance'], isFalse);
    expect(result['objective_complete'], isFalse);
    expect(result['final_tray_count'], 1);
    expect(campaignBaseline(_level(tiles), qaScreens.first)['status'],
        'INVALID_INPUT');
  });

  test('actual seven-slot loss is recorded without an unsolvability claim', () {
    final tiles = List.generate(8, (i) => _tile(i, 'unique$i'));
    final result = simulateCampaign(
        _level(tiles),
        CampaignGraph(tiles, _geometry),
        CampaignPolicy.randomLegal,
        'fixture',
        0);
    expect(result['outcome'], 'LOSS');
    expect(result['decisions'], 7);
    expect(result['max_tray_after_resolution'], 7);
    expect(result['maximum_tray_pressure'], 1.0);
    expect((result['immediate_losing_choices_by_decision'] as List).last, 2);
    expect(jsonEncode(result), isNot(contains('UNSOLVABLE')));
  });

  test('a failed constructive witness stays unverified', () {
    final tiles =
        List.generate(24, (i) => _tile(i, 'type${(23 - i) % 8}', x: 0));
    final result = campaignBaseline(_level(tiles), qaScreens.first);
    expect(result['status'], 'REVIEW_REQUIRED');
    expect(result['witness_status'], 'UNVERIFIED');
    expect((result['witness'] as Map)['outcome'], 'LOSS');
    expect(jsonEncode(result), isNot(contains('UNSOLVABLE')));
  });

  test(
      'screen comparison detects actual dependency changes, not only tile count',
      () {
    final level = _level([
      _tile(0, 'a', x: 0),
      _tile(1, 'a', x: .165),
      _tile(2, 'a', x: .6),
    ]);
    final small = campaignBaseline(level, qaScreens.first);
    final tall = campaignBaseline(level, qaScreens.last);
    expect((small['confirmed'] as Map)['initial_exposed_tiles'], 2);
    expect((tall['confirmed'] as Map)['initial_exposed_tiles'], 3);
    expect(small['witness_status'], 'REPLAYED');
    expect(tall['witness_status'], 'REPLAYED');
    final summary = buildCampaignSummary([small, tall], []);
    final comparison =
        (summary['screen_comparisons_small_to_medium_and_tall'] as List)
            .cast<Map>()
            .firstWhere((c) =>
                c['from_level'] == 1 && c['to_screen'] == qaScreens.last.name);
    expect(comparison['initial_exposed_delta'], 1);
    expect(comparison['blocking_dependencies_changed'], isTrue);
    expect(comparison['same_layer_edges_delta'], -1);
  });

  test('input and bounds failures remain visible instead of being repaired',
      () {
    final duplicate = _level([_tile(0, 'a'), _tile(0, 'a'), _tile(0, 'a')]);
    final invalid = campaignBaseline(duplicate, qaScreens.first);
    expect(invalid['status'], 'INVALID_INPUT');
    expect(invalid['issues'], contains('DUPLICATE_IDS'));
    expect(invalid['witness_status'], 'UNVERIFIED');
    final outside = _level(List.generate(3, (i) => _tile(i, 'a', x: .99)));
    final measured = campaignBaseline(outside, qaScreens.first);
    expect(measured['status'], 'REVIEW_REQUIRED');
    expect(measured['issues'], contains('OUTSIDE_LOGICAL_BOARD'));
    expect(measured['witness_status'], 'REPLAYED',
        reason: 'Logical solvability and board bounds are separate checks.');
  });

  test(
      'repeated simulations do not mutate level data and reproduce every trace',
      () {
    final tiles = List.generate(9, (i) => _tile(i, 'type${i % 3}'));
    final level = _level(tiles);
    final graph = CampaignGraph(tiles, _geometry);
    for (final policy in CampaignPolicy.values) {
      final a = simulateCampaign(level, graph, policy, 'fixture', 3);
      final b = simulateCampaign(level, graph, policy, 'fixture', 3);
      expect(a, b);
      final engine = GameEngine(tiles);
      for (final id in (a['path_ids'] as List).cast<String>()) {
        expect(engine.tapTile(id, _geometry.board, _geometry.tile), isTrue);
      }
      expect(a['final_engine_result'], engine.result.name);
    }
    expect(tiles.every((t) => t.state == TileState.board), isTrue);
  });

  test('aggregation preserves unknowns and does not invent level 11 behavior',
      () {
    final tiles = List.generate(3, (i) => _tile(i, 'a', x: 0));
    final level = _level(tiles);
    final graph = CampaignGraph(tiles, _geometry);
    final win = simulateCampaign(
        level, graph, CampaignPolicy.greedyMatch, qaScreens.first.name, 0);
    final unknown = simulateCampaign(
        level, graph, CampaignPolicy.greedyMatch, qaScreens.first.name, 1,
        moveBudget: 1);
    final summary = buildCampaignSummary(
        [campaignBaseline(level, qaScreens.first)], [win, unknown]);
    final group = (summary['behavior_groups'] as List).single as Map;
    expect(group['attempts'], 2);
    expect(group['wins'], 1);
    expect(group['losses'], 0);
    expect(group['inconclusive'], 1);
    expect(group['heuristic_completion_rate'], .5);
    expect(group['completion_rate_resolved_only'], 1.0);
    final transition = (summary['requested_transitions'] as List)
        .cast<Map>()
        .firstWhere((n) => n['from_level'] == 10);
    expect(
        (transition['behavior'] as List)
            .cast<Map>()
            .every((b) => b['status'] == 'UNMEASURED'),
        isTrue);
    final witness = (campaignBaseline(level, qaScreens.first)['witness'] as Map)
        .cast<String, Object?>();
    expect(() => buildCampaignSummary([], [witness]), throwsStateError);
  });
}
