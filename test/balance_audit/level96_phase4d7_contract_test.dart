import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/level96_playtest/app.dart';
import 'package:triple_tile_adventure/level96_playtest/isolation.dart';
import 'package:triple_tile_adventure/level96_playtest/session.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';

import 'support/level96_phase4d7_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('original asset pin and corrupt input rejection', () {
    final raw = File(level96Asset).readAsStringSync();
    expect(fingerprint(raw), level96Fingerprint);
    expect(() => PlaytestLevels('$raw '), throwsStateError);
  });
  for (final variant in PlaytestVariant.values) {
    test('${variant.label}: exact swaps, 99 tiles, inventory and geometry', () {
      final levels = testLevels();
      final original = levels.create(PlaytestVariant.original);
      final changed = levels.create(variant);
      final expected = <String, String>{
        if (variant != PlaytestVariant.original) ...{
          'L96_T094': 'star',
          'L96_T095': 'heart'
        },
        if (variant == PlaytestVariant.candidateB) ...{
          'L96_T071': 'heart',
          'L96_T069': 'banana'
        },
      };
      expect(original.tiles.length, 99);
      expect(changed.tiles.length, 99);
      expect(changed.level, original.level);
      expect(changed.name, original.name);
      expect(changed.timeBonusSeconds, original.timeBonusSeconds);
      expect(changed.objective?.type, original.objective?.type);
      expect(changed.objective?.target, original.objective?.target);
      expect(changed.tiles.map((t) => t.type).toList()..sort(),
          original.tiles.map((t) => t.type).toList()..sort());
      for (var i = 0; i < 99; i++) {
        final a = original.tiles[i], b = changed.tiles[i];
        expect([b.id, b.x, b.y, b.layer, b.state],
            [a.id, a.x, a.y, a.layer, a.state]);
        expect(b.type, expected[a.id] ?? a.type);
        expect(identical(a, b), false);
      }
    });
  }
  test('fresh independent copies survive mutations and variant switching', () {
    final levels = testLevels();
    final a = levels.create(PlaytestVariant.candidateA);
    a.tiles.clear();
    for (final v in PlaytestVariant.values) {
      expect(levels.create(v).tiles.length, 99);
    }
    expect(
        fingerprint(File(level96Asset).readAsStringSync()), level96Fingerprint);
  });
  test('asset bundle load and Level 96 repository boundary', () async {
    final levels = await PlaytestLevels.load();
    final repo = PlaytestLevelRepository(levels, PlaytestVariant.candidateB);
    expect((await repo.loadLevel(96)).tiles.length, 99);
    await expectLater(repo.loadLevel(97), throwsStateError);
  });
  test('missing opt-in and all release activation rejected', () {
    expect(() => requirePlaytestOptIn(enabled: false, release: false),
        throwsStateError);
    expect(() => requirePlaytestOptIn(enabled: true, release: true),
        throwsStateError);
    expect(() => requirePlaytestOptIn(enabled: false, release: true),
        throwsStateError);
    expect(() => requirePlaytestOptIn(enabled: true, release: false),
        returnsNormally);
    expect(() => Level96PlaytestApp(levels: testLevels(), enabled: false),
        throwsStateError);
  });
  test('normal entrypoint and Endless do not import playtest infrastructure',
      () {
    for (final path in [
      'lib/main.dart',
      'lib/presentation/screens/endless_screen.dart',
      'lib/domain/game_engine.dart'
    ]) {
      expect(
          File(path).readAsStringSync(), isNot(contains('level96_playtest')));
    }
    expect(const GameScreen(level: 96).sessionHooks, isNull);
    final entry = File('lib/main_level96_playtest.dart').readAsStringSync();
    expect(entry.indexOf('requirePlaytestOptIn();'),
        lessThan(entry.indexOf('WidgetsFlutterBinding.ensureInitialized')));
  });
  test('progress whitelist inert; economy, rewards and settings fail closed',
      () async {
    SharedPreferences.setMockInitialValues({
      'coins': 913,
      'highest_unlocked_level': 77,
      'extra_hint_boosters': 4,
      'music_enabled': false,
      'sentinel': 'keep'
    });
    final prefs = await SharedPreferences.getInstance();
    final before = {for (final k in prefs.getKeys()) k: prefs.get(k)};
    final progress = PlaytestProgress();
    expect(await progress.coins(), 0);
    expect(await progress.extraHintBoosters(), 0);
    expect(await progress.extraShuffleBoosters(), 0);
    expect(await progress.extraUndoBoosters(), 0);
    await progress.recordMatchedTiles(99, level: 96, tileTypes: ['heart']);
    expect(await progress.consumePendingAchievementPopups(), isEmpty);
    for (final operation in <void Function()>[
      () => progress.unlockNextLevel(96),
      () => progress.addCoins(100),
      () => progress.spendCoins(150),
      () => progress.recordLevelCompleted(96, 3),
      () => progress.setMusicEnabled(true),
      () => progress.useExtraHintBooster(),
    ]) {
      expect(operation, throwsStateError);
    }
    expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, before);
  });
  test('unique anonymous session identities and no engine reuse', () {
    final log = PlaytestLog(), levels = testLevels();
    final ids = <String>{};
    for (var i = 0; i < 100; i++) {
      final session = log.start(levels, PlaytestVariant.candidateB);
      expect(ids.add(session.id), true);
      expect(session.engine.tray, isEmpty);
      session.abort('contract');
    }
    expect(
        identical(log.sessions.first.engine, log.sessions.last.engine), false);
  });
}
