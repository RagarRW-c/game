import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/endless_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/win_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_over_dialog.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_effects.dart';

import 'support/geometry.dart';

class _Audio implements GameAudioService {
  final calls = <String>[];
  @override
  bool sfxEnabled = true;
  @override
  Future<void> playTap() async {
    calls.add('tap');
  }

  @override
  Future<void> playMatch() async {
    calls.add('match');
  }

  @override
  Future<void> playGameOver() async {
    calls.add('lost');
  }

  @override
  Future<void> playLevelComplete() async {
    calls.add('won');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Progress extends ProgressRepository {
  @override
  Future<List<PendingAchievementPopup>>
      consumePendingAchievementPopups() async {
    await super.consumePendingAchievementPopups();
    return [];
  }
}

class _Levels extends LevelRepository {
  _Levels(this.count, this.unique);
  final int count;
  final bool unique;
  @override
  Future<LevelDefinition> loadLevel(int level) async => LevelDefinition(
        level: level,
        name: 'Motion fixture',
        timeBonusSeconds: 60,
        tiles: List.generate(
            count,
            (i) => Tile(
                id: 'm$i',
                type: tileCatalog.keys.elementAt(unique ? i : i ~/ 3),
                x: (i % 3) * .3,
                y: (i ~/ 3) * .22,
                layer: 0)),
      );
}

Finder _board([String? id]) => find.byWidgetPredicate((w) =>
    w is GameTileWidget && !w.trayTile && (id == null || w.tile.id == id));
TileEffectsController _effects(WidgetTester tester) => tester
    .widget<GameTileEffects>(find.byType(GameTileEffects, skipOffstage: false))
    .controller;
GameTray _tray(WidgetTester tester) =>
    tester.widget<GameTray>(find.byType(GameTray, skipOffstage: false));
Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(
      box.getTransformTo(null), Offset.zero & box.size);
}

Finder _booster(String label) =>
    find.byWidgetPredicate((w) => w is GameBoosterButton && w.label == label);

Future<_Audio> _mount(WidgetTester tester,
    {int level = 1,
    bool endless = false,
    bool reduced = false,
    int count = 12,
    bool unique = false,
    QaScreen screen = const QaScreen('small', Size(320, 568), 24)}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = screen.size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final progress = _Progress();
  await progress.setLevelOneTutorialSeen();
  final audio = _Audio();
  await tester.pumpWidget(AppScope(
    levelRepository: _Levels(count, unique),
    progressRepository: progress,
    audioService: audio,
    child: MaterialApp(
        theme: GameTheme.theme(),
        navigatorObservers: [appRouteObserver],
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                padding: EdgeInsets.only(top: screen.safeTop, bottom: 24),
                viewPadding: EdgeInsets.only(top: screen.safeTop, bottom: 24),
                disableAnimations: reduced),
            child: child!),
        home: endless ? const EndlessScreen() : GameScreen(level: level)),
  ));
  await tester.pumpAndSettle();
  return audio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final haptics = <Object?>[];
  setUp(() {
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));

  for (final screen in qaScreens) {
    for (final level in [1, 2]) {
      testWidgets(
          '${screen.name}: level $level measured trajectory, identity and one visible copy',
          (tester) async {
        final audio = await _mount(tester, screen: screen, level: level);
        final board = _board('m3');
        final source = _rect(tester, board);
        final widget = tester.widget<GameTileWidget>(board);
        final effects = _effects(tester);
        final destination = _rect(tester, find.byKey(effects.slotKeys[0]));
        expect(
            level == 2
                ? destination.bottom < source.top
                : destination.top > source.bottom,
            isTrue);
        widget.onTap!();
        expect(effects.flights, hasLength(1));
        expect(audio.calls, ['tap']);
        await tester.pump();
        final flight = effects.flights.single;
        final layerOrigin = _rect(tester, find.byKey(effects.layerKey)).topLeft;
        expect(flight.source.rect.shift(layerOrigin), source);
        expect(flight.target.shift(layerOrigin), destination);
        expect(flight.slot, 0);
        expect(flight.source.tile.id, widget.tile.id);
        expect(flight.source.catalog[widget.tile.type]!.icon,
            widget.catalog[widget.tile.type]!.icon);
        expect(_board('m3'), findsNothing);
        final copy = find.byType(TileFlightVisual);
        expect(copy, findsOneWidget);
        expect(_rect(tester, copy), source);
        final canonical = find.descendant(
            of: find.byType(GameTray),
            matching: find.byWidgetPredicate(
                (w) => w is GameTileWidget && w.tile.id == 'm3'));
        expect(
            tester
                .widget<Opacity>(find
                    .ancestor(of: canonical, matching: find.byType(Opacity))
                    .first)
                .opacity,
            0);
        await tester.pump(const Duration(milliseconds: 120));
        final halfway = _rect(tester, copy);
        expect((halfway.center - destination.center).distance,
            lessThan((source.center - destination.center).distance));
        expect(halfway, isNot(source));
        expect(halfway, isNot(destination));
        await tester.pumpAndSettle();
        expect(effects.flights, isEmpty);
        expect(copy, findsNothing);
        expect(
            tester
                .widget<Opacity>(find
                    .ancestor(of: canonical, matching: find.byType(Opacity))
                    .first)
                .opacity,
            1);
        expect(_tray(tester).trayTiles.first!.id, 'm3');
        expect(haptics, hasLength(1));
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      });
    }
  }

  testWidgets(
      'rapid triple cancels obsolete flights, clears once and preserves slot order',
      (tester) async {
    final audio = await _mount(tester);
    final effects = _effects(tester);
    for (final id in ['m3', 'm0', 'm1', 'm2']) {
      final callback = tester.widget<GameTileWidget>(_board(id)).onTap!;
      callback();
      callback();
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(audio.calls, ['tap', 'tap', 'tap', 'match']);
    expect(haptics, hasLength(4));
    expect(effects.bursts, hasLength(1));
    expect(effects.bursts.single.rects, hasLength(3));
    expect(effects.flights, hasLength(1));
    expect(effects.flights.single.matched, isTrue);
    expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id), ['m3']);
    expect(effects.hides('m3'), isFalse);
    tester.widget<GameTileWidget>(_board('m6')).onTap!();
    await tester.pump();
    expect(effects.flights.single.slot, 1);
    expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id),
        ['m3', 'm6']);
    await tester.pumpAndSettle();
    expect(effects.flights, isEmpty);
    expect(effects.bursts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final action in ['Undo', 'Shuffle', 'Hint']) {
    testWidgets('$action during a flight preserves engine-owned tray state',
        (tester) async {
      await _mount(tester);
      tester.widget<GameTileWidget>(_board('m0')).onTap!();
      await tester.pump();
      final effects = _effects(tester);
      expect(effects.flights, hasLength(1));
      await tester.tap(_booster(action));
      await tester.pump();
      expect(effects.flights, isEmpty);
      if (action == 'Undo') {
        expect(_board('m0'), findsOneWidget);
        expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
      } else if (action == 'Hint') {
        expect(_board(), findsNWidgets(9));
        expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
        expect(effects.bursts, hasLength(1));
      } else {
        expect(_board(), findsNWidgets(11));
        expect(_tray(tester).trayTiles.first!.id, 'm0');
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('seventh unmatched tile opens Game Over before flights finish',
      (tester) async {
    final audio = await _mount(tester, unique: true);
    final effects = _effects(tester);
    for (var i = 0; i < 7; i++) {
      tester.widget<GameTileWidget>(_board('m$i')).onTap!();
    }
    expect(audio.calls.where((v) => v == 'lost'), hasLength(1));
    expect(effects.flights, hasLength(7));
    await tester.pump();
    expect(find.byType(GameOverDialog), findsOneWidget);
    expect(_tray(tester).trayTiles.whereType<Tile>(), hasLength(7));
    expect(find.byKey(const ValueKey('tray_near_full'), skipOffstage: false),
        findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'victory starts during the clearing effect, never after its callback',
      (tester) async {
    final audio = await _mount(tester, count: 3);
    for (var i = 0; i < 3; i++) {
      tester.widget<GameTileWidget>(_board('m$i')).onTap!();
    }
    await tester.pump(); // Flush persistence futures, not the 500 ms effect.
    expect(_effects(tester).bursts, hasLength(1));
    expect(audio.calls.where((v) => v == 'match'), hasLength(1));
    expect(audio.calls.where((v) => v == 'won'), hasLength(1));
    expect(find.byType(WinScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final endless in [false, true]) {
    testWidgets('endless=$endless: navigation away never resumes stale flights',
        (tester) async {
      await _mount(tester, endless: endless);
      final effects = _effects(tester);
      await tester.tap(_board().last);
      await tester.pump();
      expect(effects.flights, hasLength(1));
      final navigator =
          Navigator.of(tester.element(find.byType(GameTileEffects)));
      unawaited(navigator.push<void>(PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => const Scaffold(body: Text('Away')),
      )));
      await tester.pumpAndSettle();
      expect(effects.flights, isEmpty);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(TileFlightVisual), findsNothing);
      expect(_tray(tester).trayTiles.whereType<Tile>(), hasLength(1));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'endless=$endless: reduced motion instantly renders canonical tiles',
        (tester) async {
      await _mount(tester, endless: endless, reduced: true);
      final tile = tester.widget<GameTileWidget>(_board().last);
      tile.onTap!();
      await tester.pump();
      expect(_effects(tester).flights, isEmpty);
      expect(_effects(tester).bursts, isEmpty);
      expect(_tray(tester).trayTiles.first!.id, tile.tile.id);
      expect(find.byType(TileFlightVisual), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'endless=$endless: resize and dispose during flight restore presentation',
        (tester) async {
      await _mount(tester, endless: endless);
      tester.widget<GameTileWidget>(_board().last).onTap!();
      await tester.pump(const Duration(milliseconds: 60));
      final effects = _effects(tester);
      expect(effects.flights, hasLength(1));
      final id = _tray(tester).trayTiles.first!.id;
      tester.view.physicalSize = const Size(412, 915);
      await tester.pump();
      expect(effects.flights, isEmpty);
      expect(effects.hides(id), isFalse);
      expect(_tray(tester).trayTiles.first!.id, id);
      tester.widget<GameTileWidget>(_board().last).onTap!();
      await tester.pump();
      expect(effects.flights, isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(effects.flights, isEmpty);
      expect(effects.bursts, isEmpty);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final screen in qaScreens) {
    testWidgets(
        '${screen.name}: Endless alternates on round completion with no old flights',
        (tester) async {
      final audio = await _mount(tester, endless: true, screen: screen);
      final effects = _effects(tester);
      final count = _board().evaluate().length;
      final initialTray = _rect(tester, find.byType(GameTray));
      for (var i = 0; i < count; i++) {
        tester.widget<GameTileWidget>(_board().last).onTap!();
        await tester.pump(const Duration(milliseconds: 20));
        expect(effects.flights.length,
            lessThanOrEqualTo(TileEffectsController.maxFlights));
        expect(effects.bursts.length,
            lessThanOrEqualTo(TileEffectsController.maxBursts));
      }
      expect(tester.widget<GameTileEffects>(find.byType(GameTileEffects)).round,
          2);
      expect(audio.calls.where((v) => v == 'won'), hasLength(1));
      expect(audio.calls.where((v) => v == 'match'), hasLength(count ~/ 3));
      expect(effects.flights, isEmpty);
      expect(effects.bursts, isEmpty);
      final topTray = _rect(tester, find.byType(GameTray));
      expect(topTray.top, lessThan(initialTray.top));
      final source = tester.widget<GameTileWidget>(_board().last);
      source.onTap!();
      await tester.pump();
      expect(effects.flights.single.target.bottom,
          lessThan(effects.flights.single.source.rect.top));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('restart keeps level layout and cancels all previous effects',
      (tester) async {
    await _mount(tester, level: 2, unique: true);
    final effects = _effects(tester);
    final before = _rect(tester, find.byType(GameTray));
    for (var i = 0; i < 7; i++) {
      tester.widget<GameTileWidget>(_board('m$i')).onTap!();
    }
    await tester.pumpAndSettle();
    final restart = find.byKey(const ValueKey('game_over_restart'));
    await tester.ensureVisible(restart);
    await tester.tap(restart);
    await tester.pumpAndSettle();
    expect(_rect(tester, find.byType(GameTray)), before);
    expect(_board(), findsNWidgets(12));
    expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
    expect(effects.flights, isEmpty);
    expect(effects.bursts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing anchors fall back to instant canonical rendering',
      (tester) async {
    final controller = TileEffectsController();
    addTearDown(controller.dispose);
    controller.accepted(
        source: const TileFlightSource(
            Tile(id: 'a', type: 'apple', x: 0, y: 0, layer: 0),
            Rect.fromLTWH(0, 0, 50, 50),
            tileCatalog,
            1,
            Size(50, 50)),
        slot: 0,
        tray: ['a'],
        matchedIds: {},
        matchedSlots: [],
        placement: TrayPlacement.top);
    expect(controller.flights, isEmpty);
    expect(controller.hides('a'), isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  test('expressive flight preserves exact endpoints and adds a bounded lift',
      () {
    for (final targetY in [60.0, 450.0]) {
      final flight = TileFlight(
          1,
          const TileFlightSource(
              Tile(id: 'a', type: 'apple', x: 0, y: 0, layer: 0),
              Rect.fromLTWH(140, 240, 50, 50),
              tileCatalog,
              1,
              Size(50, 50)),
          Rect.fromLTWH(30, targetY, 30, 40),
          0,
          false);
      expect(flight.rectAt(0), flight.source.rect);
      expect(flight.rectAt(1), flight.target);
      final midpoint = Rect.lerp(flight.source.rect, flight.target, .5)!;
      final lifted = flight.rectAt(.5);
      expect(lifted.width, greaterThan(midpoint.width * 1.2));
      expect(lifted.center.dy, lessThan(midpoint.center.dy));
      expect(lifted.width, lessThan(midpoint.width * 1.3));
    }
    expect(FlightAccentPainter.trailSamples, 3);
    expect(TrayBurst.particlesPerSlot, 12);
    expect(TileEffectsController.maxFlights, 7);
    expect(TileEffectsController.maxBursts, 3);
  });

  for (final level in [1, 2]) {
    testWidgets(
        'level $level: accents share the flight clock and stay input-transparent',
        (tester) async {
      final audio = await _mount(tester, level: level);
      final effects = _effects(tester);
      await tester.tap(_board('m0'));
      await tester.pump();
      final first = effects.flights.single;
      expect(
          tester
              .widget<TweenAnimationBuilder<double>>(
                  find.byKey(ValueKey('flight_${first.serial}')))
              .duration,
          const Duration(milliseconds: 280));
      await tester.pump(const Duration(milliseconds: 100));
      final accents = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is FlightAccentPainter);
      expect(accents, findsOneWidget);
      expect(
          tester
              .widget<IgnorePointer>(find
                  .ancestor(of: accents, matching: find.byType(IgnorePointer))
                  .first)
              .ignoring,
          isTrue);
      // Real gestures remain accepted while the trail and outline are painted.
      await tester.tap(_board('m1'));
      await tester.pump();
      await tester.tap(_board('m2'));
      await tester.pump();
      expect(audio.calls, ['tap', 'tap', 'match']);
      expect(haptics, hasLength(3));
      expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
      expect(_board(), findsNWidgets(9));
      expect(effects.bursts, hasLength(1));
      expect(
          tester
              .widget<TweenAnimationBuilder<double>>(
                  find.byKey(ValueKey('burst_${effects.bursts.single.serial}')))
              .duration,
          const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(accents, findsNothing);
      expect(effects.flights, isEmpty);
      expect(effects.bursts, isEmpty);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final reduced in [false, true]) {
    testWidgets(
        'near-full warning is static and clears immediately after a triple, reduced=$reduced',
        (tester) async {
      final audio = await _mount(tester, reduced: reduced);
      for (final id in ['m0', 'm1', 'm3', 'm4', 'm6']) {
        tester.widget<GameTileWidget>(_board(id)).onTap!();
        await tester.pump();
      }
      final warning = find.byKey(const ValueKey('tray_near_full'));
      expect(warning, findsOneWidget);
      Semantics traySemantics() => tester.widget<Semantics>(find
          .descendant(
              of: find.byType(GameTray), matching: find.byType(Semantics))
          .first);
      expect(traySemantics().properties.hint, '2 slots remaining');
      tester.widget<GameTileWidget>(_board('m7')).onTap!();
      await tester.pumpAndSettle();
      expect(warning, findsOneWidget);
      expect(traySemantics().properties.hint, '1 slot remaining');
      expect(tester.binding.hasScheduledFrame, isFalse);
      tester.widget<GameTileWidget>(_board('m2')).onTap!();
      await tester.pump();
      expect(_tray(tester).trayTiles.whereType<Tile>(), hasLength(4));
      expect(warning, findsNothing);
      expect(audio.calls.where((v) => v == 'match'), hasLength(1));
      expect(audio.calls.where((v) => v == 'lost'), isEmpty);
      if (reduced) {
        expect(_effects(tester).flights, isEmpty);
        expect(_effects(tester).bursts, isEmpty);
      }
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  test('lift, deceleration, compression and rebound preserve exact endpoints',
      () {
    for (final y in [60.0, 450.0]) {
      final flight = TileFlight(
          1,
          const TileFlightSource(
              Tile(id: 'phase', type: 'apple', x: 0, y: 0, layer: 0),
              Rect.fromLTWH(140, 240, 50, 50),
              tileCatalog,
              .6,
              Size(50, 50)),
          Rect.fromLTWH(30, y, 30, 40),
          0,
          false);
      expect(flight.rectAt(.08).width, greaterThan(50));
      final earlyTravel =
          (flight.rectAt(.50).center - flight.rectAt(.48).center).distance;
      final lateTravel =
          (flight.rectAt(.77).center - flight.rectAt(.75).center).distance;
      expect(lateTravel, lessThan(earlyTravel));
      expect(flight.rectAt(TileFlight.arrival), flight.target);
      expect(flight.rectAt(.83).height, lessThan(flight.target.height));
      expect(flight.rectAt(.83).width, greaterThan(flight.target.width));
      expect(flight.rectAt(.94).height, greaterThan(flight.target.height));
      expect(flight.rectAt(1), flight.target);
      expect(flight.appearanceAt(0), 0);
      expect(flight.appearanceAt(TileFlight.arrival), 1);
      for (var frame = 0; frame <= 100; frame++) {
        final rect = flight.rectAt(frame / 100);
        expect(rect.isFinite, isTrue);
        expect(rect.isEmpty, isFalse);
      }
    }
  });

  for (final level in [1, 2]) {
    testWidgets(
        'level $level: landing face equals canonical tray before handoff',
        (tester) async {
      await _mount(tester, level: level);
      tester.widget<GameTileWidget>(_board('m3')).onTap!();
      await tester.pump();
      await tester.pump(TileFlight.duration);
      final visual = find.byType(TileFlightVisual);
      expect(visual, findsOneWidget);
      final copy =
          find.descendant(of: visual, matching: find.byType(GameTileWidget));
      final canonical = find.descendant(
          of: find.byType(GameTray),
          matching: find.byWidgetPredicate(
              (w) => w is GameTileWidget && w.tile.id == 'm3'));
      expect(_rect(tester, copy), _rect(tester, canonical));
      final copyTile = tester.widget<GameTileWidget>(copy);
      final trayTile = tester.widget<GameTileWidget>(canonical);
      expect(copyTile.tile.id, trayTile.tile.id);
      expect(copyTile.depth, trayTile.depth);
      expect(copyTile.catalog, trayTile.catalog);
      expect(copyTile.trayAppearanceBlend, 1);
      Container surface(Finder parent) => tester.widget<Container>(
          find.descendant(of: parent, matching: find.byType(Container)));
      expect(surface(copy).decoration, surface(canonical).decoration);
      expect(surface(copy).foregroundDecoration,
          surface(canonical).foregroundDecoration);
      Icon icon(Finder parent) => tester.widget<Icon>(
          find.descendant(of: parent, matching: find.byType(Icon)));
      expect(icon(copy).icon, icon(canonical).icon);
      expect(icon(copy).size, icon(canonical).size);
      expect(_effects(tester).hides('m3'), isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(visual, findsNothing);
      expect(_effects(tester).hides('m3'), isFalse);
      expect(_tray(tester).trayTiles.first!.id, 'm3');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('level $level: matched snapshots react together after arrival',
        (tester) async {
      final audio = await _mount(tester, level: level);
      for (final id in ['m0', 'm1', 'm2']) {
        tester.widget<GameTileWidget>(_board(id)).onTap!();
        await tester.pump();
      }
      final effects = _effects(tester);
      final burst = effects.bursts.single;
      final flight = effects.flights.single;
      expect(burst.snapshots.map((f) => f.tile.id), ['m0', 'm1', 'm2']);
      expect(burst.snapshots.every((f) => f.tile.state == TileState.matched),
          isTrue);
      expect(burst.direction, level.isEven ? 1 : -1);
      expect(burst.incomingId, 'm2');
      expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
      expect(_board(), findsNWidgets(9));
      expect(audio.calls, ['tap', 'tap', 'match']);
      expect(haptics, hasLength(3));
      expect(find.byType(MatchedTileVisual), findsNWidgets(3));
      final incoming = burst.snapshots.last;
      expect(burst.opacityAt(incoming, 0), 0);
      expect(burst.opacityAt(burst.snapshots.first, 0), 1);
      // At the common clock boundary exactly one face owns the incoming icon.
      expect(flight.opacityAt(TileFlight.arrival), 0);
      expect(burst.opacityAt(incoming, burst.reactionStart), 1);
      expect(burst.rectAt(incoming, burst.reactionStart), flight.target);
      await tester.pump(const Duration(milliseconds: 240));
      for (final visual in tester
          .widgetList<MatchedTileVisual>(find.byType(MatchedTileVisual))) {
        expect(visual.progress, closeTo(.48, .000001));
        expect(burst.opacityAt(visual.face, visual.progress), 1);
        expect(burst.rectAt(visual.face, visual.progress).height,
            lessThan(visual.face.rect.height));
      }
      expect(burst.particlesAt(.48), 0, reason: 'Compression precedes release');
      await tester.pump(const Duration(milliseconds: 80));
      expect(effects.flights, isEmpty);
      expect(burst.particlesAt(.64), greaterThan(0));
      expect(burst.opacityAt(incoming, .64), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.byType(MatchedTileVisual), findsNothing);
      expect(effects.bursts, isEmpty);
      expect(audio.calls, ['tap', 'tap', 'match']);
      expect(haptics, hasLength(3));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'rapid matches bound snapshot ownership without restarting older bursts',
      (tester) async {
    await _mount(tester, count: 18);
    final effects = _effects(tester);
    for (var i = 0; i < 12; i++) {
      tester.widget<GameTileWidget>(_board('m$i')).onTap!();
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(effects.bursts, hasLength(TileEffectsController.maxBursts));
    expect(effects.bursts.expand((b) => b.snapshots), hasLength(9));
    expect(
        effects.bursts.expand((b) => b.snapshots).map((s) => s.tile.id).toSet(),
        hasLength(9));
    final visuals = tester
        .widgetList<MatchedTileVisual>(find.byType(MatchedTileVisual))
        .toList();
    expect(visuals, hasLength(9));
    expect(visuals.first.progress, greaterThan(visuals.last.progress));
    expect(_board(), findsNWidgets(6));
    expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(effects.bursts, isEmpty);
    expect(effects.flights, isEmpty);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final action in ['Undo', 'Shuffle', 'Hint']) {
    testWidgets(
        '$action during snapshot reaction cancels or replaces effects safely',
        (tester) async {
      await _mount(tester);
      for (final id in ['m3', 'm0', 'm1', 'm2']) {
        tester.widget<GameTileWidget>(_board(id)).onTap!();
        await tester.pump();
      }
      final effects = _effects(tester);
      final oldSerial = effects.bursts.single.serial;
      await tester.pump(const Duration(milliseconds: 240));
      if (action == 'Undo') {
        // The last selection (m2) has matched, so Undo cannot skip it to
        // restore m3. Make a legal undoable move while the burst is reacting.
        expect(tester.widget<GameBoosterButton>(_booster(action)).onPressed,
            isNull);
        tester.widget<GameTileWidget>(_board('m6')).onTap!();
        await tester.pump();
        expect(_board('m6'), findsNothing);
        expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id),
            ['m3', 'm6']);
        expect(effects.bursts.single.serial, oldSerial);
        expect(find.byType(MatchedTileVisual), findsNWidgets(3));
      }
      expect(tester.widget<GameBoosterButton>(_booster(action)).onPressed,
          isNotNull);
      await tester.tap(_booster(action));
      await tester.pump();
      if (action == 'Hint') {
        final hint = effects.bursts.last;
        expect(hint.serial, isNot(oldSerial));
        expect(hint.incomingId, isNull);
        expect(hint.snapshots, hasLength(3));
        expect(hint.reactionStart, 0);
        expect(hint.snapshots.every((s) => hint.opacityAt(s, 0) == 1), isTrue);
      } else {
        expect(effects.bursts, isEmpty);
        expect(find.byType(MatchedTileVisual), findsNothing);
      }
      if (action == 'Undo') {
        expect(_board('m6'), findsOneWidget);
        expect(
            _tray(tester).trayTiles.whereType<Tile>().map((t) => t.id), ['m3']);
        expect(effects.flights, isEmpty);
        expect(_tray(tester).feedback, isNull);
        for (final id in ['m0', 'm1', 'm2']) {
          expect(_board(id), findsNothing);
        }
      }
      await tester.pumpAndSettle();
      expect(effects.flights, isEmpty);
      expect(effects.bursts, isEmpty);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'disabled Undo after a triple preserves its valid clearing effect',
      (tester) async {
    final audio = await _mount(tester);
    for (final id in ['m3', 'm0', 'm1', 'm2']) {
      tester.widget<GameTileWidget>(_board(id)).onTap!();
      await tester.pump();
    }
    final effects = _effects(tester);
    final burst = effects.bursts.single;
    await tester.pump(const Duration(milliseconds: 240));
    final undo = tester.widget<GameBoosterButton>(_booster('Undo'));
    expect(undo.onPressed, isNull);
    await tester.tap(_booster('Undo'));
    await tester.pump();
    expect(effects.bursts.single, same(burst));
    expect(find.byType(MatchedTileVisual), findsNWidgets(3));
    expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id), ['m3']);
    expect(_board(), findsNWidgets(8));
    expect(
        tester.widget<GameBoosterButton>(_booster('Undo')).badge, undo.badge);
    expect(audio.calls, ['tap', 'tap', 'tap', 'match']);
    await tester.pumpAndSettle();
    expect(effects.bursts, isEmpty);
    expect(find.byType(MatchedTileVisual), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled Undo effects cannot affect a subsequent flight clock',
      (tester) async {
    await _mount(tester);
    for (final id in ['m0', 'm1', 'm2']) {
      tester.widget<GameTileWidget>(_board(id)).onTap!();
      await tester.pump();
    }
    final effects = _effects(tester);
    final oldBurstEnd = tester
        .widget<TweenAnimationBuilder<double>>(
            find.byKey(ValueKey('burst_${effects.bursts.single.serial}')))
        .onEnd!;
    await tester.pump(const Duration(milliseconds: 240));
    tester.widget<GameTileWidget>(_board('m3')).onTap!();
    await tester.pump();
    final oldFlightEnd = tester
        .widget<TweenAnimationBuilder<double>>(
            find.byKey(ValueKey('flight_${effects.flights.single.serial}')))
        .onEnd!;
    expect(tester.widget<GameBoosterButton>(_booster('Undo')).onPressed,
        isNotNull);
    await tester.tap(_booster('Undo'));
    await tester.pump();
    expect(effects.bursts, isEmpty);
    expect(effects.flights, isEmpty);
    expect(_board('m3'), findsOneWidget);
    expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);

    tester.widget<GameTileWidget>(_board('m6')).onTap!();
    await tester.pump();
    final newFlight = effects.flights.single;
    await tester.pump(const Duration(milliseconds: 80));
    // Deliberately deliver callbacks retained from the cancelled animations.
    oldBurstEnd();
    oldFlightEnd();
    await tester.pump();
    expect(effects.bursts, isEmpty);
    expect(find.byType(MatchedTileVisual), findsNothing);
    expect(effects.flights.single, same(newFlight));
    final visual =
        tester.widget<TileFlightVisual>(find.byType(TileFlightVisual));
    expect(visual.progress, closeTo(80 / 280, .000001));
    expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id), ['m6']);
    await tester.pump(const Duration(milliseconds: 201));
    expect(effects.flights, isEmpty);
    expect(effects.hides('m6'), isFalse);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Endless match keeps exact faces in presentation snapshots only',
      (tester) async {
    final audio = await _mount(tester, endless: true);
    final effects = _effects(tester);
    final before = _board().evaluate().length;
    final selected = <String, GameTileWidget>{};
    for (var i = 0; i < before && effects.bursts.isEmpty; i++) {
      final tile = tester.widget<GameTileWidget>(_board().last);
      selected[tile.tile.id] = tile;
      tile.onTap!();
      await tester.pump();
    }
    expect(effects.bursts, hasLength(1));
    final burst = effects.bursts.single;
    expect(burst.snapshots, hasLength(3));
    expect(audio.calls.where((c) => c == 'match'), hasLength(1));
    for (final face in burst.snapshots) {
      expect(face.tile.type, selected[face.tile.id]!.tile.type);
      expect(burst.catalog[face.tile.type]!.icon,
          selected[face.tile.id]!.catalog[face.tile.type]!.icon);
      expect(_board(face.tile.id), findsNothing);
      expect(
          _tray(tester)
              .trayTiles
              .whereType<Tile>()
              .any((t) => t.id == face.tile.id),
          isFalse);
    }
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.byType(MatchedTileVisual), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(effects.bursts, isEmpty);
    expect(effects.flights, isEmpty);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing an earlier burst preserves the later snapshot clock',
      (tester) async {
    await _mount(tester);
    for (final id in ['m0', 'm1', 'm2']) {
      tester.widget<GameTileWidget>(_board(id)).onTap!();
      await tester.pump();
    }
    final effects = _effects(tester);
    final first = effects.bursts.single.serial;
    await tester.pump(const Duration(milliseconds: 100));
    for (final id in ['m3', 'm4', 'm5']) {
      tester.widget<GameTileWidget>(_board(id)).onTap!();
      await tester.pump();
    }
    final second = effects.bursts.last.serial;
    expect(effects.bursts, hasLength(2));
    await tester.pump(const Duration(milliseconds: 401));
    expect(effects.bursts.map((b) => b.serial), [second]);
    expect(effects.bursts.any((b) => b.serial == first), isFalse);
    for (final visual in tester
        .widgetList<MatchedTileVisual>(find.byType(MatchedTileVisual))) {
      expect(visual.burst.serial, second);
      expect(visual.progress, closeTo(401 / 500, .000001));
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(effects.bursts, isEmpty);
    expect(find.byType(MatchedTileVisual), findsNothing);
    await tester.pumpAndSettle();
    expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
    expect(_board(), findsNWidgets(6));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion never retains matched face snapshots',
      (tester) async {
    final audio = await _mount(tester, reduced: true);
    for (final id in ['m0', 'm1', 'm2']) {
      tester.widget<GameTileWidget>(_board(id)).onTap!();
      await tester.pump();
    }
    expect(_effects(tester).bursts, isEmpty);
    expect(_effects(tester).flights, isEmpty);
    expect(find.byType(MatchedTileVisual), findsNothing);
    expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
    expect(_board(), findsNWidgets(9));
    expect(audio.calls, ['tap', 'tap', 'match']);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation during match reaction cancels snapshots permanently',
      (tester) async {
    await _mount(tester);
    for (final id in ['m0', 'm1', 'm2']) {
      tester.widget<GameTileWidget>(_board(id)).onTap!();
      await tester.pump();
    }
    final effects = _effects(tester);
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.byType(MatchedTileVisual), findsNWidgets(3));
    final navigator =
        Navigator.of(tester.element(find.byType(GameTileEffects)));
    unawaited(navigator.push<void>(PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => const Scaffold(body: Text('Away')))));
    await tester.pumpAndSettle();
    expect(effects.bursts, isEmpty);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(MatchedTileVisual), findsNothing);
    expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
    expect(_board(), findsNWidgets(9));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing an earlier flight never restarts a later flight clock',
      (tester) async {
    await _mount(tester);
    tester.widget<GameTileWidget>(_board('m0')).onTap!();
    await tester.pump();
    final effects = _effects(tester);
    final firstSerial = effects.flights.single.serial;
    double progressOf(int serial) {
      final paint = tester.widget<CustomPaint>(find.byWidgetPredicate((w) =>
          w is CustomPaint &&
          w.painter is FlightAccentPainter &&
          (w.painter! as FlightAccentPainter).flight.serial == serial));
      return (paint.painter! as FlightAccentPainter).progress;
    }

    await tester.pump(const Duration(milliseconds: 100));
    tester.widget<GameTileWidget>(_board('m3')).onTap!();
    await tester.pump();
    expect(effects.flights, hasLength(2));
    final secondSerial = effects.flights.last.serial;
    expect(progressOf(firstSerial), closeTo(100 / 280, 0.000001),
        reason: 'Starting the second flight must not reset the first clock');
    expect(progressOf(secondSerial), 0);
    await tester.pump(const Duration(milliseconds: 180));
    expect(progressOf(firstSerial), 1);
    expect(progressOf(secondSerial), closeTo(180 / 280, 0.000001));
    // Flutter's interpolation simulation reports completion for elapsed >
    // duration, not elapsed == duration. At exactly 280 ms the first flight
    // paints its endpoint, but onEnd needs the next tick beyond that boundary.
    await tester.pump(const Duration(milliseconds: 1));
    expect(effects.flights, hasLength(1));
    expect(effects.flights.single.serial, secondSerial);
    final paint = tester.widget<CustomPaint>(find.byWidgetPredicate((w) =>
        w is CustomPaint &&
        w.painter is FlightAccentPainter &&
        (w.painter! as FlightAccentPainter).flight.serial == secondSerial));
    expect((paint.painter! as FlightAccentPainter).progress, greaterThan(.6));
    expect(progressOf(secondSerial), closeTo(181 / 280, 0.000001),
        reason: 'Removing the first flight must preserve the second clock');
    // Check prompt cleanup at the second flight's own deadline, before the
    // general settling step could conceal an unintended restart or delay.
    await tester.pump(const Duration(milliseconds: 100));
    expect(effects.flights, isEmpty);
    await tester.pumpAndSettle();
    expect(effects.flights, isEmpty);
    expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id),
        ['m0', 'm3']);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
