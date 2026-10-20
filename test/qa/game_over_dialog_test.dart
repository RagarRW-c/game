import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_over_dialog.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_ui.dart';

import 'support/geometry.dart';

Future<void> mountGameOver(
  WidgetTester tester, {
  QaScreen screen = const QaScreen('small', Size(320, 568), 24),
  double textScale = 1,
  bool reducedMotion = false,
  bool canUseShuffle = true,
  bool canRestart = true,
  VoidCallback? restart,
  VoidCallback? shuffle,
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
      body: GameOverDialog(
        canUseShuffle: canUseShuffle,
        onRestart: canRestart ? restart ?? () {} : null,
        onUseShuffle: shuffle ?? () {},
        onBackToMap: map ?? () {},
      ),
    ),
  ));
}

void main() {
  for (final screen in qaScreens) {
    for (final textScale in [1.0, 1.6, 2.0]) {
      testWidgets(
          'Game Over fits ${screen.name}, text scale $textScale; actions remain reachable',
          (tester) async {
        await mountGameOver(tester, screen: screen, textScale: textScale);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Game Over'), findsOneWidget);
        expect(find.text('Tray is full'), findsOneWidget);
        for (var i = 0; i < 7; i++) {
          expect(
              find.byKey(ValueKey('game_over_tray_tile_$i')), findsOneWidget);
        }

        final title =
            tester.getRect(find.byKey(const ValueKey('game_over_title')));
        final close =
            tester.getRect(find.byKey(const ValueKey('game_over_close')));
        expect(title.overlaps(close), isFalse,
            reason: 'Close must have its own layout space beside the header.');
        expect(close.size, const Size(48, 48));
        expect(close.top, greaterThanOrEqualTo(screen.safeTop));

        final viewport =
            tester.getRect(find.byKey(const ValueKey('game_over_scroll')));
        expect(viewport.left, greaterThanOrEqualTo(16));
        expect(viewport.right, lessThanOrEqualTo(screen.size.width - 16));
        expect(viewport.top, greaterThanOrEqualTo(screen.safeTop));
        expect(viewport.bottom, lessThanOrEqualTo(screen.size.height - 24));
        for (final action in ['restart', 'shuffle', 'map']) {
          final finder = find.byKey(ValueKey('game_over_$action'));
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          final bounds = tester.getRect(finder);
          expect(bounds.top, greaterThanOrEqualTo(viewport.top));
          expect(bounds.bottom, lessThanOrEqualTo(viewport.bottom));
          expect(bounds.left, greaterThanOrEqualTo(viewport.left));
          expect(bounds.right, lessThanOrEqualTo(viewport.right));
          expect(bounds.height, greaterThanOrEqualTo(48));
          expect(finder.hitTestable(), findsOneWidget);
          final label =
              find.descendant(of: finder, matching: find.byType(Text));
          final paragraph = tester.renderObject<RenderParagraph>(label);
          expect(paragraph.didExceedMaxLines, isFalse,
              reason: 'Action labels must stay readable with larger text.');
          final labelBounds = tester.getRect(label);
          expect(labelBounds.top, greaterThanOrEqualTo(bounds.top),
              reason: 'Buttons must grow to contain wrapped labels.');
          expect(labelBounds.bottom, lessThanOrEqualTo(bounds.bottom),
              reason: 'Wrapped labels must not be clipped vertically.');
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final action in ['restart', 'shuffle', 'map', 'close']) {
    testWidgets('$action dispatches only its existing callback',
        (tester) async {
      var restarts = 0;
      var shuffles = 0;
      var maps = 0;
      await mountGameOver(tester,
          restart: () => restarts++,
          shuffle: () => shuffles++,
          map: () => maps++);
      await tester.pumpAndSettle();
      final target = find.byKey(ValueKey('game_over_$action'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(restarts, action == 'restart' ? 1 : 0);
      expect(shuffles, action == 'shuffle' ? 1 : 0);
      expect(maps, action == 'map' || action == 'close' ? 1 : 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unavailable Shuffle and missing Restart stay disabled',
      (tester) async {
    var shuffles = 0;
    var restarts = 0;
    await mountGameOver(tester,
        canUseShuffle: false,
        canRestart: false,
        shuffle: () => shuffles++,
        restart: () => restarts++);
    await tester.pumpAndSettle();
    for (final action in ['restart', 'shuffle']) {
      final target = find.byKey(ValueKey('game_over_$action'));
      expect(tester.widget<GameButton>(target).onPressed, isNull);
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }
    expect(restarts, 0);
    expect(shuffles, 0);
    expect(
        tester
            .widget<GameButton>(find.byKey(const ValueKey('game_over_map')))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Restart is primary; entrance fades and scales once',
      (tester) async {
    await mountGameOver(tester);
    final fade = find.byKey(const ValueKey('game_over_fade'));
    final scale = find.byKey(const ValueKey('game_over_scale'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget<Opacity>(fade).opacity,
        allOf(greaterThan(0), lessThan(1)));
    expect(tester.widget<Transform>(scale).transform.entry(0, 0),
        allOf(greaterThan(0.92), lessThan(1)));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(fade).opacity, 1);
    expect(tester.widget<Transform>(scale).transform.entry(0, 0), 1);
    final restart = tester
        .widget<GameButton>(find.byKey(const ValueKey('game_over_restart')));
    final shuffle = tester
        .widget<GameButton>(find.byKey(const ValueKey('game_over_shuffle')));
    expect(restart.variant, GameButtonVariant.success);
    expect(restart.height, greaterThan(shuffle.height));
    // A parent rebuild must not replay the entrance.
    tester.element(find.byType(GameOverDialog)).markNeedsBuild();
    await tester.pump();
    expect(tester.widget<Opacity>(fade).opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Restart retains the shared tactile press feedback',
      (tester) async {
    await mountGameOver(tester, screen: qaScreens[1]);
    await tester.pumpAndSettle();
    final restart = find.byKey(const ValueKey('game_over_restart'));
    final transform =
        find.descendant(of: restart, matching: find.byType(Transform));
    final gesture = await tester.startGesture(tester.getCenter(restart));
    try {
      // Allow the tap-down deadline to start the shared press animation.
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Transform>(transform).transform.entry(0, 0),
          lessThan(1));
    } finally {
      await gesture.up();
    }
    await tester.pumpAndSettle();
    expect(tester.widget<Transform>(transform).transform.entry(0, 0), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reduced motion skips the entrance; full tray and Close are accessible',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await mountGameOver(tester, reducedMotion: true);
      await tester.pump();
      expect(
          tester
              .widget<Opacity>(find.byKey(const ValueKey('game_over_fade')))
              .opacity,
          1);
      expect(
          tester
              .widget<Transform>(find.byKey(const ValueKey('game_over_scale')))
              .transform
              .entry(0, 0),
          1);
      expect(find.bySemanticsLabel('Tray full: 7 of 7 slots occupied'),
          findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
