import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/presentation/screens/booster_shop_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/daily_challenges_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/lucky_wheel_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/settings_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/treasure_chests_screen.dart';

import 'support/golden_harness.dart';

void main() {
  configureGoldens();

  for (final scenario in <String, Widget>{
    'settings': const SettingsScreen(),
    'shop': const BoosterShopScreen(),
    'daily_challenges': const DailyChallengesScreen(),
    'lucky_wheel_ready': const LuckyWheelScreen(),
    'treasure_chests': const TreasureChestsScreen(),
  }.entries) {
    goldenTest('golden ${scenario.key}', (tester) async {
      await pumpGolden(tester, scenario.value);
      await expectGolden(tester, scenario.key, phone);
      if (scenario.key == 'daily_challenges') {
        await tester.scrollUntilVisible(find.text('Daily Bonus'), 220,
            scrollable: find.byType(Scrollable).first);
        await settleGolden(tester);
        await expectGolden(tester, 'daily_challenges_bonus', phone);
      }
    });
  }

  goldenTest('golden pause from campaign', (tester) async {
    await pumpGolden(tester, const GameScreen(level: 7));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await settleGolden(tester);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume').hitTestable(), findsOneWidget);
    await expectGolden(tester, 'pause', phone);
  });

  goldenTest('golden deterministic chest reward', (tester) async {
    await pumpGolden(tester, const TreasureChestsScreen());
    await revealGolden(tester, find.text('Open'));
    await tester.tap(find.text('Open'));
    await settleGolden(tester);
    expect(find.text('Treasure Chest Opened'), findsOneWidget);
    await expectGolden(tester, 'chest_reward', phone);
  });
}
