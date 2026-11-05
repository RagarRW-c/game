import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/level96_playtest/session.dart';

import '../qa/support/geometry.dart';
import 'support/level96_phase4d7_test_support.dart';

const board = Size(1000, 600), tile = Size(10, 10);
PlaytestSession fixture(List<String> types, {int Function()? elapsed}) =>
    PlaytestSession(
      variant: PlaytestVariant.original,
      level: exposedLevel(types),
      id: 'fixed-contract-id',
      startedUtc: DateTime.utc(2026, 11, 5),
      elapsedMilliseconds: elapsed ?? () => 42,
    );

void main() {
  test('accepted/rejected taps, first triple and terminal WIN', () {
    final session = fixture(['heart', 'heart', 'heart']);
    expect(session.engine.tapTile('absent', board, tile), false);
    expect(session.engine.tapTile('fixture_0', board, tile), true);
    expect(session.engine.tapTile('fixture_0', board, tile), false);
    session.engine.tapTile('fixture_1', board, tile);
    session.engine.tapTile('fixture_2', board, tile);
    expect(session.acceptedTaps, 3);
    expect(session.rejectedTaps, 2);
    expect(session.firstTripleTap, 3);
    expect(session.firstTripleIds, ['fixture_0', 'fixture_1', 'fixture_2']);
    expect(session.maxTrayOccupancy, 2);
    expect(session.maxTrayBeforeResolution, 3);
    expect(session.outcome, 'WIN');
    expect(session.durationMs, 42);
    expect(session.toJson()['remaining_board_tiles'], 0);
  });
  test('seventh distinct symbol loses and freezes terminal metrics', () {
    final session = fixture(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']);
    for (var i = 0; i < 7; i++) {
      session.engine.tapTile('fixture_$i', board, tile);
    }
    final before = exportSessions([session]);
    expect(session.outcome, 'LOSS');
    expect(session.toJson()['failure_tap'], 7);
    expect(session.maxTrayOccupancy, 7);
    expect(session.toJson()['final_tray_occupancy'], 7);
    expect(session.toJson()['remaining_board_tiles'], 1);
    expect(session.engine.tapTile('fixture_7', board, tile), false);
    session.abort('late-abort');
    expect(exportSessions([session]), before);
  });
  test('triple on seventh slot resolves before loss exactly as real engine',
      () {
    final session = fixture(['a', 'a', 'b', 'b', 'c', 'c', 'a', 'd']);
    final oracle = GameEngine(
        exposedLevel(['a', 'a', 'b', 'b', 'c', 'c', 'a', 'd']).tiles);
    for (var i = 0; i < 7; i++) {
      expect(session.engine.tapTile('fixture_$i', board, tile),
          oracle.tapTile('fixture_$i', board, tile));
      expect(session.engine.tray, oracle.tray);
      expect(session.engine.result, oracle.result);
    }
    expect(session.engine.result, GameResult.playing);
    expect(session.engine.tray.length, 4);
    expect(session.maxTrayOccupancy, 6);
    expect(session.maxTrayBeforeResolution, 7);
    expect(GameEngine.trayLimit, 7);
  });
  test('ABORTED restart and departure preserve terminal outcome', () {
    final a = fixture(['a']);
    a.depart('restart');
    expect(a.outcome, 'ABORTED');
    expect(a.toJson()['restart'], true);
    expect(a.toJson()['abandoned'], true);
    final b = fixture(['a', 'a', 'a']);
    for (var i = 0; i < 3; i++) {
      b.engine.tapTile('fixture_$i', board, tile);
    }
    b.depart('restart');
    expect(b.outcome, 'WIN');
    expect(b.toJson()['restart'], true);
    expect(b.toJson()['abandoned'], false);
  });
  test('assistance cannot mutate the board and remains zero', () {
    final session = fixture(['a', 'a', 'a']);
    session.engine.tapTile('fixture_0', board, tile);
    final before = exportSessions([session]);
    expect(session.engine.undo(), false);
    expect(session.engine.shuffleBoard(), false);
    expect(session.engine.findBestHintTileIds(), isEmpty);
    expect(
        session.engine
            .collectHintTileIds(['fixture_0', 'fixture_1', 'fixture_2']),
        false);
    expect(exportSessions([session]), before);
    expect(session.toJson()['booster_usage'],
        {'hint': 0, 'shuffle': 0, 'undo': 0});
  });
  test('geometry changes are indexed in chronological replay', () {
    final session = fixture(['a', 'a', 'a']);
    session.screen = const Size(320, 568);
    session.engine.tapTile('fixture_0', board, tile);
    session.screen = const Size(412, 915);
    session.engine.tapTile('fixture_1', const Size(900, 500), tile);
    final data = session.toJson();
    expect((data['geometry_history'] as List).length, 2);
    expect((data['analyst_only_accepted_trace'] as List).last['geometry_index'],
        1);
  });
  test('board pointer rejection excludes successful taps and drags', () async {
    final session = fixture(['a', 'a', 'a']);
    session.pointerDown(const PointerDownEvent(pointer: 1));
    session.pointerUp(const PointerUpEvent(pointer: 1));
    await Future<void>.delayed(Duration.zero);
    expect(session.rejectedTaps, 1);
    session.pointerDown(const PointerDownEvent(pointer: 2));
    session.engine.tapTile('fixture_0', board, tile);
    session.pointerUp(const PointerUpEvent(pointer: 2));
    session.pointerDown(const PointerDownEvent(pointer: 3));
    session.pointerUp(
        const PointerUpEvent(pointer: 3, position: Offset(100, 100)));
    await Future<void>.delayed(Duration.zero);
    expect(session.rejectedTaps, 1);
  });
  test('deterministic JSON schema and copied trace cannot mutate evidence', () {
    final a = fixture(['a', 'a', 'a']), b = fixture(['a', 'a', 'a']);
    for (final s in [a, b]) {
      s.engine.tapTile('fixture_0', board, tile);
      s.depart('selection');
    }
    expect(exportSessions([a]), exportSessions([b]));
    final decoded = jsonDecode(exportSessions([a])) as Map<String, dynamic>;
    expect(decoded['schema'], playtestSchema);
    final record = (decoded['sessions'] as List).single as Map;
    expect(
        record.keys,
        containsAll([
          'session_id',
          'variant',
          'started_utc',
          'duration_ms',
          'accepted_taps',
          'rejected_taps',
          'first_triple_tap',
          'max_tray_occupancy',
          'final_tray_occupancy',
          'outcome',
          'failure_tap',
          'remaining_board_tiles',
          'booster_usage',
          'restart',
          'abandoned',
          'analyst_only_accepted_trace'
        ]));
    (a.toJson()['analyst_only_accepted_trace'] as List).clear();
    expect(a.acceptedTaps, 1);
  });
  test('in-progress exports never falsely claim a completed human result', () {
    final s = fixture(['a']);
    expect(s.toJson()['outcome'], 'RUNNING');
    expect(s.toJson()['duration_ms'], isNull);
  });
  test(
      'all 22 stored Phase 4D-5 winning paths replay through recorded real engine',
      () {
    final file = File(
        'qa/campaign_validation_runs/phase4d5-level96-20261105T114207305023Z-34520-a437c264/attempts.jsonl');
    var wins = 0;
    for (final line in file.readAsLinesSync()) {
      final row = jsonDecode(line) as Map<String, dynamic>;
      if (row['outcome'] != 'WIN') continue;
      final variant = row['variant'] == 'control_a'
          ? PlaytestVariant.candidateA
          : PlaytestVariant.candidateB;
      final level = testLevels().create(variant);
      final s = PlaytestSession(variant: variant, level: level);
      final oracle = GameEngine(level.tiles, objective: level.objective);
      final geometry = qaScreens
          .singleWhere((screen) => screen.name == row['screen'])
          .geometry();
      for (final id in row['path_ids'] as List) {
        expect(s.engine.tapTile(id as String, geometry.board, geometry.tile),
            true);
        expect(oracle.tapTile(id, geometry.board, geometry.tile), true);
        expect(s.engine.tray, oracle.tray);
        expect(s.engine.result, oracle.result);
      }
      expect(s.outcome, 'WIN');
      expect(s.acceptedTaps, 99);
      wins++;
    }
    expect(wins, 22);
  });
}
