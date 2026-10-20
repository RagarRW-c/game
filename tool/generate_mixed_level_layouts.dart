import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../lib/domain/board_layout.dart';

/// Offline asset authoring only. Never changes level metadata or inventories.
void main() {
  final pending = <File, String>{};
  for (var level = 1; level <= 100; level++) {
    final file = File(
      'assets/levels/level_${level.toString().padLeft(2, '0')}.json',
    );
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final original = (json['tiles'] as List).cast<Map<String, dynamic>>();
    final inventory = original.map((tile) => tile['type'] as String).toList();
    final layers = original.map((tile) => tile['layer'] as int).toSet().length;
    final objective = json['objective'] as Map<String, dynamic>?;
    if (objective != null &&
        inventory.where((type) => type == objective['type']).length <
            (objective['target'] as int)) {
      throw StateError('Level $level has an unsatisfied objective inventory.');
    }
    final pattern = BoardLayouts.forLevel(level);
    final positions = BoardLayouts.compose(
      tileCount: original.length,
      layerCount: layers,
      pattern: pattern,
      seed: level,
    );
    final removalTypes = clearableTileOrder(
      inventory,
      random: Random(7919 * level),
      difficulty: level <= 10
          ? 2
          : level <= 30
              ? 3
              : 4,
    );
    json['layoutPattern'] = pattern.name;
    json['tiles'] = [
      for (var i = 0; i < original.length; i++)
        {
          ...original[i],
          'type': removalTypes[original.length - 1 - i],
          'x': positions[i].x,
          'y': positions[i].y,
          'layer': positions[i].layer,
        },
    ];
    pending[file] = '${const JsonEncoder.withIndent('  ').convert(json)}\n';
  }
  // Prepare every level before writing so invalid input cannot half-regenerate
  // a campaign. Matching, blocking, and rewards remain runtime responsibilities.
  for (final entry in pending.entries) {
    entry.key.writeAsStringSync(entry.value);
  }
  stdout.writeln('Authored ${pending.length} campaign board layouts.');
}
