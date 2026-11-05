import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/campaign_feedback_audio.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/level96_playtest/session.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/campaign_entrance.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_effects.dart';

import '../goldens/support/golden_fixtures.dart';
import 'support/geometry.dart';

class FeelAudio extends GoldenAudio {
  final events = <CampaignFeedbackEvent>[];
  final legacy = <String>[];
  @override
  Future<void> playCampaignFeedback(CampaignFeedbackEvent event) async =>
      events.add(event);
  @override
  Future<void> playTap() async => legacy.add('tap');
  @override
  Future<void> playMatch() async => legacy.add('match');
}

class FeelProgress extends ProgressRepository {
  @override
  Future<List<PendingAchievementPopup>>
      consumePendingAchievementPopups() async {
    await super.consumePendingAchievementPopups();
    return [];
  }
}

class FeelLevels extends LevelRepository {
  @override
  Future<LevelDefinition> loadLevel(int level) async => LevelDefinition(
          level: level,
          name: 'Phase 5A regression fixture',
          timeBonusSeconds: 0,
          tiles: [
            for (var i = 0; i < 9; i++)
              Tile(
                  id: 'f$i',
                  type: ['apple', 'banana', 'berry'][i ~/ 3],
                  x: (i % 3) * .3,
                  y: (i ~/ 3) * .3,
                  layer: 0),
          ]);
}

Finder boardTile([String? id]) => find.byWidgetPredicate((w) =>
    w is GameTileWidget && !w.trayTile && (id == null || w.tile.id == id));
GameTray tray(WidgetTester tester) =>
    tester.widget<GameTray>(find.byType(GameTray));
TileEffectsController effects(WidgetTester tester) =>
    tester.widget<GameTileEffects>(find.byType(GameTileEffects)).controller;
CampaignEntranceController entrance(WidgetTester tester) => tester
    .widget<CampaignEntranceGate>(find.byType(CampaignEntranceGate))
    .controller;

Future<FeelAudio> mountFeel(WidgetTester tester,
    {bool enabled = true,
    bool original = false,
    bool reduced = false,
    bool muted = false,
    QaScreen screen = const QaScreen('medium', Size(360, 800), 24),
    GameScreenSessionHooks? hooks}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = screen.size;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final progress = FeelProgress();
  await progress.setVibrationEnabled(false);
  final audio = FeelAudio()..sfxEnabled = !muted;
  await tester.pumpWidget(AppScope(
      progressRepository: progress,
      levelRepository: original ? GoldenLevels() : FeelLevels(),
      audioService: audio,
      child: MaterialApp(
          theme: GameTheme.theme(),
          navigatorObservers: [appRouteObserver],
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  disableAnimations: reduced,
                  padding: EdgeInsets.only(top: screen.safeTop, bottom: 24)),
              child: child!),
          home: GameScreen(
              level: 96, gameFeelV2: enabled, sessionHooks: hooks))));
  for (var i = 0; i < 20 && find.byType(GameTray).evaluate().isEmpty; i++) {
    await tester.pump();
  }
  expect(find.byType(GameTray), findsOneWidget);
  return audio;
}

Future<void> pointer(WidgetTester tester, String id) async {
  expect(boardTile(id), findsOneWidget);
  await tester.tap(boardTile(id));
  await tester.pump();
}

void main() {
  testWidgets(
      'wave order is deterministic, spatial and independent of input order',
      (tester) async {
    final controller = CampaignEntranceController(vsync: tester);
    try {
      final level = await GoldenLevels().loadLevel(96);
      controller.prepare(level.tiles, reducedMotion: false);
      final expected = controller.waves;
      controller.finish();
      controller.prepare(level.tiles.reversed, reducedMotion: false);
      expect(controller.waves, expected);
      final ordered = [...level.tiles]..sort((a, b) {
          var c = a.layer.compareTo(b.layer);
          if (c == 0) c = a.y.compareTo(b.y);
          if (c == 0) c = a.x.compareTo(b.x);
          return c == 0 ? a.id.compareTo(b.id) : c;
        });
      final waves = ordered.map((tile) => expected[tile.id]!).toList();
      expect(waves, orderedEquals([...waves]..sort()));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(); // First ticker frame establishes its zero timestamp.
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.progressFor(ordered.first.id), greaterThan(0));
      expect(controller.progressFor(ordered.last.id), 0);
      await tester.pump(const Duration(milliseconds: 780));
      expect(controller.running, false);
      expect(
          ordered.every((tile) => controller.progressFor(tile.id) == 1), true);
    } finally {
      controller.dispose();
    }
  });

  testWidgets('real Restart Level starts one fresh entrance and empty tray',
      (tester) async {
    final audio = await mountFeel(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    await pointer(tester, 'f0');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart Level'));
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    expect(boardTile(), findsNWidgets(9));
    expect(tray(tester).trayTiles.whereType<Tile>(), isEmpty);
    expect(audio.events.where((e) => e == CampaignFeedbackEvent.entrance),
        hasLength(2));
    expect(audio.events.where((e) => e == CampaignFeedbackEvent.landing),
        hasLength(6));
    expect(tester.takeException(), isNull);
  });

  for (final screen in qaScreens) {
    for (final enabled in [false, true]) {
      testWidgets(
          '${screen.name} flag=$enabled: exact 99-tile geometry and layers',
          (tester) async {
        final audio = await mountFeel(tester,
            enabled: enabled, original: true, screen: screen);
        final raw = File('assets/levels/level_96.json').readAsBytesSync();
        final level = LevelDefinition.fromJson(
            jsonDecode(utf8.decode(raw)) as Map<String, dynamic>);
        expect(boardTile(), findsNWidgets(99));
        final ids = tester
            .widgetList<GameTileWidget>(boardTile())
            .map((w) => w.tile.id)
            .toList();
        final sorted = [...level.tiles]..sort((a, b) {
            final layer = a.layer.compareTo(b.layer);
            return layer != 0
                ? layer
                : level.tiles.indexOf(a).compareTo(level.tiles.indexOf(b));
          });
        expect(ids, sorted.map((t) => t.id));
        final before = <String, Rect>{};
        for (final tile in level.tiles) {
          final positioned =
              tester.widget<Positioned>(find.byKey(ValueKey(tile.id)));
          expect(positioned.left, tile.x * screen.geometry().board.width);
          expect(positioned.top, tile.y * screen.geometry().board.height);
          expect(positioned.width, screen.geometry().tile.width);
          before[tile.id] = tester.getRect(find.byKey(ValueKey(tile.id)));
        }
        if (enabled) {
          expect(entrance(tester).running, true);
          expect(entrance(tester).waves.values.toSet(), {0, 1, 2, 3, 4, 5});
          await tester.tapAt(tester.getCenter(boardTile('L96_T098')));
          await tester.pump();
          expect(boardTile(), findsNWidgets(99));
          expect(tray(tester).trayTiles.whereType<Tile>(), isEmpty);
        } else {
          expect(find.byType(CampaignEntranceGate), findsNothing);
        }
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
        for (final tile in level.tiles) {
          expect(
              tester.getRect(find.byKey(ValueKey(tile.id))), before[tile.id]);
          final w = tester.widget<GameTileWidget>(boardTile(tile.id));
          expect([w.tile.type, w.tile.layer, w.tile.x, w.tile.y],
              [tile.type, tile.layer, tile.x, tile.y]);
          if (w.blocked) expect(w.onTap, isNull);
        }
        expect(File('assets/levels/level_96.json').readAsBytesSync(), raw);
        expect(audio.events.where((e) => e == CampaignFeedbackEvent.landing),
            hasLength(enabled ? 3 : 0));
        final eventCount = audio.events.length;
        tester.element(find.byType(GameScreen)).markNeedsBuild();
        await tester.pumpAndSettle();
        expect(audio.events.length, eventCount,
            reason: 'Unrelated rebuild must not replay entrance');
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('${screen.name}: rapid UI taps resolve triples without ghosts',
        (tester) async {
      final audio = await mountFeel(tester, screen: screen);
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      audio.events.clear();
      for (var i = 0; i < 6; i++) {
        await pointer(tester, 'f$i');
      }
      expect(boardTile(), findsNWidgets(3));
      expect(tray(tester).trayTiles.whereType<Tile>(), isEmpty);
      expect(effects(tester).flights.length, lessThanOrEqualTo(7));
      expect(effects(tester).bursts.length, 2);
      expect(effects(tester).bursts.every((b) => b.premium), true);
      expect(audio.events, List.filled(6, CampaignFeedbackEvent.selection));
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(audio.events.where((e) => e == CampaignFeedbackEvent.match),
          hasLength(2));
      expect(audio.events.where((e) => e == CampaignFeedbackEvent.collection),
          isEmpty,
          reason: 'Canceled flights and matched incoming tiles must not chime');
      expect(effects(tester).flights, isEmpty);
      expect(effects(tester).bursts, isEmpty);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'selection is immediate; collection sounds once on visual arrival',
      (tester) async {
    final audio = await mountFeel(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    audio.events.clear();
    await pointer(tester, 'f0');
    expect(boardTile(), findsNWidgets(8));
    expect(tray(tester).trayTiles.whereType<Tile>().single.id, 'f0');
    final flight = effects(tester).flights.single;
    expect(flight.animationDuration.inMilliseconds, 360);
    expect(flight.rectAt(0), flight.source.rect);
    expect(flight.rectAt(1), flight.target);
    expect(audio.events, [CampaignFeedbackEvent.selection]);
    await tester.pump(const Duration(milliseconds: 287));
    expect(audio.events, [CampaignFeedbackEvent.selection]);
    await tester.pump(const Duration(milliseconds: 2));
    expect(audio.events,
        [CampaignFeedbackEvent.selection, CampaignFeedbackEvent.collection]);
    await tester.pumpAndSettle();
    expect(audio.events.length, 2);
    expect(effects(tester).flights, isEmpty);
  });

  for (final reduced in [false, true]) {
    testWidgets('muted reduced=$reduced: no sound, no stuck board',
        (tester) async {
      final audio = await mountFeel(tester, reduced: reduced, muted: true);
      if (reduced) expect(entrance(tester).running, false);
      await tester.pumpAndSettle();
      await pointer(tester, 'f0');
      await pointer(tester, 'f1');
      await pointer(tester, 'f2');
      await tester.pumpAndSettle();
      expect(boardTile(), findsNWidgets(6));
      expect(tray(tester).trayTiles.whereType<Tile>(), isEmpty);
      expect(audio.events, isEmpty);
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  for (final interruption in ['background', 'route', 'dispose']) {
    testWidgets('$interruption cancels entrance without replay or stale sounds',
        (tester) async {
      final audio = await mountFeel(tester);
      final controller = entrance(tester);
      await tester.pump(const Duration(milliseconds: 100));
      if (interruption == 'dispose') {
        await tester.pumpWidget(const SizedBox());
      } else if (interruption == 'background') {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
        expect(controller.running, false);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      } else {
        final nav = tester.state<NavigatorState>(find.byType(Navigator));
        nav.push(MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('test route'))));
        await tester.pumpAndSettle();
        expect(controller.running, false);
        nav.pop();
      }
      final count = audio.events.length;
      await tester.pumpAndSettle();
      expect(audio.events.length, count);
      if (interruption != 'dispose') {
        await pointer(tester, 'f0');
        expect(boardTile(), findsNWidgets(8));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Level 96 recorded session stays compatible with flag ON',
      (tester) async {
    final level = PlaytestLevels(File(level96Asset).readAsStringSync())
        .create(PlaytestVariant.original);
    final session =
        PlaytestSession(variant: PlaytestVariant.original, level: level);
    await mountFeel(tester,
        original: true,
        hooks: GameScreenSessionHooks(
            createEngine: (_) => session.engine,
            onResult: (_) async {},
            onPause: () {},
            title: 'Phase 5A compatibility'));
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    await pointer(tester, 'L96_T098');
    await tester.pumpAndSettle();
    expect(session.acceptedTaps, 1);
    expect(session.engine.tray, ['L96_T098']);
    expect(session.toJson()['analyst_only_accepted_trace'], hasLength(1));
    expect(session.toJson()['assisted'], false);
  });

  testWidgets('flag OFF preserves original selection sound and 440 ms flight',
      (tester) async {
    final audio = await mountFeel(tester, enabled: false);
    await tester.pumpAndSettle();
    await pointer(tester, 'f0');
    expect(
        effects(tester).flights.single.animationDuration, TileFlight.duration);
    expect(audio.events, isEmpty);
    expect(audio.legacy, ['tap']);
  });
}
