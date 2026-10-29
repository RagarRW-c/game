import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/game_engine.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/endless_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_ui.dart';

import 'support/geometry.dart';

// Implement instead of extend: constructing the production audio service would
// create native AudioPlayers. No platform channels, disk audio or real prefs.
class _SilentAudio implements GameAudioService {
  @override
  Future<void> prepareTileFeedback() async {}
  @override
  void cancelPendingTileFeedback() {}

  @override
  Future<void> startGameplayMusic({int level = 1, Object? owner}) async {}
  @override
  Future<void> stopGameplayMusic({Object? owner}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QaLevels extends LevelRepository {
  @override
  Future<LevelDefinition> loadLevel(int level) async => readLevel(level);
}

LevelDefinition readLevel(int id) => LevelDefinition.fromJson(jsonDecode(
    File('assets/levels/level_${id.toString().padLeft(2, '0')}.json')
        .readAsStringSync()) as Map<String, dynamic>);

// WidgetTester.getSize returns local dimensions. Transform both corners to
// include the real FittedBox scale when checking screen-space bounds.
Rect globalRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return Rect.fromPoints(box.localToGlobal(Offset.zero),
      box.localToGlobal(Offset(box.size.width, box.size.height)));
}

Future<void> mount(WidgetTester tester, QaScreen screen, Widget child,
    {double textScale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = screen.size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final progress = ProgressRepository();
  await progress.setLevelOneTutorialSeen();
  await tester.pumpWidget(AppScope(
    progressRepository: progress,
    levelRepository: _QaLevels(),
    audioService: _SilentAudio(),
    child: MaterialApp(
      theme: GameTheme.theme(),
      navigatorObservers: [appRouteObserver],
      builder: (context, content) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(top: screen.safeTop, bottom: 24),
          viewPadding: EdgeInsets.only(top: screen.safeTop, bottom: 24),
          textScaler: TextScaler.linear(textScale),
        ),
        child: content!,
      ),
      home: child,
    ),
  ));
  await tester.pumpAndSettle();
}

List<String> inspectBoard(WidgetTester tester, QaScreen screen,
    {required bool endless, LevelDefinition? level}) {
  final issues = <String>[];
  void check(bool ok, String message) {
    if (!ok) issues.add(message);
  }

  final tiles =
      find.byWidgetPredicate((w) => w is GameTileWidget && !w.trayTile);
  final widgets = tester.widgetList<GameTileWidget>(tiles).toList();
  check(widgets.isNotEmpty, 'No actual board tiles rendered');
  if (widgets.isEmpty) return issues;
  if (level != null) {
    check(widgets.length == level.tiles.length, 'Missing board tiles');
  }
  final geometry = screen.geometry(endless: endless);
  final engine = GameEngine(widgets.map((w) => w.tile).toList())
    ..updateBoardGeometry(geometry.board, geometry.tile);
  final stack =
      find.ancestor(of: tiles.first, matching: find.byType(Stack)).first;
  final localSize = tester.getSize(stack);
  check(
      (localSize.width - geometry.board.width).abs() < 0.01 &&
          (localSize.height - geometry.board.height).abs() < 0.01,
      'Actual board geometry drifted from QA model: $localSize');
  // Enforce the new frame contract as well as the existing tile/viewport
  // containment checks: decoration must not consume the engine's canvas.
  final frame = tester.widget<Container>(
      find.ancestor(of: stack, matching: find.byType(Container)).first);
  final border = (frame.decoration! as BoxDecoration).border!.dimensions;
  check(border == const EdgeInsets.all(2), 'Unexpected board frame border');
  check(
      frame.constraints!.maxWidth == geometry.board.width + border.horizontal &&
          frame.constraints!.maxHeight ==
              geometry.board.height + border.vertical,
      'Board frame must reserve its border outside the logical canvas');
  final canvasRect = globalRect(tester, stack);
  final scaleX = canvasRect.width / localSize.width;
  final scaleY = canvasRect.height / localSize.height;
  check(scaleX > 0 && scaleX <= 1.000001 && (scaleX - scaleY).abs() < 1e-6,
      'Board must scale uniformly without changing overlap ratios');
  final fitted = tester.widget<FittedBox>(
      find.ancestor(of: stack, matching: find.byType(FittedBox)).first);
  check(fitted.fit == BoxFit.scaleDown,
      'Board must fit inside its allocated area');
  final boardRect = canvasRect.inflate(0.01);
  final screenRect = Rect.fromLTWH(0, screen.safeTop, screen.size.width,
          screen.size.height - screen.safeTop)
      .inflate(0.01);
  final orderedIds = engine.renderedBoardTiles.map((t) => t.id).toList();
  check(
      widgets.map((w) => w.tile.id).toList().toString() ==
          orderedIds.toString(),
      'Widget Stack order differs from engine paint order');
  for (var i = 0; i < widgets.length; i++) {
    final widget = widgets[i];
    final finder = tiles.at(i);
    final rect = globalRect(tester, finder);
    final logicalRect = widget.tile.boardRect(geometry.board, geometry.tile);
    final expectedRect = Rect.fromLTWH(
      canvasRect.left + logicalRect.left * scaleX,
      canvasRect.top + logicalRect.top * scaleY,
      logicalRect.width * scaleX,
      logicalRect.height * scaleY,
    );
    check(
        (rect.topLeft - expectedRect.topLeft).distance < 0.01 &&
            (rect.bottomRight - expectedRect.bottomRight).distance < 0.01,
        '${widget.tile.id}: screen transform changed the engine geometry');
    final localTile = tester.getSize(finder);
    check(
        (localTile.width - geometry.tile.width).abs() < 0.01 &&
            (localTile.height - geometry.tile.height).abs() < 0.01,
        '${widget.tile.id}: actual tile size differs from QA model');
    check(
        boardRect.contains(rect.topLeft) &&
            boardRect.contains(rect.bottomRight),
        '${widget.tile.id}: tile escapes inner board after actual FittedBox scaling');
    check(
        screenRect.contains(rect.topLeft) &&
            screenRect.contains(rect.bottomRight),
        '${widget.tile.id}: tile escapes viewport');
    final positioned =
        tester.widget<Positioned>(find.byKey(ValueKey(widget.tile.id)));
    check(
        (positioned.left! - widget.tile.x * geometry.board.width).abs() <
                0.01 &&
            (positioned.top! - widget.tile.y * geometry.board.height).abs() <
                0.01,
        '${widget.tile.id}: coordinate/scaling rule drift');
    final covered = engine.isTileCovered(widget.tile);
    check(widget.blocked == covered && widget.enabled == !covered,
        '${widget.tile.id}: widget blocked/enabled differs from engine');
    final ignored = tester.widget<IgnorePointer>(
        find.ancestor(of: finder, matching: find.byType(IgnorePointer)).first);
    check(
        ignored.ignoring == covered, '${widget.tile.id}: wrong IgnorePointer');
  }
  // Verify the actual seven-slot tray and controls exist on screen as well.
  check(find.byType(EmptyTraySlot).evaluate().length == GameEngine.trayLimit,
      'Initial tray must have seven slots');
  check(find.byType(GameBoosterButton).evaluate().length == 3,
      'Exactly three shared circular boosters');
  final trayRect = globalRect(tester, find.byType(GameTray));
  final frameRect = canvasRect.inflate(2 * scaleX);
  final expectedActions = [
    BoosterAction.undo,
    BoosterAction.hint,
    BoosterAction.shuffle
  ];
  check(
      tester
              .widgetList<GameBoosterButton>(find.byType(GameBoosterButton))
              .map((w) => w.action)
              .toList()
              .toString() ==
          expectedActions.toString(),
      'Campaign and Endless must use Undo, wand Hint and crossed Shuffle');
  for (final label in ['Undo x2', 'Hint x2', 'Shuffle x2']) {
    final finder = find.byWidgetPredicate(
        (w) => w is GameBoosterButton && '${w.label} ${w.badge}' == label);
    check(finder.evaluate().length == 1, 'Missing booster $label');
    if (finder.evaluate().length == 1) {
      final rect = globalRect(tester, finder);
      check(!rect.overlaps(trayRect), 'Booster $label overlaps tray');
      check(!rect.overlaps(frameRect), 'Booster $label overlaps board frame');
      check(
          find
                  .descendant(of: finder, matching: find.text('x2'))
                  .evaluate()
                  .length ==
              1,
          'Booster $label must render its actual free quantity');
      check(
          screenRect.contains(rect.topLeft) &&
              screenRect.contains(rect.bottomRight),
          'Booster $label outside viewport');
    }
  }
  final header = tester.widget<GameHeader>(find.byType(GameHeader));
  if (level != null && level.level % 10 == 0) {
    final world = tileVisualThemeForLevel(level.level).name;
    check(header.title == '${world[0].toUpperCase()}${world.substring(1)} Boss',
        'Wrong rendered boss title');
  }
  return issues;
}

void main() {
  final rows = <Map<String, Object>>[];
  tearDownAll(() {
    Directory('qa/results').createSync(recursive: true);
    File('qa/results/screen_fit.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'createdUtc': DateTime.now().toUtc().toIso8601String(),
      'scope': 'Actual Flutter widget layout; no emulator or screenshots',
      'checks': rows,
    }));
  });

  for (final id in [27, 50, 65, 80, 95]) {
    for (final screen in qaScreens) {
      for (final scale in [1.0, 1.6, 2.0]) {
        testWidgets(
            'L$id objective wraps inside HUD at ${screen.name} / $scale',
            (tester) async {
          try {
            await mount(tester, screen, GameScreen(level: id),
                textScale: scale);
            expect(tester.takeException(), isNull);
            final badge = find.byKey(const ValueKey('game_objective'));
            final label = find.byKey(const ValueKey('game_objective_label'));
            final target = readLevel(id).objective!.target;
            expect(tester.widget<Text>(label).data, 'Burlap Sack 0/$target');
            final paragraph = tester.renderObject<RenderParagraph>(
                find.descendant(of: label, matching: find.byType(RichText)));
            expect(paragraph.didExceedMaxLines, isFalse);
            await tester.ensureVisible(badge);
            await tester.pumpAndSettle();
            final textBounds = globalRect(tester, label);
            final badgeBounds = globalRect(tester, badge).inflate(.01);
            final hudBounds = globalRect(
                    tester, find.byKey(const ValueKey('game_hud_scroll')))
                .inflate(.01);
            for (final bounds in [badgeBounds, hudBounds]) {
              expect(bounds.contains(textBounds.topLeft), isTrue);
              expect(bounds.contains(textBounds.bottomRight), isTrue);
            }
            // Scrolling the objective cannot displace the gameplay controls.
            for (final text in ['Undo x2', 'Hint x2', 'Shuffle x2']) {
              expect(
                  find
                      .byWidgetPredicate((w) =>
                          w is GameBoosterButton &&
                          '${w.label} ${w.badge}' == text)
                      .hitTestable(),
                  findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
          }
        });
      }
    }
  }

  for (final screen in qaScreens) {
    for (var id = 1; id <= LevelRepository.levelCount; id++) {
      testWidgets('campaign L$id fits ${screen.name} with real screen scaling',
          (tester) async {
        final issues = <String>[];
        try {
          await mount(tester, screen, GameScreen(level: id));
          issues.addAll(inspectBoard(tester, screen,
              endless: false, level: readLevel(id)));
        } catch (e) {
          issues.add('$e');
        }
        while (true) {
          final error = tester.takeException();
          if (error == null) break;
          issues.add('Flutter layout exception: $error');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        rows.add({
          'level': id,
          'screen': screen.name,
          'status': issues.isEmpty ? 'PASS' : 'FAIL',
          'issues': issues
        });
        expect(issues, isEmpty, reason: 'L$id ${screen.name}');
      });
    }
    testWidgets('Endless screen fits ${screen.name}', (tester) async {
      final issues = <String>[];
      try {
        await mount(tester, screen, const EndlessScreen());
        issues.addAll(inspectBoard(tester, screen, endless: true));
      } catch (e) {
        issues.add('$e');
      }
      while (true) {
        final error = tester.takeException();
        if (error == null) break;
        issues.add('Flutter layout exception: $error');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      rows.add({
        'mode': 'endless_round_1',
        'screen': screen.name,
        'status': issues.isEmpty ? 'PASS' : 'FAIL',
        'issues': issues
      });
      expect(issues, isEmpty);
    });
  }
}
