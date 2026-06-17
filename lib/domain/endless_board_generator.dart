import 'dart:math';

import '../core/tile_catalog.dart';
import 'tile.dart';

class EndlessBoardGenerator {
  EndlessBoardGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<Tile> generate({
    required int round,
    required TileVisualTheme theme,
  }) {
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
    return List<Tile>.generate(tileCount, (index) {
      final position = positions[index];
      return Tile(
        id: 'endless_${round}_$index',
        type: typeBag[index],
        x: position.x,
        y: position.y,
        layer: position.layer,
      );
    });
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
