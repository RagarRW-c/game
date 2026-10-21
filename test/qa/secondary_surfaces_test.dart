import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/booster_shop_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/daily_challenges_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/lucky_wheel_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/settings_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/treasure_chests_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_ui.dart';

class _SilentAudio implements GameAudioService {
  @override
  Future<void> playChestOpen() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProgressRepository> _mount(
  WidgetTester tester,
  Widget home, {
  required Size size,
  required double textScale,
  bool reducedMotion = false,
  ProgressRepository? repository,
  bool resetPrefs = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (resetPrefs) SharedPreferences.setMockInitialValues({});
  final progress = repository ?? ProgressRepository();
  await tester.pumpWidget(AppScope(
    progressRepository: progress,
    levelRepository: LevelRepository(),
    audioService: _SilentAudio(),
    child: MaterialApp(
      theme: GameTheme.theme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
          padding: const EdgeInsets.only(top: 24, bottom: 24),
          viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
        ),
        child: child!,
      ),
      home: home,
    ),
  ));
  await tester.pumpAndSettle();
  return progress;
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 220,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> _scrollDialogActionIntoView(
    WidgetTester tester, Finder action) async {
  final scroll = find.byKey(const ValueKey('game_dialog_content_scroll'));
  // At large text sizes an action may be taller than the viewport. Aligning
  // its top with ensureVisible can leave its centre outside the hit-test area.
  // Use ordinary drags towards the action's centre, just as a player would.
  for (var attempt = 0;
      attempt < 30 && action.hitTestable().evaluate().isEmpty;
      attempt++) {
    final viewport = tester.getRect(scroll);
    expect(viewport.height, greaterThan(0));
    final delta = (viewport.center.dy - tester.getCenter(action).dy)
        .clamp(-80.0, 80.0)
        .toDouble();
    await tester.drag(scroll, Offset(0, delta));
    await tester.pumpAndSettle();
  }
  expect(action.hitTestable(), findsOneWidget,
      reason: 'A real scroll gesture must expose the action for tapping.');
}

void main() {
  const sizes = [Size(320, 568), Size(360, 800), Size(412, 915)];
  for (final size in sizes) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('dialog actions fit $size at $scale', (tester) async {
        await _mount(tester, Scaffold(body: Builder(builder: (context) {
          return TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => GameDialogFrame(
                title: 'A Wonderfully Long Reward Heading',
                onClose: () => Navigator.of(context).pop(),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Earned 300 coins and a Silver Chest'),
                  for (var i = 0; i < 3; i++) ...[
                    const SizedBox(height: 18),
                    GameButton(
                      key: ValueKey('action_$i'),
                      label: 'Collect the daily challenge reward',
                      wrapLabel: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ]),
              ),
            ),
            child: const Text('Open'),
          );
        })), size: size, textScale: scale);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final title =
            tester.getRect(find.text('A Wonderfully Long Reward Heading'));
        final closeButton = find.byKey(const ValueKey('game_dialog_close'));
        final close = tester.getRect(closeButton);
        expect(title.overlaps(close), isFalse);
        for (var i = 0; i < 3; i++) {
          final button = find.byKey(ValueKey('action_$i'));
          await _scrollDialogActionIntoView(tester, button);
          expect(button.hitTestable(), findsOneWidget);
          final label =
              find.descendant(of: button, matching: find.byType(Text));
          final paragraph = tester.renderObject<RenderParagraph>(label);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(tester.getRect(button).contains(tester.getRect(label).center),
              isTrue);
          expect(tester.takeException(), isNull);
        }
        expect(closeButton.hitTestable(), findsOneWidget,
            reason:
                'The dialog close control must stay visible while scrolling.');
        await tester.tap(closeButton);
        await tester.pumpAndSettle();
        expect(find.text('A Wonderfully Long Reward Heading'), findsNothing);

        // Verify the primary callback as well as the separate Close callback.
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final primary = find.byKey(const ValueKey('action_0'));
        await _scrollDialogActionIntoView(tester, primary);
        await tester.tap(primary);
        await tester.pumpAndSettle();
        expect(find.text('A Wonderfully Long Reward Heading'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('secondary screens scroll without overflow $size at $scale',
          (tester) async {
        for (final screen in [
          const BoosterShopScreen(),
          const DailyChallengesScreen(),
          const SettingsScreen(),
          const TreasureChestsScreen(),
          const LuckyWheelScreen(),
        ]) {
          await _mount(tester, screen, size: size, textScale: scale);
          expect(tester.takeException(), isNull,
              reason: '${screen.runtimeType} initial layout at $size / $scale');
          if (screen is DailyChallengesScreen) {
            final listViewport = tester.getRect(find.byType(Scrollable).first);
            expect(listViewport.height, greaterThanOrEqualTo(48),
                reason:
                    'The header must leave usable space for claim actions.');
          }
          if (screen is LuckyWheelScreen) {
            expect(find.text('Shuffle'), findsOneWidget);
            expect(
              find.byWidgetPredicate((widget) =>
                  widget is Semantics &&
                  widget.properties.label == '+1 Shuffle booster'),
              findsOneWidget,
            );
          }
          final scrollable = find.byType(Scrollable).first;
          await tester.drag(scrollable, const Offset(0, -900));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason:
                  '${screen.runtimeType} scrolled layout at $size / $scale');
        }
      });
    }
  }

  testWidgets('shop confirmation preserves coins on cancel and grants once',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final progress = ProgressRepository();
    await progress.addCoins(400);
    await _mount(tester, const BoosterShopScreen(),
        size: const Size(360, 800),
        textScale: 1,
        repository: progress,
        resetPrefs: false);
    final undo = find.widgetWithText(GameButton, '100');
    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(find.text('Confirm Purchase'), findsOneWidget);
    final underlyingUndo = find.byWidgetPredicate(
        (widget) => widget is GameButton && widget.label == '100',
        skipOffstage: false);
    expect(tester.widget<GameButton>(underlyingUndo).onPressed, isNull,
        reason: 'The shop must reject another purchase while confirming.');
    expect(await progress.coins(), 400);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await progress.coins(), 400);
    expect(await progress.extraUndoBoosters(), 0);
    await tester.tap(undo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy for 100 coins'));
    await tester.pumpAndSettle();
    expect(await progress.coins(), 300);
    expect(await progress.extraUndoBoosters(), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unearned daily challenges keep claim actions disabled',
      (tester) async {
    await _mount(tester, const DailyChallengesScreen(),
        size: const Size(360, 800), textScale: 1.6);
    final claims =
        tester.widgetList<GameButton>(find.widgetWithText(GameButton, 'Claim'));
    expect(claims, isNotEmpty);
    for (final claim in claims) {
      expect(claim.onPressed, isNull);
    }
    await _scrollTo(tester, find.text('Daily Bonus'));
    expect(find.text('Daily Bonus'), findsOneWidget);
    final bonus = find.widgetWithText(GameButton, 'Claim Bonus');
    await _scrollTo(tester, bonus);
    expect(tester.widget<GameButton>(bonus).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings info navigation and reduced-motion dialog',
      (tester) async {
    await _mount(tester, const SettingsScreen(),
        size: const Size(320, 568), textScale: 2, reducedMotion: true);
    await _scrollTo(tester, find.text('Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy coming soon'), findsOneWidget);
    final infoBack = find.byIcon(Icons.arrow_back_rounded);
    expect(infoBack.hitTestable(), findsOneWidget);
    await tester.tap(infoBack);
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Reset Progress'));
    await tester.tap(find.text('Reset Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Progress?'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Progress?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('instant chest confirmation cancels safely and opens once',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final progress = ProgressRepository();
    await progress.addCoins(400);
    await progress.grantChestForLevel(1);
    await _mount(tester, const TreasureChestsScreen(),
        size: const Size(320, 568),
        textScale: 2,
        repository: progress,
        resetPrefs: false);
    final openNow = find.text('Open Now 50');
    await _scrollTo(tester, openNow);
    expect(openNow.hitTestable(), findsOneWidget);
    await tester.tap(openNow);
    await tester.pumpAndSettle();
    expect(find.text('Open Chest Now?'), findsOneWidget);
    expect(await progress.coins(), 400);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect((await progress.treasureChests()).length, 1);
    await _scrollTo(tester, openNow);
    expect(openNow.hitTestable(), findsOneWidget);
    await tester.tap(openNow);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open Now').last);
    await tester.tap(find.text('Open Now').last);
    await tester.pumpAndSettle();
    expect(find.text('Treasure Chest Opened'), findsOneWidget);
    expect((await progress.treasureChests()).length, 0);
    final collect = find.widgetWithText(GameButton, 'Collect');
    await tester.ensureVisible(collect);
    await tester.pumpAndSettle();
    expect(collect.hitTestable(), findsOneWidget);
    await tester.tap(collect);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
