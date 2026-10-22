import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/presentation/screens/main_menu_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/map_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/world_selection_screen.dart';
import 'package:triple_tile_adventure/presentation/widgets/adventure_level_node.dart';

import 'support/golden_harness.dart';

void main() {
  configureGoldens();

  goldenTest('golden home and world selection via Adventure', (tester) async {
    await pumpGolden(tester, const MainMenuScreen(), routes: {
      WorldSelectionScreen.route: (_) => const WorldSelectionScreen(),
    });
    expect(find.text('1250'), findsOneWidget);
    expect(find.text('Adventure'), findsOneWidget);
    expect(find.text('Endless Mode'), findsOneWidget);
    await expectGolden(tester, 'home', phone);

    await revealGolden(tester, find.text('Booster Shop'));
    await expectGolden(tester, 'home_navigation', phone);

    await revealGolden(tester, find.text('Adventure'));
    await tester.tap(find.text('Adventure'));
    await settleGolden(tester);
    expect(find.byType(WorldSelectionScreen), findsOneWidget);
    await expectGolden(tester, 'world_selection', phone);
  });

  for (final viewport in [smallPhone, largePhone]) {
    goldenTest('golden home ${viewport.suffix}', (tester) async {
      await pumpGolden(tester, const MainMenuScreen(), viewport: viewport);
      await expectGolden(tester, 'home', viewport);
    });
  }

  goldenTest('golden primary navigation at text 2.0', (tester) async {
    await pumpGolden(tester, const MainMenuScreen(), viewport: smallLargeText);
    await revealGolden(tester, find.text('Endless Mode'));
    await expectGolden(tester, 'home_primary_actions', smallLargeText);
  });

  for (final viewport in [phone, smallPhone, largePhone]) {
    goldenTest('golden map current completed locked ${viewport.suffix}',
        (tester) async {
      await pumpGolden(tester, MapScreen(world: gameWorlds.first),
          viewport: viewport);
      final nodes = tester
          .widgetList<AdventureLevelNode>(find.byType(AdventureLevelNode));
      expect(nodes.singleWhere((node) => node.level == 5).current, isTrue);
      expect(nodes.singleWhere((node) => node.level == 4).completed, isTrue);
      expect(nodes.singleWhere((node) => node.level == 6).unlocked, isFalse);
      await expectGolden(tester, 'map_current', viewport);
    });
  }

  goldenTest('golden map boss destination', (tester) async {
    await pumpGolden(tester, MapScreen(world: gameWorlds.first));
    final boss = find.byWidgetPredicate(
        (widget) => widget is AdventureLevelNode && widget.level == 10);
    await revealGolden(tester, boss);
    expect(tester.widget<AdventureLevelNode>(boss).boss, isTrue);
    await expectGolden(tester, 'map_boss_locked', phone);
  });
}
