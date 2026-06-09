import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

void main() {
  final levelsDirectory = Directory('assets/levels');
  for (var level = 1; level <= 40; level++) {
    final path =
        '${levelsDirectory.path}/level_${level.toString().padLeft(2, '0')}.json';
    final file = File(path);
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final tiles = (json['tiles'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
    final style = _layoutByLevel[level]!;
    final arranged = _arrangeTiles(level, style, tiles);
    json['tiles'] = arranged;
    file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n');
  }
}

List<Map<String, dynamic>> _arrangeTiles(
  int level,
  String style,
  List<Map<String, dynamic>> tiles,
) {
  final triples = _tileTriples(tiles, level);
  final arranged = <Map<String, dynamic>>[];
  for (var group = 0; group < triples.length; group++) {
    final positions = _positionsForTriple(level, style, group, triples.length);
    for (var member = 0; member < 3; member++) {
      final source = triples[group][member];
      final position = positions[member];
      arranged.add({
        'id': source['id'],
        'type': source['type'],
        'x': _round(position.x),
        'y': _round(position.y),
        'layer': position.layer,
      });
    }
  }
  return arranged;
}

List<List<Map<String, dynamic>>> _tileTriples(
  List<Map<String, dynamic>> tiles,
  int level,
) {
  final tilesByType = <String, List<Map<String, dynamic>>>{};
  for (final tile in tiles) {
    final type = tile['type'] as String;
    tilesByType.putIfAbsent(type, () => []).add(tile);
  }
  final triples = <List<Map<String, dynamic>>>[];
  for (final entry in tilesByType.entries) {
    if (entry.value.length % 3 != 0) {
      throw StateError('Level $level has invalid count for ${entry.key}.');
    }
    for (var index = 0; index < entry.value.length; index += 3) {
      triples.add(entry.value.sublist(index, index + 3));
    }
  }
  triples.shuffle(Random(level * 7919));
  return triples;
}

List<_Position> _positionsForTriple(
  int level,
  String style,
  int group,
  int groupCount,
) {
  if (style == 'grid') return _gridTriple(level, group);
  if (style == 'scatter') return _scatterTriple(level, group);
  if (style == 'pyramid') return _pyramidTriple(level, group, groupCount);
  return _shapeTriple(level, style, group, groupCount);
}

List<_Position> _gridTriple(int level, int group) {
  const grid = <List<double>>[
    [0.05, 0.07],
    [0.27, 0.07],
    [0.49, 0.07],
    [0.71, 0.07],
    [0.05, 0.31],
    [0.27, 0.31],
    [0.49, 0.31],
    [0.71, 0.31],
    [0.05, 0.55],
    [0.27, 0.55],
    [0.49, 0.55],
    [0.71, 0.55],
  ];
  final band = group ~/ 4;
  final start = (group % 4) * 3;
  final offset = band * 0.007;
  return List<_Position>.generate(3, (member) {
    final point = grid[start + member];
    return _Position(point[0] + offset, point[1] + offset, band);
  });
}

List<_Position> _scatterTriple(int level, int group) {
  final random = Random(level * 100003 + group * 97);
  final points = <_Position>[];
  while (points.length < 3) {
    final candidate = _Position(
      0.07 + random.nextDouble() * 0.72,
      0.06 + random.nextDouble() * 0.68,
      group,
    );
    final separated = points.every((point) {
      final dx = (candidate.x - point.x).abs();
      final dy = (candidate.y - point.y).abs();
      return dx >= 0.18 || dy >= 0.15;
    });
    if (separated) points.add(candidate);
  }
  return points;
}

List<_Position> _pyramidTriple(int level, int group, int groupCount) {
  final progress = groupCount <= 1 ? 0.0 : group / (groupCount - 1);
  final width = 0.72 - progress * 0.34;
  final y = 0.7 - progress * 0.58;
  final center = 0.44 + ((group % 2 == 0) ? -0.012 : 0.012);
  return [
    _Position(center - width / 2, y, group),
    _Position(center, y - 0.025, group),
    _Position(center + width / 2, y, group),
  ];
}

List<_Position> _shapeTriple(
  int level,
  String style,
  int group,
  int groupCount,
) {
  final phase = groupCount <= 1 ? 0.0 : group / groupCount;
  return List<_Position>.generate(3, (member) {
    final t = (phase + member / 3) % 1.0;
    final point = _shapePoint(style, t, group, groupCount);
    return _Position(point.x, point.y, group);
  });
}

Point<double> _shapePoint(
  String style,
  double t,
  int group,
  int groupCount,
) {
  final angle = 2 * pi * t;
  switch (style) {
    case 'circle':
      final radius = 0.27 + (group % 3) * 0.018;
      return Point(0.44 + cos(angle) * radius, 0.4 + sin(angle) * 0.3);
    case 'diamond':
      final segment = t * 4;
      final side = segment.floor();
      final local = segment - side;
      const top = Point<double>(0.44, 0.06);
      const right = Point<double>(0.8, 0.4);
      const bottom = Point<double>(0.44, 0.74);
      const left = Point<double>(0.08, 0.4);
      const points = [top, right, bottom, left, top];
      return _lerp(points[side], points[side + 1], local);
    case 'heart':
      final x = 16 * pow(sin(angle), 3).toDouble();
      final y = 13 * cos(angle) -
          5 * cos(2 * angle) -
          2 * cos(3 * angle) -
          cos(4 * angle);
      return Point(0.44 + x * 0.021, 0.4 - y * 0.021);
    case 'wave':
      final x = 0.08 + t * 0.72;
      final y = 0.4 + sin(t * pi * 4 + group * 0.3) * 0.25;
      return Point(x, y);
    case 'spiral':
      final progress = (group + t) / max(1, groupCount);
      final radius = 0.08 + progress * 0.3;
      final spiralAngle = progress * pi * 5.5 + t * pi * 2;
      return Point(
        0.44 + cos(spiralAngle) * radius,
        0.4 + sin(spiralAngle) * radius,
      );
    default:
      throw StateError('Unknown shape style: $style');
  }
}

Point<double> _lerp(Point<double> a, Point<double> b, double t) {
  return Point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
}

double _round(double value) {
  return (value.clamp(0.04, 0.84) * 1000).round() / 1000;
}

class _Position {
  const _Position(this.x, this.y, this.layer);

  final double x;
  final double y;
  final int layer;
}
