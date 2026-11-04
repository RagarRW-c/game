import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/achievement_popup.dart';
import 'package:triple_tile_adventure/presentation/widgets/achievement_reward_dialog.dart';

import 'support/geometry.dart';
import 'support/result_layout.dart';

const _short = AchievementDefinition(
  id: AchievementId.firstMatch,
  name: 'First Match',
  description: 'Clear your first set of 3 matching tiles.',
  reward: 50,
);
const _long = AchievementDefinition(
  id: AchievementId.firstMatch,
  name: 'Champion of Every World and Master of a Thousand Matches',
  description: 'Long-name layout fixture.',
  reward: 12345,
);

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  QaScreen screen = const QaScreen('small', Size(320, 568), 24),
  double textScale = 1,
  bool reducedMotion = false,
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
    home: Scaffold(body: child),
  ));
}

void main() {
  for (final screen in qaScreens) {
    for (final scale in [1.0, 1.6, 2.0]) {
      for (final definition in [_short, _long]) {
        testWidgets(
            '${screen.name} / $scale / ${definition.name}: readable, scrollable reward',
            (tester) async {
          var closed = 0;
          await _mount(
              tester,
              AchievementRewardDialog(
                definition: definition,
                onClose: () => closed++,
              ),
              screen: screen,
              textScale: scale);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final heading = find.byKey(const ValueKey('achievement_heading'));
          final close = find.byKey(const ValueKey('achievement_close'));
          final scroll = find.byKey(const ValueKey('achievement_scroll'));
          final viewport = tester.getRect(scroll);
          final panel =
              tester.getRect(find.byKey(const ValueKey('achievement_panel')));
          expect(panel.left, greaterThanOrEqualTo(16));
          expect(panel.right, lessThanOrEqualTo(screen.size.width - 16));
          expect(panel.top, greaterThanOrEqualTo(screen.safeTop));
          expect(panel.bottom, lessThanOrEqualTo(screen.size.height - 24));
          expect(tester.getSize(close), const Size(48, 48));
          final closeBounds = tester.getRect(close);
          expect(closeBounds.overlaps(tester.getRect(heading)), isFalse);
          expect(closeBounds.bottom, lessThanOrEqualTo(viewport.top));
          final title = tester.widget<Text>(heading);
          expect(title.textSpan!.toPlainText(), 'Achievement\nUnlocked!');
          expect(title.semanticsLabel, 'Achievement Unlocked!');
          final titleBounds = tester.getRect(heading);
          expect(titleBounds.top, greaterThanOrEqualTo(viewport.top));
          expect(titleBounds.bottom, lessThanOrEqualTo(viewport.bottom));
          expectAchievementArtworkVisible(tester);
          final artworkBounds = resultGlobalRect(
              tester, find.byKey(const ValueKey('achievement_trophy')));
          if (definition == _long && scale == 2) {
            final state = tester.state<ScrollableState>(
                find.descendant(of: scroll, matching: find.byType(Scrollable)));
            expect(state.position.maxScrollExtent, greaterThan(0),
                reason: 'Oversized titles and rewards must remain scrollable.');
          }

          for (final key in [
            'achievement_heading',
            'achievement_name',
            'achievement_reward'
          ]) {
            final text = find.byKey(ValueKey(key));
            await tester.ensureVisible(text);
            await tester.pumpAndSettle();
            // Text can wrap its paragraph in Semantics when semanticsLabel
            // is set. Read the RichText render object, not that wrapper.
            final richText = find.descendant(
              of: text,
              matching: find.byType(RichText),
            );
            expect(richText, findsOneWidget,
                reason: '$key must render one text paragraph');
            final paragraph = tester.renderObject<RenderParagraph>(richText);
            expect(paragraph.didExceedMaxLines, isFalse,
                reason: '$key must not truncate');
            final bounds = tester.getRect(text);
            expect(bounds.left, greaterThanOrEqualTo(viewport.left));
            expect(bounds.right, lessThanOrEqualTo(viewport.right));
            expect(tester.getRect(close), closeBounds,
                reason:
                    'Close must remain fixed outside the scrolling content');
            expect(close.hitTestable(), findsOneWidget);
            expectAchievementArtworkVisible(tester);
            expect(
                resultGlobalRect(
                    tester, find.byKey(const ValueKey('achievement_trophy'))),
                artworkBounds,
                reason:
                    'The whole illustration stays fixed while reading rewards');
            expect(tester.takeException(), isNull);
          }
          expect(find.text(definition.name), findsOneWidget);
          expect(find.text('+${definition.reward} coins'), findsOneWidget);
          final reward =
              tester.getRect(find.byKey(const ValueKey('achievement_reward')));
          expect(reward.top, greaterThanOrEqualTo(viewport.top));
          expect(reward.bottom, lessThanOrEqualTo(viewport.bottom));
          expectResultInside(
              viewport,
              resultGlobalRect(tester,
                  find.byKey(const ValueKey('achievement_reward_badge'))),
              'The large coin badge must be entirely visible at the end');
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(closed, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  // Public debugLayer and repaint metrics inspect framework paint reuse and
  // invalidation in debug widget tests. They do not observe engine raster-cache
  // retention or establish a GPU/frame-time improvement.
  for (final reducedMotion in [false, true]) {
    testWidgets(
        'entrance retains the static panel display list; reduced motion=$reducedMotion',
        (tester) async {
      await _mount(
          tester, AchievementRewardDialog(definition: _short, onClose: () {}),
          reducedMotion: reducedMotion);
      // The first nontransparent frame records the complete panel once.
      await tester.pump(const Duration(milliseconds: 80));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('achievement_panel_paint')));
      final layer = boundary.debugLayer!;
      final recordedContent = layer.firstChild;
      expect(recordedContent, isNotNull);
      final size = boundary.size;
      final fade = find.byKey(const ValueKey('achievement_fade'));
      final beforeOpacity = tester.widget<Opacity>(fade).opacity;
      boundary.debugResetMetrics();
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(boundary.debugLayer, same(layer));
        expect(layer.firstChild, same(recordedContent),
            reason: 'Entrance ticks must reuse recorded panel paint.');
        expect(boundary.size, size);
      }
      expect(boundary.debugSymmetricPaintCount, 0,
          reason:
              'The static panel must not repaint with its animated parent.');
      if (!reducedMotion) {
        expect(boundary.debugAsymmetricPaintCount, greaterThan(0));
        expect(
            tester.widget<Opacity>(fade).opacity, greaterThan(beforeOpacity));
      }
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(fade).opacity, 1);
      expectAchievementArtworkVisible(tester);
      expect(find.byKey(const ValueKey('achievement_close')).hitTestable(),
          findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'entrance finishes without a loop; reduced motion=$reducedMotion',
        (tester) async {
      await _mount(
          tester, AchievementRewardDialog(definition: _short, onClose: () {}),
          reducedMotion: reducedMotion);
      final fade = find.byKey(const ValueKey('achievement_fade'));
      final scale = find.byKey(const ValueKey('achievement_scale'));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.widget<Opacity>(fade).opacity,
          reducedMotion ? equals(1) : allOf(greaterThan(0), lessThan(1)));
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(fade).opacity, 1);
      expect(tester.widget<Transform>(scale).transform.entry(0, 0), 1);
      expectAchievementArtworkVisible(tester);
      tester.element(find.byType(AchievementRewardDialog)).markNeedsBuild();
      await tester.pump();
      expect(tester.widget<Opacity>(fade).opacity, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('retained reward panel repaints when its content changes',
      (tester) async {
    final definition = ValueNotifier(_short);
    addTearDown(definition.dispose);
    await _mount(
        tester,
        ValueListenableBuilder<AchievementDefinition>(
            valueListenable: definition,
            builder: (_, value, __) =>
                AchievementRewardDialog(definition: value, onClose: () {})));
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('achievement_panel_paint')));
    Iterable<PictureLayer> pictures(ContainerLayer layer) sync* {
      for (Layer? child = layer.firstChild;
          child != null;
          child = child.nextSibling) {
        if (child is PictureLayer) yield child;
        if (child is ContainerLayer) yield* pictures(child);
      }
    }

    final recordedContent = pictures(boundary.debugLayer!).toList();
    expect(recordedContent, isNotEmpty);
    definition.value = _long;
    await tester.pumpAndSettle();
    expect(find.text(_short.name), findsNothing);
    expect(find.text(_long.name), findsOneWidget);
    expect(find.text('+${_long.reward} coins'), findsOneWidget);
    // Scrolling content may repaint inside its own retained layer without
    // repainting the panel's outer decoration.
    expect(
        pictures(boundary.debugLayer!), isNot(orderedEquals(recordedContent)));
    expectAchievementArtworkVisible(tester);
    expect(tester.takeException(), isNull);
  });

  for (final dispose in [false, true]) {
    testWidgets(
        'achievement sound ownership ends once on ${dispose ? 'dispose' : 'navigation'}',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = ProgressRepository();
      await repository.recordMatchedTiles(3);
      var starts = 0, ends = 0;
      await _mount(
          tester,
          Builder(
              builder: (context) => TextButton(
                  onPressed: () => unawaited(
                      showPendingAchievementPopups(context, repository,
                          onPopup: () async {
                            starts++;
                          },
                          onPopupEnded: () => ends++)),
                  child: const Text('Open reward'))));
      await tester.tap(find.text('Open reward'));
      await tester.pumpAndSettle();
      expect(starts, 1);
      if (dispose) {
        await tester.pumpWidget(const SizedBox.shrink());
      } else {
        final navigator =
            Navigator.of(tester.element(find.byType(AchievementRewardDialog)));
        unawaited(navigator.push<void>(PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => const Scaffold(body: Text('Away')))));
        await tester.pump();
        expect(ends, 1);
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Away'), findsOneWidget,
            reason: 'The popup deadline must not pop a different route');
        navigator.pop();
        await tester.pumpAndSettle();
        expect(starts, 1, reason: 'Returning must not replay the reward');
        await tester.tap(find.byKey(const ValueKey('achievement_close')));
        await tester.pumpAndSettle();
      }
      expect(starts, 1);
      expect(ends, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'queued achievements close independently without stale timers or duplicate rewards',
      (tester) async {
    SharedPreferences.setMockInitialValues({'coins': 100});
    final repository = ProgressRepository();
    await repository.recordMatchedTiles(3);
    await repository.recordLevelCompleted(1, 3);
    final earnedBalance = await repository.coins();
    final expectedRewards = ProgressRepository.achievementsCatalog
        .where((item) =>
            item.id == AchievementId.firstMatch ||
            item.id == AchievementId.firstWin)
        .fold<int>(0, (sum, item) => sum + item.reward);
    expect(earnedBalance, 100 + expectedRewards);
    Future<void>? presentation;
    var sounds = 0;
    var soundEnds = 0;
    await _mount(
        tester,
        Builder(
            builder: (context) => TextButton(
                  onPressed: () {
                    presentation =
                        showPendingAchievementPopups(context, repository,
                            onPopup: () async {
                              sounds++;
                            },
                            onPopupEnded: () => soundEnds++);
                  },
                  child: const Text('Show queue'),
                )));
    await tester.tap(find.text('Show queue'));
    await tester.pumpAndSettle();
    expect(find.text('First Match'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('achievement_close')));
    await tester.pumpAndSettle();
    expect(find.text('First Win'), findsOneWidget);
    // Pass the first dialog's deadline, but not the second dialog's deadline.
    await tester.pump(const Duration(milliseconds: 2100));
    expect(find.text('First Win'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('achievement_close')));
    await tester.pumpAndSettle();
    await presentation;
    await tester.pump(const Duration(seconds: 4));
    expect(sounds, 2);
    expect(soundEnds, 2);
    expect(find.byType(AchievementRewardDialog), findsNothing);
    expect(find.text('Show queue'), findsOneWidget);
    expect(await repository.coins(), earnedBalance);
    expect(await repository.consumePendingAchievementPopups(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final dismissal in ['close', 'timeout', 'system back']) {
    testWidgets(
        '$dismissal preserves lifecycle and never grants the reward again',
        (tester) async {
      SharedPreferences.setMockInitialValues({'coins': 100});
      final repository = ProgressRepository();
      final definition = ProgressRepository.achievementsCatalog
          .firstWhere((item) => item.id == AchievementId.firstMatch);
      await repository.recordMatchedTiles(3);
      final earnedBalance = 100 + definition.reward;
      expect(await repository.coins(), earnedBalance);
      Future<void>? presentation;
      var sounds = 0;
      late BuildContext hostContext;
      await _mount(tester, Builder(builder: (context) {
        hostContext = context;
        return TextButton(
          onPressed: () {
            presentation = showPendingAchievementPopups(context, repository,
                onPopup: () async {
              sounds++;
            });
          },
          child: const Text('Show achievements'),
        );
      }));
      await tester.tap(find.text('Show achievements'));
      await tester.pumpAndSettle();
      expect(find.byType(AchievementRewardDialog), findsOneWidget);
      expect(find.text('+${definition.reward} coins'), findsOneWidget);
      expect(sounds, 1);
      expect(await repository.coins(), earnedBalance);
      // An inherited/UI rebuild must not grant or requeue the achievement.
      tester.element(find.byType(AchievementRewardDialog)).markNeedsBuild();
      await tester.pump();
      expect(await repository.coins(), earnedBalance);
      if (dismissal == 'close') {
        await tester.tap(find.byKey(const ValueKey('achievement_close')));
      } else if (dismissal == 'system back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(AchievementRewardDialog), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
      await presentation;
      expect(find.byType(AchievementRewardDialog), findsNothing);
      expect(Navigator.of(hostContext).canPop(), isFalse);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Show achievements'), findsOneWidget);
      expect(await repository.coins(), earnedBalance);
      // Repeated matching and a subsequent popup request must be idempotent.
      await repository.recordMatchedTiles(3);
      await tester.tap(find.text('Show achievements'));
      await tester.pumpAndSettle();
      await presentation;
      expect(find.byType(AchievementRewardDialog), findsNothing);
      expect(sounds, 1);
      final reloaded = ProgressRepository();
      expect(await reloaded.coins(), earnedBalance);
      expect(await reloaded.consumePendingAchievementPopups(), isEmpty);
      expect(
          (await reloaded.achievements())
              .singleWhere(
                  (item) => item.definition.id == AchievementId.firstMatch)
              .unlocked,
          isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
