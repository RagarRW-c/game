import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _tileTypes = <String>[
  'apple',
  'banana',
  'berry',
  'carrot',
  'star',
  'shell',
  'flower',
  'moon',
  'gem',
  'leaf',
  'candy',
  'heart',
  'sun',
  'drop',
  'clover',
];

const _layoutByLevel = <int, String>{
  1: 'grid',
  2: 'grid',
  3: 'scatter',
  4: 'pyramid',
  5: 'circle',
  6: 'grid',
  7: 'scatter',
  8: 'pyramid',
  9: 'heart',
  10: 'pyramid',
  11: 'grid',
  12: 'scatter',
  13: 'pyramid',
  14: 'diamond',
  15: 'wave',
  16: 'grid',
  17: 'scatter',
  18: 'pyramid',
  19: 'circle',
  20: 'wave',
  21: 'grid',
  22: 'scatter',
  23: 'pyramid',
  24: 'heart',
  25: 'wave',
  26: 'grid',
  27: 'scatter',
  28: 'pyramid',
  29: 'diamond',
  30: 'spiral',
  31: 'grid',
  32: 'scatter',
  33: 'pyramid',
  34: 'circle',
  35: 'wave',
  36: 'grid',
  37: 'scatter',
  38: 'pyramid',
  39: 'spiral',
  40: 'diamond',
};

const _tileCounts = <int>[
  30,
  30,
  36,
  36,
  36,
  36,
  42,
  42,
  42,
  54,
  42,
  42,
  48,
  48,
  48,
  54,
  54,
  54,
  54,
  66,
  54,
  54,
  60,
  60,
  60,
  66,
  66,
  72,
  72,
  78,
  72,
  72,
  78,
  78,
  78,
  84,
  84,
  84,
  90,
  90,
];

const _layerCounts = <int>[
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  4,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  5,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
  6,
];

void main() {
  final levelsDirectory = Directory('assets/levels');
  for (var level = 1; level <= 40; level++) {
    final path =
        '${levelsDirectory.path}/level_${level.toString().padLeft(2, '0')}.json';
    final file = File(path);
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    json['tiles'] = _buildLevel(
      level: level,
      tileCount: _tileCounts[level - 1],
      layerCount: _layerCounts[level - 1],
      style: _layoutByLevel[level]!,
      objectiveType:
          (json['objective'] as Map<String, dynamic>?)?['type'] as String?,
      objectiveTarget:
          (json['objective'] as Map<String, dynamic>?)?['target'] as int?,
    );
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(json)}\n',
    );
  }
}

List<Map<String, dynamic>> _buildLevel({
  required int level,
  required int tileCount,
  required int layerCount,
  required String style,
  required String? objectiveType,
  required int? objectiveTarget,
}) {
  final positions = _buildPositions(level, tileCount, layerCount, style);
  final removalOrder = positions.reversed.toList(growable: false);
  final typesInRemovalOrder = _buildSolvableTypeSequence(
    level,
    tileCount,
    objectiveType,
    objectiveTarget,
  );
  final typeByPosition = <_Position, String>{};
  for (var index = 0; index < removalOrder.length; index++) {
    typeByPosition[removalOrder[index]] = typesInRemovalOrder[index];
  }

  final tiles = List<Map<String, dynamic>>.generate(tileCount, (index) {
    final position = positions[index];
    return {
      'id': 'L${level}_T${index.toString().padLeft(3, '0')}',
      'type': typeByPosition[position],
      'x': _round(position.x),
      'y': _round(position.y),
      'layer': position.layer,
    };
  });
  _separateSameTypeVerticalPairs(tiles);
  return tiles;
}

void _separateSameTypeVerticalPairs(List<Map<String, dynamic>> tiles) {
  const offsets = <Point<double>>[
    Point(0, 0),
    Point(0.04, 0),
    Point(-0.04, 0),
    Point(0, 0.04),
    Point(0, -0.04),
    Point(0.07, 0.025),
    Point(-0.07, -0.025),
    Point(0.07, -0.025),
    Point(-0.07, 0.025),
    Point(0.1, 0),
    Point(-0.1, 0),
    Point(0, 0.08),
    Point(0, -0.08),
  ];
  for (var index = 0; index < tiles.length; index++) {
    final tile = tiles[index];
    final originalX = (tile['x'] as num).toDouble();
    final originalY = (tile['y'] as num).toDouble();
    for (final offset in offsets) {
      final candidateX = (originalX + offset.x).clamp(0.06, 0.81).toDouble();
      final candidateY = (originalY + offset.y).clamp(0.06, 0.72).toDouble();
      final nearSameType = tiles.take(index).any((other) {
        if (other['type'] != tile['type']) return false;
        final layerDistance =
            ((other['layer'] as int) - (tile['layer'] as int)).abs();
        if (layerDistance != 1) return false;
        final dx = ((other['x'] as num) - candidateX).abs();
        final dy = ((other['y'] as num) - candidateY).abs();
        return dx < 0.03 && dy < 0.03;
      });
      if (nearSameType) continue;
      tile['x'] = _round(candidateX);
      tile['y'] = _round(candidateY);
      break;
    }
  }
}

List<String> _buildSolvableTypeSequence(
  int level,
  int tileCount,
  String? objectiveType,
  int? objectiveTarget,
) {
  final pool = List<String>.from(_tileTypes);
  if (objectiveType != null && pool.remove(objectiveType)) {
    pool.insert(0, objectiveType);
  }
  final rotation = (level * 3) % pool.length;
  final rotated = [...pool.skip(rotation), ...pool.take(rotation)];
  if (objectiveType != null && rotated.remove(objectiveType)) {
    rotated.insert(0, objectiveType);
  }

  final sequence = <String>[];
  var chunk = 0;
  var objectiveTriplesRemaining =
      objectiveTarget == null ? 0 : (objectiveTarget / 3).ceil();
  while (sequence.length + 12 <= tileCount) {
    final a = objectiveType != null && objectiveTriplesRemaining > 0
        ? objectiveType
        : rotated[(chunk * 3) % rotated.length];
    final alternatives = rotated.where((type) => type != a).toList();
    final b = alternatives[(chunk * 3) % alternatives.length];
    final c = alternatives[(chunk * 3 + 1) % alternatives.length];
    final d = alternatives[(chunk * 3 + 2) % alternatives.length];
    sequence.addAll([a, b, c, d, a, b, a, c, d, b, c, d]);
    if (a == objectiveType) objectiveTriplesRemaining--;
    chunk++;
  }
  if (sequence.length + 6 == tileCount) {
    final a = objectiveType != null && objectiveTriplesRemaining > 0
        ? objectiveType
        : rotated[(chunk * 3) % rotated.length];
    final b = rotated.firstWhere((type) => type != a);
    sequence.addAll([a, b, a, b, a, b]);
  }
  return sequence;
}

List<_Position> _buildPositions(
  int level,
  int tileCount,
  int layerCount,
  String style,
) {
  final counts = _tilesPerLayer(tileCount, layerCount);
  final positions = <_Position>[];
  List<_Position> parents = const [];

  for (var layer = layerCount - 1; layer >= 0; layer--) {
    final count = counts[layer];
    final current = <_Position>[];
    for (var index = 0; index < count; index++) {
      final rawPoint = parents.isEmpty
          ? _topPoint(style, index, count, level)
          : _childPoint(
              parent: parents[index % parents.length],
              childIndex: index,
              layer: layer,
              level: level,
            );
      final point = parents.isEmpty && level % 10 == 0
          ? Point(
              0.44 + (rawPoint.x - 0.44) * 0.55,
              0.38 + (rawPoint.y - 0.38) * 0.55,
            )
          : rawPoint;
      current.add(_Position(point.x, point.y, layer));
    }
    positions.insertAll(0, current);
    parents = current;
  }
  return positions;
}

List<int> _tilesPerLayer(int tileCount, int layerCount) {
  final counts = List<int>.filled(layerCount, 0);
  counts[layerCount - 1] = min(5, tileCount);
  var remaining = tileCount - counts[layerCount - 1];
  for (var layer = layerCount - 2; layer >= 0; layer--) {
    final layersLeft = layer + 1;
    final count = (remaining / layersLeft).ceil();
    counts[layer] = count;
    remaining -= count;
  }
  return counts;
}

Point<double> _topPoint(String style, int index, int count, int level) {
  final t = count <= 1 ? 0.0 : index / count;
  final angle = 2 * pi * t;
  switch (style) {
    case 'pyramid':
      const points = [
        Point<double>(0.27, 0.22),
        Point<double>(0.44, 0.16),
        Point<double>(0.61, 0.22),
        Point<double>(0.31, 0.43),
        Point<double>(0.44, 0.49),
        Point<double>(0.57, 0.43),
      ];
      return points[index % points.length];
    case 'circle':
      return Point(0.44 + cos(angle) * 0.2, 0.37 + sin(angle) * 0.24);
    case 'diamond':
      const points = [
        Point<double>(0.44, 0.13),
        Point<double>(0.62, 0.29),
        Point<double>(0.62, 0.5),
        Point<double>(0.44, 0.66),
        Point<double>(0.26, 0.5),
        Point<double>(0.26, 0.29),
      ];
      return points[index % points.length];
    case 'heart':
      const points = [
        Point<double>(0.28, 0.25),
        Point<double>(0.39, 0.2),
        Point<double>(0.5, 0.2),
        Point<double>(0.61, 0.25),
        Point<double>(0.54, 0.45),
        Point<double>(0.44, 0.58),
      ];
      return points[index % points.length];
    case 'wave':
      return Point(0.18 + index * 0.105, 0.37 + sin(index * 1.25) * 0.13);
    case 'spiral':
      final radius = 0.08 + index * 0.035;
      final spiralAngle = index * 1.35;
      return Point(
        0.44 + cos(spiralAngle) * radius,
        0.38 + sin(spiralAngle) * radius,
      );
    case 'scatter':
      final random = Random(level * 104729 + index * 8191);
      return Point(
        0.19 + random.nextDouble() * 0.5,
        0.16 + random.nextDouble() * 0.45,
      );
    default:
      const points = [
        Point<double>(0.24, 0.23),
        Point<double>(0.44, 0.23),
        Point<double>(0.64, 0.23),
        Point<double>(0.24, 0.48),
        Point<double>(0.44, 0.48),
        Point<double>(0.64, 0.48),
      ];
      return points[index % points.length];
  }
}

Point<double> _childPoint({
  required _Position parent,
  required int childIndex,
  required int layer,
  required int level,
}) {
  final world = (level - 1) ~/ 10;
  const spreadByWorld = [0.06, 0.045, 0.032, 0.022];
  final spread = spreadByWorld[world] * (level % 10 == 0 ? 0.28 : 1);
  final angle = (childIndex * 2.399963 + layer * 0.71 + level * 0.13);
  final radius = spread * (0.35 + (childIndex % 4) * 0.2);
  return Point(
    (parent.x + cos(angle) * radius).clamp(0.06, 0.81).toDouble(),
    (parent.y + sin(angle) * radius * 0.72).clamp(0.06, 0.72).toDouble(),
  );
}

double _round(double value) => (value * 1000).round() / 1000;

class _Position {
  const _Position(this.x, this.y, this.layer);

  final double x;
  final double y;
  final int layer;
}
