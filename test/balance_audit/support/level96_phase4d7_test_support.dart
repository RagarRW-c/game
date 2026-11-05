import 'dart:io';

import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/level96_playtest/session.dart';

PlaytestLevels testLevels() =>
    PlaytestLevels(File(level96Asset).readAsStringSync());

LevelDefinition exposedLevel(List<String> types) => LevelDefinition(
      level: 96,
      name: 'Contract fixture',
      timeBonusSeconds: 0,
      tiles: [
        for (var i = 0; i < types.length; i++)
          Tile(id: 'fixture_$i', type: types[i], x: i * .1, y: 0, layer: 0)
      ],
    );

class PlaytestTestAudio implements GameAudioService {
  @override
  bool sfxEnabled = false;
  @override
  void cancelPendingTileFeedback() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
