import 'dart:math';

import '../core/tile_catalog.dart';
import 'board_layout.dart';
import 'endless_difficulty.dart';
import 'game_engine.dart';
import 'tile.dart';

class EndlessBoardGenerator {
  EndlessBoardGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<Tile> generate({
    required int round,
    required TileVisualTheme theme,
  }) {
    if (round >= 14) return _generateProgressive(round, theme);
    final profile = _profileForRound(round);
    final tileCount = _divisibleByThree(
      profile.minTiles +
          _random.nextInt(profile.maxTiles - profile.minTiles + 1),
    );
    final types = tileCatalogForTheme(theme).keys.toList(growable: false);
    final typeBag = <String>[];
    var lastType = '';
    while (typeBag.length < tileCount) {
      final candidates =
          types.where((type) => type != lastType).toList(growable: false);
      final type = candidates[_random.nextInt(candidates.length)];
      typeBag.addAll([type, type, type]);
      lastType = type;
    }
    typeBag
      ..length = tileCount
      ..shuffle(_random);

    final positions = _positionsFor(profile, tileCount);
    final tiles = List<Tile>.generate(tileCount, (index) {
      final position = positions[index];
      return Tile(
        id: 'endless_${round}_$index',
        type: typeBag[index],
        x: position.x,
        y: position.y,
        layer: position.layer,
      );
    });

    // Random inventories with complete triples are not necessarily clearable:
    // coverage can force seven unmatched tiles before a triple is available.
    // The last painted remaining tile is always uncovered at any screen size.
    // Assign a tray-safe type sequence along that guaranteed removal order.
    final removalOrder = GameEngine(tiles).renderedBoardTiles.reversed.toList();
    final removalTypes = clearableTileOrder(
      typeBag,
      random: Random(_solutionSeed(typeBag, round)),
      difficulty: round <= 3
          ? 2
          : round <= 7
              ? 3
              : 4,
    );
    final typeById = <String, String>{
      for (var i = 0; i < removalOrder.length; i++)
        removalOrder[i].id: removalTypes[i],
    };
    return tiles
        .map((tile) => tile.copyWith(type: typeById[tile.id]!))
        .toList();
  }

  List<Tile> _generateProgressive(int round, TileVisualTheme theme) {
    final profile = EndlessDifficulty.forRound(round);
    final tileCount = profile.minTiles +
        3 * _random.nextInt((profile.maxTiles - profile.minTiles) ~/ 3 + 1);
    final layers = profile.minLayers +
        _random.nextInt(profile.maxLayers - profile.minLayers + 1);
    final types = tileCatalogForTheme(theme).keys.toList()..shuffle(_random);
    final palette = types.take(min(profile.typeCount, types.length)).toList();
    // Guarantee the requested variety, then vary the remaining triple counts.
    final triples = List<String>.from(palette);
    while (triples.length < tileCount ~/ 3) {
      triples.add(palette[_random.nextInt(palette.length)]);
    }
    triples.shuffle(_random);

    final positions = <_TilePosition>[];
    final slots = List<int>.generate(16, (i) => i)..shuffle(_random);
    final mirror = _random.nextBool();
    for (var layer = 0; layer < layers; layer++) {
      final lowerCount = tileCount - profile.topTiles;
      final count = layer == layers - 1
          ? profile.topTiles
          : lowerCount ~/ (layers - 1) +
              (layer < lowerCount % (layers - 1) ? 1 : 0);
      // Rotate holes between layers. A whole layer shares one small offset:
      // cells stay separate within that layer, while adjacent cells on other
      // layers can cover one another without accumulated jitter or edge piles.
      for (var i = 0; i < count; i++) {
        final cell = slots[(i + layer * 3) % slots.length];
        final column = cell % 4;
        final row = cell ~/ 4;
        final direction = layer.isEven ? -1.0 : 1.0;
        final dx = profile.layout == EndlessLayout.weave
            ? 0.0
            : direction * profile.offset;
        final dy = profile.layout == EndlessLayout.terraces
            ? 0.0
            : direction * profile.offset;
        final x = 0.075 + column * 0.190 + dx;
        positions.add(_TilePosition(
          mirror ? 0.765 - x : x,
          0.100 + row * 0.180 + dy,
          layer,
        ));
      }
    }
    positions.shuffle(_random);
    final tiles = List<Tile>.generate(
        tileCount,
        (i) => Tile(
              id: 'endless_${round}_$i',
              type: triples.first,
              x: positions[i].x,
              y: positions[i].y,
              layer: positions[i].layer,
            ));

    final order = <String>[];
    var batchIndex = 0;
    while (triples.isNotEmpty) {
      final width = profile.batchWidth(batchIndex++);
      final batch = <String>[];
      while (batch.length < width && triples.isNotEmpty) {
        final distinct = triples.indexWhere((type) => !batch.contains(type));
        batch.add(triples.removeAt(distinct < 0 ? 0 : distinct));
      }
      order.addAll(clearableTileOrder(
        [
          for (final type in batch) ...[type, type, type]
        ],
        random: _random,
        difficulty: width,
      ));
    }
    final removalOrder = GameEngine(tiles).renderedBoardTiles.reversed.toList();
    final typeById = <String, String>{
      for (var i = 0; i < removalOrder.length; i++)
        removalOrder[i].id: order[i],
    };
    return tiles
        .map((tile) => tile.copyWith(type: typeById[tile.id]!))
        .toList();
  }

  int _solutionSeed(List<String> shuffledInventory, int round) {
    // Do not consume additional _random values: keep existing seeded counts,
    // inventories and positions, including subsequent boards in the same run.
    // Avoid String.hashCode so the derived seed is stable across processes.
    var seed = round & 0x7fffffff;
    for (final type in shuffledInventory) {
      for (final unit in type.codeUnits) {
        seed = (seed * 31 + unit) & 0x7fffffff;
      }
      seed = (seed * 31) & 0x7fffffff;
    }
    return seed;
  }

  _EndlessProfile _profileForRound(int round) {
    if (round <= 3) {
      return const _EndlessProfile(24, 30, 2, 3, 0.025);
    }
    if (round <= 7) {
      return const _EndlessProfile(30, 42, 3, 3, 0.045);
    }
    if (round <= 12) {
      return const _EndlessProfile(42, 54, 4, 4, 0.07);
    }
    return const _EndlessProfile(54, 72, 5, 6, 0.095);
  }

  int _divisibleByThree(int value) => value - (value % 3);

  List<_TilePosition> _positionsFor(_EndlessProfile profile, int tileCount) {
    final layers = profile.minLayers +
        _random.nextInt(profile.maxLayers - profile.minLayers + 1);
    final columns = max(4, sqrt(tileCount / layers).ceil() + 1);
    final rows = max(4, (tileCount / (columns * layers)).ceil() + 2);
    final positions = <_TilePosition>[];

    for (var layer = 0; layer < layers; layer++) {
      final countForLayer = (tileCount / layers).ceil();
      for (var i = 0; i < countForLayer && positions.length < tileCount; i++) {
        final column = i % columns;
        final row = i ~/ columns;
        final baseX = 0.05 + (column / max(1, columns - 1)) * 0.74;
        final baseY = 0.05 + (row / max(1, rows - 1)) * 0.72;
        final jitter = profile.overlapJitter * (layer + 1);
        final x = (baseX +
                (_random.nextDouble() - 0.5) * jitter +
                layer * profile.overlapJitter)
            .clamp(0.02, 0.82)
            .toDouble();
        final y = (baseY +
                (_random.nextDouble() - 0.5) * jitter +
                layer * profile.overlapJitter)
            .clamp(0.02, 0.80)
            .toDouble();
        positions.add(_TilePosition(x, y, layer));
      }
    }

    positions.shuffle(_random);
    return positions;
  }
}

class _EndlessProfile {
  const _EndlessProfile(
    this.minTiles,
    this.maxTiles,
    this.minLayers,
    this.maxLayers,
    this.overlapJitter,
  );

  final int minTiles;
  final int maxTiles;
  final int minLayers;
  final int maxLayers;
  final double overlapJitter;
}

class _TilePosition {
  const _TilePosition(this.x, this.y, this.layer);

  final double x;
  final double y;
  final int layer;
}
