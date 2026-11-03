import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/domain/endless_board_generator.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';

import 'support/geometry.dart';

void main() {
  // Independent measurements of 7a8b186, seed 0, small QA canvas. These are
  // gameplay invariants, not new balance targets. The rejected body-contact
  // predicate reduces neighboring-cell edges to zero in every case below.
  const cases = [
    (round: 14, covered: 42, openings: 12, edges: 99, neighbors: 33, chain: 5),
    (round: 15, covered: 47, openings: 13, edges: 124, neighbors: 37, chain: 5),
    (round: 21, covered: 36, openings: 12, edges: 107, neighbors: 56, chain: 4),
    (round: 31, covered: 40, openings: 14, edges: 99, neighbors: 32, chain: 4),
    (round: 51, covered: 48, openings: 12, edges: 161, neighbors: 77, chain: 5),
    (
      round: 101,
      covered: 46,
      openings: 14,
      edges: 121,
      neighbors: 37,
      chain: 5
    ),
  ];
  for (final sample in cases) {
    test('Endless ${sample.round} preserves reviewed neighboring-cell depth',
        () {
      final g = qaScreens.first.geometry(endless: true);
      for (final theme in TileVisualTheme.values) {
        final tiles = EndlessBoardGenerator(random: Random(0))
            .generate(round: sample.round, theme: theme);
        final engine = GameEngine(tiles)..updateBoardGeometry(g.board, g.tile);
        final painted = engine.renderedBoardTiles;
        var edges = 0;
        var neighbors = 0;
        final depths = List.filled(painted.length, 1);
        for (var i = painted.length - 1; i >= 0; i--) {
          for (var j = i + 1; j < painted.length; j++) {
            if (!painted[i].overlaps(painted[j], g.board, g.tile)) continue;
            edges++;
            depths[i] = max(depths[i], 1 + depths[j]);
            if (painted[i].layer != painted[j].layer &&
                ((painted[i].x - painted[j].x).abs() > .09 ||
                    (painted[i].y - painted[j].y).abs() > .09)) {
              neighbors++;
            }
          }
        }
        expect(painted.where(engine.isTileCovered), hasLength(sample.covered));
        expect(painted.where((t) => !engine.isTileCovered(t)),
            hasLength(sample.openings));
        expect(edges, sample.edges);
        expect(neighbors, sample.neighbors);
        expect(depths.reduce(max), sample.chain);
      }
    });
  }
}
