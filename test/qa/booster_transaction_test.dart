import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/endless_board_generator.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/booster_transaction.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/endless_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';

List<Tile> tiles() => List.generate(18, (i) => Tile(
    id: 't$i', type: tileCatalog.keys.elementAt(i ~/ 3),
    x: (i % 3) * .3, y: (i ~/ 3) * .15, layer: 0));
class _Levels extends LevelRepository {
  _Levels({this.layout});
  final List<Tile>? layout;

  @override
  Future<LevelDefinition> loadLevel(int level) async => LevelDefinition(
      level: level, name: 'Booster fixture', timeBonusSeconds: 60,
      tiles: layout ?? tiles());
}
class _Boards extends EndlessBoardGenerator {
  _Boards({this.layout});
  final List<Tile>? layout;

  @override
  List<Tile> generate({required int round, required TileVisualTheme theme}) => layout ?? tiles();
}
class _Audio implements GameAudioService {
  @override
  bool sfxEnabled = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
class _Progress extends ProgressRepository {
  Completer<void>? gate;
  bool fail = false;
  int attempts = 0, deductions = 0, effects = 0, refunds = 0;
  final coinDebits = <int>[];
  final coinRefunds = <int>[];
  final inventoryDebits = <BoosterKind>[];
  final inventoryRefunds = <BoosterKind>[];
  final firstMatchGrants = <int>[];
  final matchedBatches = <int>[];

  @override
  Future<void> recordMatchedTiles(int amount, {
    int? level,
    Iterable<String> tileTypes = const <String>[],
  }) async {
    final before = (await achievements())
        .singleWhere((a) => a.definition.id == AchievementId.firstMatch).unlocked;
    final earnedBefore = (await statistics()).totalCoinsEarned;
    await super.recordMatchedTiles(amount, level: level, tileTypes: tileTypes);
    matchedBatches.add(amount);
    final after = (await achievements())
        .singleWhere((a) => a.definition.id == AchievementId.firstMatch).unlocked;
    if (!before && after) {
      firstMatchGrants.add((await statistics()).totalCoinsEarned - earnedBefore);
    }
  }

  Future<bool> debitInventory(BoosterKind kind, Future<bool> Function() action) =>
      debit(() async {
        final used = await action();
        if (used) inventoryDebits.add(kind);
        return used;
      });

  Future<bool> debit(Future<bool> Function() action) async {
    attempts++;
    final held = gate;
    gate = null;
    if (held != null) await held.future;
    if (fail) { fail = false; throw StateError('Before deduction'); }
    final success = await action();
    if (success) deductions++;
    return success;
  }
  @override
  Future<bool> spendCoins(int amount) => debit(() async {
    final spent = await super.spendCoins(amount);
    if (spent) coinDebits.add(amount);
    return spent;
  });
  @override
  Future<bool> useExtraHintBooster() => debitInventory(BoosterKind.hint, super.useExtraHintBooster);
  @override
  Future<bool> useExtraShuffleBooster() => debitInventory(BoosterKind.shuffle, super.useExtraShuffleBooster);
  @override
  Future<bool> useExtraUndoBooster() => debitInventory(BoosterKind.undo, super.useExtraUndoBooster);
  @override
  Future<void> refundBoosterCoins(int amount) async {
    await super.refundBoosterCoins(amount); refunds++; coinRefunds.add(amount);
  }
  @override
  Future<int> addExtraHintBoosters(int amount) async {
    final total = await super.addExtraHintBoosters(amount);
    inventoryRefunds.add(BoosterKind.hint);
    return total;
  }
  @override
  Future<int> addExtraShuffleBoosters(int amount) async {
    final total = await super.addExtraShuffleBoosters(amount);
    inventoryRefunds.add(BoosterKind.shuffle);
    return total;
  }
  @override
  Future<int> addExtraUndoBoosters(int amount) async {
    final total = await super.addExtraUndoBoosters(amount);
    inventoryRefunds.add(BoosterKind.undo);
    return total;
  }
  @override
  Future<void> recordBoosterUsed(BoosterKind kind) async { effects++; }
  @override
  Future<List<PendingAchievementPopup>> consumePendingAchievementPopups() async => [];
}
Finder board() => find.byWidgetPredicate((w) => w is GameTileWidget && !w.trayTile);
String boardState(WidgetTester tester) => tester.widgetList<GameTileWidget>(
    find.byWidgetPredicate((w) => w is GameTileWidget && !w.trayTile,
        skipOffstage: false)).map((w) => '${w.tile.id}:${w.tile.type}:${w.tile.state}').join('|');
Finder booster(String label) => find.byWidgetPredicate((w) => w is GameBoosterButton && w.label == label);
Future<void> tapTile(WidgetTester tester) async {
  tester.widgetList<GameTileWidget>(board()).first.onTap!();
  await tester.pump();
}
Future<void> press(WidgetTester tester, String label) async {
  tester.widget<GameBoosterButton>(booster(label)).onPressed!();
  await tester.pump();
}
Future<int> inventory(_Progress p, String kind) => switch(kind) {
  'Undo' => p.extraUndoBoosters(), 'Hint' => p.extraHintBoosters(),
  _ => p.extraShuffleBoosters(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('coin compensation restores balance without earned-income statistics', () async {
    SharedPreferences.setMockInitialValues({'coins': 500, 'stats_coins_earned': 80});
    final p = ProgressRepository();
    expect(await p.spendCoins(150), isTrue);
    await p.refundBoosterCoins(150);
    expect(await p.coins(), 500);
    expect((await p.statistics()).totalCoinsEarned, 80);
  });
  test('failed refund is recovered before any new debit', () async {
    final transaction = BoosterTransaction();
    var valid = true;
    var paid = 0, refunded = 0, errors = 0, refundAttempts = 0;
    Future<bool> request() => transaction.run(
      free: false,
      pay: () async { paid++; valid = false; return true; },
      refund: () async {
        if (++refundAttempts == 1) throw StateError('Before refund write');
        refunded++;
      },
      valid: () => valid,
      apply: () => throw StateError('Stale action must never execute'),
      onError: (_, __) { errors++; },
    );
    expect(await request(), isFalse);
    expect(paid, 1);
    expect(errors, 1);
    expect(refunded, 0);
    valid = true;
    expect(await request(), isFalse);
    expect(paid, 1);
    expect(refunded, 1);
  });

  for (final endless in [false, true]) {
    for (final exhaustFreeUses in [false, true]) {
      for (final stock in [false, true]) {
        testWidgets('$endless unavailable Hint is quiet, exhausted=$exhaustFreeUses stock=$stock',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(360, 800);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({
            'coins': 500,
            'vibration_enabled': false,
            'level_one_tutorial_seen': true,
            'extra_hint_boosters': stock ? 2 : 0,
          });
          final layout = [
            if (exhaustFreeUses)
              for (var i = 0; i < 6; i++)
                Tile(id: 'match$i', type: i < 3 ? 'apple' : 'banana',
                    x: (i % 3) * .3, y: (i ~/ 3) * .3, layer: 0),
            const Tile(id: 'leaf', type: 'leaf', x: .1, y: .65, layer: 0),
            const Tile(id: 'paper', type: 'shell', x: .5, y: .65, layer: 0),
          ];
          final p = _Progress();
          try {
            await tester.pumpWidget(AppScope(
                progressRepository: p, levelRepository: _Levels(layout: layout),
                audioService: _Audio(),
                child: MaterialApp(theme: GameTheme.theme(),
                    home: endless
                        ? EndlessScreen.forTesting(boardGenerator: _Boards(layout: layout))
                        : const GameScreen(level: 2))));
            await tester.pumpAndSettle();
            if (exhaustFreeUses) {
              for (var i = 0; i < 2; i++) {
                await tester.tap(booster('Hint'));
                await tester.pumpAndSettle();
              }
            }
            final achievementCoins = !endless && exhaustFreeUses ? 50 : 0;
            expect(p.effects, exhaustFreeUses ? 2 : 0);
            expect(p.firstMatchGrants, achievementCoins == 0 ? isEmpty : [50]);
            expect(await p.coins(), 500 + achievementCoins);
            expect(board(), findsNWidgets(2));
            final before = boardState(tester);
            final badge = tester.widget<GameBoosterButton>(booster('Hint')).badge;
            // Real pointer interaction, followed by duplicate same-turn requests.
            await tester.tap(booster('Hint'));
            final callback = tester.widget<GameBoosterButton>(booster('Hint')).onPressed!;
            callback();
            callback();
            await tester.pump();
            expect(find.text('No hint available'), findsNothing);
            expect(find.byType(SnackBar), findsNothing);
            await tester.pumpAndSettle();
            expect(find.byType(SnackBar), findsNothing);
            expect(boardState(tester), before);
            expect(tester.widget<GameTray>(find.byType(GameTray))
                .trayTiles.whereType<Tile>(), isEmpty);
            expect(tester.widget<GameBoosterButton>(booster('Hint')).badge, badge);
            expect(await p.coins(), 500 + achievementCoins);
            expect(await p.extraHintBoosters(), stock ? 2 : 0);
            expect(p.attempts, 0);
            expect(p.deductions, 0);
            expect(p.coinDebits, isEmpty);
            expect(p.inventoryDebits, isEmpty);
            expect(p.coinRefunds, isEmpty);
            expect(p.inventoryRefunds, isEmpty);
            expect(p.effects, exhaustFreeUses ? 2 : 0);
            expect((await p.statistics()).totalCoinsEarned, achievementCoins);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          }
        });
      }
    }

    for (final kind in ['Undo', 'Hint', 'Shuffle']) {
      for (final stock in [false, true]) {
        for (final event in ['duplicate', 'tile', 'dispose', 'navigate', 'replace', 'restart', 'failure',
          if (kind == 'Hint') 'hint_target']) {
          testWidgets('$endless $kind stock=$stock $event', (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(360, 800);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            SharedPreferences.setMockInitialValues({
              'coins': 500, 'vibration_enabled': false,
              'level_one_tutorial_seen': true,
              'extra_${kind.toLowerCase()}_boosters': stock ? 1 : 0,
            });
            final p = _Progress();
            final navigator = GlobalKey<NavigatorState>();
            Widget app({int level = 2, int run = 0}) => AppScope(
              progressRepository: p, levelRepository: _Levels(), audioService: _Audio(),
              child: MaterialApp(navigatorKey: navigator, theme: GameTheme.theme(),
                home: endless
                  ? EndlessScreen.forTesting(key: ValueKey(run), boardGenerator: _Boards())
                  : GameScreen(level: level)));
            await tester.pumpWidget(app());
            await tester.pumpAndSettle();
            for (var i = 0; i < 2; i++) {
              if (kind == 'Undo') await tapTile(tester);
              await press(tester, kind);
              await tester.pumpAndSettle();
            }
            expect(p.effects, 2);
            expect(p.attempts, 0);
            // The first free Campaign Hint matches three tiles and unlocks
            // First Match. Hiding its popup does not remove its real reward.
            final achievementCoins = !endless && kind == 'Hint' ? 50 : 0;
            expect(p.firstMatchGrants, achievementCoins == 0 ? isEmpty : [50]);
            expect(p.matchedBatches, achievementCoins == 0 ? isEmpty : [3, 3]);
            expect((await p.statistics()).totalCoinsEarned, achievementCoins);
            expect(await p.coins(), 500 + achievementCoins);
            expect(p.coinDebits, isEmpty);
            expect(p.inventoryDebits, isEmpty);
            if (kind == 'Hint') {
              expect(tester.widgetList<GameTileWidget>(board()).map((w) => w.tile.id),
                  [for (var i = 0; i < 12; i++) 't$i']);
              expect(tester.widget<GameTray>(find.byType(GameTray))
                  .trayTiles.whereType<Tile>(), isEmpty);
            }
            if (kind == 'Undo') await tapTile(tester);
            final gate = Completer<void>();
            addTearDown(() { if (!gate.isCompleted) gate.complete(); });
            p.gate = gate;
            p.fail = event == 'failure';
            await press(tester, kind);
            expect(p.attempts, 1);
            expect(p.deductions, 0);
            expect(p.effects, 2);
            final beforeBoard = tester.widgetList<GameTileWidget>(board()).length;
            if (event == 'duplicate') {
              await press(tester, kind);
              await press(tester, kind == 'Shuffle' ? 'Hint' : 'Shuffle');
              expect(p.attempts, 1);
              expect(p.effects, 2);
            } else if (event == 'hint_target') {
              // Hint scans reverse paint order. After two setup triples its
              // reserved targets are t11, t10, t9, not the first board tile t0.
              final target = tester.widgetList<GameTileWidget>(board())
                  .singleWhere((w) => w.tile.id == 't11');
              target.onTap!();
              await tester.pump();
              expect(tester.widgetList<GameTileWidget>(board()).length, beforeBoard - 1);
            } else if (event == 'tile') {
              await tapTile(tester);
              expect(tester.widgetList<GameTileWidget>(board()).length, beforeBoard - 1);
            } else if (event == 'dispose') {
              await tester.pumpWidget(const SizedBox.shrink());
            } else if (event == 'navigate') {
              unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Away')))));
              await tester.pumpAndSettle();
            } else if (event == 'restart') {
              if (endless) {
                while (tester.widget<GameTray>(find.byType(GameTray)).trayTiles
                    .whereType<Tile>().length < 7) {
                  final tray = tester.widget<GameTray>(find.byType(GameTray))
                      .trayTiles.whereType<Tile>().toList();
                  final next = tester.widgetList<GameTileWidget>(board()).firstWhere(
                      (w) => tray.where((t) => t.type == w.tile.type).length < 2);
                  next.onTap!();
                  await tester.pump();
                }
                await tester.pumpAndSettle();
                await tester.tap(find.text('Try Again'));
              } else {
                await tester.tap(find.byIcon(Icons.pause_rounded));
                await tester.pumpAndSettle();
                await tester.tap(find.text('Restart Level'));
              }
              await tester.pumpAndSettle();
            } else if (event == 'replace') {
              await tester.pumpWidget(app(level: 3, run: 1));
              await tester.pumpAndSettle();
            }
            final stateAfterInterruption = boardState(tester);
            gate.complete();
            await tester.pumpAndSettle();
            final stale = ['dispose', 'navigate', 'replace', 'restart'].contains(event) ||
                event == 'hint_target' || (event == 'tile' && kind == 'Undo');
            final applied = !stale && event != 'failure';
            expect(p.attempts, 1);
            expect(p.deductions, event == 'failure' ? 0 : 1);
            expect(p.effects, applied ? 3 : 2);
            if (!applied) expect(boardState(tester), stateAfterInterruption);
            if (applied && event == 'duplicate') {
              expect(tester.widgetList<GameTileWidget>(board()).length,
                  beforeBoard + (kind == 'Undo' ? 1 : kind == 'Hint' ? -3 : 0));
            }
            final paid = event != 'failure';
            final refunded = paid && stale;
            final boosterKind = BoosterKind.values.singleWhere(
                (value) => value.name == kind.toLowerCase());
            expect(p.coinDebits, paid && !stock ? [150] : isEmpty);
            expect(p.inventoryDebits, paid && stock ? [boosterKind] : isEmpty);
            expect(p.coinRefunds, refunded && !stock ? [150] : isEmpty);
            expect(p.refunds, refunded && !stock ? 1 : 0);
            expect(p.inventoryRefunds, refunded && stock ? [boosterKind] : isEmpty);
            expect(p.firstMatchGrants, achievementCoins == 0 ? isEmpty : [50]);
            expect(p.matchedBatches,
                achievementCoins == 0 ? isEmpty : [3, 3, if (applied) 3]);
            expect((await p.statistics()).totalCoinsEarned, achievementCoins);
            expect(await p.coins(), 500 + achievementCoins -
                (paid && !stock ? 150 : 0) + (refunded && !stock ? 150 : 0));
            if (kind == 'Hint' && (event == 'tile' || event == 'hint_target')) {
              expect(tester.widget<GameTray>(find.byType(GameTray))
                  .trayTiles.whereType<Tile>().map((t) => t.id),
                  [event == 'tile' ? 't0' : 't11']);
              expect(tester.widgetList<GameTileWidget>(board()).length,
                  beforeBoard - 1 - (applied ? 3 : 0));
              final remaining = tester.widgetList<GameTileWidget>(board())
                  .map((w) => w.tile.id).toSet();
              expect(remaining.contains('t10'), !applied);
              expect(remaining.contains('t9'), !applied);
            }
            expect(await inventory(p, kind), stock && !applied ? 1 : 0);
            if (event == 'replace' || event == 'restart') {
              expect(board(), findsNWidgets(18));
              expect(tester.widget<GameTray>(find.byType(GameTray)).trayTiles.whereType<Tile>(), isEmpty);
            }
            if (event == 'failure') {
              await press(tester, kind);
              await tester.pumpAndSettle();
              expect(p.attempts, 2);
              expect(p.deductions, 1);
              expect(p.effects, 3);
              expect(p.coinDebits, stock ? isEmpty : [150]);
              expect(p.inventoryDebits, stock ? [boosterKind] : isEmpty);
              expect(p.coinRefunds, isEmpty);
              expect(p.inventoryRefunds, isEmpty);
              expect(p.firstMatchGrants, achievementCoins == 0 ? isEmpty : [50]);
              expect(p.matchedBatches, achievementCoins == 0 ? isEmpty : [3, 3, 3]);
              expect((await p.statistics()).totalCoinsEarned, achievementCoins);
              expect(await p.coins(), 500 + achievementCoins - (stock ? 0 : 150));
              expect(await inventory(p, kind), 0);
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          });
        }
      }
    }
  }
}
