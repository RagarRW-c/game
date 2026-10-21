import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

import '../qa/support/geometry.dart';
import 'support/balance_metrics.dart';

const geometry = QaGeometry(Size(1000, 1000), Size(20, 20));

void main() {
  test('measurements retain identities and an engine-compatible full witness', () {
    final tiles = List.generate(6, (i) => Tile(id: 't$i', type: i < 3 ? 'apple' : 'berry',
      x: i * .05, y: 0, layer: 0));
    final budget = SearchBudget(0, 0);
    final result = auditBoard(tiles, geometry, budget);
    final shape = result['geometry'] as Map;
    final solver = result['solver'] as Map;
    expect(shape['initial_playable'], 6);
    expect(shape['initial_blocked'], 0);
    expect(shape['same_layer_blocking_edges'], 0);
    expect(shape['max_blocker_chain_tiles'], 1);
    expect(shape['maximum_coincident_rectangle_depth'], 1);
    expect(shape['union_area'], 2400);
    expect(solver['status'], 'SOLVED');
    expect(solver['witness_replay_passed'], isTrue);
    expect((solver['path'] as List).toSet(), tiles.map((t) => t.id).toSet());
    expect((result['witness_metrics'] as Map)['peak_tray_after_resolution'], 2);
    expect(result['difficulty_score'], inInclusiveRange(0, 100));
    expect(result['issues'], isEmpty);
    expect(budget.spent, 0);
  });

  test('same-layer paint order and deep chains are distinct from layer labels', () {
    final tiles = List.generate(6, (i) => Tile(id: 't$i', type: 'apple', x: 0, y: 0, layer: 0));
    final shape = auditBoard(tiles, geometry, SearchBudget(0, 0))['geometry'] as Map;
    expect(shape['layer_labels'], [0]);
    expect(shape['initial_playable_ids'], ['t5']);
    expect(shape['same_layer_blocking_edges'], 15);
    expect(shape['max_direct_blockers'], 5);
    expect(shape['max_blocker_chain_tiles'], 6);
    expect(shape['maximum_coincident_rectangle_depth'], 6);
    expect(shape['union_area'], 400);
    expect(shape['initial_coverage_matches_engine'], isTrue);
  });

  test('coverage ignores touching edges and applies the real three-percent rule', () {
    final coverage = rectangleCoverage(const [Rect.fromLTWH(0, 0, 20, 20),
      Rect.fromLTWH(20, 0, 20, 20)], const Size(100, 100));
    expect(coverage['maximum_coincident_rectangle_depth'], 1);
    expect(coverage['union_area'], 800);
    final tiles = [
      const Tile(id: 'a', type: 'apple', x: 0, y: 0, layer: 0),
      const Tile(id: 'b', type: 'apple', x: .0195, y: 0, layer: 0),
      const Tile(id: 'c', type: 'apple', x: .1, y: 0, layer: 0),
    ];
    final shape = auditBoard(tiles, geometry, SearchBudget(0, 0))['geometry'] as Map;
    expect(shape['same_layer_blocking_edges'], 0, reason: '2.5% overlap is below the engine threshold');
    expect(shape['maximum_coincident_rectangle_depth'], 2);
  });

  test('a budget cutoff is UNKNOWN; exhaustive forced-tray loss is UNSOLVABLE', () {
    final tiles = List.generate(24, (i) => Tile(id: 't$i', type: 'type${(23 - i) % 8}',
      x: 0, y: 0, layer: i));
    final cutoff = auditBoard(tiles, geometry, SearchBudget(0, 0));
    expect((cutoff['solver'] as Map)['status'], 'UNKNOWN');
    expect(cutoff['difficulty_score'], isNull);
    final budget = SearchBudget(100, 100);
    final exhaustive = auditBoard(tiles, geometry, budget);
    expect((exhaustive['solver'] as Map)['status'], 'UNSOLVABLE');
    expect((exhaustive['solver'] as Map)['reason'], 'Exhaustive tap search');
    expect((exhaustive['solver'] as Map)['engine_win_status'], 'UNSOLVABLE');
    expect(budget.spent, inInclusiveRange(1, 100));
    expect(budget.next, 100 - budget.spent);
  });

  test('strict solver rejection is not presented as engine impossibility for invalid inventory', () {
    const tiles = [Tile(id: 'a', type: 'apple', x: 0, y: 0, layer: 0)];
    final engine = GameEngine(tiles);
    expect(engine.tapTile('a', geometry.board, geometry.tile), isTrue);
    expect(engine.result, GameResult.won);
    final result = auditBoard(tiles, geometry, SearchBudget(0, 0));
    final solver = result['solver'] as Map;
    expect(solver['status'], 'UNSOLVABLE');
    expect(solver['criterion'], 'FULL_CLEARANCE_AND_OBJECTIVE');
    expect(solver['engine_win_status'], 'UNKNOWN');
    expect(solver['criterion_equivalent_to_engine_win_for_this_inventory'], isFalse);
    expect(result['issues'], contains('STRICT_CLEARANCE_DIFFERS_FROM_ENGINE_WIN'));
  });
}
