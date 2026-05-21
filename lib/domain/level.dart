import 'tile.dart';

class LevelDefinition {
  const LevelDefinition({
    required this.level,
    required this.name,
    required this.timeBonusSeconds,
    required this.tiles,
    this.objective,
  });

  final int level;
  final String name;
  final int timeBonusSeconds;
  final List<Tile> tiles;
  final LevelObjective? objective;

  factory LevelDefinition.fromJson(Map<String, dynamic> json) =>
      LevelDefinition(
        level: json['level'] as int,
        name: json['name'] as String,
        timeBonusSeconds: json['timeBonusSeconds'] as int,
        objective: json['objective'] == null
            ? null
            : LevelObjective.fromJson(
                json['objective'] as Map<String, dynamic>,
              ),
        tiles: (json['tiles'] as List<dynamic>)
            .map((item) => Tile.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class LevelObjective {
  const LevelObjective({
    required this.type,
    required this.target,
  });

  final String type;
  final int target;

  factory LevelObjective.fromJson(Map<String, dynamic> json) => LevelObjective(
        type: json['type'] as String,
        target: json['target'] as int,
      );
}
