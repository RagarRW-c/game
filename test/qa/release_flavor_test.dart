import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/app_flavor.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/qa_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/settings_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';

// Explicit oracle supplied by each documented flavor-matrix invocation. The
// full PROD QA suite uses false. Never derive the oracle from AppFlavorConfig.
const _expectQa = bool.fromEnvironment('EXPECT_QA');

class _SilentAudio implements GameAudioService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _mount(WidgetTester tester, Widget screen) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(AppScope(
    progressRepository: ProgressRepository(),
    levelRepository: LevelRepository(),
    audioService: _SilentAudio(),
    child: MaterialApp(theme: GameTheme.theme(), home: screen),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'coins': 123,
        'highest_unlocked_level': 7,
        'level_stars_6': 3,
        'music_enabled': false,
        'sfx_enabled': false,
        'vibration_enabled': false,
        'extra_hint_boosters': 2,
      }));

  test('native flavor determines QA access and app identity', () {
    expect(AppFlavorConfig.qaToolsEnabled, _expectQa);
    expect(AppFlavorConfig.current, _expectQa ? AppFlavor.dev : AppFlavor.prod);
    expect(AppFlavorConfig.appName,
        _expectQa ? 'Tile Adventure DEV' : 'Tile Adventure');
  });

  test('repository debug mutations are guarded independently of navigation',
      () async {
    final repository = ProgressRepository();
    final prefs = await SharedPreferences.getInstance();
    if (_expectQa) {
      await repository.debugAddCoins();
      await repository.debugUnlockAllWorlds();
      expect(await repository.coins(), 10123);
      expect(await repository.highestUnlockedLevel(), 91);
    } else {
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      final actions = <Future<dynamic> Function()>[
        repository.debugUnlockAllWorlds,
        repository.debugUnlockAllLevels,
        repository.debugAddCoins,
        repository.debugAddBoosters,
        repository.debugAddXp,
        repository.debugResetDailySpin,
        repository.debugResetDailyChallenges,
        repository.debugResetChests,
        repository.debugResetAchievements,
        repository.debugResetCollectionBook,
        repository.debugCompleteLevel100,
      ];
      for (final action in actions) {
        await expectLater(Future<dynamic>.sync(action), throwsStateError);
        expect(
            {for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
      }
    }
  });

  test('normal saved progression, inventory and settings remain readable',
      () async {
    final repository = ProgressRepository();
    expect(await repository.coins(), 123);
    expect(await repository.highestUnlockedLevel(), 7);
    expect(await repository.bestStarsForLevel(6), 3);
    expect(await repository.extraHintBoosters(), 2);
    expect(await repository.musicEnabled(), isFalse);
    expect(await repository.sfxEnabled(), isFalse);
    expect(await repository.vibrationEnabled(), isFalse);
    await repository.setMusicEnabled(true);
    expect(await ProgressRepository().musicEnabled(), isTrue);
    expect(await ProgressRepository().coins(), 123);
  });

  testWidgets('direct QA screen construction cannot bypass the flavor gate',
      (tester) async {
    await _mount(tester, const QaScreen());
    expect(
        find.text('DEV QA Tools'), _expectQa ? findsOneWidget : findsNothing);
    expect(find.text('Unlock All Levels'),
        _expectQa ? findsOneWidget : findsNothing);
    if (_expectQa) {
      await tester.scrollUntilVisible(find.text('Add 10,000 Coins'), 200);
    }
    expect(find.text('Add 10,000 Coins'),
        _expectQa ? findsOneWidget : findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings exposes development navigation only in DEV',
      (tester) async {
    await _mount(tester, const SettingsScreen());
    expect(find.text('Background music'), findsOneWidget);
    final resetProgress = find.text('Reset Progress');
    await tester.scrollUntilVisible(resetProgress, 200);
    await tester.pumpAndSettle();
    expect(resetProgress, findsOneWidget);
    expect(resetProgress.hitTestable(), findsOneWidget);
    // Development is the final section: inspect it after scrolling, not while
    // lazy ListView children may still be unbuilt outside the viewport.
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    final qaTools = find.text('DEV QA Tools');
    expect(qaTools, _expectQa ? findsOneWidget : findsNothing);
    expect(
      qaTools.hitTestable(),
      _expectQa ? findsOneWidget : findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
