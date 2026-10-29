import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/app_flavor.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/main_menu_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/player_profile_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/settings_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/world_selection_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_ui.dart';

class _CountingProgress extends ProgressRepository {
  int coinReads = 0;
  int statusReads = 0;
  int popupReads = 0;
  Completer<int>? nextCoinRead;

  @override
  Future<int> coins() {
    coinReads++;
    final pending = nextCoinRead;
    if (pending != null) {
      nextCoinRead = null;
      return pending.future;
    }
    return super.coins();
  }

  @override
  Future<DailyLoginStreakStatus> dailyLoginStreakStatus(DateTime now) async {
    statusReads++;
    // Keep this test on the menu instead of opening the unrelated login dialog.
    return const DailyLoginStreakStatus(
      todayKey: 'test-day',
      lastClaimDate: 'test-day',
      currentStreak: 1,
      claimDay: 1,
      reward: 50,
      available: false,
    );
  }

  @override
  Future<List<PendingAchievementPopup>> consumePendingAchievementPopups() {
    popupReads++;
    return super.consumePendingAchievementPopups();
  }

  Future<void> clearPendingPopups() async {
    await super.consumePendingAchievementPopups();
  }
}

class _SilentAudio implements GameAudioService {
  @override
  Future<void> startMenuMusic() async {}

  @override
  Future<void> setMusicEnabled(bool enabled) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProbeScreen extends StatefulWidget {
  const _ProbeScreen(this.name, this.onChange);

  final String name;
  final Future<void> Function(String name)? onChange;

  @override
  State<_ProbeScreen> createState() => _ProbeScreenState();
}

class _ProbeScreenState extends State<_ProbeScreen> {
  bool _changeComplete = false;

  Future<void> _changeState() async {
    await widget.onChange!(widget.name);
    if (!mounted) return;
    setState(() => _changeComplete = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Text(widget.name),
              if (widget.name == WorldSelectionScreen.route)
                TextButton(
                  key: const ValueKey('open_map'),
                  onPressed: () => Navigator.pushNamed(context, '/map'),
                  child: const Text('Open map'),
                ),
              if (widget.name == '/map')
                TextButton(
                  key: const ValueKey('open_campaign'),
                  onPressed: () => Navigator.pushNamed(context, '/game'),
                  child: const Text('Open campaign'),
                ),
              if (widget.onChange != null)
                TextButton(
                  key: const ValueKey('change_state'),
                  onPressed: _changeState,
                  child: const Text('Change state'),
                ),
              if (_changeComplete)
                const Text('Change complete', key: ValueKey('change_complete')),
              TextButton(
                key: const ValueKey('return_to_menu'),
                onPressed: () => Navigator.pop(
                  context,
                  widget.name == SettingsScreen.route ? true : null,
                ),
                child: const Text('Return'),
              ),
            ],
          ),
        ),
      );
}

Future<void> _mountMenu(
  WidgetTester tester,
  _CountingProgress repository, {
  bool realSettings = false,
  bool realProfile = false,
  Size size = const Size(360, 800),
  double textScale = 1,
  Future<void> Function(String name)? onChange,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    AppScope(
      progressRepository: repository,
      levelRepository: LevelRepository(),
      audioService: _SilentAudio(),
      child: MaterialApp(
        theme: GameTheme.theme(),
        navigatorObservers: [appRouteObserver],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: const MainMenuScreen(),
        onGenerateRoute: (settings) => MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) {
            if (settings.name == SettingsScreen.route && realSettings) {
              return const SettingsScreen();
            }
            if (settings.name == PlayerProfileScreen.route && realProfile) {
              return const PlayerProfileScreen();
            }
            return _ProbeScreen(settings.name!, onChange);
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapMenu(WidgetTester tester, String label) async {
  final button = find.byKey(ValueKey('menu_action_$label'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  expect(target, findsOneWidget);
  // Returning routes retain the menu's scroll offset. Header shortcuts may
  // need scrolling back into view just like the lower menu actions.
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  final viewport =
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  expect(viewport.contains(tester.getCenter(target)), isTrue,
      reason: '$key must be inside the viewport before tapping');
  await tester.tap(target);
  if (key == 'change_state') {
    final completion = find.byKey(const ValueKey('change_complete'));
    for (var i = 0; i < 100 && completion.evaluate().isEmpty; i++) {
      await tester.pump();
    }
    expect(completion, findsOneWidget,
        reason: 'The route must finish saving before it is popped.');
  }
  await tester.pumpAndSettle();
}

Future<void> _waitForMenuSnapshot(
    WidgetTester tester, _CountingProgress repository, int count) async {
  for (var i = 0; i < 100 && repository.popupReads < count; i++) {
    await tester.pump();
  }
  expect(repository.coinReads, count);
  expect(repository.statusReads, count);
  expect(repository.popupReads, count);
  await tester.pumpAndSettle();
}

Future<void> _showProfileContent(
  WidgetTester tester,
  Finder target, {
  bool scrollBack = false,
}) async {
  final scroll = find.byType(NestedScrollView);
  // Gesture on the viewport: at large text sizes the tab's inner ListView
  // can initially be entirely below the summary, outside the visible area.
  await tester.dragUntilVisible(
    target.hitTestable(),
    scroll,
    Offset(0, scrollBack ? 180 : -180),
    maxIteration: 80,
  );
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  final bounds = tester.getRect(scroll).inflate(0.01);
  final content = tester.getRect(target);
  expect(
      bounds.contains(content.topLeft) && bounds.contains(content.bottomRight),
      isTrue,
      reason: 'Profile content must be reachable without clipping.');
  final widget = tester.widget(target);
  final expectedLabel = switch (widget) {
    Text(:final data) => data!,
    GameButton(:final label) => label,
    _ => throw StateError('Unexpected Profile content: $widget'),
  };
  final labelText = widget is Text
      ? target
      : find.descendant(
          of: target,
          matching: find.byWidgetPredicate(
            (candidate) => candidate is Text && candidate.data == expectedLabel,
          ),
        );
  expect(labelText, findsOneWidget,
      reason: 'The selected control must contain its exact Text label.');
  // Icon uses RichText too. Descend from the label's Text, not from the button.
  final renderedLabel =
      find.descendant(of: labelText, matching: find.byType(RichText));
  expect(renderedLabel, findsOneWidget,
      reason: 'The selected Profile label must have one rendered paragraph.');
  expect(
      tester.widget<RichText>(renderedLabel).text.toPlainText(), expectedLabel);
  final labelBounds = tester.getRect(renderedLabel);
  final targetBounds = content.inflate(0.01);
  expect(
      targetBounds.contains(labelBounds.topLeft) &&
          targetBounds.contains(labelBounds.bottomRight),
      isTrue,
      reason: '"$expectedLabel" must fit inside its visible control or card.');
  final paragraph = tester.renderObject<RenderParagraph>(renderedLabel);
  expect(paragraph.didExceedMaxLines, isFalse,
      reason: '"$expectedLabel" must not be ellipsized or faded.');
  expect(
      paragraph.textSize.width <= paragraph.size.width + 0.01 &&
          paragraph.textSize.height <= paragraph.size.height + 0.01,
      isTrue,
      reason: '"$expectedLabel" must fit its rendered text box.');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 915),
  ]) {
    testWidgets(
        'one menu refresh per return, including unchanged routes / $size',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('final_reward_unlocked', true);
      final repository = _CountingProgress();
      await repository.addCoins(400);
      await _mountMenu(tester, repository, size: size);
      expect(repository.coinReads, 1);
      expect(repository.statusReads, 1);
      expect(repository.popupReads, 1);
      final menuState = tester.state(find.byType(MainMenuScreen));
      final scroll = find.byKey(const ValueKey('main_menu_scroll'));
      final position = tester
          .state<ScrollableState>(
              find.descendant(of: scroll, matching: find.byType(Scrollable)))
          .position;

      for (final entry in {
        'Adventure': '/worlds',
        'Endless Mode': '/endless',
        'Daily Spin': '/lucky-wheel',
        'Booster Shop': '/booster-shop',
        'Profile': '/player-profile',
        'Chests': '/treasure-chests',
        'Daily Challenges': '/daily-challenges',
        'Collection Book': '/collection-book',
        'Achievements': '/achievements',
        'Statistics': '/statistics',
        'Settings': '/settings',
        'Final Reward': '/final-code',
        if (AppFlavorConfig.qaToolsEnabled) 'DEV QA Tools': '/dev-qa',
      }.entries) {
        final label = entry.key;
        final before = repository.coinReads;
        await _tapMenu(tester, label);
        expect(find.text(entry.value), findsOneWidget);
        expect(repository.coinReads, before, reason: 'opening $label');
        final retainedOffset = position.pixels;
        await _tapKey(tester, 'return_to_menu');
        expect(position.pixels, retainedOffset,
            reason: 'An unchanged return from $label must not jump the menu');
        expect(repository.coinReads, before + 1, reason: label);
        expect(repository.statusReads, before + 1, reason: label);
        expect(repository.popupReads, before + 1, reason: label);
        expect(tester.state(find.byType(MainMenuScreen)), same(menuState));
        expect(find.text('400'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      final beforeShortcut = repository.coinReads;
      await _tapKey(tester, 'menu_shop_shortcut');
      expect(find.text('/booster-shop'), findsOneWidget);
      await _tapKey(tester, 'return_to_menu');
      expect(repository.coinReads, beforeShortcut + 1);
      expect(repository.statusReads, beforeShortcut + 1);
      expect(repository.popupReads, beforeShortcut + 1);
      expect(find.byKey(const ValueKey('menu_shop_shortcut')).hitTestable(),
          findsOneWidget);
      expect(tester.state(find.byType(MainMenuScreen)), same(menuState));
      expect(find.text('400'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nested campaign return and Endless winnings refresh once',
      (tester) async {
    final repository = _CountingProgress();
    await repository.addCoins(400);
    await _mountMenu(
      tester,
      repository,
      onChange: (name) async {
        if (name == '/game') {
          await repository.addCoins(75);
          await repository.unlockNextLevel(10);
          await repository.saveBestStarsForLevel(10, 2);
        } else if (name == '/endless') {
          await repository.addCoins(25);
        }
      },
    );

    await _tapMenu(tester, 'Adventure');
    await _tapKey(tester, 'open_map');
    await _tapKey(tester, 'open_campaign');
    await _tapKey(tester, 'change_state');
    await _tapKey(tester, 'return_to_menu'); // Game to Map.
    await _tapKey(tester, 'return_to_menu'); // Map to Worlds.
    expect(repository.coinReads, 1);
    await _tapKey(tester, 'return_to_menu'); // Worlds to Menu.
    expect(repository.coinReads, 2);
    expect(repository.statusReads, 2);
    expect(find.text('475'), findsOneWidget);
    expect(await repository.highestUnlockedLevel(), 11);
    expect(await repository.bestStarsForLevel(10), 2);

    await _tapMenu(tester, 'Endless Mode');
    await _tapKey(tester, 'change_state');
    await _tapKey(tester, 'return_to_menu');
    expect(repository.coinReads, 3);
    expect(repository.statusReads, 3);
    expect(find.text('500'), findsOneWidget);
  });

  testWidgets('reward availability and final unlock refresh once',
      (tester) async {
    final repository = _CountingProgress();
    // Read the same persisted save without inflating menu refresh counters.
    final savedProgress = ProgressRepository();
    final rewardDate = DateTime.now();
    const completionAchievements = [
      AchievementId.firstWin,
      AchievementId.gardenWorld,
      AchievementId.oceanWorld,
      AchievementId.candyWorld,
      AchievementId.spaceWorld,
      AchievementId.desertWorld,
      AchievementId.iceWorld,
      AchievementId.jungleWorld,
      AchievementId.volcanoWorld,
      AchievementId.dreamWorld,
      AchievementId.crystalWorld,
    ];
    final achievementCoins = ProgressRepository.achievementsCatalog
        .where((entry) => completionAchievements.contains(entry.id))
        .fold<int>(0, (total, entry) => total + entry.reward);
    expect(achievementCoins, 8500);
    final expectedCoins = 400 + 100 + achievementCoins;
    expect(await savedProgress.coins(), 0);
    await repository.addCoins(400);
    await _mountMenu(
      tester,
      repository,
      onChange: (name) async {
        if (name != '/lucky-wheel') return;
        await repository.markDailySpinClaimed(rewardDate);
        expect(await savedProgress.coins(), 400);
        expect(await repository.claimDailyReward(rewardDate), 500);
        expect(await savedProgress.coins(), 500);
        await repository.recordLevelCompleted(100, 3);
        expect(await savedProgress.coins(), expectedCoins);
        final popups = await savedProgress.consumePendingAchievementPopups();
        expect(popups.map((popup) => popup.definition.id),
            unorderedEquals(completionAchievements));
        expect(await savedProgress.coins(), expectedCoins,
            reason: 'Consuming notification IDs must not grant coins.');
      },
    );
    expect(find.text('Claim Daily Reward'), findsOneWidget);
    expect(find.text('Daily Spin'), findsOneWidget);
    expect(find.text('Final Reward'), findsNothing);

    await _tapMenu(tester, 'Daily Spin');
    await _tapKey(tester, 'change_state');
    await _tapKey(tester, 'return_to_menu');
    await _waitForMenuSnapshot(tester, repository, 2);
    expect(await savedProgress.coins(), expectedCoins);
    expect(find.text('$expectedCoins'), findsOneWidget);
    expect(find.text('Claim Daily Reward'), findsNothing);
    expect(find.text('Next Spin Tomorrow'), findsOneWidget);
    expect(find.text('Final Reward'), findsOneWidget);
    expect(await repository.finalRewardUnlocked(), isTrue);

    // Replaying completion and retrying a same-day claim must not award the
    // same achievement/daily coins again, including after another route return.
    await _tapMenu(tester, 'Achievements');
    expect(await repository.claimDailyReward(rewardDate), isNull);
    await repository.recordLevelCompleted(100, 3);
    expect(await savedProgress.coins(), expectedCoins);
    expect(await savedProgress.consumePendingAchievementPopups(), isEmpty);
    await _tapKey(tester, 'return_to_menu');
    await _waitForMenuSnapshot(tester, repository, 3);
    expect(find.text('$expectedCoins'), findsOneWidget);

    await _tapMenu(tester, 'Achievements');
    await _tapKey(tester, 'return_to_menu');
    await _waitForMenuSnapshot(tester, repository, 4);
    expect(await savedProgress.coins(), expectedCoins);
    expect(find.text('$expectedCoins'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('real settings and cosmetic choices survive route returns',
      (tester) async {
    final repository = _CountingProgress();
    final savedProgress = ProgressRepository();
    expect(await savedProgress.coins(), 0);
    // First Win (100) + Garden World (300) already supply the 400-coin
    // fixture. Adding another 400 before completion incorrectly seeded 800.
    await repository.recordLevelCompleted(10, 3);
    expect(await savedProgress.coins(), 400);
    await repository.clearPendingPopups();
    expect(await savedProgress.coins(), 400);
    await _mountMenu(tester, repository, realSettings: true, realProfile: true);

    await _tapMenu(tester, 'Settings');
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(await repository.musicEnabled(), isFalse);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    await _waitForMenuSnapshot(tester, repository, 2);
    await _tapMenu(tester, 'Settings');
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    await _waitForMenuSnapshot(tester, repository, 3);

    await _tapMenu(tester, 'Profile');
    await tester.tap(find.text('Cosmetics'));
    await tester.pumpAndSettle();
    final gardenCard = find
        .ancestor(
          of: find.text('Garden Frame'),
          matching: find.byType(GameCard),
        )
        .first;
    final select = find.descendant(
      of: gardenCard,
      matching: find.widgetWithText(GameButton, 'Select'),
    );
    await tester.tap(select);
    await tester.pumpAndSettle();
    expect((await repository.playerCosmetics()).selectedFrame,
        ProgressRepository.avatarFrameGarden);
    final active = find.descendant(
      of: gardenCard,
      matching: find.widgetWithText(GameButton, 'Active'),
    );
    for (var i = 0; i < 100 && active.evaluate().isEmpty; i++) {
      await tester.pump();
    }
    expect(active, findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    await _waitForMenuSnapshot(tester, repository, 4);

    await _tapMenu(tester, 'Profile');
    await tester.tap(find.text('Cosmetics'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Garden Frame'),
              matching: find.byType(GameCard),
            )
            .first,
        matching: find.widgetWithText(GameButton, 'Active'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byType(MainMenuScreen), findsOneWidget);
    await _waitForMenuSnapshot(tester, repository, 5);
    expect(await repository.coins(), 400);
    expect(
      find.descendant(
        of: find.byType(MainMenuScreen),
        matching: find.text('400'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('short menu keeps wider test-font rows reachable',
      (tester) async {
    // Deliberately retain this suite's Ahem font: its wider words force more
    // rows than Roboto, exercising the height fallback rather than hiding it.
    await _mountMenu(tester, _CountingProgress(), size: const Size(320, 568));
    expect(tester.takeException(), isNull,
        reason: 'The menu itself must lay out before any Profile navigation');
    final scroll = find.byKey(const ValueKey('main_menu_scroll'));
    final position = tester
        .state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)))
        .position;
    expect(position.maxScrollExtent, greaterThan(0),
        reason: 'Extra action rows must use reachable scrollable content');
    for (final label in [
      'Adventure',
      'Endless Mode',
      'Claim Daily Reward',
      'Daily Spin',
      'Booster Shop',
      'Profile',
      'Chests',
      'Daily Challenges',
      'Collection Book',
      'Achievements',
      'Statistics',
      'Settings',
      if (AppFlavorConfig.qaToolsEnabled) 'DEV QA Tools',
    ]) {
      final action = find.byKey(ValueKey('menu_action_$label'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget);
      final bounds = tester.getRect(action);
      final viewport = tester.getRect(scroll);
      expect(bounds.top, greaterThanOrEqualTo(viewport.top));
      expect(bounds.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(tester.takeException(), isNull, reason: 'Reaching $label');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('profile stat cards fit $size at text scale $scale',
          (tester) async {
        final repository = _CountingProgress();
        await repository.recordLevelCompleted(10, 3);
        await repository.clearPendingPopups();
        await _mountMenu(
          tester,
          repository,
          realProfile: true,
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull,
            reason: 'Menu mounting must not overflow before opening Profile');
        await _tapMenu(tester, 'Profile');
        expect(find.text('Player Profile'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _showProfileContent(tester, find.text('Endless Boards'));
        expect(find.text('Endless Boards'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _showProfileContent(tester, find.text('Cosmetics'),
            scrollBack: true);
        await tester.tap(find.text('Cosmetics'));
        await tester.pumpAndSettle();
        final gardenCard = find
            .ancestor(
              of: find.text('Garden Frame'),
              matching: find.byType(GameCard),
            )
            .first;
        await _showProfileContent(tester, find.text('Garden Frame'));
        final select = find.descendant(
          of: gardenCard,
          matching: find.widgetWithText(GameButton, 'Select'),
        );
        await _showProfileContent(tester, select);
        await tester.tap(select);
        final active = find.descendant(
          of: gardenCard,
          matching: find.widgetWithText(GameButton, 'Active'),
        );
        for (var i = 0; i < 100 && active.evaluate().isEmpty; i++) {
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(active, findsOneWidget);
        await _showProfileContent(tester, active);
        expect((await repository.playerCosmetics()).selectedFrame,
            ProgressRepository.avatarFrameGarden);
        await _showProfileContent(tester, find.text('Badges'));
        expect(tester.takeException(), isNull);

        // Back remains available even at the bottom of the cosmetics list.
        final back = find.byIcon(Icons.arrow_back_rounded).hitTestable();
        expect(back, findsOneWidget);
        await tester.tap(back);
        await tester.pumpAndSettle();
        await _waitForMenuSnapshot(tester, repository, 2);
        expect(await ProgressRepository().coins(), 400);
        expect(find.text('400'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('rapid returns keep the newest balance and discard stale reads',
      (tester) async {
    final repository = _CountingProgress();
    await repository.addCoins(400);
    await _mountMenu(tester, repository);
    final staleRead = Completer<int>();
    repository.nextCoinRead = staleRead;

    await _tapMenu(tester, 'Achievements');
    await _tapKey(tester, 'return_to_menu');
    expect(repository.coinReads, 2);
    await _tapMenu(tester, 'Booster Shop');
    await repository.addCoins(50);
    await _tapKey(tester, 'return_to_menu');
    expect(repository.coinReads, 3);
    expect(find.text('450'), findsOneWidget);

    staleRead.complete(400);
    await tester.pumpAndSettle();
    expect(find.text('450'), findsOneWidget);
    expect(repository.statusReads, 2);
    expect(repository.popupReads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'route observer unsubscribes and pending refresh ignores disposal',
      (tester) async {
    final repository = _CountingProgress();
    await repository.addCoins(400);
    await _mountMenu(tester, repository);
    final route = ModalRoute.of(tester.element(find.byType(MainMenuScreen)))!
        as PageRoute<dynamic>;
    expect(appRouteObserver.debugObservingRoute(route), isTrue);
    final pendingRead = Completer<int>();
    repository.nextCoinRead = pendingRead;

    await _tapMenu(tester, 'Achievements');
    await _tapKey(tester, 'return_to_menu');
    expect(repository.coinReads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(appRouteObserver.debugObservingRoute(route), isFalse);
    pendingRead.complete(999);
    await tester.pump();
    expect(repository.statusReads, 1);
    expect(repository.popupReads, 1);
    expect(tester.takeException(), isNull);
  });
}
