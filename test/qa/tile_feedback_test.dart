import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/game_result.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/endless_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/win_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/theme/world_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_over_dialog.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_effects.dart';

import 'support/geometry.dart';

class _Audio implements GameAudioService {
  final calls = <String>[];
  bool fail = false;
  @override
  bool sfxEnabled = true;
  Future<void> _cue(String name) {
    calls.add(name);
    if (fail) throw StateError('Platform unavailable');
    return Future<void>.value();
  }

  @override
  Future<void> playTap() => _cue('tap');
  @override
  Future<void> playMatch() => _cue('match');
  @override
  Future<void> playGameOver() => _cue('lost');
  @override
  Future<void> playLevelComplete() => _cue('won');
  @override
  Future<void> playBooster() => _cue('booster');
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Progress extends ProgressRepository {
  // Keep reward persistence, but isolate these tests from achievement dialogs.
  @override
  Future<List<PendingAchievementPopup>>
      consumePendingAchievementPopups() async {
    await super.consumePendingAchievementPopups();
    return [];
  }
}

class _Levels extends LevelRepository {
  _Levels(this.tiles);
  final List<Tile> tiles;
  @override
  Future<LevelDefinition> loadLevel(int level) async => LevelDefinition(
      level: level,
      name: 'Feedback fixture',
      timeBonusSeconds: 60,
      tiles: tiles);
}

List<Tile> _tiles({bool unique = false}) {
  final types = unique
      ? tileCatalog.keys.take(9).toList()
      : [
          'apple',
          'apple',
          'apple',
          'banana',
          'banana',
          'banana',
          'berry',
          'berry',
          'berry'
        ];
  return List.generate(
      types.length,
      (i) => Tile(
          id: 't$i',
          type: types[i],
          x: (i % 3) * .3,
          y: (i ~/ 3) * .3,
          layer: 0));
}

Finder _board([String? id]) => find.byWidgetPredicate((w) =>
    w is GameTileWidget && !w.trayTile && (id == null || w.tile.id == id));
GameTray _tray(WidgetTester tester) =>
    tester.widget<GameTray>(find.byType(GameTray));
Finder _booster(String label) =>
    find.byWidgetPredicate((w) => w is GameBoosterButton && w.label == label);

Future<void> _mount(
  WidgetTester tester,
  _Audio audio, {
  bool endless = false,
  bool unique = false,
  bool reduced = false,
  bool vibration = true,
  QaScreen screen = const QaScreen('small', Size(320, 568), 24),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = screen.size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({});
  final progress = _Progress();
  await progress.setVibrationEnabled(vibration);
  await progress.setLevelOneTutorialSeen();
  await tester.pumpWidget(AppScope(
    audioService: audio,
    levelRepository: _Levels(_tiles(unique: unique)),
    progressRepository: progress,
    child: MaterialApp(
        theme: GameTheme.theme(),
        navigatorObservers: [appRouteObserver],
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                disableAnimations: reduced,
                padding: EdgeInsets.only(top: screen.safeTop, bottom: 24),
                viewPadding: EdgeInsets.only(top: screen.safeTop, bottom: 24)),
            child: child!),
        home: endless ? const EndlessScreen() : const GameScreen(level: 2)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final haptics = <String>[];
  setUp(() {
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate')
        haptics.add(call.arguments as String);
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));

  testWidgets('overlapping triples retain separate release clocks',
      (tester) async {
    final audio = _Audio();
    await _mount(tester, audio);
    Future<void> triple(int first) async {
      for (var i = first; i < first + 3; i++) {
        final tap = tester.widget<GameTileWidget>(_board('t$i')).onTap!;
        tap();
        tap();
        await tester.pump();
      }
    }

    await triple(0);
    await tester.pump(const Duration(milliseconds: 100));
    await triple(3);
    expect(_board(), findsNWidgets(3));
    expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
    expect(audio.calls, List.filled(6, 'tap'));
    await tester.pump(const Duration(milliseconds: 313));
    expect(audio.calls.where((c) => c == 'match'), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(audio.calls.where((c) => c == 'match'), hasLength(1));
    tester.element(find.byType(GameTileEffects)).markNeedsBuild();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 99));
    expect(audio.calls.where((c) => c == 'match'), hasLength(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(audio.calls.where((c) => c == 'match'), hasLength(2));
    await tester.pumpAndSettle();
    expect(audio.calls, [...List.filled(6, 'tap'), 'match', 'match']);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final interruption in [
    'dispose',
    'background',
    'route',
    'mute',
    'clear'
  ]) {
    testWidgets('$interruption cancels pending match audio without replay',
        (tester) async {
      final audio = _Audio();
      await _mount(tester, audio);
      for (var i = 0; i < 3; i++) {
        tester.widget<GameTileWidget>(_board('t$i')).onTap!();
        await tester.pump();
      }
      final effects = tester
          .widget<GameTileEffects>(find.byType(GameTileEffects))
          .controller;
      await tester.pump(const Duration(milliseconds: 400));
      expect(audio.calls, ['tap', 'tap', 'tap']);
      NavigatorState? navigator;
      if (interruption == 'dispose') {
        await tester.pumpWidget(const SizedBox.shrink());
      } else if (interruption == 'background') {
        addTearDown(() {
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        });
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else if (interruption == 'route') {
        navigator = Navigator.of(tester.element(find.byType(GameTileEffects)));
        unawaited(navigator.push<void>(MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Away')))));
        await tester.pump();
      } else if (interruption == 'mute') {
        audio.sfxEnabled = false;
      } else {
        // Even an already queued post-frame cue must be invalidated.
        final burst = effects.bursts.single;
        effects.observeBurst(burst, burst.release);
        effects.clear();
      }
      await tester.pump(const Duration(milliseconds: 20));
      if (interruption == 'background') {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
      audio.sfxEnabled = true;
      navigator?.pop();
      await tester.pumpAndSettle();
      expect(audio.calls, ['tap', 'tap', 'tap']);
      if (interruption != 'dispose') {
        expect(_board(), findsNWidgets(6));
        expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
      }
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Hint matches sound at their 70 ms release without a flight',
      (tester) async {
    final audio = _Audio();
    await _mount(tester, audio);
    await tester.tap(_booster('Hint'));
    await tester.pump();
    expect(audio.calls.where((c) => c == 'match'), isEmpty);
    expect(_board(), findsNWidgets(6));
    await tester.pump(const Duration(milliseconds: 69));
    expect(audio.calls.where((c) => c == 'match'), isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    expect(audio.calls.where((c) => c == 'match'), hasLength(1));
    expect(audio.calls.where((c) => c == 'tap'), isEmpty);
    await tester.pumpAndSettle();
    expect(audio.calls.where((c) => c == 'match'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'accepted taps are immediate, matches follow burst release and rebuilds are silent',
      (tester) async {
    final audio = _Audio();
    await _mount(tester, audio);
    expect(audio.calls, isEmpty);
    expect(haptics, isEmpty);
    final firstTap = tester.widget<GameTileWidget>(_board('t0')).onTap!;
    firstTap();
    firstTap(); // Stale callback cannot collect the same canonical tile again.
    await tester.pump();
    expect(audio.calls, ['tap']);
    expect(_tray(tester).feedback!.serial, 1);
    expect(_tray(tester).feedback!.slots, [0]);
    tester.widget<GameTileWidget>(_board('t1')).onTap!();
    tester.widget<GameTileWidget>(_board('t2')).onTap!();
    expect(audio.calls, ['tap', 'tap', 'tap'],
        reason: 'Acceptance feedback must not wait for repository futures');
    await tester.pump();
    expect(_tray(tester).feedback!.matched, isTrue);
    expect(_tray(tester).feedback!.serial, 3);
    expect(_tray(tester).feedback!.slots, [0, 1, 2]);
    expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
    expect(_board(), findsNWidgets(6));
    await tester.pump(const Duration(milliseconds: 343));
    expect(audio.calls.where((c) => c == 'match'), isEmpty);
    await tester.pump(const Duration(milliseconds: 70));
    expect(audio.calls.where((c) => c == 'match'), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(audio.calls, ['tap', 'tap', 'tap', 'match']);
    final burstVisual = tester
        .widgetList<MatchedTileVisual>(find.byType(MatchedTileVisual))
        .first;
    expect(burstVisual.burst.particlesAt(burstVisual.progress), greaterThan(0));
    await tester.pumpAndSettle();
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact'
    ]);
    tester.element(find.byType(GameScreen)).markNeedsBuild();
    await tester.pumpAndSettle();
    expect(audio.calls, ['tap', 'tap', 'tap', 'match']);
    expect(_board(), findsNWidgets(6));
    tester.widget<GameTileWidget>(_board('t3')).onTap!();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final screen in qaScreens) {
    for (final endless in [false, true]) {
      testWidgets(
          '${screen.name}, endless=$endless: touch, Undo, Shuffle and Hint keep functioning',
          (tester) async {
        final audio = _Audio();
        await _mount(tester, audio, endless: endless, screen: screen);
        final selectable = find.byWidgetPredicate((w) =>
            w is GameTileWidget && !w.trayTile && w.enabled && !w.blocked);
        final count = _board().evaluate().length;
        final id = tester.widget<GameTileWidget>(selectable.first).tile.id;
        expect(selectable.first.hitTestable(), findsOneWidget);
        await tester.tap(selectable.first);
        await tester.pump();
        expect(audio.calls, ['tap']);
        expect(_tray(tester).feedback!.serial, 1);
        expect(_board(), findsNWidgets(count - 1));
        await tester.tap(_booster('Undo'));
        await tester.pumpAndSettle();
        expect(_board(id), findsOneWidget);
        expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
        expect(_tray(tester).feedback, isNull);
        // Endless generates a random, solvable board. Follow its guaranteed
        // reverse paint order until a legal Hint is available, before shuffling.
        bool hintAvailable() {
          final counts = <String, int>{};
          for (final tile in _tray(tester).trayTiles.whereType<Tile>()) {
            counts.update(tile.type, (n) => n + 1, ifAbsent: () => 1);
          }
          for (final widget in tester.widgetList<GameTileWidget>(selectable)) {
            counts.update(widget.tile.type, (n) => n + 1, ifAbsent: () => 1);
          }
          return counts.values.any((n) => n >= 3);
        }

        for (var step = 0; !hintAvailable() && step < count; step++) {
          await tester.tap(selectable.last);
          await tester.pumpAndSettle();
        }
        expect(hintAvailable(), isTrue);
        final boardBeforeHint = _board().evaluate().length;
        final trayBeforeHint = _tray(tester).trayTiles.whereType<Tile>().length;
        final matchesBeforeHint = audio.calls.where((c) => c == 'match').length;
        await tester.tap(_booster('Hint'));
        await tester.pumpAndSettle();
        expect(audio.calls.where((c) => c == 'match'),
            hasLength(matchesBeforeHint + 1));
        expect(_tray(tester).feedback!.matched, isTrue);
        expect(
            _board().evaluate().length +
                _tray(tester).trayTiles.whereType<Tile>().length,
            boardBeforeHint + trayBeforeHint - 3);
        final before = tester
            .widgetList<GameTileWidget>(_board())
            .map((w) => w.tile.type)
            .toList()
          ..sort();
        await tester.tap(_booster('Shuffle'));
        await tester.pumpAndSettle();
        final after = tester
            .widgetList<GameTileWidget>(_board())
            .map((w) => w.tile.type)
            .toList()
          ..sort();
        expect(after, before);
        expect(_tray(tester).feedback, isNull);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'seventh unmatched tile immediately opens Game Over during feedback',
      (tester) async {
    final audio = _Audio();
    await _mount(tester, audio, unique: true);
    for (var i = 0; i < 7; i++) {
      tester.widget<GameTileWidget>(_board('t$i')).onTap!();
    }
    expect(audio.calls.where((c) => c == 'lost'), hasLength(1));
    await tester.pump();
    final tray =
        tester.widget<GameTray>(find.byType(GameTray, skipOffstage: false));
    expect(tray.trayTiles.whereType<Tile>(), hasLength(7));
    expect(find.byType(GameOverDialog), findsOneWidget);
    await tester.pumpAndSettle();
    expect(audio.calls.where((c) => c == 'lost'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final endless in [false, true]) {
    testWidgets(
        'endless=$endless: sound and vibration settings suppress event output',
        (tester) async {
      final audio = _Audio()..sfxEnabled = false;
      await _mount(tester, audio, vibration: false, endless: endless);
      final count = _board().evaluate().length;
      for (var i = 0; i < count; i++) {
        tester.widget<GameTileWidget>(_board().last).onTap!();
        await tester.pump();
        if (_tray(tester).feedback!.matched) break;
      }
      await tester.pumpAndSettle();
      expect(audio.calls, isEmpty);
      expect(haptics, isEmpty);
      expect(_tray(tester).feedback!.matched, isTrue);
      expect(
          _board().evaluate().length +
              _tray(tester).trayTiles.whereType<Tile>().length,
          count - 3);
    });
  }

  testWidgets('victory follows the final triple exactly once', (tester) async {
    final audio = _Audio();
    await _mount(tester, audio);
    final callbacks = tester
        .widgetList<GameTileWidget>(_board())
        .map((w) => w.onTap!)
        .toList();
    for (final callback in callbacks.take(8)) {
      callback();
      await tester.pumpAndSettle();
    }
    expect(audio.calls.where((cue) => cue == 'won'), isEmpty);
    expect(_board(), findsOneWidget);
    callbacks.last();
    callbacks.last(); // Terminal stale input must not replay match or victory.
    await tester.pumpAndSettle();
    expect(audio.calls.where((cue) => cue == 'match'), hasLength(3));
    expect(audio.calls.where((cue) => cue == 'won'), isEmpty,
        reason: 'Campaign completion must not play the retired synthetic chime');
    expect(find.byType(WinScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final reduced in [false, true]) {
    testWidgets('Endless rapid matches and active disposal, reduced=$reduced',
        (tester) async {
      final audio = _Audio();
      await _mount(tester, audio, endless: true, reduced: reduced);
      var accepted = 0;
      var matches = 0;
      final burstStarts = <DateTime>[];
      var audibleMatches = 0;
      final initialCount = _board().evaluate().length;
      // The generator guarantees this reverse paint order is tray-safe.
      for (var i = 0; i < initialCount && matches < 2; i++) {
        final callback = tester.widget<GameTileWidget>(_board().last).onTap!;
        callback();
        callback(); // Same ID cannot be accepted twice before rebuilding.
        accepted++;
        await tester.pump(const Duration(milliseconds: 20));
        // pump advances the test's FakeAsync clock. Sample after the frame:
        // a newly mounted burst starts its animation on this first frame.
        final now = tester.binding.clock.now();
        final event = _tray(tester).feedback!;
        if (event.matched) {
          matches++;
          burstStarts.add(now);
        }
        audibleMatches = reduced
            ? matches
            : burstStarts
                .where((start) => now.difference(start).inMicroseconds >= 413200)
                .length;
        expect(event.serial, accepted);
        expect(
            audio.calls, hasLength(accepted + (reduced ? 0 : audibleMatches)));
        expect(audio.calls.where((cue) => cue == 'match'),
            hasLength(audibleMatches));
        expect(_board().evaluate().length, initialCount - accepted);
        expect(_tray(tester).trayTiles.whereType<Tile>(),
            hasLength(accepted - 3 * matches));
        final effect = find.byKey(ValueKey('tray_feedback_${event.serial}'));
        expect(
            tester.widget<TweenAnimationBuilder<double>>(effect).duration,
            reduced
                ? Duration.zero
                : Duration(milliseconds: event.matched ? 280 : 160));
      }
      expect(matches, 2);
      expect(haptics, hasLength(accepted));
      // Remove the actual screen while the last match glow is still running.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(audio.calls.where((cue) => cue == 'match'),
          hasLength(audibleMatches));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('press feedback keeps hit geometry and cancels without selecting',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
      width: 60,
      height: 60,
      child: GameTileWidget(
          tile: _tiles().first,
          enabled: true,
          highlighted: false,
          onTap: () => taps++),
    )))));
    final tile = find.byType(GameTileWidget);
    final size = tester.getSize(tile);
    final gesture = await tester.startGesture(tester.getCenter(tile));
    await tester.pump(const Duration(milliseconds: 200));
    final pressTween = find.descendant(
        of: tile, matching: find.byType(TweenAnimationBuilder<double>));
    expect(tester.widget<TweenAnimationBuilder<double>>(pressTween).duration,
        const Duration(milliseconds: 70));
    final transform =
        find.descendant(of: tile, matching: find.byType(Transform));
    expect(tester.widget<Transform>(transform).transformHitTests, isFalse);
    expect(tester.getSize(tile), size);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.widget<TweenAnimationBuilder<double>>(pressTween).duration,
        const Duration(milliseconds: 110));
    expect(taps, 0);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('feedback channel failures cannot interrupt accepted moves',
      (tester) async {
    final audio = _Audio()..fail = true;
    await _mount(tester, audio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        throw PlatformException(code: 'unavailable');
      }
      return null;
    });
    for (var i = 0; i < 3; i++) {
      tester.widget<GameTileWidget>(_board('t$i')).onTap!();
    }
    await tester.pumpAndSettle();
    expect(_board(), findsNWidgets(6));
    expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final screen in qaScreens) {
    for (final reduced in [false, true]) {
      testWidgets('${screen.name}: finite tray effects, reduced=$reduced',
          (tester) async {
        final audio = _Audio();
        await _mount(tester, audio, screen: screen, reduced: reduced);
        for (var i = 0; i < 6; i++) {
          tester.widget<GameTileWidget>(_board('t$i')).onTap!();
          await tester.pump(const Duration(milliseconds: 20));
        }
        final effect = find
            .byKey(ValueKey('tray_feedback_${_tray(tester).feedback!.serial}'));
        expect(tester.widget<TweenAnimationBuilder<double>>(effect).duration,
            reduced ? Duration.zero : const Duration(milliseconds: 280));
        expect(audio.calls.where((cue) => cue == 'match'),
            hasLength(reduced ? 2 : 0));
        expect(_board(), findsNWidgets(3));
        await tester.pumpAndSettle();
        expect(audio.calls.where((cue) => cue == 'match'), hasLength(2));
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'tray animation never mutates an engine or delays triple resolution',
      (tester) async {
    final engine = GameEngine(_tiles());
    for (var i = 0; i < 3; i++) {
      expect(engine.tapTile('t$i', const Size(300, 400), const Size(50, 50)),
          isTrue);
    }
    expect(engine.result, GameResult.playing);
    final snapshot = engine.tiles.map((tile) => tile.state).toList();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GameTray(
      trayTiles: List<Tile?>.filled(7, null),
      catalog: tileCatalog,
      worldTheme: WorldThemes.garden,
      feedback: TrayFeedback(
          serial: 1,
          matched: true,
          before: ['t0', 't1'],
          collected: ['t2'],
          matchedIds: {'t0', 't1', 't2'}),
    ))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.tiles.map((tile) => tile.state), snapshot);
    expect(engine.tray, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink()); // Interrupt the effect.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
