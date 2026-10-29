import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/presentation/screens/endless_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_effects.dart';

import 'support/golden_fixtures.dart';
import 'support/golden_harness.dart';

Finder get _boardTiles => find.byWidgetPredicate(
    (widget) => widget is GameTileWidget && !widget.trayTile);

void _expectBoard(WidgetTester tester, int round) {
  expect(_boardTiles, findsWidgets);
  final tray = tester.widget<GameTray>(find.byType(GameTray));
  expect(tray.trayTiles.length, GameEngine.trayLimit);
  for (final label in ['Undo', 'Hint', 'Shuffle']) {
    final button = find.byWidgetPredicate(
        (w) => w is GameBoosterButton && w.label == label && w.badge == 'x2');
    expect(button, findsOneWidget);
    expect(
        find.descendant(of: button, matching: find.text('x2')), findsOneWidget);
  }
  final trayBounds = goldenGlobalRect(tester, find.byType(GameTray));
  final tileBounds = goldenGlobalRect(tester, _boardTiles.last);
  if (trayPlacementForRound(round) == TrayPlacement.top) {
    expect(trayBounds.bottom, lessThanOrEqualTo(tileBounds.top));
  } else {
    expect(trayBounds.top, greaterThanOrEqualTo(tileBounds.bottom));
  }
}

void main() {
  configureGoldens();

  for (final level in [7, 10]) {
    goldenTest('golden campaign level $level', (tester) async {
      await pumpGolden(tester, GameScreen(level: level));
      _expectBoard(tester, level);
      final definition = await GoldenLevels().loadLevel(level);
      expect(_boardTiles, findsNWidgets(definition.tiles.length));
      await expectGolden(tester, 'campaign_level_$level', phone);

      if (level == 7) {
        // One legal, deterministic move on the real board, not a random play
        // session. Last painted enabled tile is unobscured by later tiles.
        final enabled = find.byWidgetPredicate((widget) =>
            widget is GameTileWidget &&
            !widget.trayTile &&
            widget.enabled &&
            !widget.blocked);
        final selectedId = tester.widget<GameTileWidget>(enabled.last).tile.id;
        await tester.tap(enabled.last);
        await settleGolden(tester);
        final tray = tester.widget<GameTray>(find.byType(GameTray));
        expect(tray.trayTiles.where((tile) => tile != null).length, 1);
        expect(tray.trayTiles.first!.id, selectedId);
        expect(find.byType(EmptyTraySlot), findsNWidgets(6));
        await expectGolden(tester, 'campaign_occupied_tray', phone);
      }
    });
  }

  goldenTest('golden campaign small viewport', (tester) async {
    await pumpGolden(tester, const GameScreen(level: 7), viewport: smallPhone);
    _expectBoard(tester, 7);
    await expectGolden(tester, 'campaign_level_7', smallPhone);
  });

  for (final scenario in [
    (round: 1, viewport: phone),
    (round: 14, viewport: phone),
    (round: 1, viewport: smallPhone),
    (round: 14, viewport: largePhone),
  ]) {
    goldenTest(
        'golden endless round ${scenario.round} ${scenario.viewport.suffix}',
        (tester) async {
      await pumpGolden(
          tester,
          EndlessScreen.forTesting(
            initialRound: scenario.round,
            boardGenerator: goldenEndlessGenerator(),
          ),
          viewport: scenario.viewport);
      _expectBoard(tester, scenario.round);
      expect(find.byType(EmptyTraySlot), findsNWidgets(7));
      await expectGolden(
          tester, 'endless_round_${scenario.round}', scenario.viewport);
    });
  }
}
