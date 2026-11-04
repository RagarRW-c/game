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
import 'package:triple_tile_adventure/domain/endless_board_generator.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/endless_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/win_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/achievement_reward_dialog.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_over_dialog.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_effects.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_face.dart';

import 'support/geometry.dart';
import 'support/tile_asset_images.dart';

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
  Future<void> playAchievementUnlocked() async {
    calls.add('achievement');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Progress extends ProgressRepository {
  _Progress({this.showPopups = false});
  final bool showPopups;

  @override
  Future<List<PendingAchievementPopup>>
      consumePendingAchievementPopups() async {
    final popups = await super.consumePendingAchievementPopups();
    return showPopups ? popups : [];
  }
}

// A controllable persistence boundary, not an animation delay. This proves
// victory depends on committed rewards rather than on a VFX completion callback.
class _VictoryProgress extends _Progress {
  _VictoryProgress({this.completionGate, super.showPopups});
  final Completer<void>? completionGate;
  int completionCalls = 0;
  int unlockCalls = 0;
  int coinCalls = 0;

  @override
  Future<void> recordLevelCompleted(int level, int stars) async {
    completionCalls++;
    final gate = completionGate;
    if (gate != null) await gate.future;
    await super.recordLevelCompleted(level, stars);
  }

  @override
  Future<void> unlockNextLevel(int level) async {
    unlockCalls++;
    await super.unlockNextLevel(level);
  }

  @override
  Future<int> addCoins(int amount) async {
    coinCalls++;
    return super.addCoins(amount);
  }
}

class _Levels extends LevelRepository {
  _Levels(this.count, this.unique, [this.layout]);
  final List<Tile>? layout;
  final int count;
  final bool unique;
  @override
  Future<LevelDefinition> loadLevel(int level) async => LevelDefinition(
        level: level,
        name: 'Motion fixture',
        timeBonusSeconds: 60,
        tiles: layout ?? fixture(count, unique),
      );

  static List<Tile> fixture(int count, bool unique) => List.generate(
      count,
      (i) => Tile(
          id: 'm$i',
          type: tileCatalog.keys.elementAt(unique ? i : i ~/ 3),
          x: (i % 3) * .3,
          y: (i ~/ 3) * .22,
          layer: 0));
}

class _FixedBoards extends EndlessBoardGenerator {
  _FixedBoards([this.layout]);
  final List<Tile>? layout;
  @override
  List<Tile> generate({required int round, required TileVisualTheme theme}) =>
      layout ?? _Levels.fixture(12, false);
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

void _expectBurstClockOnly(int serial) {
  final clock = find.byKey(ValueKey('burst_$serial'), skipOffstage: false);
  expect(clock, findsOneWidget,
      reason: 'Supersession must retain the original audio clock.');
  expect(
      find.descendant(
          of: clock,
          skipOffstage: false,
          matching: find.byWidgetPredicate(
              (w) =>
                  w is MatchedTileVisual ||
                  w is TrayShiftVisual ||
                  w is GameTileWidget ||
                  w is CustomPaint ||
                  w is Opacity,
              skipOffstage: false)),
      findsNothing,
      reason: 'Invisible burst faces, shifts and painters must be unmounted, '
          'not retained beneath zero opacity.');
}

// Absolute logical pixels: separate FittedBox/Stack transform chains may round
// differently. This remains far below even a 0.000001-pixel alignment error.
const _geometryTolerance = 1e-9;

void _expectAlignedRects(Rect actual, Rect expected, String description) {
  String precise(Rect r) => [r.left, r.top, r.right, r.bottom]
      .map((value) => value.toStringAsPrecision(17))
      .join(', ');
  final detail =
      '$description: actual [${precise(actual)}], expected [${precise(expected)}]';
  expect(actual.left, closeTo(expected.left, _geometryTolerance),
      reason: '$detail: left');
  expect(actual.top, closeTo(expected.top, _geometryTolerance),
      reason: '$detail: top');
  expect(actual.right, closeTo(expected.right, _geometryTolerance),
      reason: '$detail: right');
  expect(actual.bottom, closeTo(expected.bottom, _geometryTolerance),
      reason: '$detail: bottom');
}

Finder _booster(String label) =>
    find.byWidgetPredicate((w) => w is GameBoosterButton && w.label == label);

Future<_Audio> _mount(WidgetTester tester,
    {int level = 1,
    bool endless = false,
    bool fixedEndless = false,
    bool reduced = false,
    int count = 12,
    bool unique = false,
    List<Tile>? layout,
    _Progress? progressRepository,
    QaScreen screen = const QaScreen('small', Size(320, 568), 24)}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = screen.size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final progress = progressRepository ?? _Progress();
  await progress.setLevelOneTutorialSeen();
  final audio = _Audio();
  await tester.pumpWidget(AppScope(
    levelRepository: _Levels(count, unique, layout),
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
        home: endless
            ? (fixedEndless
                ? EndlessScreen.forTesting(
                    initialRound: level, boardGenerator: _FixedBoards(layout))
                : const EndlessScreen())
            : GameScreen(level: level)),
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

  for (final endless in [false, true]) {
    for (final occupied in [false, true]) {
      testWidgets(
          'endless=$endless occupied=$occupied: direct Hint clears once at measured board faces',
          (tester) async {
        final layout = _Levels.fixture(12, false)
            .asMap()
            .entries
            .map((entry) => entry.key < 6
                ? entry.value
                    .copyWith(type: tileCatalog.keys.elementAt(entry.key + 4))
                : entry.value)
            .toList();
        await _mount(tester,
            endless: endless,
            fixedEndless: true,
            layout: occupied ? layout : null);
        if (occupied) {
          // Six ordinary tray tiles; Hint must not invent slots eight/nine.
          for (final id in ['m0', 'm1', 'm2', 'm3', 'm4', 'm5']) {
            tester.widget<GameTileWidget>(_board(id)).onTap!();
            await tester.pumpAndSettle();
          }
        }
        final effects = _effects(tester);
        final beforeTray = _tray(tester).trayTiles.map((t) => t?.id).toList();
        final beforeBoard = _board().evaluate().length;
        final sources = {
          for (final element in _board().evaluate())
            (element.widget as GameTileWidget).tile.id:
                effects.rectFor(element)!,
        };
        final action =
            tester.widget<GameBoosterButton>(_booster('Hint')).onPressed!;
        action();
        action(); // Same-turn duplicate must not create a second burst/charge.
        await tester.pump();
        expect(effects.bursts, hasLength(1));
        final burst = effects.bursts.single;
        expect(burst.boardMatch, isTrue);
        expect(burst.snapshots, hasLength(3));
        expect(effects.boardCue, isNull, reason: 'One effect owns this triple');
        expect(effects.flights, isEmpty);
        expect(_board(), findsNWidgets(beforeBoard - 3));
        expect(_tray(tester).trayTiles.map((t) => t?.id), beforeTray);
        expect(tester.widget<GameBoosterButton>(_booster('Hint')).badge, 'x1');
        final trayRect =
            effects.rectFor(tester.element(find.byType(GameTray)))!;
        for (final face in burst.snapshots) {
          _expectAlignedRects(
              face.rect, sources[face.tile.id]!, 'Hint board anchor');
          expect(face.rect.overlaps(trayRect), isFalse);
          expect(_board(face.tile.id), findsNothing);
          expect(burst.opacityAt(face, 0), 1);
          expect(burst.opacityAt(face, 1), 0);
        }
        await tester.pump(const Duration(milliseconds: 71));
        expect(find.byType(MatchedTileVisual), findsNWidgets(3));
        await tester.pumpAndSettle();
        expect(effects.bursts, isEmpty);
        expect(find.byType(MatchedTileVisual), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'endless=$endless: covered faces never receive accepted or Hint effects',
        (tester) async {
      final layout = _Levels.fixture(12, false);
      final covered = layout.first;
      final cover = layout[9];
      layout[0] = Tile(
          id: covered.id,
          type: covered.type,
          x: cover.x,
          y: cover.y,
          layer: cover.layer);
      await _mount(tester,
          endless: endless, fixedEndless: true, layout: layout);
      final effects = _effects(tester);
      final blocked = tester.widget<GameTileWidget>(_board('m0'));
      expect(blocked.blocked, isTrue);
      expect(blocked.onTap, isNull);
      final legal = tester
          .widgetList<GameTileWidget>(_board())
          .where((tile) => !tile.blocked)
          .map((tile) => tile.tile.id)
          .toSet();
      await tester.tap(_booster('Hint'));
      await tester.pump();
      expect(effects.bursts, hasLength(1));
      expect(
          effects.bursts.single.snapshots
              .every((s) => legal.contains(s.tile.id)),
          isTrue);
      expect(effects.bursts.single.snapshots.any((s) => s.tile.id == 'm0'),
          isFalse);
      expect(_board('m0'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(effects.flights, isEmpty);
      expect(effects.bursts, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'endless=$endless: fitting Hint accents only its exposed board targets',
        (tester) async {
      await _mount(tester, endless: endless, fixedEndless: true);
      tester.widget<GameTileWidget>(_board('m0')).onTap!();
      await tester.pumpAndSettle();
      final effects = _effects(tester);
      final expected = {
        for (final id in ['m1', 'm2'])
          id: effects.rectFor(tester.element(_board(id)))!
      };
      final beforeIds = tester
          .widgetList<GameTileWidget>(_board())
          .map((tile) => tile.tile.id)
          .toSet();
      for (final id in expected.keys) {
        final target = tester.widget<GameTileWidget>(_board(id));
        expect(target.blocked, isFalse);
        expect(target.enabled, isTrue);
      }
      await tester.tap(_booster('Hint'));
      await tester.pump();
      expect(effects.bursts, hasLength(1));
      expect(effects.bursts.single.boardMatch, isFalse);
      expect(effects.boardCue!.kind, BoardCueKind.hint);
      // The cue transforms board-space rects; rectFor composes each tile's
      // local transform first. These equivalent FittedBox paths can round
      // differently. Match bijectively by location, never by list order or
      // Rect's exact-double equality. 1e-9 is far below a physical pixel.
      final actual = effects.boardCue!.rects;
      expect(actual, hasLength(2));
      final remaining = Map<String, Rect>.of(expected);
      for (final rect in actual) {
        final candidates = remaining.entries
            .where((entry) =>
                (entry.value.center - rect.center).distance <=
                _geometryTolerance)
            .toList();
        expect(candidates, hasLength(1),
            reason: 'Each accent must uniquely identify m1 or m2; coordinates: '
                '${[
              rect.left,
              rect.top,
              rect.right,
              rect.bottom
            ].map((v) => v.toStringAsPrecision(17)).join(', ')}');
        final target = candidates.single;
        _expectAlignedRects(rect, target.value, 'Hint target ${target.key}');
        remaining.remove(target.key);
      }
      expect(remaining, isEmpty, reason: 'No missing or duplicate target');
      final afterIds = tester
          .widgetList<GameTileWidget>(_board())
          .map((tile) => tile.tile.id)
          .toSet();
      expect(beforeIds.difference(afterIds), unorderedEquals(expected.keys));
      expect(effects.bursts.single.snapshots.map((face) => face.tile.id),
          unorderedEquals(['m0', 'm1', 'm2']));
      expect(effects.flights, isEmpty);
      expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
      await tester.pumpAndSettle();
      expect(effects.boardCue, isNull);
      expect(effects.bursts, isEmpty);
      expect(tester.takeException(), isNull);
    });

    for (final action in ['Undo', 'Shuffle']) {
      testWidgets(
          'endless=$endless: $action cue preserves authoritative geometry and settles',
          (tester) async {
        await _mount(tester, endless: endless, fixedEndless: true);
        final original = {
          for (final e in _board().evaluate())
            (e.widget as GameTileWidget).tile.id:
                _rect(tester, _board((e.widget as GameTileWidget).tile.id))
        };
        if (action == 'Undo') {
          tester.widget<GameTileWidget>(_board('m0')).onTap!();
          await tester.pumpAndSettle();
        }
        final effects = _effects(tester);
        await tester.tap(_booster(action));
        await tester.pump();
        final cue = effects.boardCue;
        if (action == 'Undo') {
          expect(cue, isNull);
          expect(effects.flights.single.reversed, isTrue);
          expect(effects.hidesBoard('m0'), isTrue);
        } else {
          expect(cue!.kind, BoardCueKind.shuffle);
          expect(cue.rects.length, lessThanOrEqualTo(BoardCue.maxRects));
        }
        expect(_board(), findsNWidgets(12));
        expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
        for (final e in _board().evaluate()) {
          final tile = e.widget as GameTileWidget;
          _expectAlignedRects(_rect(tester, _board(tile.tile.id)),
              original[tile.tile.id]!, 'booster position');
        }
        await tester.pump(const Duration(milliseconds: 100));
        if (action == 'Undo') {
          expect(
              tester
                  .widget<TileFlightVisual>(find.byType(TileFlightVisual))
                  .progress,
              closeTo(100 / 440, 1e-6));
        } else {
          final paint = tester.widget<CustomPaint>(find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is BoardCuePainter));
          expect((paint.painter! as BoardCuePainter).progress,
              closeTo(100 / cue!.duration.inMilliseconds, 1e-6));
        }
        await tester.pumpAndSettle();
        expect(effects.boardCue, isNull);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'endless=$endless: reduced motion suppresses all booster accents',
        (tester) async {
      await _mount(tester, endless: endless, fixedEndless: true, reduced: true);
      final effects = _effects(tester);
      tester.widget<GameTileWidget>(_board('m0')).onTap!();
      await tester.pump();
      for (final action in ['Undo', 'Hint', 'Shuffle']) {
        await tester.tap(_booster(action));
        await tester.pumpAndSettle();
        expect(effects.boardCue, isNull);
        expect(effects.bursts, isEmpty);
        expect(effects.flights, isEmpty);
      }
      expect(_board(), findsNWidgets(9));
      expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    for (final interruption in ['tap', 'navigate', 'background', 'dispose']) {
      testWidgets(
          'endless=$endless: $interruption cancels booster cue permanently',
          (tester) async {
        await _mount(tester, endless: endless, fixedEndless: true);
        final effects = _effects(tester);
        await tester.tap(_booster('Shuffle'));
        await tester.pump();
        expect(effects.boardCue, isNotNull);
        final revision = effects.revision;
        NavigatorState? navigator;
        if (interruption == 'tap') {
          tester.widget<GameTileWidget>(_board().last).onTap!();
          await tester.pump();
        } else if (interruption == 'navigate') {
          navigator =
              Navigator.of(tester.element(find.byType(GameTileEffects)));
          unawaited(navigator.push<void>(PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, __, ___) =>
                  const Scaffold(body: Text('Away')))));
          await tester.pumpAndSettle();
        } else if (interruption == 'background') {
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          await tester.pump();
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pump();
        } else {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        expect(effects.boardCue, isNull);
        // A late completion cannot revive the old visual, including after a
        // newer ordinary move. No timers or delayed action queue are involved.
        effects.showBoardCue(
            BoardCueKind.undo,
            [
              const TileFlightSource(
                  Tile(id: 'stale', type: 'apple', x: 0, y: 0, layer: 0),
                  Rect.fromLTWH(0, 0, 30, 30),
                  tileCatalog,
                  1,
                  Size(30, 30))
            ],
            expectedRevision: revision);
        expect(effects.boardCue, isNull);
        navigator?.pop();
        await tester.pumpAndSettle();
        expect(
            find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is BoardCuePainter),
            findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final endless in [false, true]) {
    for (final level in [1, 2]) {
      for (final action in ['Resume', 'Restart Level']) {
        testWidgets('reverse Undo cancels on Campaign pause and $action',
            (tester) async {
          await _mount(tester);
          tester.widget<GameTileWidget>(_board('m0')).onTap!();
          await tester.pumpAndSettle();
          final effects = _effects(tester);
          await tester.tap(_booster('Undo'));
          await tester.pump();
          expect(effects.hidesBoard('m0'), isTrue);
          await tester.tap(find.byIcon(Icons.pause_rounded));
          await tester.pumpAndSettle();
          expect(effects.flights, isEmpty);
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          expect(_board(), findsNWidgets(12));
          expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
          expect(effects.hidesBoard('m0'), isFalse);
          expect(find.byType(TileFlightVisual), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets(
          'final Hint during reverse Undo leaves no return copy over victory',
          (tester) async {
        await _mount(tester, count: 3);
        tester.widget<GameTileWidget>(_board('m0')).onTap!();
        await tester.pumpAndSettle();
        final effects = _effects(tester);
        await tester.tap(_booster('Undo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(effects.flights.single.reversed, isTrue);
        await tester.tap(_booster('Hint'));
        await tester.pumpAndSettle();
        expect(find.byType(WinScreen), findsOneWidget);
        expect(effects.flights, isEmpty);
        expect(effects.bursts, isEmpty);
        expect(effects.hidesBoard('m0'), isFalse);
        expect(
            find.byType(TileFlightVisual, skipOffstage: false), findsNothing);
        expect(tester.takeException(), isNull);
      });

      for (final screen in qaScreens) {
        testWidgets(
            'reverse Undo endless=$endless level=$level ${screen.name}: exact anchors and one visible copy',
            (tester) async {
          await _mount(tester,
              endless: endless,
              fixedEndless: true,
              level: level,
              screen: screen);
          final effects = _effects(tester);
          tester.widget<GameTileWidget>(_board('m0')).onTap!();
          await tester.pumpAndSettle();
          // Slot 1 proves this is the actual former slot, not a hardcoded zero.
          final historicalCell = effects.rectFor(tester.element(_board('m3')))!;
          final originalTile = tester.widget<GameTileWidget>(_board('m3')).tile;
          final hudBefore = endless
              ? tester.getSize(find.byKey(const ValueKey('endless_hud_scroll')))
              : null;
          tester.widget<GameTileWidget>(_board('m3')).onTap!();
          await tester.pump();
          final forward = effects.flights.single;
          await tester.pumpAndSettle();
          final traySource =
              effects.rectFor(effects.slotKeys[1].currentContext)!;
          final trayTile = find.descendant(
              of: find.byType(GameTray),
              matching: find.byWidgetPredicate(
                  (w) => w is GameTileWidget && w.tile.id == 'm3'));
          Rect artwork(Finder tile) => effects.rectFor(tester.element(
              find.descendant(of: tile, matching: find.byType(TileSymbol))))!;
          final trayArtwork = artwork(trayTile);
          final action =
              tester.widget<GameBoosterButton>(_booster('Undo')).onPressed!;
          action();
          action();
          await tester.pump();
          final reverse = effects.flights.single;
          // Score/Best 5 -> 10 reflows the small Endless HUD. Undo preserves
          // score, so the ORIGINAL logical cell now has a different screen
          // transform. Measure the restored RenderBox, even while paint-hidden.
          final destination = effects.rectFor(tester.element(_board('m3')))!;
          final restored = tester.widget<GameTileWidget>(_board('m3')).tile;
          expect((
            restored.id,
            restored.type,
            restored.x,
            restored.y,
            restored.layer
          ), (
            originalTile.id,
            originalTile.type,
            originalTile.x,
            originalTile.y,
            originalTile.layer
          ));
          if (endless && screen.size == const Size(320, 568)) {
            expect(
                tester
                    .getSize(find.byKey(const ValueKey('endless_hud_scroll')))
                    .height,
                greaterThan(hudBefore!.height));
            expect(
                (destination.left - historicalCell.left).abs(), greaterThan(1),
                reason:
                    'Keep the real HUD reflow that exposed the stale anchor oracle');
          }
          final currentPath = TileFlight(
              0,
              TileFlightSource(restored, destination, forward.source.catalog,
                  forward.source.depth, tester.getSize(_board('m3'))),
              traySource,
              1,
              false);
          expect(reverse.reversed, isTrue);
          expect(reverse.source.tile.id, 'm3');
          expect(reverse.slot, 1);
          _expectAlignedRects(
              reverse.rectAt(0), traySource, 'actual tray source');
          _expectAlignedRects(
              reverse.rectAt(1), destination, 'original board destination');
          for (final p in [0.0, .14, .5, .78, 1.0]) {
            _expectAlignedRects(reverse.rectAt(p), currentPath.rectAt(1 - p),
                'reverse path in current layout at $p');
            expect(reverse.appearanceAt(p),
                closeTo(currentPath.appearanceAt(1 - p), 1e-9));
          }
          expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id),
              ['m0']);
          expect(
              tester.widget<GameBoosterButton>(_booster('Undo')).badge, 'x1');
          expect(effects.hidesBoard('m3'), isTrue);
          final opacity = find
              .ancestor(of: _board('m3'), matching: find.byType(Opacity))
              .first;
          expect(tester.widget<Opacity>(opacity).opacity, 0);
          expect(find.byType(TileFlightVisual), findsOneWidget);
          _expectAlignedRects(artwork(find.byType(TileFlightVisual)),
              trayArtwork, 'full transformed artwork at actual tray source');
          await tester.pump(const Duration(milliseconds: 220));
          final visual =
              tester.widget<TileFlightVisual>(find.byType(TileFlightVisual));
          expect(visual.progress, .5);
          expect(effects.hidesBoard('m3'), isTrue);
          await tester.pump(const Duration(milliseconds: 220));
          expect(
              tester
                  .widget<TileFlightVisual>(find.byType(TileFlightVisual))
                  .progress,
              1);
          _expectAlignedRects(
              artwork(find.byType(TileFlightVisual)),
              artwork(_board('m3')),
              'full transformed artwork aligns before canonical reveal');
          expect(tester.widget<Opacity>(opacity).opacity, 0);
          await tester.pump(const Duration(milliseconds: 1));
          expect(effects.flights, isEmpty);
          expect(effects.hidesBoard('m3'), isFalse);
          expect(tester.widget<Opacity>(opacity).opacity, 1);
          _expectAlignedRects(effects.rectFor(tester.element(_board('m3')))!,
              destination, 'settled destination');
          expect(find.byType(TileFlightVisual), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets(
        'reverse Undo endless=$endless: unfinished flight reverses without a slot teleport',
        (tester) async {
      await _mount(tester, endless: endless, fixedEndless: true);
      final effects = _effects(tester);
      Rect artwork(Finder tile) => effects.rectFor(tester.element(
          find.descendant(of: tile, matching: find.byType(TileSymbol))))!;
      tester.widget<GameTileWidget>(_board('m0')).onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      final forward = effects.flights.single;
      final painted = forward.rectAt(.5);
      final paintedArtwork = artwork(find.byType(TileFlightVisual));
      await tester.tap(_booster('Undo'));
      await tester.pump();
      final reverse = effects.flights.single;
      expect(reverse.reverseFrom, .5);
      expect(reverse.rectAt(0), painted);
      expect(reverse.appearanceAt(0), forward.appearanceAt(.5));
      _expectAlignedRects(
          artwork(find.byType(TileFlightVisual)),
          paintedArtwork,
          'interrupted flight keeps its full transformed artwork');
      await tester.pump(const Duration(milliseconds: 110));
      // Reselecting the returned canonical tile starts where its copy is now.
      final current = reverse.rectAt(.25);
      tester.widget<GameTileWidget>(_board('m0')).onTap!();
      await tester.pump();
      expect(effects.flights, hasLength(1));
      expect(effects.flights.single.reversed, isFalse);
      expect(effects.flights.single.rectAt(0), current);
      expect(effects.hidesBoard('m0'), isFalse);
      await tester.pump(const Duration(milliseconds: 110));
      final selectedAgain = effects.flights.single;
      final secondStart = selectedAgain.rectAt(.25);
      final secondArtwork = artwork(find.byType(TileFlightVisual));
      await tester.tap(_booster('Undo'));
      await tester.pump();
      final secondReturn = effects.flights.single;
      expect(secondReturn.rectAt(0), secondStart);
      _expectAlignedRects(artwork(find.byType(TileFlightVisual)), secondArtwork,
          'repeated Undo keeps its full transformed artwork');
      // The reselection raised Score/Best to 10. The new fitted layout is
      // authoritative; the first flight's source is a historical screen rect.
      final destination = effects.rectFor(tester.element(_board('m0')))!;
      final restored = tester.widget<GameTileWidget>(_board('m0')).tile;
      expect((
        restored.id,
        restored.x,
        restored.y,
        restored.layer
      ), (
        forward.source.tile.id,
        forward.source.tile.x,
        forward.source.tile.y,
        forward.source.tile.layer
      ));
      _expectAlignedRects(secondReturn.rectAt(1), destination,
          'reselected tile returns to the original cell in its current transform');
      await tester.pumpAndSettle();
      _expectAlignedRects(effects.rectFor(tester.element(_board('m0')))!,
          destination, 'canonical tile does not teleport when return ends');
      expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
      expect(effects.hidesBoard('m0'), isFalse);
      expect(tester.takeException(), isNull);
    });

    for (final interruption in [
      'repeat',
      'Shuffle',
      'Hint',
      'route',
      'background',
      'resize',
      'dispose'
    ]) {
      testWidgets(
          'reverse Undo endless=$endless: $interruption does not leave duplicate or stale copies',
          (tester) async {
        await _mount(tester, endless: endless, fixedEndless: true);
        final effects = _effects(tester);
        for (final id in ['m0', 'm3']) {
          tester.widget<GameTileWidget>(_board(id)).onTap!();
          await tester.pumpAndSettle();
        }
        await tester.tap(_booster('Undo'));
        await tester.pump();
        final first = effects.flights.single;
        await tester.pump(const Duration(milliseconds: 100));
        NavigatorState? navigator;
        if (interruption == 'repeat') {
          await tester.tap(_booster('Undo'));
          await tester.pump();
          expect(effects.flights, hasLength(2));
          expect(effects.flights.map((f) => f.source.tile.id).toSet(),
              {'m0', 'm3'});
          final visual = tester.widget<TileFlightVisual>(find.byWidgetPredicate(
              (w) => w is TileFlightVisual && w.flight.serial == first.serial));
          expect(visual.progress, closeTo(100 / 440, 1e-9));
        } else if (interruption == 'Shuffle' || interruption == 'Hint') {
          await tester.tap(_booster(interruption));
          await tester.pump();
        } else if (interruption == 'route') {
          navigator =
              Navigator.of(tester.element(find.byType(GameTileEffects)));
          unawaited(navigator.push<void>(PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              pageBuilder: (_, __, ___) =>
                  const Scaffold(body: Text('Away')))));
          await tester.pumpAndSettle();
          expect(effects.flights, isEmpty);
          navigator.pop();
        } else if (interruption == 'background') {
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          await tester.pump();
          expect(effects.flights, isEmpty);
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        } else if (interruption == 'resize') {
          tester.view.physicalSize = const Size(412, 915);
          await tester.pump();
          expect(effects.flights, isEmpty);
        } else {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        await tester.pumpAndSettle();
        expect(effects.flights, isEmpty);
        expect(effects.hidesBoard('m0'), isFalse);
        expect(effects.hidesBoard('m3'), isFalse);
        expect(find.byType(TileFlightVisual), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

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
        await tester.pump(const Duration(milliseconds: 220));
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
    expect(audio.calls, ['tap', 'tap', 'tap', 'tap']);
    expect(haptics, hasLength(4));
    expect(effects.bursts, hasLength(1));
    expect(effects.bursts.single.rects, hasLength(3));
    expect(effects.flights, hasLength(1));
    expect(effects.flights.single.matched, isTrue);
    expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id), ['m3']);
    expect(effects.hides('m3'), isTrue);
    expect(effects.bursts.single.shifts.map((s) => s.tile.id), ['m3'],
        reason: 'The survivor has one presentation copy during tray reflow.');
    expect(find.byType(TrayShiftVisual), findsOneWidget);
    final superseded = effects.bursts.single;
    tester.widget<GameTileWidget>(_board('m6')).onTap!();
    await tester.pump();
    expect(effects.flights.single.slot, 1);
    expect(effects.presents(superseded), isFalse,
        reason: 'Old match faces must not cover a newly reused slot.');
    _expectBurstClockOnly(superseded.serial);
    expect(find.byType(TrayShiftVisual), findsNothing);
    expect(effects.hides('m3'), isFalse);
    expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id),
        ['m3', 'm6']);
    await tester.pumpAndSettle();
    expect(audio.calls, ['tap', 'tap', 'tap', 'tap', 'tap', 'match']);
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
      if (action == 'Undo') {
        expect(effects.flights.single.reversed, isTrue);
      } else {
        expect(effects.flights, isEmpty);
      }
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

  for (final endless in [false, true]) {
    for (final level in [1, 2]) {
      testWidgets(
          'mode endless=$endless round $level: separated pair lands as an adjacent triple',
          (tester) async {
        final audio = await _mount(tester,
            level: level, endless: endless, fixedEndless: true);
        for (final id in ['m0', 'm3', 'm1', 'm6']) {
          tester.widget<GameTileWidget>(_board(id)).onTap!();
          await tester.pumpAndSettle();
        }
        final effects = _effects(tester);
        final slots = [
          for (final key in effects.slotKeys)
            effects.rectFor(key.currentContext)!
        ];
        expect(slots, hasLength(7));
        expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id),
            ['m0', 'm3', 'm1', 'm6']);
        tester.widget<GameTileWidget>(_board('m2')).onTap!();
        await tester.pump();
        final burst = effects.bursts.single;
        final flight = effects.flights.single;
        expect(flight.slot, 4);
        _expectAlignedRects(flight.target, slots[4], 'Third tile target');
        expect(burst.snapshots.map((s) => s.tile.id), ['m0', 'm1', 'm2']);
        expect(burst.rects, [slots[2], slots[3], slots[4]]);
        _expectAlignedRects(
            burst.rectAt(burst.snapshots[0], 0), slots[0], 'First pair origin');
        _expectAlignedRects(burst.rectAt(burst.snapshots[1], 0), slots[2],
            'Second pair origin');
        expect(burst.shifts.map((s) => s.tile.id), ['m3', 'm6']);
        expect(effects.hides('m3'), isTrue);
        expect(effects.hides('m6'), isTrue);
        expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id),
            ['m3', 'm6'],
            reason:
                'Presentation must not defer or reorder canonical match resolution.');

        await tester.pump(const Duration(microseconds: 343100));
        expect(flight.opacityAt(343100 / 440000), 1);
        expect(burst.opacityAt(burst.snapshots.last, 343100 / 640000), 0);
        expect(audio.calls.where((c) => c == 'match'), isEmpty);
        await tester.pump(const Duration(microseconds: 100));
        final origin = _rect(tester, find.byKey(effects.layerKey)).topLeft;
        for (var i = 0; i < 3; i++) {
          final face = burst.snapshots[i];
          expect(burst.opacityAt(face, burst.reactionStart), 1);
          _expectAlignedRects(burst.rectAt(face, burst.reactionStart),
              slots[i + 2], 'Aligned match model');
          _expectAlignedRects(
              _rect(
                  tester,
                  find.byKey(
                      ValueKey('match_${burst.serial}_${face.tile.id}'))),
              slots[i + 2].shift(origin),
              'Visible match landing');
        }
        for (var i = 0; i < 2; i++) {
          _expectAlignedRects(
              burst.shiftRectAt(burst.shifts[i], burst.reactionStart),
              slots[i],
              'Survivor canonical destination');
        }
        expect(burst.particlesAt(burst.reactionStart), 0);
        expect(flight.opacityAt(TileFlight.arrival), 0,
            reason: 'Incoming face has exactly one owner at arrival.');
        await tester.pump(const Duration(microseconds: 69999));
        expect(audio.calls.where((c) => c == 'match'), isEmpty);
        expect(burst.opacityAt(burst.snapshots.last, 413199 / 640000), 1);
        await tester.pump(const Duration(microseconds: 2));
        expect(audio.calls.where((c) => c == 'match'), hasLength(1));
        await tester.pumpAndSettle();
        expect(effects.flights, isEmpty);
        expect(effects.bursts, isEmpty);
        expect(find.byType(TrayShiftVisual), findsNothing);
        expect(effects.hides('m3'), isFalse);
        expect(effects.hides('m6'), isFalse);
        expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id),
            ['m3', 'm6']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
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
      'final match reward popups precede Victory without duplicate grants or stale effects',
      (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final progress = _VictoryProgress(completionGate: gate, showPopups: true);
    final audio = await _mount(tester, count: 3, progressRepository: progress);
    final effects = _effects(tester);
    final finalTap = tester.widget<GameTileWidget>(_board('m2')).onTap!;
    for (final id in ['m0', 'm1', 'm2']) {
      tester.widget<GameTileWidget>(_board(id)).onTap!();
    }
    await tester.pumpAndSettle();
    expect(find.byType(AchievementRewardDialog), findsOneWidget);
    expect(find.text('First Match'), findsOneWidget);
    expect(find.byType(WinScreen), findsNothing);
    expect(progress.completionCalls, 0,
        reason: 'The match-earned coin popup precedes completion persistence.');
    expect(audio.calls.where((c) => c == 'achievement'), hasLength(1));
    expect(effects.bursts, isEmpty);
    expect(effects.flights, isEmpty);
    expect(find.byType(MatchedTileVisual, skipOffstage: false), findsNothing);

    await tester.tap(find.byKey(const ValueKey('achievement_close')));
    await tester.pumpAndSettle();
    expect(progress.completionCalls, 1);
    expect(find.byType(AchievementRewardDialog), findsNothing);
    expect(find.byType(WinScreen), findsNothing,
        reason: 'Completion rewards must be committed before Victory.');

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('First Win'), findsOneWidget);
    expect(find.byType(WinScreen), findsNothing);
    expect(audio.calls.where((c) => c == 'achievement'), hasLength(2));
    final earnedCoins = await progress.coins();
    final coinCalls = progress.coinCalls;
    tester.element(find.byType(AchievementRewardDialog)).markNeedsBuild();
    await tester.pump();
    expect(await progress.coins(), earnedCoins);
    expect(audio.calls.where((c) => c == 'achievement'), hasLength(2));

    await tester.tap(find.byKey(const ValueKey('achievement_close')));
    await tester.pumpAndSettle();
    expect(find.byType(WinScreen), findsOneWidget);
    finalTap();
    await tester.pump();
    expect(progress.completionCalls, 1);
    expect(progress.unlockCalls, 1);
    expect(progress.coinCalls, coinCalls);
    expect(await progress.coins(), earnedCoins);
    expect(audio.calls.where((c) => c == 'achievement'), hasLength(2));
    expect(effects.bursts, isEmpty);
    expect(effects.flights, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final holdPersistence in [false, true]) {
    testWidgets(
        holdPersistence
            ? 'final match paints while persistence is pending; victory does not await VFX'
            : 'victory starts during the clearing effect, never after its callback',
        (tester) async {
      final gate = holdPersistence ? Completer<void>() : null;
      addTearDown(() {
        if (gate != null && !gate.isCompleted) gate.complete();
      });
      final progress = _VictoryProgress(completionGate: gate);
      final audio =
          await _mount(tester, count: 3, progressRepository: progress);
      final effects = _effects(tester);
      final created = <int>{};
      void observe() =>
          created.addAll(effects.bursts.map((burst) => burst.serial));
      effects.addListener(observe);
      addTearDown(() => effects.removeListener(observe));
      final finalTap = tester.widget<GameTileWidget>(_board('m2')).onTap!;
      final start = tester.binding.clock.now();
      for (var i = 0; i < 3; i++) {
        tester.widget<GameTileWidget>(_board('m$i')).onTap!();
      }
      // The final accepted move creates both events synchronously, BEFORE
      // pumping persistence futures can push the victory route and clear them.
      expect(effects.bursts, hasLength(1));
      expect(effects.flights, hasLength(1));
      final burst = effects.bursts.single;
      final flight = effects.flights.single;
      expect(flight.matched, isTrue);
      expect(burst.incomingId, 'm2');
      expect(burst.snapshots.map((face) => face.tile.id),
          unorderedEquals(['m0', 'm1', 'm2']));
      expect(created, {burst.serial});
      expect(TileFlight.duration, const Duration(milliseconds: 440));
      expect(TrayBurst.duration, const Duration(milliseconds: 640));
      expect(audio.calls.where((v) => v == 'match'), hasLength(1));
      finalTap(); // A stale accepted-tile callback cannot complete/reward twice.
      await tester.pump(); // Zero elapsed time; drains mocked persistence.
      if (gate != null) {
        expect(progress.completionCalls, 1);
        expect(find.byType(WinScreen), findsNothing);
        expect(effects.bursts.single, same(burst));
        expect(find.byType(MatchedTileVisual), findsNWidgets(3));
        expect(
            tester
                .widget<TileFlightVisual>(find.byType(TileFlightVisual))
                .progress,
            0);
        // Paint the exact arrival boundary while real completion is pending.
        await tester.pump(const Duration(microseconds: 343200));
        final visual =
            tester.widget<TileFlightVisual>(find.byType(TileFlightVisual));
        expect(visual.progress, closeTo(TileFlight.arrival, 1e-9));
        expect(flight.opacityAt(visual.progress), 0);
        for (final face in burst.snapshots) {
          expect(burst.opacityAt(face, 343200 / 640000), 1);
        }
        gate.complete();
        await tester.pump(); // Release persistence, not the animation clock.
      }
      expect(
          tester.binding.clock.now().difference(start),
          holdPersistence
              ? const Duration(microseconds: 343200)
              : Duration.zero);
      expect(find.byType(WinScreen), findsOneWidget);
      expect(progress.completionCalls, 1);
      expect(progress.unlockCalls, 1);
      expect(progress.coinCalls, greaterThan(0));
      final coinCalls = progress.coinCalls;
      final coins = await progress.coins();
      // Losing the current route deliberately cancels presentation before its
      // 440/640 ms onEnd callbacks. Retention here would be a stale-effect bug.
      expect(effects.bursts, isEmpty);
      expect(effects.flights, isEmpty);
      expect(effects.boardCue, isNull);
      expect(find.byType(MatchedTileVisual, skipOffstage: false), findsNothing);
      expect(find.byType(TrayShiftVisual, skipOffstage: false), findsNothing);
      expect(find.byType(TileFlightVisual, skipOffstage: false), findsNothing);
      expect(find.byKey(ValueKey('burst_${burst.serial}'), skipOffstage: false),
          findsNothing);
      finalTap();
      effects.finishBurst(burst.serial);
      effects.finishFlight(flight.serial);
      await tester.pumpAndSettle();
      expect(created, {burst.serial});
      expect(progress.completionCalls, 1);
      expect(progress.unlockCalls, 1);
      expect(progress.coinCalls, coinCalls);
      expect(await progress.coins(), coins);
      expect(audio.calls.where((v) => v == 'match'), hasLength(1));
      expect(audio.calls.where((v) => v == 'won'), isEmpty,
          reason:
              'Campaign completion must not play the retired synthetic chime');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(effects.bursts, isEmpty);
      expect(effects.flights, isEmpty);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

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
        if (_tray(tester).feedback!.matched) {
          await tester.pump(const Duration(milliseconds: 414));
        }
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
      final midpoint =
          Rect.lerp(flight.source.rect, flight.target, flight.travelAt(.5))!;
      final lifted = flight.rectAt(.5);
      expect(lifted.width, greaterThan(midpoint.width * 1.08));
      expect(lifted.center.dy, lessThan(midpoint.center.dy));
      expect(lifted.width, lessThan(midpoint.width * 1.22));
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
          const Duration(milliseconds: 440));
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
      expect(audio.calls, ['tap', 'tap', 'tap']);
      expect(haptics, hasLength(3));
      expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
      expect(_board(), findsNWidgets(9));
      expect(effects.bursts, hasLength(1));
      expect(
          tester
              .widget<TweenAnimationBuilder<double>>(
                  find.byKey(ValueKey('burst_${effects.bursts.single.serial}')))
              .duration,
          const Duration(milliseconds: 640));
      await tester.pumpAndSettle();
      expect(audio.calls, ['tap', 'tap', 'tap', 'match']);
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
      expect(
          audio.calls.where((v) => v == 'match'), hasLength(reduced ? 1 : 0));
      expect(audio.calls.where((v) => v == 'lost'), isEmpty);
      if (reduced) {
        expect(_effects(tester).flights, isEmpty);
        expect(_effects(tester).bursts, isEmpty);
      }
      await tester.pumpAndSettle();
      expect(audio.calls.where((v) => v == 'match'), hasLength(1));
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
      expect(TileFlight.duration, const Duration(milliseconds: 440));
      expect(flight.travelAt(TileFlight.pickup), 0,
          reason: 'Pickup must lift before starting transport.');
      final pickedUp = flight.rectAt(TileFlight.pickup);
      expect(pickedUp.center.dx, flight.source.rect.center.dx);
      expect(pickedUp.center.dy, lessThan(flight.source.rect.center.dy));
      expect(pickedUp.width, closeTo(flight.source.rect.width * 1.22, .001));
      expect(flight.travelAt(280 / 440), inExclusiveRange(0, 1),
          reason: 'The old completion deadline must now still be in transit.');
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
      const h = .00001;
      final leftAcceleration = (flight.travelAt(.5) -
              2 * flight.travelAt(.5 - h) +
              flight.travelAt(.5 - 2 * h)) /
          (h * h);
      final rightAcceleration = (flight.travelAt(.5 + 2 * h) -
              2 * flight.travelAt(.5 + h) +
              flight.travelAt(.5)) /
          (h * h);
      expect(leftAcceleration, closeTo(rightAcceleration, .03),
          reason: 'The brake must not introduce an acceleration kink.');
      final endAcceleration = (flight.travelAt(TileFlight.arrival) -
              2 * flight.travelAt(TileFlight.arrival - h) +
              flight.travelAt(TileFlight.arrival - 2 * h)) /
          (h * h);
      expect(endAcceleration.abs(), lessThan(.1),
          reason: 'Travel acceleration must approach zero before landing.');
      final pickupAcceleration = (flight.travelAt(TileFlight.pickup + 2 * h) -
              2 * flight.travelAt(TileFlight.pickup + h) +
              flight.travelAt(TileFlight.pickup)) /
          (h * h);
      expect(pickupAcceleration.abs(), lessThan(.1),
          reason: 'Transport must start smoothly after pickup.');
      var previous = 0.0;
      for (var step = 0; step <= 1000; step++) {
        final travel = flight.travelAt(step / 1000);
        expect(travel, inInclusiveRange(previous, 1.0));
        previous = travel;
      }
      for (var frame = 0; frame <= 100; frame++) {
        final rect = flight.rectAt(frame / 100);
        expect(rect.isFinite, isTrue);
        expect(rect.isEmpty, isFalse);
      }
    }
  });

  for (final level in [1, 2]) {
    for (final movingId in ['m3', 'm6']) {
      testWidgets(
          'level $level / $movingId: landing face equals canonical tray before handoff',
          (tester) async {
        await _mount(tester, level: level);
        await loadVisibleTileImages(tester);
        tester.widget<GameTileWidget>(_board(movingId)).onTap!();
        await tester.pump();
        await tester.pump(TileFlight.duration);
        final visual = find.byType(TileFlightVisual);
        expect(visual, findsOneWidget);
        final copy =
            find.descendant(of: visual, matching: find.byType(GameTileWidget));
        final canonical = find.descendant(
            of: find.byType(GameTray),
            matching: find.byWidgetPredicate(
                (w) => w is GameTileWidget && w.tile.id == movingId));
        _expectAlignedRects(_rect(tester, copy), _rect(tester, canonical),
            'Landed tile must align with its canonical tray tile');
        final copyTile = tester.widget<GameTileWidget>(copy);
        final trayTile = tester.widget<GameTileWidget>(canonical);
        expect(copyTile.tile.id, trayTile.tile.id);
        expect(copyTile.depth, trayTile.depth);
        expect(copyTile.catalog, trayTile.catalog);
        expect(copyTile.trayAppearanceBlend, 1);
        TileFace surface(Finder parent) => tester.widget<TileFace>(
            find.descendant(of: parent, matching: find.byType(TileFace)));
        expect(surface(copy).art, surface(canonical).art);
        expect(surface(copy).art.assetPath, surface(canonical).art.assetPath);
        if (movingId == 'm6') {
          expect(
              surface(copy).art.assetPath, 'assets/tiles/approved/chili.png');
          for (final parent in [copy, canonical]) {
            final image = tester.widget<Image>(
                find.descendant(of: parent, matching: find.byType(Image)));
            expect((image.image as AssetImage).assetName,
                'assets/tiles/approved/chili.png');
            final pixels = tester.widget<RawImage>(
                find.descendant(of: parent, matching: find.byType(RawImage)));
            expect(pixels.image, isNotNull,
                reason: 'Both faces must render the decoded approved artwork.');
          }
        }
        expect(surface(copy).blocked, surface(canonical).blocked);
        expect(surface(copy).highlighted, surface(canonical).highlighted);
        expect(surface(copy).pressed, surface(canonical).pressed);
        expect(surface(copy).depth, surface(canonical).depth);
        expect(surface(copy).trayBlend, surface(canonical).trayBlend);
        Finder symbol(Finder parent) =>
            find.descendant(of: parent, matching: find.byType(TileSymbol));
        expect(tester.widget<TileSymbol>(symbol(copy)).art.icon,
            tester.widget<TileSymbol>(symbol(canonical)).art.icon);
        expect(tester.widget<TileSymbol>(symbol(copy)).art.color,
            tester.widget<TileSymbol>(symbol(canonical)).art.color);
        _expectAlignedRects(
            _rect(tester, symbol(copy)),
            _rect(tester, symbol(canonical)),
            'Landed artwork must align with its canonical tray artwork');
        expect(_effects(tester).hides(movingId), isTrue);
        await tester.pump(const Duration(milliseconds: 1));
        expect(visual, findsNothing);
        expect(_effects(tester).hides(movingId), isFalse);
        expect(_tray(tester).trayTiles.first!.id, movingId);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

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
      expect(audio.calls, ['tap', 'tap', 'tap']);
      expect(haptics, hasLength(3));
      expect(find.byType(MatchedTileVisual), findsNWidgets(3));
      final incoming = burst.snapshots.last;
      expect(burst.opacityAt(incoming, 0), 0);
      expect(burst.opacityAt(burst.snapshots.first, 0), 1);
      // At the common clock boundary exactly one face owns the incoming icon.
      expect(flight.opacityAt(TileFlight.arrival), 0);
      expect(burst.opacityAt(incoming, burst.reactionStart), 1);
      expect(burst.rectAt(incoming, burst.reactionStart), flight.target);
      const h = .00001;
      final initialCompressionSpeed =
          (burst.rectAt(incoming, burst.reactionStart + h).height /
                          incoming.rect.height -
                      1)
                  .abs() /
              h;
      expect(initialCompressionSpeed, lessThan(.01),
          reason: 'The matched faces must start compressing smoothly.');
      expect(
          (1 - burst.opacityAt(incoming, burst.release + h)) / h, lessThan(.01),
          reason: 'Disappearance must ease out of the hold.');
      await tester.pump(const Duration(milliseconds: 280));
      final travelling =
          tester.widget<TileFlightVisual>(find.byType(TileFlightVisual));
      expect(travelling.progress, closeTo(280 / 440, .000001));
      expect(flight.opacityAt(travelling.progress), 1);
      expect(flight.rectAt(travelling.progress), isNot(flight.target));
      await tester.pump(const Duration(milliseconds: 63));
      expect(flight.opacityAt(343 / 440), 1);
      expect(burst.opacityAt(incoming, 343 / 640), 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(flight.opacityAt(344 / 440), 0);
      expect(burst.opacityAt(incoming, 344 / 640), 1);
      expect(find.byType(MatchedTileVisual), findsNWidgets(3));
      await tester.pump(const Duration(milliseconds: 26));
      for (final visual in tester
          .widgetList<MatchedTileVisual>(find.byType(MatchedTileVisual))) {
        expect(visual.progress, closeTo(370 / 640, .000001));
        expect(burst.opacityAt(visual.face, visual.progress), 1);
        expect(burst.rectAt(visual.face, visual.progress).height,
            lessThan(visual.face.rect.height));
      }
      expect(burst.particlesAt(370 / 640), 0,
          reason: 'Compression precedes release');
      await tester.pump(const Duration(milliseconds: 80));
      expect(effects.flights, isEmpty);
      expect(burst.particlesAt(450 / 640), greaterThan(0));
      expect(burst.opacityAt(incoming, 450 / 640), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.byType(MatchedTileVisual), findsNothing);
      expect(effects.bursts, isEmpty);
      expect(audio.calls, ['tap', 'tap', 'tap', 'match']);
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
    expect(visuals, hasLength(3),
        reason: 'Three retained clocks must not retain nine visual faces.');
    expect(visuals.map((v) => v.burst.serial),
        everyElement(effects.bursts.last.serial));
    double clockProgress(TrayBurst burst) => tester
        .state<ImplicitlyAnimatedWidgetState<TweenAnimationBuilder<double>>>(
            find.byKey(ValueKey('burst_${burst.serial}')))
        .animation
        .value;
    expect(clockProgress(effects.bursts.first),
        greaterThan(clockProgress(effects.bursts.last)));
    expect(effects.bursts.where(effects.presents), [effects.bursts.last],
        reason:
            'Retired snapshots retain clocks, never ownership of reused slots.');
    for (final burst in effects.bursts) {
      if (!effects.presents(burst)) _expectBurstClockOnly(burst.serial);
    }
    expect(_board(), findsNWidgets(6));
    expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(effects.bursts, isEmpty);
    expect(effects.flights, isEmpty);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'rapid third tap starts pair reflow at the currently painted flights',
      (tester) async {
    await _mount(tester);
    final effects = _effects(tester);
    tester.widget<GameTileWidget>(_board('m0')).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.widget<GameTileWidget>(_board('m1')).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final positions = {
      for (final visual
          in tester.widgetList<TileFlightVisual>(find.byType(TileFlightVisual)))
        visual.flight.source.tile.id: visual.flight.rectAt(visual.progress),
    };
    expect(positions.keys, unorderedEquals(['m0', 'm1']));
    tester.widget<GameTileWidget>(_board('m2')).onTap!();
    await tester.pump();
    final burst = effects.bursts.single;
    for (final face in burst.snapshots.take(2)) {
      _expectAlignedRects(burst.rectAt(face, 0), positions[face.tile.id]!,
          'Rapid pair must not teleport from an obsolete tray position');
    }
    expect(effects.flights.single.source.tile.id, 'm2');
    expect(effects.flights.single.slot, 2);
    await tester.pumpAndSettle();
    expect(effects.flights, isEmpty);
    expect(effects.bursts, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final action in ['Undo', 'Shuffle', 'Hint']) {
    for (final endless in [false, true]) {
      testWidgets(
          '$action during snapshot reaction cancels or replaces effects safely${endless ? ' (Endless)' : ''}',
          (tester) async {
        final audio =
            await _mount(tester, endless: endless, fixedEndless: true);
        for (final id in ['m3', 'm0', 'm1', 'm2']) {
          tester.widget<GameTileWidget>(_board(id)).onTap!();
          await tester.pump();
        }
        final effects = _effects(tester);
        final oldBurst = effects.bursts.single;
        final oldSerial = oldBurst.serial;
        final oldClockFinder =
            find.byKey(ValueKey('burst_$oldSerial'), skipOffstage: false);
        final oldClock = tester.state(oldClockFinder);
        await tester.pump(const Duration(milliseconds: 370));
        expect(effects.bursts.where(effects.presents), [oldBurst]);
        final activeFaces = tester.widgetList<MatchedTileVisual>(
            find.byType(MatchedTileVisual, skipOffstage: false));
        expect(activeFaces, hasLength(3));
        expect(activeFaces.map((v) => v.burst), everyElement(same(oldBurst)));
        expect(activeFaces.map((v) => v.face.tile.id),
            unorderedEquals(['m0', 'm1', 'm2']));
        expect(audio.calls.where((c) => c == 'match'), isEmpty,
            reason:
                '370 ms is inside compression, before the 413.2 ms release.');
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
          expect(effects.bursts.single, same(oldBurst));
          expect(oldBurst.snapshots.map((s) => s.tile.id),
              unorderedEquals(['m0', 'm1', 'm2']));
          expect(effects.bursts.where(effects.presents), isEmpty,
              reason:
                  'The accepted m6 move supersedes the previous arrangement.');
          _expectBurstClockOnly(oldSerial);
          expect(tester.state(oldClockFinder), same(oldClock));
          expect(
              tester
                  .state<
                      ImplicitlyAnimatedWidgetState<
                          TweenAnimationBuilder<double>>>(oldClockFinder)
                  .animation
                  .value,
              closeTo(370 / 640, 1e-9),
              reason: 'Supersession retains the clock without restarting it.');
          expect(find.byType(MatchedTileVisual, skipOffstage: false),
              findsNothing);
          expect(
              find.byType(TrayShiftVisual, skipOffstage: false), findsNothing);
          expect(effects.hides('m3'), isFalse);
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
          expect(
              hint.snapshots.every((s) => hint.opacityAt(s, 0) == 1), isTrue);
          expect(effects.bursts.where(effects.presents), [hint]);
          final faces = tester.widgetList<MatchedTileVisual>(
              find.byType(MatchedTileVisual, skipOffstage: false));
          expect(faces, hasLength(3));
          expect(faces.map((v) => v.burst), everyElement(same(hint)));
        } else {
          expect(effects.bursts, isEmpty);
          expect(find.byType(MatchedTileVisual), findsNothing);
        }
        if (action == 'Undo') {
          expect(oldClockFinder, findsNothing,
              reason: 'Undo fully cancels the retained audio-only burst.');
          expect(_board('m6'), findsOneWidget);
          expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id),
              ['m3']);
          expect(effects.flights.single.reversed, isTrue);
          expect(effects.flights.single.source.tile.id, 'm6');
          expect(find.byType(TileFlightVisual), findsOneWidget);
          expect(effects.hidesBoard('m6'), isTrue);
          final boardOpacity = find
              .ancestor(of: _board('m6'), matching: find.byType(Opacity))
              .first;
          expect(tester.widget<Opacity>(boardOpacity).opacity, 0,
              reason: 'The reverse flight is the only visible m6 copy.');
          expect(_tray(tester).feedback, isNull);
          for (final id in ['m0', 'm1', 'm2']) {
            expect(_board(id), findsNothing);
          }
        }
        await tester.pumpAndSettle();
        expect(effects.flights, isEmpty);
        expect(effects.bursts, isEmpty);
        if (action == 'Undo') {
          expect(effects.hidesBoard('m6'), isFalse);
          expect(_board('m6'), findsOneWidget);
          expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id),
              ['m3']);
          expect(
              find.byType(TileFlightVisual, skipOffstage: false), findsNothing);
          expect(audio.calls, ['tap', 'tap', 'tap', 'tap', 'tap', 'tap'],
              reason:
                  'Undo uses selection audio; the cancelled burst cannot play.');
        }
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final endless in [false, true]) {
    testWidgets(
        'disabled Undo after a triple preserves its valid clearing effect${endless ? ' (Endless)' : ''}',
        (tester) async {
      final audio = await _mount(tester, endless: endless, fixedEndless: true);
      for (final id in ['m3', 'm0', 'm1', 'm2']) {
        tester.widget<GameTileWidget>(_board(id)).onTap!();
        await tester.pump();
      }
      final effects = _effects(tester);
      final burst = effects.bursts.single;
      await tester.pump(const Duration(milliseconds: 370));
      final undo = tester.widget<GameBoosterButton>(_booster('Undo'));
      expect(undo.onPressed, isNull);
      await tester.tap(_booster('Undo'));
      await tester.pump();
      expect(effects.bursts.single, same(burst));
      expect(effects.bursts.where(effects.presents), [burst]);
      expect(find.byType(MatchedTileVisual), findsNWidgets(3));
      final faces =
          tester.widgetList<MatchedTileVisual>(find.byType(MatchedTileVisual));
      expect(faces.map((v) => v.burst), everyElement(same(burst)));
      expect(faces.map((v) => v.face.tile.id),
          unorderedEquals(['m0', 'm1', 'm2']));
      expect(
          _tray(tester).trayTiles.whereType<Tile>().map((t) => t.id), ['m3']);
      expect(_board(), findsNWidgets(8));
      expect(
          tester.widget<GameBoosterButton>(_booster('Undo')).badge, undo.badge);
      expect(audio.calls, ['tap', 'tap', 'tap', 'tap']);
      // Advance just past the existing 343.2 ms arrival + 70 ms compression.
      await tester.pump(const Duration(microseconds: 43201));
      expect(audio.calls, ['tap', 'tap', 'tap', 'tap', 'match']);
      await tester.pump();
      expect(audio.calls, ['tap', 'tap', 'tap', 'tap', 'match']);
      await tester.pumpAndSettle();
      expect(audio.calls, ['tap', 'tap', 'tap', 'tap', 'match']);
      expect(effects.bursts, isEmpty);
      expect(find.byType(MatchedTileVisual), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

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
    await tester.pump(const Duration(milliseconds: 370));
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
    expect(effects.flights.single.reversed, isTrue);
    expect(_board('m3'), findsOneWidget);
    expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);

    tester.widget<GameTileWidget>(_board('m6')).onTap!();
    await tester.pump();
    final newFlight = effects.flights.singleWhere((flight) => !flight.reversed);
    await tester.pump(const Duration(milliseconds: 80));
    // Deliberately deliver callbacks retained from the cancelled animations.
    oldBurstEnd();
    oldFlightEnd();
    await tester.pump();
    expect(effects.bursts, isEmpty);
    expect(find.byType(MatchedTileVisual), findsNothing);
    expect(effects.flights.singleWhere((flight) => !flight.reversed),
        same(newFlight));
    expect(effects.flights.where((flight) => flight.reversed), hasLength(1));
    final visual = tester.widget<TileFlightVisual>(find.byWidgetPredicate(
        (w) => w is TileFlightVisual && w.flight.serial == newFlight.serial));
    expect(visual.progress, closeTo(80 / 440, .000001));
    expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id), ['m6']);
    await tester.pump(const Duration(milliseconds: 361));
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
    expect(audio.calls.where((c) => c == 'match'), isEmpty);
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
    await tester.pump(const Duration(milliseconds: 370));
    expect(find.byType(MatchedTileVisual), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(audio.calls.where((c) => c == 'match'), isEmpty);
    expect(effects.bursts, isEmpty);
    expect(effects.flights, isEmpty);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final endless in [false, true]) {
    testWidgets(
        'endless=$endless: removing an earlier burst preserves the later snapshot clock and both audio cues',
        (tester) async {
      final audio = await _mount(tester, endless: endless, fixedEndless: true);
      for (final id in ['m0', 'm1', 'm2']) {
        tester.widget<GameTileWidget>(_board(id)).onTap!();
        await tester.pump();
      }
      final effects = _effects(tester);
      final first = effects.bursts.single.serial;
      final firstClock = tester.state(find.byKey(ValueKey('burst_$first')));
      await tester.pump(const Duration(milliseconds: 100));
      for (final id in ['m3', 'm4', 'm5']) {
        tester.widget<GameTileWidget>(_board(id)).onTap!();
        await tester.pump();
      }
      final second = effects.bursts.last.serial;
      expect(effects.bursts, hasLength(2));
      _expectBurstClockOnly(first);
      expect(
          tester.state(find.byKey(ValueKey('burst_$first'))), same(firstClock));
      final faces = tester.widgetList<MatchedTileVisual>(
          find.byType(MatchedTileVisual, skipOffstage: false));
      expect(faces, hasLength(3),
          reason: 'Only the current triple owns visual faces.');
      expect(faces.map((v) => v.burst.serial), everyElement(second));
      expect(faces.map((v) => v.face.tile.id).toSet(), {'m3', 'm4', 'm5'});
      expect(
          find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is MatchBurstPainter),
          findsOneWidget);

      // First release is at 343.2 ms arrival + 70 ms compression. The second
      // clock starts 100 ms later. Supersession must neither reset nor skip audio.
      await tester.pump(const Duration(microseconds: 313199));
      expect(audio.calls.where((c) => c == 'match'), isEmpty);
      _expectBurstClockOnly(first);
      await tester.pump(const Duration(microseconds: 2));
      expect(audio.calls.where((c) => c == 'match'), hasLength(1));
      await tester.pump();
      expect(audio.calls.where((c) => c == 'match'), hasLength(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(audio.calls.where((c) => c == 'match'), hasLength(2));
      await tester.pump(const Duration(microseconds: 127799));
      expect(effects.bursts.map((b) => b.serial), [second]);
      expect(effects.bursts.any((b) => b.serial == first), isFalse);
      for (final visual in tester
          .widgetList<MatchedTileVisual>(find.byType(MatchedTileVisual))) {
        expect(visual.burst.serial, second);
        expect(visual.progress, closeTo(541 / 640, .000001));
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(effects.bursts, isEmpty);
      expect(find.byType(MatchedTileVisual), findsNothing);
      await tester.pumpAndSettle();
      expect(_tray(tester).trayTiles.whereType<Tile>(), isEmpty);
      expect(_board(), findsNWidgets(6));
      expect(audio.calls.where((c) => c == 'match'), hasLength(2));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    for (final interruption in ['route', 'background', 'dispose']) {
      testWidgets(
          'endless=$endless: $interruption cancels a superseded audio-only burst',
          (tester) async {
        final audio =
            await _mount(tester, endless: endless, fixedEndless: true);
        for (final id in ['m0', 'm1', 'm2', 'm3']) {
          tester.widget<GameTileWidget>(_board(id)).onTap!();
          await tester.pump();
        }
        final effects = _effects(tester);
        _expectBurstClockOnly(effects.bursts.single.serial);
        expect(audio.calls.where((c) => c == 'match'), isEmpty);
        if (interruption == 'route') {
          final navigator =
              Navigator.of(tester.element(find.byType(GameTileEffects)));
          unawaited(navigator.push<void>(PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, __, ___) =>
                  const Scaffold(body: Text('Away')))));
          await tester.pump();
          expect(effects.bursts, isEmpty);
          navigator.pop();
        } else if (interruption == 'background') {
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          await tester.pump();
          expect(effects.bursts, isEmpty);
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        } else {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        expect(effects.bursts, isEmpty);
        expect(effects.flights, isEmpty);
        expect(
            find.byType(MatchedTileVisual, skipOffstage: false), findsNothing);
        expect(
            find.byType(TileFlightVisual, skipOffstage: false), findsNothing);
        expect(find.byType(TrayShiftVisual, skipOffstage: false), findsNothing);
        expect(audio.calls.where((c) => c == 'match'), isEmpty,
            reason: 'Returning or resuming must not replay a cancelled cue.');
        if (interruption != 'dispose') {
          expect(_tray(tester).trayTiles.whereType<Tile>().map((t) => t.id),
              ['m3']);
          expect(_board(), findsNWidgets(8));
        }
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final endless in [false, true]) {
    testWidgets(
        'endless=$endless: reduced motion never retains matched face snapshots',
        (tester) async {
      final audio = await _mount(tester,
          reduced: true, endless: endless, fixedEndless: true);
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
  }

  testWidgets('navigation during match reaction cancels snapshots permanently',
      (tester) async {
    await _mount(tester);
    for (final id in ['m0', 'm1', 'm2']) {
      tester.widget<GameTileWidget>(_board(id)).onTap!();
      await tester.pump();
    }
    final effects = _effects(tester);
    await tester.pump(const Duration(milliseconds: 370));
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
    expect(progressOf(firstSerial), closeTo(100 / 440, 0.000001),
        reason: 'Starting the second flight must not reset the first clock');
    expect(progressOf(secondSerial), 0);
    await tester.pump(const Duration(milliseconds: 340));
    expect(progressOf(firstSerial), 1);
    expect(progressOf(secondSerial), closeTo(340 / 440, 0.000001));
    // Flutter's interpolation simulation reports completion for elapsed >
    // duration, not elapsed == duration. At exactly 440 ms the first flight
    // paints its endpoint, but onEnd needs the next tick beyond that boundary.
    await tester.pump(const Duration(milliseconds: 1));
    expect(effects.flights, hasLength(1));
    expect(effects.flights.single.serial, secondSerial);
    final paint = tester.widget<CustomPaint>(find.byWidgetPredicate((w) =>
        w is CustomPaint &&
        w.painter is FlightAccentPainter &&
        (w.painter! as FlightAccentPainter).flight.serial == secondSerial));
    expect((paint.painter! as FlightAccentPainter).progress, greaterThan(.6));
    expect(progressOf(secondSerial), closeTo(341 / 440, 0.000001),
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
