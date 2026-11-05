import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/level96_playtest/app.dart';
import 'package:triple_tile_adventure/level96_playtest/session.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';

import '../qa/support/geometry.dart';
import 'support/level96_phase4d7_test_support.dart';

Future<PlaytestLog> mount(WidgetTester tester, QaScreen screen) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = screen.size;
  tester.view.padding = FakeViewPadding(top: screen.safeTop, bottom: 24);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'coins': 987,
    'highest_unlocked_level': 42,
    'extra_hint_boosters': 17,
    'sentinel': 'unchanged'
  });
  final log = PlaytestLog();
  await tester.pumpWidget(Level96PlaytestApp(
      levels: testLevels(),
      enabled: true,
      log: log,
      audio: PlaytestTestAudio()));
  await tester.pumpAndSettle();
  return log;
}

Future<void> start(WidgetTester tester, PlaytestVariant variant) async {
  await tester.tap(find.byKey(ValueKey(variant.name)));
  await tester.tap(find.byKey(const ValueKey('start_session')));
  await tester.pumpAndSettle();
  expect(find.byType(GameScreen), findsOneWidget);
}

Future<void> tapTile(WidgetTester tester, String id) async {
  final finder = find.descendant(
      of: find.byKey(ValueKey(id)), matching: find.byType(GameTileWidget));
  expect(finder, findsOneWidget);
  expect(tester.widget<GameTileWidget>(finder).enabled, true);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> pause(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.pause_rounded));
  await tester.pumpAndSettle();
}

Map<String, dynamic> storedPath({required bool win}) {
  final directory = win
      ? 'phase4d5-level96-20261105T114207305023Z-34520-a437c264'
      : 'shadow96-20261105T102737023052Z-30288-562eae3b';
  return File('qa/campaign_validation_runs/$directory/attempts.jsonl')
      .readAsLinesSync()
      .map((line) => jsonDecode(line) as Map<String, dynamic>)
      .firstWhere((row) =>
          row['screen'] == 'small_320x568' &&
          row['variant'] == (win ? 'candidate_b' : 'control') &&
          row['outcome'] == (win ? 'WIN' : 'LOSS'));
}

void main() {
  for (final screen in qaScreens) {
    testWidgets(
        '${screen.name}: real board, tray, pointer triple, geometry and hidden-info boundary',
        (tester) async {
      final log = await mount(tester, screen);
      expect(find.text('ORIGINAL'), findsOneWidget);
      expect(find.text('CANDIDATE A'), findsOneWidget);
      expect(find.text('CANDIDATE B'), findsOneWidget);
      await start(tester, PlaytestVariant.candidateA);
      final s = log.sessions.single;
      expect(find.text('96 • CANDIDATE A'), findsOneWidget);
      expect(find.byType(GameTray), findsOneWidget);
      expect(s.board, screen.geometry().board);
      expect(s.tile, screen.geometry().tile);
      expect(s.screen, screen.size);
      expect(find.text('Off'), findsNWidgets(3));
      for (final button in tester
          .widgetList<GameBoosterButton>(find.byType(GameBoosterButton))) {
        expect(button.onPressed, isNull);
      }
      final boardStack = find
          .ancestor(
              of: find.byKey(const ValueKey('L96_T001')),
              matching: find.byType(Stack))
          .first;
      await tester.tapAt(tester.getTopLeft(boardStack) + const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(s.rejectedTaps, 1);
      final covered = find.byWidgetPredicate(
          (w) => w is GameTileWidget && w.blocked && !w.trayTile);
      expect(covered, findsWidgets);
      for (final element in covered.evaluate()) {
        final ancestors = find.ancestor(
            of: find.byWidget(element.widget),
            matching: find.byType(ExcludeSemantics));
        expect(
            tester
                .widgetList<ExcludeSemantics>(ancestors)
                .any((w) => w.excluding),
            true);
      }
      expect(
          tester
              .widgetList<Text>(find.byType(Text))
              .any((w) => (w.data ?? '').contains('L96_T')),
          false);
      for (var i = 0; i < 3; i++) {
        final selectableHeart = tester
            .widgetList<GameTileWidget>(find.byType(GameTileWidget))
            .firstWhere((w) =>
                !w.trayTile &&
                w.enabled &&
                !w.blocked &&
                w.tile.type == 'heart');
        await tapTile(tester, selectableHeart.tile.id);
      }
      expect(s.acceptedTaps, 3);
      expect(s.rejectedTaps, 1);
      expect(s.firstTripleTap, 3);
      expect(s.engine.tray, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(s.outcome, 'ABORTED');
    });
  }
  testWidgets('restart and variant selection discard all prior board state',
      (tester) async {
    final log = await mount(tester, qaScreens[1]);
    await start(tester, PlaytestVariant.candidateB);
    final old = log.sessions.single;
    final selectable = tester
        .widgetList<GameTileWidget>(find.byType(GameTileWidget))
        .firstWhere((w) => w.enabled && !w.blocked && !w.trayTile);
    await tapTile(tester, selectable.tile.id);
    await pause(tester);
    await tester.tap(find.byKey(const ValueKey('restart_session')));
    await tester.pumpAndSettle();
    expect(old.outcome, 'ABORTED');
    expect(old.toJson()['restart'], true);
    final fresh = log.sessions.last;
    expect(fresh.id, isNot(old.id));
    expect(fresh.engine.boardTiles.length, 99);
    expect(fresh.engine.tray, isEmpty);
    expect(fresh.acceptedTaps, 0);
    await pause(tester);
    await tester.tap(find.byKey(const ValueKey('variant_selection')));
    await tester.pumpAndSettle();
    expect(fresh.outcome, 'ABORTED');
    await start(tester, PlaytestVariant.original);
    final original = log.sessions.last;
    expect(original.engine.tileById('L96_T094')!.type, 'heart');
    expect(original.engine.tileById('L96_T071')!.type, 'banana');
    expect(original.engine.boardTiles.length, 99);
    expect(original.engine.tray, isEmpty);
    expect(original.toJson()['booster_usage'],
        {'hint': 0, 'shuffle': 0, 'undo': 0});
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  for (final win in [false, true]) {
    testWidgets(
        '${win ? 'WIN' : 'LOSS'} real pointer replay opens summary without rewards or saves',
        (tester) async {
      final log = await mount(tester, qaScreens.first);
      final prefs = await SharedPreferences.getInstance();
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      await start(
          tester, win ? PlaytestVariant.candidateB : PlaytestVariant.original);
      for (final id in storedPath(win: win)['path_ids'] as List) {
        await tapTile(tester, id as String);
      }
      final session = log.sessions.single;
      expect(session.outcome, win ? 'WIN' : 'LOSS');
      expect(find.byKey(const ValueKey('restart_session')), findsOneWidget);
      expect(session.acceptedTaps, win ? 99 : 7);
      expect(session.rejectedTaps, 0);
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(session.outcome, win ? 'WIN' : 'LOSS');
    });
  }
  testWidgets('clipboard export round-trips complete structured local records',
      (tester) async {
    final log = await mount(tester, qaScreens[1]);
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await start(tester, PlaytestVariant.original);
    await pause(tester);
    await tester.tap(find.byKey(const ValueKey('variant_selection')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('export_sessions')));
    await tester.tap(find.byKey(const ValueKey('export_sessions')));
    await tester.pumpAndSettle();
    expect(copied, log.exportJson());
    expect(
        (jsonDecode(copied!)['sessions'] as List).single['outcome'], 'ABORTED');
  });
}
