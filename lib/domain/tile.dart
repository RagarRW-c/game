import 'dart:ui';

enum TileState { board, tray, matched }

class Tile {
  const Tile({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.layer,
    this.state = TileState.board,
  });

  final String id;
  final String type;
  final double x;
  final double y;
  final int layer;
  final TileState state;

  Tile copyWith({String? type, TileState? state}) => Tile(
        id: id,
        type: type ?? this.type,
        x: x,
        y: y,
        layer: layer,
        state: state ?? this.state,
      );

  factory Tile.fromJson(Map<String, dynamic> json) => Tile(
        id: json['id'] as String,
        type: json['type'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        layer: json['layer'] as int,
      );

  Rect boardRect(Size boardSize, Size tileSize) => Rect.fromLTWH(
        x * boardSize.width,
        y * boardSize.height,
        tileSize.width,
        tileSize.height,
      );

  bool overlaps(
    Tile other,
    Size boardSize,
    Size tileSize, {
    double minimumCoveredRatio = 0.03,
  }) {
    final candidateRect = boardRect(boardSize, tileSize);
    final otherRect = other.boardRect(boardSize, tileSize);
    if (!candidateRect.overlaps(otherRect)) return false;

    final intersection = candidateRect.intersect(otherRect);
    if (intersection.width <= 0 || intersection.height <= 0) return false;

    final candidateArea = candidateRect.width * candidateRect.height;
    if (candidateArea <= 0) return false;

    final coveredArea = intersection.width * intersection.height;
    return coveredArea / candidateArea >= minimumCoveredRatio;
  }
}
