import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/level96_playtest/app.dart';
import 'package:triple_tile_adventure/level96_playtest/session.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';

import '../../integration_test/ui_driver.dart';
import 'support/level96_phase4d7_test_support.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(411.428571, 891.428571),
    const Size(412, 915),
  ]) {
    testWidgets('$size: driver reveals lazy variants with long session history',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final levels = testLevels();
      final log = PlaytestLog();
      for (var i = 0; i < 25; i++) {
        log.start(levels, PlaytestVariant.original).abort('history_fixture');
      }
      await tester.pumpWidget(Level96PlaytestApp(
          levels: levels, log: log, audio: PlaytestTestAudio(), enabled: true));
      final ui = Level96UiDriver(tester);
      await ui.settle();
      for (final variant in [
        PlaytestVariant.candidateB,
        PlaytestVariant.original,
        PlaytestVariant.candidateA,
      ]) {
        // Reproduce an option outside the lazily built viewport. These are
        // pointer drags, not direct ScrollController or engine manipulation.
        for (var i = 0; i < 5; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -350));
          await ui.settle();
        }
        expect(find.byKey(ValueKey(variant.name)), findsNothing);
        await ui.selectVariant(variant.name);
        await ui.tap(find.byKey(const ValueKey('start_session')));
        expect(find.byType(GameScreen), findsOneWidget);
        final session = log.sessions.last;
        expect(session.variant, variant);
        expect(session.engine.boardTiles, hasLength(99));
        expect(session.engine.tray, isEmpty);
        expect(session.acceptedTaps, 0);
        for (final label in ['Undo', 'Hint', 'Shuffle']) {
          await ui.tapDisabledBooster(label);
        }
        expect(session.acceptedTaps, 0);
        expect(session.engine.boardTiles, hasLength(99));
        expect(session.engine.tray, isEmpty);
        await ui.tap(find.byIcon(Icons.pause_rounded));
        await ui.tap(find.byKey(const ValueKey('variant_selection')));
        expect(session.outcome, 'ABORTED');
        expect(tester.takeException(), isNull);
      }
      expect(log.sessions, hasLength(28));
    });
  }
}
