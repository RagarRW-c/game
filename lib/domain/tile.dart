import 'dart:ui';

enum TileState { board, tray, matched }

class Tile {
  const Tile({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.layer,
    required this.width,
    required this.height,
    this.state = TileState.board,
  });

  final String id;
  final String type;
  final double x;
  final double y;
  final int layer;
  final double width;
  final double height;
  final TileState state;

  int get zIndex => layer;
  bool get removed => state == TileState.matched;
  bool get visibleOnBoard => state == TileState.board;

  Tile copyWith({TileState? state}) => Tile(
        id: id,
        type: type,
        x: x,
        y: y,
        layer: layer,
        width: width,
        height: height,
        state: state ?? this.state,
      );

  factory Tile.fromJson(Map<String, dynamic> json) => Tile(
        id: json['id'] as String,
        type: json['type'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        layer: json['layer'] as int,
        width: _readDimension(json['width']),
        height: _readDimension(json['height']),
      );

  static double _readDimension(Object? value) =>
      value is num ? value.toDouble() : 0.16;

  Size renderSize(Size boardSize, Size fallbackTileSize) => Size(
        width > 0 ? width * boardSize.width : fallbackTileSize.width,
        height > 0 ? height * boardSize.height : fallbackTileSize.height,
      );

  Rect boardRect(Size boardSize, Size fallbackTileSize) {
    final size = renderSize(boardSize, fallbackTileSize);
    return Rect.fromLTWH(
      x * boardSize.width,
      y * boardSize.height,
      size.width,
      size.height,
    );
  }
}
