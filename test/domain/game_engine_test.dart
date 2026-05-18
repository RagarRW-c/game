import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/tile.dart';

void main() {
  const boardSize = Size(1000, 1000);
  const fallbackTileSize = Size(160, 160);

  Tile tile({
    required String id,
    required double x,
    required double y,
    required int layer,
  }) => Tile(
        id: id,
        type: 'apple',
        x: x,
        y: y,
        layer: layer,
        width: 0.2,
        height: 0.2,
      );

  test('minimal rectangle intersection covers a lower tile', () {
    final engine = GameEngine([
      tile(id: 'lower', x: 0, y: 0, layer: 0),
      tile(id: 'upper', x: 0.199, y: 0, layer: 1),
    ])..configureBoardGeometry(boardSize, fallbackTileSize);

    expect(engine.isTileCovered(engine.tileById('lower')!), isTrue);
    expect(engine.tapTile('lower', boardSize, fallbackTileSize), isFalse);
  });

  test('edge contact without intersection keeps a tile selectable', () {
    final engine = GameEngine([
      tile(id: 'left', x: 0, y: 0, layer: 0),
      tile(id: 'right', x: 0.2, y: 0, layer: 1),
    ])..configureBoardGeometry(boardSize, fallbackTileSize);

    expect(engine.isTileCovered(engine.tileById('left')!), isFalse);
    expect(engine.tapTile('left', boardSize, fallbackTileSize), isTrue);
  });
}
