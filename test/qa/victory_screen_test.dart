import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/presentation/screens/win_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_ui.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
import 'package:triple_tile_adventure/presentation/widgets/coastal_ui.dart';
import 'package:triple_tile_adventure/presentation/widgets/victory_premium.dart';
import 'package:triple_tile_adventure/presentation/theme/world_theme.dart';

import 'support/geometry.dart';
import 'support/result_layout.dart';

Future<void> mountVictory(
  WidgetTester tester,
  QaScreen screen, {
  int level = 7,
  int stars = 3,
  int coins = 50,
  int xp = 150,
  String? chest = 'Silver Chest',
  bool boss = false,
  bool finalLevel = false,
  double textScale = 1,
  bool reducedMotion = false,
  VoidCallback? next,
  VoidCallback? replay,
  VoidCallback? map,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = screen.size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: GameTheme.theme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: EdgeInsets.only(top: screen.safeTop, bottom: 24),
        viewPadding: EdgeInsets.only(top: screen.safeTop, bottom: 24),
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reducedMotion,
      ),
      child: child!,
    ),
    home: Scaffold(
        body: WinScreen(
      level: level,
      isFinalLevel: finalLevel,
      isBossLevel: boss,
      bossTitle: boss ? 'Garden Boss' : null,
      tilesCleared: 108,
      undoUsed: 1,
      hintUsed: 2,
      shuffleUsed: 0,
      starsEarned: stars,
      coinsEarned: coins,
      xpEarned: xp,
      chestLabel: chest,
      onNext: next ?? () {},
      onRestart: replay ?? () {},
      onMap: map ?? () {},
    )),
  ));
}

void main() {
  for (final screen in qaScreens) {
    for (final kind in ['level', 'boss', 'final']) {
      testWidgets(
          '$kind victory renders rewards and reachable actions on ${screen.name}',
          (tester) async {
        final boss = kind != 'level';
        final finalLevel = kind == 'final';
        final stars = finalLevel
            ? 3
            : boss
                ? 2
                : 1;
        final coins = boss ? 350 : 50;
        final xp = finalLevel
            ? 350
            : boss
                ? 300
                : 100;
        final chest = finalLevel
            ? 'Chest slots full'
            : boss
                ? 'Gold Chest'
                : 'Silver Chest';
        var next = 0;
        var replay = 0;
        var map = 0;
        await mountVictory(tester, screen,
            level: finalLevel
                ? 100
                : boss
                    ? 10
                    : 7,
            stars: stars,
            coins: coins,
            xp: xp,
            chest: chest,
            boss: boss,
            finalLevel: finalLevel,
            next: () => next++,
            replay: () => replay++,
            map: () => map++);
        await tester.pumpAndSettle();

        if (boss) {
          expect(find.text('108 tiles cleared'), findsOneWidget,
              reason: 'Boss and final result statistics remain unchanged');
        } else {
          expect(find.textContaining('tiles cleared'), findsNothing,
              reason: 'Ordinary Campaign results no longer show statistics');
        }

        if (boss) {
          expect(
              find.text(finalLevel ? 'Adventure Complete!' : 'Level Complete!'),
              findsOneWidget);
          expect(find.byType(PremiumVictoryBanner), findsNothing);
        } else {
          final banner = find.byType(PremiumVictoryBanner);
          expect(banner, findsOneWidget);
          final art = tester.widget<Image>(
              find.descendant(of: banner, matching: find.byType(Image)));
          expect(
              (art.image as AssetImage).assetName, VictoryPremiumAssets.banner);
        }
        for (var i = 1; i <= 3; i++) {
          final star = find.byKey(ValueKey('victory_star_$i'));
          if (boss) {
            expect(tester.widget<Icon>(star).icon,
                i <= stars ? Icons.star_rounded : Icons.star_border_rounded);
          } else {
            expect(tester.widget<PremiumVictoryStar>(star).earned, i <= stars);
            final art = tester.widget<Image>(
                find.descendant(of: star, matching: find.byType(Image)));
            expect(
                (art.image as AssetImage).assetName,
                i <= stars
                    ? VictoryPremiumAssets.star
                    : VictoryPremiumAssets.unearnedStar);
          }
        }
        expect(
            tester
                .widget<Text>(
                    find.byKey(const ValueKey('victory_reward_Coins')))
                .data,
            '+$coins');
        expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('victory_reward_XP')))
                .data,
            '+$xp');
        expect(find.text(chest), findsOneWidget);
        if (boss) {
          expect(
              find.byKey(const ValueKey('victory_milestone')), findsOneWidget);
          expect(
              find.text(
                  finalLevel ? 'All worlds complete!' : 'World Complete!'),
              findsOneWidget);
        }

        // Each reward stays readable inside the scroll viewport, independently
        // of the pinned actions below it, including the shortest profile.
        for (final key in [
          'victory_reward_Coins',
          'victory_reward_XP',
          'victory_chest'
        ]) {
          final detail = find.byKey(ValueKey(key));
          await tester.ensureVisible(detail);
          await tester.pumpAndSettle();
          final scrollBounds = tester
              .getRect(find.byKey(const ValueKey('victory_scroll')))
              .inflate(0.01);
          final detailBounds = tester.getRect(detail);
          expect(
              scrollBounds.contains(detailBounds.topLeft) &&
                  scrollBounds.contains(detailBounds.bottomRight),
              isTrue,
              reason: '$key must be fully readable by scrolling');
        }
        final viewport = Rect.fromLTWH(0, screen.safeTop, screen.size.width,
                screen.size.height - screen.safeTop - 24)
            .inflate(0.01);
        for (final key in ['victory_next', 'victory_replay', 'victory_map']) {
          final button = find.byKey(ValueKey(key));
          final rect = tester.getRect(button);
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(
              viewport.contains(rect.topLeft) &&
                  viewport.contains(rect.bottomRight),
              isTrue,
              reason: '$key must stay reachable without scrolling');
          await tester.tap(button);
          await tester.pumpAndSettle();
        }
        expect([next, replay, map], [1, 1, 1]);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('large text keeps victory rewards readable on ${screen.name}',
        (tester) async {
      await mountVictory(tester, screen,
          textScale: 1.4,
          coins: 1234567,
          xp: 350,
          chest: 'Gold Chest added to your chest slots');
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const ValueKey('victory_reward_Coins')));
      await tester.pumpAndSettle();
      expect(find.text('+1234567'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('victory_chest')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final screen in qaScreens) {
    for (final scale in [1.0, 1.6, 2.0]) {
      for (final reducedMotion in [false, true]) {
        for (final finalLevel in [false, true]) {
          testWidgets(
              'result text and actions stay separated ${screen.name} / $scale / '
              'reduced=$reducedMotion / final=$finalLevel', (tester) async {
            var next = 0;
            var replay = 0;
            var map = 0;
            await mountVictory(tester, screen,
                level: finalLevel ? 100 : 10,
                boss: true,
                finalLevel: finalLevel,
                textScale: scale,
                reducedMotion: reducedMotion,
                next: () => next++,
                replay: () => replay++,
                map: () => map++);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final scroll = find.byKey(const ValueKey('victory_scroll'));
            final primary = find.byKey(const ValueKey('victory_next'));
            final primaryBounds = resultGlobalRect(tester, primary);
            expectVictoryContentSeparated(tester);

            // Read each full paragraph, including the longer final-world copy.
            // Real-font initial framing is additionally asserted by goldens.
            for (final key in [
              'victory_description',
              'victory_milestone_title',
              'victory_milestone_description',
              'victory_reward_Coins',
              'victory_reward_XP',
              'victory_chest',
            ]) {
              await tester.ensureVisible(find.byKey(ValueKey(key)));
              await tester.pumpAndSettle();
              expectResultTextVisible(tester, key, 'victory_scroll');
              if (key == 'victory_description') {
                expectVictoryDescriptionVisible(tester);
              }
              expectVictoryContentSeparated(tester);
              expect(resultGlobalRect(tester, primary), primaryBounds);
              expect(tester.takeException(), isNull);
            }

            if (screen.size.height == 568 && scale == 2) {
              final state = tester.state<ScrollableState>(find.descendant(
                  of: scroll, matching: find.byType(Scrollable)));
              expect(state.position.maxScrollExtent, greaterThan(0));
              await tester.drag(scroll, const Offset(0, 120));
              await tester.pumpAndSettle();
              final before = state.position.pixels;
              await tester.drag(scroll, const Offset(0, -80));
              await tester.pumpAndSettle();
              expect(state.position.pixels, greaterThan(before),
                  reason: 'A real gesture must move the content.');
              expect(resultGlobalRect(tester, primary), primaryBounds);
            }

            final safeBounds = Rect.fromLTRB(
                0, screen.safeTop, screen.size.width, screen.size.height - 24);
            for (final key in [
              'victory_next',
              'victory_replay',
              'victory_map'
            ]) {
              final action = find.byKey(ValueKey(key));
              await tester.ensureVisible(action);
              await tester.pumpAndSettle();
              expect(action.hitTestable(), findsOneWidget);
              final bounds = resultGlobalRect(tester, action);
              expectResultInside(safeBounds, bounds, '$key must be reachable');
              expectResultInside(
                  bounds,
                  resultGlobalRect(tester,
                      find.descendant(of: action, matching: find.byType(Text))),
                  '$key must contain its complete scaled label');
              expectVictoryContentSeparated(tester);
              await tester.tap(action);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            expect([next, replay, map], [1, 1, 1]);
          });
        }
      }
    }
  }

  testWidgets('stars reveal once and announce their earned count',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await mountVictory(tester, qaScreens.first);
      final stars = find.byType(VictoryStars);
      await tester.ensureVisible(stars);
      await tester.pump(const Duration(milliseconds: 400));
      final fades = find.descendant(of: stars, matching: find.byType(Opacity));
      expect(tester.widget<Opacity>(fades.first).opacity,
          allOf(greaterThan(0), lessThan(1)));
      await tester.pumpAndSettle();
      expect(tester.widgetList<Opacity>(fades).every((w) => w.opacity == 1),
          isTrue);
      expect(find.bySemanticsLabel('3 of 3 stars'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      // Dispose before Flutter's end-of-test semantics handle verification.
      semantics.dispose();
    }
  });

  testWidgets(
      'reduced motion finishes stars immediately and missing chest is omitted',
      (tester) async {
    await mountVictory(tester, qaScreens.first,
        chest: null, reducedMotion: true);
    await tester.pumpAndSettle();
    final fades = find.descendant(
        of: find.byType(VictoryStars), matching: find.byType(Opacity));
    expect(
        tester.widgetList<Opacity>(fades).every((w) => w.opacity == 1), isTrue);
    expect(find.byKey(const ValueKey('victory_chest')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final level in [1, 11, 21, 31, 41, 51, 61, 71, 81, 91]) {
    testWidgets(
        'victory carries its world identity in the coastal design for level $level',
        (tester) async {
      await mountVictory(tester, qaScreens[1], level: level);
      await tester.pumpAndSettle();
      expect(find.byType(CoastalBackdrop), findsOneWidget);
      expect(find.byKey(const ValueKey('victory_world')), findsNothing);
      expect(find.byKey(const ValueKey('victory_description')), findsNothing);
      expect(
          find.bySemanticsLabel(
              '${WorldThemes.forLevel(level).worldName}, level $level'),
          findsOneWidget,
          reason: 'World and level remain accessible without visible copy');
      final primary = tester.widget<PremiumVictoryButton>(
          find.byKey(const ValueKey('victory_next')));
      expect(primary.primary, isTrue);
      expect(primary.symbol, VictoryActionSymbol.play);
      expect(primary.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bounded badges wrap their content without overflowing the panel',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Center(
      child: SizedBox(
          width: 150,
          child: GameBadge(
            icon: Icons.flag_rounded,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Levels completed', maxLines: 3),
              Text('100'),
            ]),
          )),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('polished booster shell preserves enabled and disabled callbacks',
      (tester) async {
    var taps = 0;
    Future<void> show(VoidCallback? action) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 100,
                      child: GameBoosterButton(
                        onPressed: action,
                        action: BoosterAction.undo,
                        label: 'Undo',
                        badge: 'x2',
                      )))),
        ));
    await show(() => taps++);
    await tester.tap(find.byType(GameBoosterButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
    final button = find.byType(GameBoosterButton);
    final enabledBounds = tester.getRect(button);
    final label = find.descendant(of: button, matching: find.text('x2'));
    final labelBounds = tester.getRect(label);
    final labelParagraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)));
    expect(enabledBounds.height, greaterThanOrEqualTo(64));
    expect(labelParagraph.didExceedMaxLines, isFalse);
    expect(enabledBounds.contains(labelBounds.topLeft), isTrue);
    expect(enabledBounds.contains(labelBounds.bottomRight), isTrue);
    await show(null);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(64));
    await tester.tap(find.byType(GameBoosterButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
