import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import '../qa/support/geometry.dart';
import 'support/campaign_paired.dart';
import 'support/campaign_paired_report.dart';
import 'support/campaign_validation.dart';

const _g = QaGeometry(Size(1000, 1000), Size(20, 20));
Tile _tile(int i, String type, {double? x, double y = 0, int layer = 0}) =>
    Tile(id: 'author_$i', type: type, x: x ?? i * .08, y: y, layer: layer);
LevelDefinition _level(List<Tile> tiles) => LevelDefinition(
    level: 3, name: 'Paired contract', timeBonusSeconds: 0, tiles: tiles);
VisibleCampaignBoard _view(List<Tile> tiles, QaGeometry g) =>
    CampaignObservation.capture(GameEngine(tiles), CampaignGraph(tiles, g))
        .visible;
String? _chosen(VisibleCampaignBoard view, CampaignPolicy policy,
    PairedPriorities priorities,
    {int nodes = 84}) {
  final d = decideCampaignMove(view, policy, NoPairedRng(),
      tieBreak: priorities.compare, lookaheadNodes: nodes);
  return d.handle == null
      ? null
      : publicTileToken(view.exposed.singleWhere((t) => t.id == d.handle));
}

CampaignJson _step(int i, List<String> legal, String chosen,
        {List<String>? remaining, List<String> tray = const []}) =>
    {
      'decision': i,
      'legal_tokens': legal,
      'chosen_token': chosen,
      'diagnostic_actual_chosen_id': chosen,
      'diagnostic_legal_ids': legal,
      'diagnostic_remaining_ids': remaining ?? legal,
      'diagnostic_tray_ids': tray,
      'tray_before': tray.length,
    };
CampaignJson _attempt(List<CampaignJson> trace,
        {String outcome = 'WIN',
        String screen = 'small_320x568',
        CampaignPolicy policy = CampaignPolicy.randomLegal}) =>
    {
      ...pairedAttemptIdentity(3, screen, policy, 0),
      'evidence': 'SIMULATED',
      'outcome': outcome,
      'trace': trace,
      'decisions': trace.length,
      'stop_reason': outcome.toLowerCase(),
    };

void main() {
  test('same public token gets the same priority on all three screens', () {
    final tiles = [
      _tile(0, 'a', x: 0),
      _tile(1, 'b', x: .4),
      _tile(2, 'c', x: .8)
    ];
    const p = PairedPriorities(3, 7, 9);
    Map<String, int> priorities(QaGeometry g) => {
          for (final t in _view(tiles, g).exposed)
            publicTileToken(t): p.priority(publicTileToken(t)),
        };
    final expected = priorities(qaScreens.first.geometry());
    for (final s in qaScreens) {
      expect(priorities(s.geometry()), expected);
      for (final policy in CampaignPolicy.values) {
        expect(_chosen(_view(tiles, s.geometry()), policy, p),
            _chosen(_view(tiles, qaScreens.first.geometry()), policy, p));
      }
    }
    expect(p.experimentSeed, const PairedPriorities(3, 7, 100).experimentSeed);
    expect(p.experimentSeed,
        isNot(const PairedPriorities(3, 8, 9).experimentSeed));
  });

  test('enumeration and changing public handles cannot change priorities', () {
    final tiles = List.generate(9, (i) => _tile(i, 'type${i % 3}'));
    const p = PairedPriorities(3, 2, 4);
    final a = List<Tile>.of(tiles)..sort((x, y) => p.compare(x, y, []));
    final b = tiles.reversed.toList()..sort((x, y) => p.compare(x, y, []));
    expect(a.map(publicTileToken), b.map(publicTileToken));
    for (final tile in tiles) {
      final renamed = Tile(
          id: 'different', type: tile.type, x: tile.x, y: tile.y, layer: 999);
      expect(publicTileToken(tile), publicTileToken(renamed));
      expect(p.priority(publicTileToken(tile)),
          p.priority(publicTileToken(renamed)));
    }
    for (final policy in CampaignPolicy.values) {
      expect(_chosen(_view(tiles, _g), policy, p),
          _chosen(_view(tiles.reversed.toList(), _g), policy, p));
    }
    // Another legal candidate changes handle numbering but not shared priorities.
    final expanded = [_tile(99, 'extra', x: 0, y: -.1), ...tiles];
    final original = _view(tiles, _g), changed = _view(expanded, _g);
    final shared = original.exposed.map(publicTileToken).toSet();
    expect({
      for (final t
          in changed.exposed.where((t) => shared.contains(publicTileToken(t))))
        publicTileToken(t): p.priority(publicTileToken(t))
    }, {
      for (final t in original.exposed)
        publicTileToken(t): p.priority(publicTileToken(t))
    });
  });

  test(
      'hidden types, authoring IDs and witnesses are outside every policy input',
      () {
    List<Tile> board(String secret, String prefix) => [
          Tile(id: '${prefix}_hidden', type: secret, x: 0, y: 0, layer: 0),
          Tile(id: '${prefix}_top', type: 'a', x: 0, y: 0, layer: 1),
          Tile(id: '${prefix}_other', type: 'b', x: .3, y: 0, layer: 0),
        ];
    final a = _view(board('secret_A', 'author_A'), _g);
    final b = _view(board('secret_B', 'author_B'), _g);
    expect(a.toJson(), b.toJson());
    expect(jsonEncode(a.toJson()), isNot(contains('secret')));
    expect(jsonEncode(a.toJson()), isNot(contains('author')));
    for (final policy in CampaignPolicy.values) {
      final ranksA = <Object>[], ranksB = <Object>[];
      const p = PairedPriorities(3, 0, 0);
      final da = decideCampaignMove(a, policy, NoPairedRng(),
          tieBreak: p.compare,
          onRanked: (ranked, path) =>
              ranksA.add([ranked, path.map(publicTileToken).toList()]));
      final db = decideCampaignMove(b, policy, NoPairedRng(),
          tieBreak: p.compare,
          onRanked: (ranked, path) =>
              ranksB.add([ranked, path.map(publicTileToken).toList()]));
      expect(da.handle, db.handle);
      expect(da.nodes, db.nodes);
      expect(da.nodes, lessThanOrEqualTo(4)); // no hidden tile expanded
      expect(ranksA, ranksB);
    }
  });

  test(
      'arbitrary RNG draws and extra internal searches cannot shift actual priorities',
      () {
    final tiles = List.generate(9, (i) => _tile(i, 'type${i % 3}'));
    final view = _view(tiles, _g);
    const next = PairedPriorities(3, 4, 12);
    final token = publicTileToken(view.exposed.first);
    final expected = next.priority(token);
    final expectedMove = _chosen(view, CampaignPolicy.randomLegal, next);
    final rng = CampaignRng(99);
    for (var i = 0; i < 300; i++) {
      rng.nextUint32();
    }
    _chosen(
        view, CampaignPolicy.visibleLookahead, const PairedPriorities(3, 4, 11),
        nodes: 3);
    _chosen(view, CampaignPolicy.visibleLookahead,
        const PairedPriorities(3, 4, 11));
    for (final t in view.exposed) {
      next.priority(token, plannedPath: [publicTileToken(t)]);
    }
    expect(next.priority(token), expected);
    expect(_chosen(view, CampaignPolicy.randomLegal, next), expectedMove);
    expect(next.priority(token, plannedPath: [token]), isNot(expected));
    expect(const PairedPriorities(3, 4, 13).priority(token), isNot(expected));
  });

  test('planning bounds, greedy scores and observer transparency are retained',
      () {
    final tiles =
        List.generate(12, (i) => _tile(i, 'type${i % 4}', x: i * .05));
    final view = _view(tiles, _g);
    const p = PairedPriorities(3, 0, 0);
    final observed = <Object>[];
    final a = decideCampaignMove(
        view, CampaignPolicy.visibleLookahead, NoPairedRng(),
        tieBreak: p.compare);
    final b = decideCampaignMove(
        view, CampaignPolicy.visibleLookahead, NoPairedRng(),
        tieBreak: p.compare,
        onRanked: (ranked, path) =>
            observed.add([ranked, path.map(publicTileToken).toList()]));
    expect(a.handle, b.handle);
    expect(a.nodes, 84);
    expect(a.branchPruned, b.branchPruned);
    expect(a.branchPruned, greaterThan(0));
    expect(a.budgetExhausted, isFalse);
    expect(observed.length, 21);
    final zero = decideCampaignMove(
        view, CampaignPolicy.visibleLookahead, NoPairedRng(),
        tieBreak: p.compare, lookaheadNodes: 0);
    expect(zero.handle, isNull);
    expect(zero.budgetExhausted, isTrue);
    final resolving = [
      _tile(0, 'a'),
      _tile(1, 'a'),
      _tile(2, 'b'),
      _tile(3, 'c'),
      _tile(4, 'd'),
      _tile(5, 'e'),
      _tile(6, 'a'),
      _tile(7, 'z')
    ];
    final engine = GameEngine(resolving);
    for (var i = 0; i < 6; i++) {
      expect(engine.tapTile('author_$i', _g.board, _g.tile), isTrue);
    }
    final capture =
        CampaignObservation.capture(engine, CampaignGraph(resolving, _g));
    for (final policy in [
      CampaignPolicy.greedyMatch,
      CampaignPolicy.visibleLookahead
    ]) {
      final d = decideCampaignMove(capture.visible, policy, NoPairedRng(),
          tieBreak: p.compare);
      expect(capture.actualIdByHandle[d.handle], 'author_6');
    }
  });

  test(
      'repeated attempt traces are byte-identical and replay the unchanged engine',
      () {
    final level = _level(List.generate(9, (i) => _tile(i, 'type${i % 3}')));
    for (final policy in CampaignPolicy.values) {
      final graph = CampaignGraph(level.tiles, _g);
      final a = simulatePairedCampaign(level, graph, policy, 'fixture', 2);
      final b = simulatePairedCampaign(level, graph, policy, 'fixture', 2);
      expect(jsonEncode(a), jsonEncode(b));
      final replay = GameEngine(level.tiles)
        ..updateBoardGeometry(_g.board, _g.tile);
      for (final step in (a['trace'] as List).cast<CampaignJson>()) {
        expect(graph.agreesWithEngine(replay), isTrue);
        final legal = replay.boardTiles
            .where((t) => !replay.isTileCovered(t))
            .map((t) => t.id)
            .toList()
          ..sort();
        expect(step['diagnostic_legal_ids'], legal);
        expect(step['tray_before'], replay.tray.length);
        expect(
            replay.tapTile(step['diagnostic_actual_chosen_id'] as String,
                _g.board, _g.tile),
            isTrue);
        expect(step['tray_after'], replay.tray.length);
        expect(step['pressure_after'], replay.tray.length / 7);
      }
      expect(a['final_engine_result'], replay.result.name);
      expect(a['first_available_triple_decision'], 0);
      expect(a['first_resolved_triple_decision'], isNotNull);
    }
  });

  test('seven-slot loss, high risk and incomplete traces are distinguished',
      () {
    final level = _level(List.generate(8, (i) => _tile(i, 'unique$i')));
    final graph = CampaignGraph(level.tiles, _g);
    final a = simulatePairedCampaign(
        level, graph, CampaignPolicy.randomLegal, 'fixture', 0);
    expect(a['outcome'], 'LOSS');
    expect(a['first_available_triple_decision'], isNull);
    expect(a['first_high_risk_decision'], 6);
    expect(a['max_tray_after_resolution'], GameEngine.trayLimit);
    final short = simulatePairedCampaign(
        level, graph, CampaignPolicy.randomLegal, 'fixture', 0,
        moveBudget: 1);
    expect(short['outcome'], 'INCONCLUSIVE');
    expect(short['stop_reason'], 'MOVE_BUDGET');
    final pair = comparePairedAttempts(short, a);
    expect(pair['first_divergent_chosen_move'], isNull);
    expect((pair['unmatched_tail'] as Map)['first_unmatched_decision'], 1);
    expect(pair['trace_comparison_status'], 'INCOMPLETE_EVIDENCE');
  });

  test('a reveal is recorded even when the next tile has the same public token',
      () {
    final level = _level(List.generate(3, (i) => _tile(i, 'a', x: 0)));
    final result = simulatePairedCampaign(level, CampaignGraph(level.tiles, _g),
        CampaignPolicy.visibleLookahead, 'fixture', 0);
    final trace = result['trace'] as List;
    expect(result['outcome'], 'WIN');
    expect(result['first_available_triple_decision'], 2);
    expect(result['first_immediate_triple_decision'], 2);
    expect(result['first_resolved_triple_decision'], 2);
    expect(trace[0]['lookahead_nodes'], 1);
    expect(trace[0]['newly_selectable_tokens_after_tap'],
        [trace[0]['chosen_token']]);
    expect(trace[1]['newly_selectable_tokens_after_tap'],
        [trace[1]['chosen_token']]);
    expect(trace[2]['newly_selectable_tokens_after_tap'], isEmpty);
  });

  test('real geometry legal-set differences are separated from later moves',
      () {
    final level = _level(
        [_tile(0, 'a', x: 0), _tile(1, 'a', x: .165), _tile(2, 'a', x: .6)]);
    final small = CampaignGraph(level.tiles, qaScreens[0].geometry());
    final medium = CampaignGraph(level.tiles, qaScreens[1].geometry());
    final a = simulatePairedCampaign(
        level, small, CampaignPolicy.greedyMatch, qaScreens[0].name, 0);
    final b = simulatePairedCampaign(
        level, medium, CampaignPolicy.greedyMatch, qaScreens[1].name, 0);
    expect(a['experiment_seed_uint32'], b['experiment_seed_uint32']);
    final pair = comparePairedAttempts(a, b);
    final event = pair['first_divergent_legal_candidate_set'] as Map;
    expect(event['decision'], 0);
    expect(event['relation'], 'SHARED_ACTION_PREFIX');
    expect(event['interpretation'], contains('Structural geometry'));
    final structural =
        comparePairedGeometry(pairedGeometry(small), pairedGeometry(medium));
    expect(structural['same_blocking_dependencies'], isFalse);
    expect(structural['edges_only_left'], isNotEmpty);
    expect(structural['edges_only_right'], isEmpty);
  });

  test(
      'post-divergence legal differences and outcome pairs are recorded honestly',
      () {
    final a = _attempt([
      _step(0, ['a', 'b'], 'a'),
      _step(1, ['b', 'c'], 'b', tray: ['a']),
    ], outcome: 'LOSS');
    final b = _attempt([
      _step(0, ['a', 'b'], 'b'),
      _step(1, ['a', 'd'], 'd', tray: ['b']),
      _step(2, ['a'], 'a', tray: ['b', 'd']),
    ], policy: CampaignPolicy.greedyMatch);
    final pair = comparePairedAttempts(a, b);
    expect((pair['first_divergent_chosen_move'] as Map)['decision'], 0);
    expect((pair['first_divergent_chosen_move'] as Map)['interpretation'],
        contains('Strategy decision'));
    expect((pair['first_divergent_legal_candidate_set'] as Map)['decision'], 1);
    expect((pair['first_divergent_legal_candidate_set'] as Map)['relation'],
        'POST_DIVERGENCE_DESCRIPTIVE_ONLY');
    expect(pair['outcome_pair'], 'LOSS/WIN');
    final summary = buildPairedSummary([a, b], {});
    expect(summary['wins'], 1);
    expect(summary['losses'], 1);
    expect(summary['complete_coverage'], isFalse);
    final comparison = (summary['comparisons'] as List).singleWhere((c) =>
        c['level'] == 3 &&
        c['kind'] == 'strategy' &&
        c['left_screen'] == 'small_320x568' &&
        c['left_strategy'] == 'randomLegal' &&
        c['right_strategy'] == 'greedyMatch');
    expect(comparison['outcome_matrix']['LOSS/WIN'], 1);
    expect(comparison['paired_replicas'], 1);
    expect(comparison['missing_replica_pairs'], List.generate(9, (i) => i + 1));
    final report = pairedMarkdown({
      'run_id': 'fixture',
      'status': 'PARTIAL',
      'measurement_health': 'REVIEW_REQUIRED'
    }, summary);
    expect(report, contains('LOSS/WIN'));
    expect(report, contains('POST_DIVERGENCE_DESCRIPTIVE_ONLY'));
    expect(() => buildPairedSummary([a, a], {}), throwsArgumentError);
    expect(() => comparePairedAttempts(a, {...b, 'replica': 1}),
        throwsArgumentError);
    expect(
        () => buildPairedSummary([
              {...a, 'omniscient': true}
            ], {}),
        throwsArgumentError);
  });

  test(
      'fixed cohort yields 165 cells and 1650 replica pairs without extra attempts',
      () {
    final rows = <CampaignJson>[
      for (final level in pairedLevels)
        for (final screen in qaScreens)
          for (final policy in CampaignPolicy.values)
            for (var replica = 0; replica < pairedReplicas; replica++)
              {
                ...pairedAttemptIdentity(level, screen.name, policy, replica),
                'outcome': 'INCONCLUSIVE',
                'stop_reason': 'SYNTHETIC_REPORT_FIXTURE',
                'trace': <CampaignJson>[],
              },
    ];
    // Aggregation fixture only; no game simulation and no result claim.
    final summary = buildPairedSummary(rows, {});
    expect(rows.length, 990);
    expect(summary['complete_coverage'], isTrue);
    expect(summary['inconclusive'], 990);
    final cells = summary['comparisons'] as List;
    expect(cells.length, 165);
    expect(cells.fold<int>(0, (n, c) => n + (c['pairs'] as List).length), 1650);
    expect(cells.every((c) => (c['missing_replica_pairs'] as List).isEmpty),
        isTrue);
  });

  test('historical policy reproduces stored complete traces from the old run',
      () {
    final fixture = jsonDecode(
        File('test/balance_audit/fixtures/campaign_historical_v1.json')
            .readAsStringSync()) as Map;
    final level = LevelDefinition.fromJson(
        jsonDecode(File('assets/levels/level_03.json').readAsStringSync())
            as Map<String, dynamic>);
    for (final expected in fixture['attempts'] as List) {
      final policy =
          CampaignPolicy.values.byName(expected['strategy'] as String);
      final screen = qaScreens.singleWhere((s) => s.name == expected['screen']);
      final actual = simulateCampaign(
          level,
          CampaignGraph(level.tiles, screen.geometry()),
          policy,
          screen.name,
          expected['seed_index'] as int);
      expect(actual, expected,
          reason:
              'Historical ${policy.name} must remain byte-policy compatible');
    }
  });
}
