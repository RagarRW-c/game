import 'tile.dart';

class LevelDefinition {
  const LevelDefinition({
    required this.level,
    required this.name,
    required this.timeBonusSeconds,
    required this.tiles,
  });

  final int level;
  final String name;
  final int timeBonusSeconds;
  final List<Tile> tiles;

  factory LevelDefinition.fromJson(Map<String, dynamic> json) => LevelDefinition(
        level: json['level'] as int,
        name: json['name'] as String,
        timeBonusSeconds: json['timeBonusSeconds'] as int,
        tiles: (json['tiles'] as List<dynamic>)
            .map((item) => Tile.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
