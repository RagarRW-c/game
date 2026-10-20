import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/models/adventure_progress.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/map_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/world_selection_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/adventure_level_node.dart';
import 'package:triple_tile_adventure/presentation/widgets/adventure_map_path.dart';
import 'package:triple_tile_adventure/presentation/widgets/adventure_world_destination_card.dart';
import 'package:triple_tile_adventure/presentation/widgets/adventure_world_scenery.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_decoration.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_ui.dart';

import 'support/geometry.dart';

// These screens do not play audio. Avoid constructing platform audio players.
class _UnusedAudio implements GameAudioService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Real campaign documents, read synchronously to keep fixture I/O independent
// of widget-test fake time. Production still uses the existing asset repository.
class _CampaignFixtures extends LevelRepository {
  final requested = <int>[];

  @override
  Future<LevelDefinition> loadLevel(int level) async {
    requested.add(level);
    return LevelDefinition.fromJson(jsonDecode(
      File('assets/levels/level_${level.toString().padLeft(2, '0')}.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>);
  }
}

class _Harness {
  _Harness({ProgressRepository? repository})
      : repository = repository ?? ProgressRepository();

  final ProgressRepository repository;
  final levels = _CampaignFixtures();
  final navigator = GlobalKey<NavigatorState>();
  final launches = <RouteSettings>[];
}

class _DeferredProgress extends ProgressRepository {
  Completer<int>? pendingHighest;

  @override
  Future<int> highestUnlockedLevel() =>
      pendingHighest?.future ?? super.highestUnlockedLevel();
}

Future<_Harness> _mount(
  WidgetTester tester, {
  Widget? home,
  QaScreen screen = const QaScreen('small', Size(320, 568), 24),
  double scale = 1,
  bool reducedMotion = false,
  ProgressRepository? repository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = screen.size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final harness = _Harness(repository: repository);
  await tester.pumpWidget(AppScope(
    progressRepository: harness.repository,
    levelRepository: harness.levels,
    audioService: _UnusedAudio(),
    child: MaterialApp(
      navigatorKey: harness.navigator,
      theme: GameTheme.theme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(top: screen.safeTop, bottom: 24),
          viewPadding: EdgeInsets.only(top: screen.safeTop, bottom: 24),
          textScaler: TextScaler.linear(scale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: home ?? MapScreen(world: gameWorlds.first),
      onGenerateRoute: (settings) {
        harness.launches.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => settings.name == MapScreen.route
              ? MapScreen(world: settings.arguments! as GameWorld)
              : Scaffold(
                  body: Center(
                    child: TextButton(
                      key: const ValueKey('return_from_game'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Return from level ${settings.arguments}'),
                    ),
                  ),
                ),
        );
      },
    ),
  ));
  await tester.pumpAndSettle();
  return harness;
}

Finder _node(int level) => find.byKey(ValueKey('level_$level'));

ScrollController _mapController(WidgetTester tester) =>
    tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;

Map<String, Object?> _saved(SharedPreferences prefs) =>
    {for (final key in prefs.getKeys()) key: prefs.get(key)};

void _assertTextFits(WidgetTester tester, Finder scope) {
  for (final element in find
      .descendant(of: scope, matching: find.byType(RichText))
      .evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse);
    final measure = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      textAlign: paragraph.textAlign,
      textHeightBehavior: paragraph.textHeightBehavior,
      textWidthBasis: paragraph.textWidthBasis,
      strutStyle: paragraph.strutStyle,
      locale: paragraph.locale,
    )..layout(maxWidth: paragraph.size.width);
    try {
      for (final line in measure.computeLineMetrics()) {
        expect(line.width, lessThanOrEqualTo(paragraph.size.width + .5),
            reason: 'Text must fit without horizontal clipping');
      }
      expect(measure.height, lessThanOrEqualTo(paragraph.size.height + .5),
          reason: 'All wrapped lines must have room');
    } finally {
      measure.dispose();
    }
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

Future<void> _tapTwiceAtTarget(WidgetTester tester, Finder finder) async {
  expect(finder.hitTestable(), findsOneWidget);
  final position = tester.getCenter(finder, warnIfMissed: true);
  // A user repeats a screen position. After the first tap changes routes,
  // looking up the old widget again incorrectly targets an obscured widget.
  // Send both real pointer sequences; the new route must handle the second.
  await tester.tapAt(position);
  await tester.tapAt(position);
}

void main() {
  setUp(() {
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
    SharedPreferences.setMockInitialValues({
      'highest_unlocked_level': 6,
      'level_stars_1': 2,
      'level_stars_2': 3,
      'level_stars_5': 1,
      'coins': 987,
    });
  });

  test('world boundaries cover every campaign ID and the ten boss milestones',
      () async {
    final levels = _CampaignFixtures();
    final ids = <int>[];
    expect(
        gameWorlds.map((w) => w.visualTheme.tileTheme).toSet(), hasLength(10));
    for (var i = 0; i < 10; i++) {
      final world = gameWorlds[i];
      expect(world.startLevel, i * 10 + 1);
      expect(world.endLevel, (i + 1) * 10);
      expect(world.unlockAfterLevel, i * 10);
      for (var id = world.startLevel; id <= world.endLevel; id++) {
        expect((await levels.loadLevel(id)).level, id);
        ids.add(id);
      }
    }
    expect(ids, List.generate(100, (i) => i + 1));
    expect(gameWorlds.map((w) => w.endLevel),
        [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]);
  });

  testWidgets('saved progress drives states, exact stars and locked taps',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final harness = await _mount(tester);
      final prefs = await SharedPreferences.getInstance();
      final before = _saved(prefs);
      final first = tester.widget<AdventureLevelNode>(_node(1));
      final current = tester.widget<AdventureLevelNode>(_node(6));
      final locked = tester.widget<AdventureLevelNode>(_node(7));
      expect(first.completed, isTrue);
      expect(first.stars, 2);
      expect(current.current, isTrue);
      expect(current.completed, isFalse);
      expect(current.stars, 0);
      expect(locked.unlocked, isFalse);
      expect(locked.current, isFalse);
      expect(
          tester
              .widget<Icon>(find.byKey(const ValueKey('level_1_star_1')))
              .icon,
          Icons.star_rounded);
      expect(
          tester
              .widget<Icon>(find.byKey(const ValueKey('level_1_star_3')))
              .icon,
          Icons.star_border_rounded);
      expect(
          tester.getSemantics(_node(6)),
          matchesSemantics(
            label: 'Level 6, Play now, 0 of 3 stars',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ));
      await _reveal(tester, _node(7));
      expect(
          tester.getSemantics(_node(7)),
          matchesSemantics(
            label: 'Level 7, Locked, 0 of 3 stars',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ));
      await tester.tap(_node(7));
      await tester.pumpAndSettle();
      expect(harness.levels.requested, isEmpty);
      expect(harness.launches, isEmpty);
      expect(find.byKey(const ValueKey('level_preview')), findsNothing);
      expect(_saved(prefs), before);
    } finally {
      // Dispose before Flutter's end-of-test semantics handle verification.
      semantics.dispose();
    }
  });

  for (final world in gameWorlds) {
    testWidgets(
        '${world.name}: all ten nodes launch their existing campaign IDs',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'highest_unlocked_level': 100,
        'level_stars_100': 3,
        'coins': 321,
      });
      final harness = await _mount(tester, home: MapScreen(world: world));
      final prefs = await SharedPreferences.getInstance();
      final before = _saved(prefs);
      final nodes = tester
          .widgetList<AdventureLevelNode>(find.byType(AdventureLevelNode))
          .toList();
      expect(nodes.map((node) => node.level),
          List.generate(10, (i) => world.startLevel + i));
      expect(nodes.where((node) => node.boss).single.level, world.endLevel);
      expect(nodes.every((node) => node.unlocked && node.completed), isTrue);
      expect(nodes.any((node) => node.current), isFalse);
      for (var id = world.startLevel; id <= world.endLevel; id++) {
        await _reveal(tester, _node(id));
        expect(_node(id).hitTestable(), findsOneWidget);
        await tester.tap(_node(id));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('level_preview')), findsOneWidget);
        expect(find.text('Level $id'), findsOneWidget);
        final start = find.byKey(const ValueKey('preview_start'));
        await _reveal(tester, start);
        expect(start.hitTestable(), findsOneWidget);
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(harness.launches.last.name, GameScreen.route);
        expect(harness.launches.last.arguments, id);
        await tester.tap(find.byKey(const ValueKey('return_from_game')));
        await tester.pumpAndSettle();
      }
      expect(harness.launches, hasLength(10));
      expect(harness.levels.requested,
          List.generate(10, (i) => world.startLevel + i));
      expect(_saved(prefs), before,
          reason: 'Browsing and replay navigation are read-only');
      expect(tester.takeException(), isNull);
    });
  }

  for (final screen in [
    ...qaScreens,
    const QaScreen('landscape', Size(800, 360), 24),
  ]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('${screen.name} / $scale: map, finale and preview fit',
          (tester) async {
        SharedPreferences.setMockInitialValues({'highest_unlocked_level': 100});
        await _mount(tester,
            home: MapScreen(world: gameWorlds.last),
            screen: screen,
            scale: scale);
        final scroll = find.byType(CustomScrollView);
        final viewport = tester.getRect(scroll);
        expect(_node(100).hitTestable(), findsOneWidget,
            reason: 'Opening the map must locate the latest level');
        final path = tester.getRect(find.byType(AdventureMapPath));
        Rect? previous;
        for (var id = 91; id <= 100; id++) {
          final bounds = tester.getRect(_node(id));
          expect(bounds.left, greaterThanOrEqualTo(path.left));
          expect(bounds.right, lessThanOrEqualTo(path.right));
          expect(bounds.top, greaterThanOrEqualTo(path.top));
          expect(bounds.bottom, lessThanOrEqualTo(path.bottom));
          expect(bounds.size.width, greaterThanOrEqualTo(48));
          expect(bounds.size.height, greaterThanOrEqualTo(48));
          if (previous != null) expect(previous.overlaps(bounds), isFalse);
          previous = bounds;
          _assertTextFits(tester, _node(id));
        }
        final controller = _mapController(tester);
        controller.jumpTo(0);
        await tester.pumpAndSettle();
        _assertTextFits(tester, find.byType(MapScreen));
        await tester.tap(find.byKey(const ValueKey('find_current_level')));
        await tester.pumpAndSettle();
        expect(_node(100).hitTestable(), findsOneWidget);
        // A tall node may need to scroll in a short landscape viewport.
        await _reveal(tester, _node(100));
        expect(viewport.overlaps(tester.getRect(_node(100))), isTrue);
        await tester.tap(_node(100));
        await tester.pumpAndSettle();
        final preview = find.byKey(const ValueKey('level_preview'));
        _assertTextFits(tester, preview);
        final back = find.byKey(const ValueKey('preview_back'));
        await _reveal(tester, back);
        expect(back.hitTestable(), findsOneWidget);
        final backBounds = tester.getRect(back);
        expect(backBounds.bottom, lessThanOrEqualTo(screen.size.height - 24));
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(preview, findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          '${screen.name} / $scale: all illustrated destinations are readable',
          (tester) async {
        SharedPreferences.setMockInitialValues({'highest_unlocked_level': 46});
        await _mount(tester,
            home: const WorldSelectionScreen(), screen: screen, scale: scale);
        final scrollable = find.byType(Scrollable);
        for (final world in gameWorlds) {
          final card = find.byKey(ValueKey('world_${world.startLevel}'));
          await tester.scrollUntilVisible(card, 180, scrollable: scrollable);
          await tester.pumpAndSettle();
          final destination =
              tester.widget<AdventureWorldDestinationCard>(card);
          expect(destination.world, same(world));
          expect(destination.unlocked, world.startLevel <= 46);
          expect(destination.current, world.startLevel == 41);
          expect(
              destination.completed,
              world.endLevel < 46
                  ? 10
                  : world.startLevel == 41
                      ? 5
                      : 0);
          _assertTextFits(tester, card);
          final bounds = tester.getRect(card);
          expect(bounds.left, greaterThanOrEqualTo(16));
          expect(bounds.right, lessThanOrEqualTo(screen.size.width - 16));
          final scenery = find.descendant(
              of: card, matching: find.byType(AdventureWorldScenery));
          expect(scenery, findsOneWidget);
          expect(tester.widget<AdventureWorldScenery>(scenery).theme,
              same(world.visualTheme));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets(
      'current locator and ordinary rebuilds preserve browsing position',
      (tester) async {
    await _mount(tester);
    expect(_node(6).hitTestable(), findsOneWidget);
    final controller = _mapController(tester);
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    tester.element(find.byType(MapScreen)).markNeedsBuild();
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    await tester.tap(find.byKey(const ValueKey('find_current_level')));
    await tester.pumpAndSettle();
    expect(_node(6).hitTestable(), findsOneWidget);
    final offset = controller.offset;
    await tester.tap(_node(6));
    await tester.pumpAndSettle();
    await _reveal(tester, find.byKey(const ValueKey('preview_back')));
    await tester.tap(find.byKey(const ValueKey('preview_back')));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(offset, .01));
  });

  testWidgets('double taps open one preview and one game route',
      (tester) async {
    final harness = await _mount(tester);
    await _tapTwiceAtTarget(tester, _node(6));
    await tester.pumpAndSettle();
    expect(harness.levels.requested, [6]);
    expect(find.byKey(const ValueKey('level_preview')), findsOneWidget);
    final start = find.byKey(const ValueKey('preview_start'));
    await _reveal(tester, start);
    await _tapTwiceAtTarget(tester, start);
    await tester.pumpAndSettle();
    expect(harness.launches.map((route) => route.name), [GameScreen.route]);
    harness.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
  });

  testWidgets('world locks, entry, return and world scroll restoration',
      (tester) async {
    final harness = await _mount(tester, home: const WorldSelectionScreen());
    final ocean = find.byKey(const ValueKey('world_11'));
    await tester.scrollUntilVisible(ocean, 180);
    await tester.pumpAndSettle();
    expect(ocean.hitTestable(), findsOneWidget);
    await tester.tap(ocean);
    await tester.pumpAndSettle();
    expect(harness.launches, isEmpty);
    final garden = find.byKey(const ValueKey('world_1'));
    await tester.scrollUntilVisible(garden, -180);
    await tester.pumpAndSettle();
    final controller =
        tester.widget<ListView>(find.byType(ListView)).controller!;
    final offset = controller.offset;
    await _tapTwiceAtTarget(tester, garden);
    await tester.pumpAndSettle();
    expect(harness.launches, hasLength(1));
    expect(harness.launches.single.name, MapScreen.route);
    expect(harness.launches.single.arguments, same(gameWorlds.first));
    await tester.tap(find.byKey(const ValueKey('map_back')));
    await tester.pumpAndSettle();
    expect(find.byType(WorldSelectionScreen), findsOneWidget);
    expect(controller.offset, closeTo(offset, .01));
  });

  testWidgets(
      'duplicate callbacks cannot reenter world, preview or Start navigation',
      (tester) async {
    final harness = await _mount(tester, home: const WorldSelectionScreen());
    final garden = find.byKey(const ValueKey('world_1'));
    final enterWorld =
        tester.widget<AdventureWorldDestinationCard>(garden).onTap!;
    expect(garden.hitTestable(), findsOneWidget);
    await tester.tap(garden);
    enterWorld();
    await tester.pumpAndSettle();
    expect(harness.launches.map((route) => route.name), [MapScreen.route]);

    final enterLevel = tester.widget<AdventureLevelNode>(_node(6)).onTap!;
    expect(_node(6).hitTestable(), findsOneWidget);
    await tester.tap(_node(6));
    enterLevel();
    await tester.pumpAndSettle();
    expect(harness.levels.requested, [6]);
    expect(find.byKey(const ValueKey('level_preview')), findsOneWidget);

    final start = find.byKey(const ValueKey('preview_start'));
    await _reveal(tester, start);
    final startLevel = tester.widget<GameButton>(start).onPressed!;
    expect(start.hitTestable(), findsOneWidget);
    await tester.tap(start);
    startLevel();
    await tester.pumpAndSettle();
    expect(harness.launches.map((route) => route.name),
        [MapScreen.route, GameScreen.route]);
    expect(harness.launches.last.arguments, 6);
    await tester.tap(find.byKey(const ValueKey('return_from_game')));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an outstanding progress refresh is safe after map disposal',
      (tester) async {
    final repository = _DeferredProgress();
    await _mount(tester, repository: repository);
    await tester.tap(_node(6));
    await tester.pumpAndSettle();
    final start = find.byKey(const ValueKey('preview_start'));
    await _reveal(tester, start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    final pending = Completer<int>();
    repository.pendingHighest = pending;
    await tester.tap(find.byKey(const ValueKey('return_from_game')));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(6);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('level 100 refreshes saved stars after play without scroll reset',
      (tester) async {
    SharedPreferences.setMockInitialValues({'highest_unlocked_level': 100});
    final harness =
        await _mount(tester, home: MapScreen(world: gameWorlds.last));
    expect(tester.widget<AdventureLevelNode>(_node(100)).current, isTrue);
    final controller = _mapController(tester);
    final offset = controller.offset;
    await tester.tap(_node(100));
    await tester.pumpAndSettle();
    final start = find.byKey(const ValueKey('preview_start'));
    await _reveal(tester, start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    // Simulate the existing game's save through its real repository API.
    await harness.repository.saveBestStarsForLevel(100, 2);
    expect(await harness.repository.bestStarsForLevel(100), 2,
        reason: 'Separate persistence failures from a stale map snapshot');
    await tester.tap(find.byKey(const ValueKey('return_from_game')));
    await tester.pumpAndSettle();
    final finalNode = tester.widget<AdventureLevelNode>(_node(100));
    expect(finalNode.stars, 2);
    expect(finalNode.completed, isTrue);
    expect(finalNode.current, isFalse);
    expect(controller.offset, closeTo(offset, .01));
    final reloaded = await AdventureProgress.load(ProgressRepository());
    expect(reloaded.highestUnlockedLevel, 100);
    expect(reloaded.completedIn(91, 100), 10);
    expect(reloaded.starsByLevel[100], 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('world completion and unlock refresh from the real repository',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'highest_unlocked_level': 10,
      'coins': 765,
    });
    final harness = await _mount(tester, home: const WorldSelectionScreen());
    await tester.tap(find.byKey(const ValueKey('world_1')));
    await tester.pumpAndSettle();
    expect(_node(10).hitTestable(), findsOneWidget);
    await harness.repository.saveBestStarsForLevel(10, 1);
    await harness.repository.unlockNextLevel(10);
    final prefs = await SharedPreferences.getInstance();
    final afterGameSave = _saved(prefs);
    await tester.tap(find.byKey(const ValueKey('map_back')));
    await tester.pumpAndSettle();
    final garden = tester.widget<AdventureWorldDestinationCard>(
        find.byKey(const ValueKey('world_1')));
    expect(garden.completed, 10);
    expect(garden.current, isFalse);
    final ocean = find.byKey(const ValueKey('world_11'));
    await tester.scrollUntilVisible(ocean, 180);
    await tester.pumpAndSettle();
    final destination = tester.widget<AdventureWorldDestinationCard>(ocean);
    expect(destination.unlocked, isTrue);
    expect(destination.current, isTrue);
    await tester.tap(ocean);
    await tester.pumpAndSettle();
    expect(_node(11).hitTestable(), findsOneWidget);
    expect(tester.widget<AdventureLevelNode>(_node(11)).current, isTrue);
    expect(_saved(prefs), afterGameSave,
        reason: 'Refreshing navigation must not write progression or rewards');
  });

  testWidgets('completed Crystal destination shows 10/10 and saved stars',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'highest_unlocked_level': 100,
      'level_stars_100': 2,
    });
    await _mount(tester,
        home: const WorldSelectionScreen(), reducedMotion: true);
    final crystal = find.byKey(const ValueKey('world_91'));
    await tester.scrollUntilVisible(crystal, 220);
    await tester.pumpAndSettle();
    expect(tester.widget<AdventureWorldDestinationCard>(crystal).completed, 10);
    final entrance = find.descendant(
        of: crystal, matching: find.byType(TweenAnimationBuilder<double>));
    expect(tester.widget<TweenAnimationBuilder<double>>(entrance).duration,
        Duration.zero);
    await tester.tap(crystal);
    await tester.pumpAndSettle();
    final finale = tester.widget<AdventureLevelNode>(_node(100));
    expect(finale.completed, isTrue);
    expect(finale.stars, 2);
    expect(finale.current, isFalse);
  });

  testWidgets('reduced motion disables entrance, pulse and locator animation',
      (tester) async {
    await _mount(tester, reducedMotion: true);
    final pulse = find.descendant(
        of: _node(6), matching: find.byType(TweenAnimationBuilder<double>));
    expect(tester.widget<TweenAnimationBuilder<double>>(pulse).duration,
        Duration.zero);
    _mapController(tester).jumpTo(0);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('find_current_level')));
    await tester.pump();
    expect(_node(6).hitTestable(), findsOneWidget);
    final scenery = find.byKey(const ValueKey('map_scenery'));
    expect(
        tester
            .widget<IgnorePointer>(find.descendant(
                of: scenery, matching: find.byType(IgnorePointer)))
            .ignoring,
        isTrue);
    await tester.tap(_node(6));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('level_preview')), findsOneWidget,
        reason: 'Scenery must never intercept level taps');
    final entrance = find.descendant(
        of: find.byType(GameEntrance),
        matching: find.byType(TweenAnimationBuilder<double>));
    final animations =
        tester.widgetList<TweenAnimationBuilder<double>>(entrance).toList();
    expect(animations, isNotEmpty);
    for (final animation in animations) {
      expect(animation.duration, Duration.zero);
    }
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
