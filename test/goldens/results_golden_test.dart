import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/presentation/screens/win_screen.dart';
import 'package:triple_tile_adventure/presentation/widgets/achievement_reward_dialog.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_over_dialog.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_ui.dart';

import 'support/golden_harness.dart';
import '../qa/support/result_layout.dart';

Future<void> _openResult(
    WidgetTester tester, Widget result, GoldenViewport viewport) async {
  // Production result widgets on the production background, without replaying
  // a win/loss or requiring unrelated gameplay layout at large text scales.
  await pumpGolden(
      tester, const Scaffold(body: GameBackground(child: SizedBox.expand())),
      viewport: viewport);
  unawaited(showDialog<void>(
    context: tester.element(find.byType(GameBackground)),
    barrierDismissible: false,
    builder: (_) => result,
  ));
  await settleGolden(tester);
}

void main() {
  configureGoldens();

  for (final viewport in [smallPhone, phone, largePhone]) {
    goldenTest('golden compact Campaign victory ${viewport.suffix}',
        (tester) async {
      await _openResult(
          tester,
          WinScreen(
            level: 7,
            isFinalLevel: false,
            tilesCleared: 42,
            undoUsed: 0,
            hintUsed: 1,
            shuffleUsed: 0,
            starsEarned: 3,
            coinsEarned: 50,
            xpEarned: 150,
            chestLabel: 'Silver Chest',
            onNext: () {},
            onRestart: () {},
            onMap: () {},
          ),
          viewport);
      final scroll = find.byKey(const ValueKey('victory_scroll'));
      final position = tester
          .state<ScrollableState>(
              find.descendant(of: scroll, matching: find.byType(Scrollable)))
          .position;
      expect(position.maxScrollExtent, closeTo(0, .01));
      for (final key in [
        'victory_cat_frame',
        'victory_title',
        'victory_reward_Coins',
        'victory_reward_XP',
        'victory_chest',
        'victory_next',
        'victory_replay',
        'victory_map'
      ]) {
        expectResultInside(
            resultGlobalRect(tester, scroll),
            resultGlobalRect(tester, find.byKey(ValueKey(key))),
            '$key must be visible together with the celebration');
      }
      // Desktop/reduced-motion uses the existing deterministic trophy fallback.
      // Native cat playback is covered by victory_video_test's fake platform.
      await expectGolden(tester, 'victory_campaign_compact', viewport);
    });
  }

  for (final viewport in [phone, smallLargeText]) {
    goldenTest('golden victory rewards ${viewport.suffix}', (tester) async {
      await _openResult(
          tester,
          WinScreen(
            level: 10,
            isFinalLevel: false,
            isBossLevel: true,
            bossTitle: 'Garden Boss',
            tilesCleared: 108,
            undoUsed: 0,
            hintUsed: 0,
            shuffleUsed: 0,
            starsEarned: 3,
            coinsEarned: 350,
            xpEarned: 300,
            chestLabel: 'Gold Chest',
            onNext: () {},
            onRestart: () {},
            onMap: () {},
          ),
          viewport);
      expect(find.text('Level Complete!'), findsOneWidget);
      expect(find.text('+350'), findsOneWidget);
      expect(find.byKey(const ValueKey('victory_next')).hitTestable(),
          findsOneWidget);
      // A passing pixel comparison cannot excuse a clipped boss description.
      // Check its full paragraph before scrolling or capturing the initial view.
      expectVictoryDescriptionVisible(tester);
      await expectGolden(tester, 'victory_boss', viewport);
      if (viewport == phone) {
        await revealGolden(tester, find.byKey(const ValueKey('victory_chest')));
        await expectGolden(tester, 'victory_rewards', viewport);
      }
      if (viewport == smallLargeText) {
        await revealGolden(tester, find.byKey(const ValueKey('victory_map')));
        final scroll = resultGlobalRect(
            tester, find.byKey(const ValueKey('victory_scroll')));
        for (final key in ['victory_replay', 'victory_map']) {
          final action = find.byKey(ValueKey(key));
          expectResultInside(scroll, resultGlobalRect(tester, action),
              'Secondary navigation must be fully visible after scrolling');
          expect(action.hitTestable(), findsOneWidget);
        }
        expectVictoryContentSeparated(tester);
        await expectGolden(tester, 'victory_secondary_actions', viewport);
      }
    });
  }

  for (final viewport in [phone, smallPhone, largeText]) {
    goldenTest('golden game over ${viewport.suffix}', (tester) async {
      await _openResult(
          tester,
          GameOverDialog(
            canUseShuffle: true,
            onRestart: () {},
            onUseShuffle: () {},
            onBackToMap: () {},
          ),
          viewport);
      expect(find.text('Game Over'), findsOneWidget);
      if (viewport == largeText) {
        await revealGolden(
            tester, find.byKey(const ValueKey('game_over_restart')));
      }
      await expectGolden(tester, 'game_over', viewport);
    });
  }

  for (final viewport in [phone, smallLargeText]) {
    goldenTest('golden achievement ${viewport.suffix}', (tester) async {
      // Use the actual popup content; its three-second auto-dismiss wrapper
      // is exercised by existing QA, not allowed to race a screenshot.
      await _openResult(
          tester,
          AchievementRewardDialog(
            definition: ProgressRepository.achievementsCatalog[2],
            onClose: () {},
          ),
          viewport);
      expect(find.text('Complete Garden World'), findsOneWidget);
      expectAchievementArtworkVisible(tester);
      expectResultTextVisible(
          tester, 'achievement_heading', 'achievement_scroll');
      if (viewport == smallLargeText) {
        await expectGolden(tester, 'achievement_header', viewport);
        await revealGolden(
            tester, find.byKey(const ValueKey('achievement_reward')));
      }
      expectAchievementArtworkVisible(tester);
      if (viewport == smallLargeText) {
        expectResultTextVisible(
            tester, 'achievement_name', 'achievement_scroll');
        expectResultInside(
            resultGlobalRect(
                tester, find.byKey(const ValueKey('achievement_scroll'))),
            resultGlobalRect(
                tester, find.byKey(const ValueKey('achievement_reward_badge'))),
            'The complete reward badge must stay visible');
      }
      await expectGolden(tester, 'achievement_unlocked', viewport);
    });
  }
}
