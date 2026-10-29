import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/presentation/screens/endless_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_ui.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_face.dart';

import '../goldens/support/golden_fixtures.dart';
import '../goldens/support/golden_harness.dart';
import 'screen_fit_test.dart' as fit;
import 'support/geometry.dart';
import 'support/result_layout.dart';

// Match the approved captures' real font metrics, without running a Golden
// comparator or writing images. Ahem changes the HUD's Wrap row count.
Future<void> _loadFonts() async {
  final configFile = File('.dart_tool/package_config.json').absolute;
  final config =
      jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
  final flutter = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((p) => p['name'] == 'flutter');
  final fonts =
      Directory.fromUri(configFile.uri.resolve(flutter['rootUri'] as String))
          .uri
          .resolve('../../bin/cache/artifacts/material_fonts/');
  final loader = FontLoader('Roboto');
  for (final weight in [
    'regular',
    'light',
    'medium',
    'bold',
    'black',
    'italic'
  ]) {
    loader.addFont(Future.value(ByteData.sublistView(
        await File.fromUri(fonts.resolve('roboto-$weight.ttf'))
            .readAsBytes())));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 915)
  ]) {
    for (final textScale in [1.0, 1.6, 2.0]) {
      for (final scenario in [
        (endless: false, round: 7),
        (endless: false, round: 10),
        (endless: true, round: 1),
        (endless: true, round: 14)
      ]) {
        testWidgets('board budget $scenario at $size / $textScale',
            (tester) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final screen = QaScreen('golden_insets', size, 24);
          try {
            await pumpGolden(
                tester,
                scenario.endless
                    ? EndlessScreen.forTesting(
                        initialRound: scenario.round,
                        boardGenerator: goldenEndlessGenerator())
                    : GameScreen(level: scenario.round),
                viewport: GoldenViewport(size, textScale: textScale));
            expect(
                fit.inspectBoard(tester, screen,
                    endless: scenario.endless,
                    level: scenario.endless
                        ? null
                        : fit.readLevel(scenario.round)),
                isEmpty);
            final tiles = find
                .byWidgetPredicate((w) => w is GameTileWidget && !w.trayTile);
            final stack = find
                .ancestor(of: tiles.first, matching: find.byType(Stack))
                .first;
            final logical = tester.getSize(stack);
            final canvas = fit.globalRect(tester, stack);
            final scale = canvas.width / logical.width;
            final hud = find.byKey(ValueKey(
                scenario.endless ? 'endless_hud_scroll' : 'game_hud_scroll'));
            final hudHeight = tester.getSize(hud).height;
            if (textScale == 1) {
              final scroll = tester.state<ScrollableState>(
                  find.descendant(of: hud, matching: find.byType(Scrollable)));
              expect(scroll.position.maxScrollExtent, 0,
                  reason: 'Normal-size HUD must remain fully visible');
            }
            // Frozen pre-circular layout: 94px tray + 8/16px margins,
            // 64px booster + 4/8px padding; board border 2px and 8px gutters.
            // Use the unchanged HUD's actual font metrics, not new spacing
            // constants. The regressed 88/95px row fails this lower bound.
            final legacyAvailable = size.height - 48 - hudHeight - 118 - 76;
            final legacyScale = math.min(
                1.0,
                math.min(size.width / (logical.width + 24),
                    legacyAvailable / (logical.height + 20)));
            if (textScale == 1) {
              expect(scale, greaterThanOrEqualTo(legacyScale - 1e-6),
                  reason:
                      'Restore the approved board scale, not only containment');
              expect(canvas.height,
                  greaterThanOrEqualTo(logical.height * legacyScale - 1e-6));
            }
            final safe = Rect.fromLTWH(0, 24, size.width, size.height - 48);
            final frame = canvas.inflate(2 * scale);
            expectResultInside(safe, frame, 'Complete board frame');
            final tray = fit.globalRect(tester, find.byType(GameTray));
            expectResultInside(safe, tray, 'Complete tray');
            final controls = <Rect>[];
            for (final action in BoosterAction.values) {
              final button = find.byWidgetPredicate(
                  (w) => w is GameBoosterButton && w.action == action);
              final bounds = fit.globalRect(tester, button);
              controls.add(bounds);
              expectResultInside(safe, bounds, 'Entire $action control');
              expect(bounds.height, greaterThanOrEqualTo(48));
              expect(bounds.overlaps(frame), isFalse);
              expect(bounds.overlaps(tray), isFalse);
              final circle = fit.globalRect(
                  tester,
                  find.descendant(
                      of: button,
                      matching: find
                          .byKey(const ValueKey('booster_icon_medallion'))));
              final badge = fit.globalRect(
                  tester,
                  find.descendant(
                      of: button,
                      matching:
                          find.byKey(const ValueKey('booster_funding_badge'))));
              expectResultInside(bounds, circle, 'Complete silver rim');
              expectResultInside(bounds, badge, 'Complete navy badge');
              expect(circle.width, closeTo(circle.height, 1e-9));
              expect(circle.width, greaterThanOrEqualTo(72));
              expect(badge.center.dx, closeTo(circle.center.dx, 1e-9));
              expect(badge.top, greaterThan(circle.center.dy));
              expect(badge.top, lessThan(circle.bottom));
              expect(badge.bottom, greaterThan(circle.bottom));
              for (final paragraph in tester.renderObjectList<RenderParagraph>(
                  find.descendant(
                      of: button, matching: find.byType(RichText)))) {
                expect(paragraph.didExceedMaxLines, isFalse);
                expectResultInside(
                    badge,
                    Rect.fromPoints(
                        paragraph.localToGlobal(Offset.zero),
                        paragraph.localToGlobal(
                            paragraph.size.bottomRight(Offset.zero))),
                    'Readable quantity');
              }
            }
            for (var i = 1; i < controls.length; i++) {
              expect(controls[i - 1].right, lessThan(controls[i].left));
            }
            expect(frame.bottom, lessThanOrEqualTo(controls.first.top));
            if (scenario.round.isEven) {
              expect(tray.bottom, lessThanOrEqualTo(frame.top));
            } else {
              expect(controls.first.bottom, lessThanOrEqualTo(tray.top));
            }
            // Actual art and input boxes must share the same screen transform.
            for (var i = 0; i < tiles.evaluate().length; i++) {
              final tile = tiles.at(i);
              final bounds = fit.globalRect(tester, tile);
              final face = fit.globalRect(tester,
                  find.descendant(of: tile, matching: find.byType(TileFace)));
              final input = fit.globalRect(
                  tester,
                  find.descendant(
                      of: tile, matching: find.byType(GestureDetector)));
              for (final rect in [face, input]) {
                expect(
                    (rect.topLeft - bounds.topLeft).distance, lessThan(1e-6));
                expect((rect.bottomRight - bounds.bottomRight).distance,
                    lessThan(1e-6));
              }
              final faceWidget = tester.widget<TileFace>(
                  find.descendant(of: tile, matching: find.byType(TileFace)));
              if (faceWidget.art.assetPath != null) {
                final artwork = fit.globalRect(
                    tester,
                    find.descendant(
                        of: tile, matching: find.byType(TileSymbol)));
                final localArt = TileFace.artworkRect(tester.getSize(tile));
                expect(artwork.width, closeTo(localArt.width * scale, 1e-6));
                expect(artwork.height, closeTo(localArt.height * scale, 1e-6));
                expectResultInside(
                    bounds, artwork, 'Complete approved tile sprite');
              }
              if (textScale == 1) {
                expect(
                    bounds.width,
                    greaterThanOrEqualTo(
                        tester.getSize(tile).width * legacyScale - 1e-6));
              }
            }
            // Large-text HUD labels remain reachable inside their own scroll
            // area; scrolling them cannot move the board or controls.
            for (final element in find
                .descendant(of: hud, matching: find.byType(GameBadge))
                .evaluate()) {
              final badge = find.byWidget(element.widget);
              await tester.ensureVisible(badge);
              await tester.pumpAndSettle();
              expectResultInside(fit.globalRect(tester, hud),
                  fit.globalRect(tester, badge), 'Reachable HUD badge');
            }
            expect(fit.globalRect(tester, stack), canvas);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          }
        });
      }
    }
  }
}
