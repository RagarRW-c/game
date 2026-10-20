import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/presentation/screens/win_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_ui.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
import 'package:triple_tile_adventure/presentation/widgets/world_atmosphere.dart';

import 'support/geometry.dart';

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

        expect(
            find.text(finalLevel ? 'Adventure Complete!' : 'Level Complete!'),
            findsOneWidget);
        for (var i = 1; i <= 3; i++) {
          final icon =
              tester.widget<Icon>(find.byKey(ValueKey('victory_star_$i')));
          expect(icon.icon,
              i <= stars ? Icons.star_rounded : Icons.star_border_rounded);
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
      expect(
          tester.widgetList<Opacity>(fades).every((w) => w.opacity == 1), isTrue);
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
    testWidgets('victory carries its world palette for level $level',
        (tester) async {
      await mountVictory(tester, qaScreens[1], level: level);
      await tester.pumpAndSettle();
      final background =
          tester.widget<GameBackground>(find.byType(GameBackground));
      final atmosphere =
          tester.widget<WorldAtmosphere>(find.byType(WorldAtmosphere));
      expect(background.worldTheme!.tileTheme, tileVisualThemeForLevel(level));
      expect(atmosphere.theme, background.worldTheme);
      final primary =
          tester.widget<GameButton>(find.byKey(const ValueKey('victory_next')));
      expect((primary.gradient! as LinearGradient).colors,
          background.worldTheme!.actionGradient.colors);
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
                        icon: const Icon(Icons.undo_rounded),
                        label: 'Undo',
                        badge: 'x2',
                        accent: Colors.teal,
                      )))),
        ));
    await show(() => taps++);
    await tester.tap(find.byType(GameBoosterButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.getSize(find.byType(GameBoosterButton)).height, 64);
    await show(null);
    await tester.tap(find.byType(GameBoosterButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
