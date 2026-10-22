import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/presentation/screens/world_selection_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/adventure_level_node.dart';
import 'package:triple_tile_adventure/presentation/widgets/adventure_world_destination_card.dart';
import 'package:triple_tile_adventure/presentation/widgets/adventure_world_scenery.dart';

const _cardKey = ValueKey('card_under_test');

Future<void> _mount(
  WidgetTester tester, {
  GameWorld? world,
  bool unlocked = true,
  bool current = true,
  int completed = 5,
  bool reducedMotion = false,
  VoidCallback? onTap,
}) =>
    tester.pumpWidget(MaterialApp(
      theme: GameTheme.theme(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 328,
              child: AdventureWorldDestinationCard(
                key: _cardKey,
                world: world ?? gameWorlds.first,
                unlocked: unlocked,
                current: current,
                completed: completed,
                onTap: onTap ?? () {},
              ),
            ),
          ),
        ),
      ),
    ));

RenderRepaintBoundary _body(WidgetTester tester) {
  final pressable =
      tester.widget<AdventurePressable>(find.byType(AdventurePressable));
  expect(pressable.child, isA<RepaintBoundary>());
  return tester
      .renderObject<RenderRepaintBoundary>(find.byWidget(pressable.child));
}

void _expectRetainedBody(RenderRepaintBoundary body) {
  // Debug paint counters test display-list reuse, not GPU cache use or FPS.
  expect(body.debugAsymmetricPaintCount, greaterThan(0),
      reason: 'The animated parent must paint independently of the body');
  expect(body.debugSymmetricPaintCount, 0,
      reason: 'Transform-only frames must not repaint the decorated body');
  expect(body.debugNeedsPaint, isFalse);
}

void main() {
  testWidgets('entrance and press transforms retain the painted card body',
      (tester) async {
    await _mount(tester);
    // Opacity starts at zero. First allow a visible frame to paint the body.
    await tester.pump(const Duration(milliseconds: 42));
    final body = _body(tester);
    body.debugResetMetrics();
    await tester.pump(const Duration(milliseconds: 84));
    await tester.pump(const Duration(milliseconds: 84));
    _expectRetainedBody(body);
    await tester.pumpAndSettle();

    body.debugResetMetrics();
    final gesture =
        await tester.startGesture(tester.getCenter(find.byKey(_cardKey)));
    // Allow InkWell's tap-down timeout, then sample the active scale tween.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 50));
    final scale = find.descendant(
        of: find.byType(AnimatedScale), matching: find.byType(Transform));
    expect(tester.widget<Transform>(scale).transform.storage[0], lessThan(1));
    expect(_body(tester), same(body));
    _expectRetainedBody(body);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final world in gameWorlds) {
    testWidgets('${world.name}: retained body updates states and semantics',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var taps = 0;
        void onTap() => taps++;
        await _mount(tester,
            world: world,
            unlocked: false,
            current: false,
            completed: 0,
            reducedMotion: true,
            onTap: onTap);
        await tester.pumpAndSettle();
        final body = _body(tester);
        final pressState = tester.state(find.byType(AdventurePressable));
        final entranceState =
            tester.state(find.byType(TweenAnimationBuilder<double>));

        for (final stage in [0, 1, 2]) {
          final unlocked = stage != 0;
          final current = stage == 1;
          final completed = stage * 5;
          body.debugResetMetrics();
          if (stage != 0) {
            await _mount(tester,
                world: world,
                unlocked: unlocked,
                current: current,
                completed: completed,
                reducedMotion: true,
                onTap: onTap);
            await tester.pumpAndSettle();
            expect(
                body.debugSymmetricPaintCount + body.debugAsymmetricPaintCount,
                greaterThan(0),
                reason: 'Changed progress must invalidate paint');
          }
          expect(_body(tester), same(body));
          expect(
              tester.state(find.byType(AdventurePressable)), same(pressState));
          expect(tester.state(find.byType(TweenAnimationBuilder<double>)),
              same(entranceState));
          expect(
              tester
                  .widget<AdventureWorldScenery>(
                      find.byType(AdventureWorldScenery))
                  .theme,
              same(world.visualTheme));
          expect(find.text(world.name), findsOneWidget);
          expect(find.text('${world.subtitle}  •  $completed/10 cleared'),
              findsOneWidget);
          expect(find.text('YOUR JOURNEY'),
              current ? findsOneWidget : findsNothing);
          expect(
              tester
                  .widget<LinearProgressIndicator>(
                      find.byType(LinearProgressIndicator))
                  .value,
              completed / 10);
          final expectedLabel =
              '${world.name}, ${world.subtitle}, $completed of 10 cleared. '
              '${current ? 'Current world. ' : ''}'
              '${unlocked ? 'Explore' : 'Complete Level ${world.unlockAfterLevel} to unlock'}';
          // The card key resolves to its outer entrance Opacity. getSemantics
          // walks ancestors, so target the actual descendant semantics node.
          final cardSemantics = find.descendant(
            of: find.byKey(_cardKey),
            matching: find.bySemanticsLabel(expectedLabel),
          );
          expect(cardSemantics, findsOneWidget);
          expect(
              tester.getSemantics(cardSemantics),
              matchesSemantics(
                label: expectedLabel,
                isButton: true,
                hasEnabledState: true,
                isEnabled: unlocked,
                hasTapAction: unlocked,
              ));
          expect(
              tester
                  .widget<TweenAnimationBuilder<double>>(
                      find.byType(TweenAnimationBuilder<double>))
                  .duration,
              Duration.zero);
          expect(
              tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
              Duration.zero);
          await tester.tap(find.byKey(_cardKey));
          await tester.pumpAndSettle();
          expect(taps, stage);
          expect(tester.binding.hasScheduledFrame, isFalse);
        }
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('input is delivered before the card entrance finishes',
      (tester) async {
    var taps = 0;
    await _mount(tester, onTap: () => taps++);
    await tester.pump(const Duration(milliseconds: 84));
    final opacity = find.descendant(
        of: find.byKey(_cardKey), matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
    await tester.tap(find.byKey(_cardKey));
    expect(taps, 1,
        reason: 'Input must not wait for entrance or press animation');
    await tester.pumpAndSettle();
  });

  for (final pressing in [false, true]) {
    testWidgets('disposing during ${pressing ? 'press' : 'entrance'} is safe',
        (tester) async {
      await _mount(tester);
      await tester.pump(const Duration(milliseconds: 84));
      final body = _body(tester);
      if (pressing) {
        await tester.pumpAndSettle();
        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(_cardKey)));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpWidget(const SizedBox.shrink());
        await gesture.cancel();
      } else {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.pump(const Duration(seconds: 1));
      expect(body.attached, isFalse);
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }
}
