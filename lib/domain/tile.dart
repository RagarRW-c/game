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

  Tile copyWith({TileState? state}) => Tile(
        id: id,
        type: type,
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
}
