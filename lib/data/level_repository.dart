import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/level.dart';

class LevelRepository {
  static const int levelCount = 40;

  Future<LevelDefinition> loadLevel(int level) async {
    final padded = level.toString().padLeft(2, '0');
    final raw = await rootBundle.loadString('assets/levels/level_$padded.json');
    return LevelDefinition.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
