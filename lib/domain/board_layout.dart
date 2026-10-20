import 'dart:math';

/// Coordinates describe tile origins, matching the existing board renderer.
class BoardPosition {
  const BoardPosition(this.x, this.y, this.layer);

  final double x;
  final double y;
  final int layer;
}

enum BoardPattern {
  petals,
  grove,
  leaf,
  arch,
  gardenBloom,
  waves,
  tide,
  reef,
  crescent,
  oceanGyre,
  staggered,
  steps,
  bow,
  pyramid,
  candyCastle,
  orbit,
  diamond,
  cross,
  satellites,
  spaceNova,
  dunes,
  fan,
  desertTemple,
  snowflake,
  shards,
  iceCrown,
  vine,
  canopy,
  jungleSanctuary,
  cone,
  flow,
  crater,
  volcanoCaldera,
  cloud,
  islands,
  dreamPalace,
  prism,
  cluster,
  crystalCrown,
}

class BoardLayouts {
  const BoardLayouts._();

  // The last entry in each pool is reserved for that world's boss.
  static const worldPatterns = <List<BoardPattern>>[
    [
      BoardPattern.petals,
      BoardPattern.grove,
      BoardPattern.leaf,
      BoardPattern.arch,
      BoardPattern.staggered,
      BoardPattern.gardenBloom
    ],
    [
      BoardPattern.waves,
      BoardPattern.tide,
      BoardPattern.reef,
      BoardPattern.crescent,
      BoardPattern.orbit,
      BoardPattern.oceanGyre
    ],
    [
      BoardPattern.staggered,
      BoardPattern.steps,
      BoardPattern.bow,
      BoardPattern.pyramid,
      BoardPattern.cluster,
      BoardPattern.candyCastle
    ],
    [
      BoardPattern.orbit,
      BoardPattern.diamond,
      BoardPattern.cross,
      BoardPattern.satellites,
      BoardPattern.prism,
      BoardPattern.spaceNova
    ],
    [
      BoardPattern.pyramid,
      BoardPattern.dunes,
      BoardPattern.diamond,
      BoardPattern.orbit,
      BoardPattern.fan,
      BoardPattern.desertTemple
    ],
    [
      BoardPattern.snowflake,
      BoardPattern.shards,
      BoardPattern.orbit,
      BoardPattern.steps,
      BoardPattern.fan,
      BoardPattern.iceCrown
    ],
    [
      BoardPattern.vine,
      BoardPattern.leaf,
      BoardPattern.canopy,
      BoardPattern.tide,
      BoardPattern.arch,
      BoardPattern.jungleSanctuary
    ],
    [
      BoardPattern.cone,
      BoardPattern.flow,
      BoardPattern.crater,
      BoardPattern.cross,
      BoardPattern.steps,
      BoardPattern.volcanoCaldera
    ],
    [
      BoardPattern.cloud,
      BoardPattern.crescent,
      BoardPattern.islands,
      BoardPattern.arch,
      BoardPattern.bow,
      BoardPattern.dreamPalace
    ],
    [
      BoardPattern.diamond,
      BoardPattern.prism,
      BoardPattern.cluster,
      BoardPattern.shards,
      BoardPattern.orbit,
      BoardPattern.crystalCrown
    ],
  ];

  static BoardPattern forLevel(int level) {
    final pool = worldPatterns[((level - 1) ~/ 10).clamp(0, 9)];
    final stage = (level - 1) % 10;
    return stage == 9 ? pool.last : pool[stage % (pool.length - 1)];
  }

  static List<BoardPosition> compose({
    required int tileCount,
    required int layerCount,
    required BoardPattern pattern,
    required int seed,
  }) {
    if (tileCount < layerCount || layerCount < 1) {
      throw ArgumentError('Each layer needs at least one tile.');
    }
    final random = Random(seed);
    final counts = _layerCounts(tileCount, layerCount);
    final positions = <BoardPosition>[];
    final candidates = _candidates(pattern);
    // Repeated patterns alternate their balance without random coordinate noise.
    final mirror = seed.isEven ? 1.0 : -1.0;
    final verticalScale = seed % 3 == 0 ? 0.94 : 1.0;
    for (var layer = 0; layer < layerCount; layer++) {
      final depth = layerCount == 1 ? 1.0 : layer / (layerCount - 1);
      final scale = 1.0 - depth * 0.08;
      final offsetX = layer.isEven ? -0.012 : 0.012;
      final offsetY = (layer % 3 - 1) * 0.012;
      final selected = _spread(candidates, counts[layer], layer);
      // Paint order varies spatially while the silhouette remains stable.
      selected.shuffle(random);
      for (final point in selected) {
        positions.add(BoardPosition(
          _round(0.415 + point.x * 0.325 * scale * mirror + offsetX),
          _round(0.415 + point.y * 0.285 * scale * verticalScale + offsetY),
          layer,
        ));
      }
    }
    return positions;
  }

  static List<int> _layerCounts(int total, int layers) {
    if (layers == 1) return [total];
    // Keep a readable cap and enough lower tiles to support its silhouette.
    final top = max(min(10, total ~/ layers), total - (layers - 1) * 22);
    final counts = List<int>.filled(layers, 0);
    counts[layers - 1] = top;
    for (var i = 0; i < total - top; i++) {
      counts[i % (layers - 1)]++;
    }
    return counts;
  }

  /// Samples the entire formation, never a truncated prefix of its rows.
  static List<Point<double>> _spread(
    List<Point<double>> candidates,
    int count,
    int layer,
  ) {
    if (count > candidates.length) {
      throw ArgumentError('Formation has too few anchors for $count tiles.');
    }
    final remaining = List<Point<double>>.from(candidates);
    remaining.sort((a, b) => a.magnitude.compareTo(b.magnitude));
    final selected = <Point<double>>[remaining.removeAt(layer % 3)];
    while (selected.length < count) {
      var bestIndex = 0;
      var bestDistance = -1.0;
      for (var i = 0; i < remaining.length; i++) {
        final distance =
            selected.map((point) => point.distanceTo(remaining[i])).reduce(min);
        if (distance > bestDistance) {
          bestDistance = distance;
          bestIndex = i;
        }
      }
      selected.add(remaining.removeAt(bestIndex));
    }
    return selected;
  }

  static List<Point<double>> _candidates(BoardPattern pattern) {
    switch (pattern) {
      case BoardPattern.petals:
        return _lobes(5, 0.55, 0.40);
      case BoardPattern.grove:
      case BoardPattern.reef:
      case BoardPattern.canopy:
        return _clusters(const [
          Point(-0.53, -0.42),
          Point(0.48, -0.35),
          Point(0, 0.48),
        ]);
      case BoardPattern.leaf:
        return _rows([1, 3, 5, 7, 5, 3, 1], bend: 0.18);
      case BoardPattern.arch:
        return _arc(-pi, 0, flattened: true);
      case BoardPattern.gardenBloom:
        return _lobes(6, 0.56, 0.38);
      case BoardPattern.waves:
        return _rows([5, 6, 5, 6, 5], wave: 0.16);
      case BoardPattern.tide:
      case BoardPattern.vine:
        return _rows([3, 4, 3, 4, 3, 4, 3], bend: 0.33);
      case BoardPattern.crescent:
        return _arc(pi * 0.27, pi * 1.73);
      case BoardPattern.oceanGyre:
        return _rings(spiral: true);
      case BoardPattern.staggered:
        return _rows([5, 6, 5, 6, 5]);
      case BoardPattern.steps:
        return _rows([3, 3, 5, 5, 7, 7], bend: 0.10);
      case BoardPattern.bow:
        return _rows([7, 5, 3, 3, 5, 7]);
      case BoardPattern.pyramid:
        return _rows([1, 2, 3, 4, 5, 6, 7]);
      case BoardPattern.candyCastle:
        return _rows([5, 3, 7, 5, 7, 7]);
      case BoardPattern.orbit:
      case BoardPattern.crater:
        return _rings();
      case BoardPattern.diamond:
        return _rows([1, 3, 5, 7, 5, 3, 1]);
      case BoardPattern.cross:
        return _rows([3, 3, 7, 7, 7, 3, 3]);
      case BoardPattern.satellites:
      case BoardPattern.islands:
        return _clusters(const [
          Point(-0.52, -0.48),
          Point(0.51, -0.45),
          Point(-0.42, 0.48),
          Point(0.49, 0.48),
        ]);
      case BoardPattern.spaceNova:
        return _lobes(8, 0.62, 0.32);
      case BoardPattern.dunes:
        return _rows([4, 6, 7, 6, 4], wave: 0.24);
      case BoardPattern.fan:
        return _arc(pi * 1.07, pi * 1.93);
      case BoardPattern.desertTemple:
        return _rows([1, 3, 5, 7, 5, 7, 7]);
      case BoardPattern.snowflake:
        return _lobes(6, 0.65, 0.29);
      case BoardPattern.shards:
        return _rows([3, 5, 3, 7, 3, 5, 3]);
      case BoardPattern.iceCrown:
        return _rows([3, 5, 7, 3, 7, 5, 3]);
      case BoardPattern.jungleSanctuary:
        return _lobes(3, 0.50, 0.47);
      case BoardPattern.cone:
        return _rows([3, 3, 4, 5, 6, 7]);
      case BoardPattern.flow:
        return _rows([3, 4, 5, 4, 5, 4, 3], bend: 0.30, wave: 0.08);
      case BoardPattern.volcanoCaldera:
        return _rings(squash: 0.72);
      case BoardPattern.cloud:
        return _clusters(const [
          Point(-0.57, 0.12),
          Point(-0.22, -0.38),
          Point(0.34, -0.32),
          Point(0.59, 0.20),
          Point(0, 0.39),
        ]);
      case BoardPattern.dreamPalace:
        return _lobes(4, 0.50, 0.46);
      case BoardPattern.prism:
        return _rows([3, 5, 5, 5, 5, 3], bend: 0.22);
      case BoardPattern.cluster:
        return _clusters(const [
          Point(0, -0.54),
          Point(-0.48, 0.25),
          Point(0.48, 0.30),
        ]);
      case BoardPattern.crystalCrown:
        return _rows([5, 3, 5, 7, 7, 5, 3]);
    }
  }

  static List<Point<double>> _rows(
    List<int> widths, {
    double bend = 0,
    double wave = 0,
  }) {
    final points = <Point<double>>[];
    for (var row = 0; row < widths.length; row++) {
      final y = -1.0 + 2 * row / (widths.length - 1);
      for (var col = 0; col < widths[row]; col++) {
        final x = (col - (widths[row] - 1) / 2) / 3;
        points.add(
            Point(x + bend * sin(y * pi), y + wave * sin(x * pi + row * 0.7)));
      }
    }
    return _normalize(points);
  }

  static List<Point<double>> _rings({
    bool spiral = false,
    double squash = 1,
  }) =>
      [
        for (var ring = 0; ring < 3; ring++)
          for (var i = 0; i < 16; i++)
            Point(
              (0.55 + ring * 0.20) *
                  cos(i * pi / 8 + ring * (spiral ? 0.27 : 0)),
              (0.55 + ring * 0.20) *
                  sin(i * pi / 8 + ring * (spiral ? 0.27 : 0)) *
                  squash,
            ),
      ];

  static List<Point<double>> _arc(
    double from,
    double to, {
    bool flattened = false,
  }) =>
      _normalize([
        for (var band = 0; band < 3; band++)
          for (var i = 0; i < 15; i++)
            Point((0.55 + band * 0.22) * cos(from + (to - from) * i / 14),
                (0.55 + band * 0.22) * sin(from + (to - from) * i / 14)),
      ], height: flattened ? 0.70 : 1);

  static List<Point<double>> _lobes(int arms, double radius, double lobe) =>
      _clusters([
        for (var i = 0; i < arms; i++)
          Point(radius * cos(-pi / 2 + i * 2 * pi / arms),
              radius * sin(-pi / 2 + i * 2 * pi / arms)),
        const Point(0, 0),
      ], radius: lobe);

  static List<Point<double>> _clusters(
    List<Point<double>> centers, {
    double radius = 0.36,
  }) =>
      _normalize([
        for (final center in centers) ...[
          center,
          for (var i = 0; i < 12; i++)
            Point(center.x + radius * cos(i * pi / 6),
                center.y + radius * sin(i * pi / 6)),
        ],
      ]);

  static List<Point<double>> _normalize(
    List<Point<double>> points, {
    double height = 1,
  }) {
    final left = points.map((p) => p.x).reduce(min);
    final right = points.map((p) => p.x).reduce(max);
    final top = points.map((p) => p.y).reduce(min);
    final bottom = points.map((p) => p.y).reduce(max);
    return [
      for (final p in points)
        Point((p.x - (left + right) / 2) * 2 / (right - left),
            (p.y - (top + bottom) / 2) * 2 * height / (bottom - top)),
    ];
  }

  static double _round(double value) => (value * 10000).round() / 10000;
}

/// Assigns the existing inventory along reverse paint order. The last painted
/// remaining tile is always selectable, independent of screen geometry.
List<String> clearableTileOrder(
  Iterable<String> inventory, {
  required Random random,
  required int difficulty,
}) {
  final counts = <String, int>{};
  for (final type in inventory) {
    counts.update(type, (value) => value + 1, ifAbsent: () => 1);
  }
  if (counts.values.any((count) => count % 3 != 0)) {
    throw ArgumentError('Tile inventory must contain complete triples.');
  }
  final triples = <String>[
    for (final type in counts.keys.toList()..sort())
      for (var i = 0; i < counts[type]! ~/ 3; i++) type,
  ]..shuffle(random);
  final order = <String>[];
  final batchSize = difficulty.clamp(2, 4);
  while (triples.isNotEmpty) {
    final batch = <String>[];
    while (batch.length < batchSize && triples.isNotEmpty) {
      final distinct = triples.indexWhere((type) => !batch.contains(type));
      batch.add(triples.removeAt(distinct < 0 ? 0 : distinct));
    }
    final sequence = switch (batch.length) {
      4 => [0, 1, 2, 3, 0, 1, 0, 2, 3, 1, 2, 3],
      3 => [0, 1, 2, 0, 1, 0, 2, 1, 2],
      2 => [0, 1, 0, 1, 0, 1],
      _ => [0, 0, 0],
    };
    order.addAll(sequence.map((index) => batch[index]));
  }
  return order;
}
