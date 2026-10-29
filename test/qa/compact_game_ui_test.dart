import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/app_flavor.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/main_menu_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/win_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/coastal_ui.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
import 'package:triple_tile_adventure/presentation/widgets/victory_premium.dart';

import 'support/result_layout.dart';
import 'support/coastal_assets.dart';

// Phone-fit assertions need the production font metrics, not Ahem's square
// glyphs. Use the same bundled SDK fonts as the existing Windows goldens;
// this reads local files only and does not depend on an installed OS font.
Future<void> _loadUiFonts() async {
  final configFile = File('.dart_tool/package_config.json').absolute;
  final config =
      jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
  final flutter = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((package) => package['name'] == 'flutter');
  final fonts =
      Directory.fromUri(configFile.uri.resolve(flutter['rootUri'] as String))
          .uri
          .resolve('../../bin/cache/artifacts/material_fonts/');
  final loader = FontLoader('Roboto');
  for (final name in ['regular', 'medium', 'bold', 'black']) {
    final bytes =
        await File.fromUri(fonts.resolve('roboto-$name.ttf')).readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

class _Audio implements GameAudioService {
  final ValueNotifier<bool> _musicPreference = ValueNotifier<bool>(false);
  bool _disposed = false;

  @override
  ValueListenable<bool> get musicPreference => _musicPreference;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _musicPreference.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Future<void> mount(WidgetTester tester, Widget screen, Size size, double scale,
    {RouteFactory? onGenerateRoute}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'final_reward_unlocked': true,
    'coins': 1234567,
  });
  final progress = ProgressRepository();
  await progress.claimDailyLoginStreak(DateTime.now());
  final audio = _Audio();
  addTearDown(audio.dispose);
  await tester.pumpWidget(AppScope(
      progressRepository: progress,
      levelRepository: LevelRepository(),
      audioService: audio,
      child: MaterialApp(
          theme: GameTheme.theme(),
          onGenerateRoute: onGenerateRoute,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.symmetric(vertical: 24)),
              child: child!),
          home: screen)));
  await tester.pumpAndSettle();
  await loadCoastalImages(tester);
}

void expectReadable(WidgetTester tester, Finder scope) {
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
      find.descendant(of: scope, matching: find.byType(RichText)))) {
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.size.width, greaterThan(0));
    expectResultInside(
        resultGlobalRect(tester, scope),
        Rect.fromPoints(paragraph.localToGlobal(Offset.zero),
            paragraph.localToGlobal(paragraph.size.bottomRight(Offset.zero))),
        'The control must contain its full label and icon');
  }
}

// Paragraph overflow alone misses a word wrapping onto two valid lines.
// Inspect the actual laid-out selection boxes for each complete label word.
void expectUnbrokenWords(WidgetTester tester, Finder button, String label) {
  final text = find.descendant(of: button, matching: find.text(label));
  expect(text, findsOneWidget);
  final richText = find.descendant(of: text, matching: find.byType(RichText));
  expect(richText, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(richText);
  expect(paragraph.text.toPlainText(), label);
  expect(paragraph.didExceedMaxLines, isFalse);
  for (final word in RegExp(r'\S+').allMatches(label)) {
    final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: word.start, extentOffset: word.end));
    expect(boxes, isNotEmpty, reason: '${word.group(0)} must be painted');
    final lineTop = boxes.first.top;
    for (final box in boxes) {
      expect(box.top, closeTo(lineTop, .001),
          reason: '$label must not split ${word.group(0)} across lines');
      expect(box.left, greaterThanOrEqualTo(-.001));
      expect(box.right, lessThanOrEqualTo(paragraph.size.width + .001));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadUiFonts);
  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 915)
  ]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('victory actions and cat fit $size / $scale', (tester) async {
        final calls = <String>[];
        await mount(
            tester,
            WinScreen(
                level: 7,
                isFinalLevel: false,
                tilesCleared: 30,
                undoUsed: 1,
                hintUsed: 0,
                shuffleUsed: 1,
                starsEarned: 3,
                coinsEarned: 50,
                xpEarned: 225,
                chestLabel: 'Wood Chest',
                onNext: () => calls.add('next'),
                onRestart: () => calls.add('replay'),
                onMap: () => calls.add('map')),
            size,
            scale);
        final scroll = find.byKey(const ValueKey('victory_scroll'));
        final position = tester
            .state<ScrollableState>(
                find.descendant(of: scroll, matching: find.byType(Scrollable)))
            .position;
        expect(find.byKey(const ValueKey('victory_world')), findsNothing);
        expect(find.byKey(const ValueKey('victory_description')), findsNothing);
        expect(find.textContaining('tiles cleared'), findsNothing);
        if (scale == 1) {
          expect(position.maxScrollExtent, closeTo(0, .01));
          final cat =
              tester.getRect(find.byKey(const ValueKey('victory_cat_frame')));
          expect(cat.height, greaterThan(100));
          expect(cat.width / cat.height, closeTo(9 / 16, .001));
          final surround = resultGlobalRect(
              tester, find.byKey(const ValueKey('victory_premium_frame')));
          expect(cat.center.dx, closeTo(surround.center.dx, .01));
          expect(cat.center.dy, closeTo(surround.center.dy, .01));
          expect(cat.height / surround.height,
              closeTo(PremiumVictoryVideoFrame.openingFraction, 1e-9));
          expect(cat.width / surround.width,
              closeTo(PremiumVictoryVideoFrame.openingFraction, 1e-9));
          final viewport = tester.getRect(scroll);
          for (final key in [
            'victory_cat_frame',
            'victory_title',
            'victory_reward_Coins',
            'victory_reward_XP',
            'victory_chest',
            'victory_star_1',
            'victory_star_2',
            'victory_star_3'
          ]) {
            expectResultInside(
                viewport,
                resultGlobalRect(tester, find.byKey(ValueKey(key))),
                '$key must be fully visible without scrolling');
          }
          final bannerBottom = resultGlobalRect(
                  tester, find.byKey(const ValueKey('victory_title')))
              .bottom;
          final rewardTop = resultGlobalRect(
                  tester, find.byKey(const ValueKey('victory_rewards')))
              .top;
          expect(rewardTop - bannerBottom, inInclusiveRange(0, 8),
              reason: 'No empty subtitle area may remain below the banner');
          final nextTop = resultGlobalRect(
                  tester, find.byKey(const ValueKey('victory_next')))
              .top;
          expect(
              nextTop -
                  resultGlobalRect(
                          tester, find.byKey(const ValueKey('victory_rewards')))
                      .bottom,
              inInclusiveRange(0, 8),
              reason:
                  'Next Level must follow Rewards without a statistics gap');
          final regions = <String, Rect>{
            'cat surround': surround,
            'stars': resultGlobalRect(tester, find.byType(VictoryStars)),
            for (final key in [
              'victory_title',
              'victory_rewards',
              'victory_next',
              'victory_replay',
              'victory_map'
            ])
              key: resultGlobalRect(tester, find.byKey(ValueKey(key))),
          }.entries.toList();
          for (var i = 0; i < regions.length; i++) {
            expectResultInside(viewport, regions[i].value,
                '${regions[i].key} must be inside the initial viewport');
            for (var j = i + 1; j < regions.length; j++) {
              final overlap = regions[i].value.intersect(regions[j].value);
              expect(overlap.width > .01 && overlap.height > .01, isFalse,
                  reason:
                      '${regions[i].key} must not overlap ${regions[j].key}');
            }
          }
        }
        final rewards = find.byKey(const ValueKey('victory_rewards'));
        if (scale != 1) {
          await tester.ensureVisible(rewards);
          await tester.pumpAndSettle();
        }
        expectReadable(tester, rewards);
        expectResultTextVisible(
            tester, 'victory_reward_Coins', 'victory_scroll');
        expectResultTextVisible(tester, 'victory_reward_XP', 'victory_scroll');
        final nextSize =
            tester.getSize(find.byKey(const ValueKey('victory_next')));
        final replaySize =
            tester.getSize(find.byKey(const ValueKey('victory_replay')));
        final mapSize =
            tester.getSize(find.byKey(const ValueKey('victory_map')));
        expect(nextSize.height, greaterThanOrEqualTo(76));
        expect(replaySize.height, greaterThanOrEqualTo(64));
        expect(mapSize.height, greaterThanOrEqualTo(64));
        expect(replaySize, mapSize,
            reason: 'The two blue actions have balanced dimensions');
        if (scale == 1) {
          expect(nextSize.width / nextSize.height, lessThanOrEqualTo(4.75),
              reason:
                  'The primary action must not become a thin full-width strip');
          expect(nextSize.height, greaterThan(replaySize.height));
        }
        for (final key in ['victory_next', 'victory_replay', 'victory_map']) {
          final target = find.byKey(ValueKey(key));
          if (scale != 1) await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(target.hitTestable(), findsOneWidget);
          expectResultInside(
              Rect.fromLTRB(0, 24, size.width, size.height - 24),
              resultGlobalRect(tester, target),
              '$key must fit the safe viewport');
          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          final image = tester.widget<Image>(
              find.descendant(of: target, matching: find.byType(Image)));
          final density = (image.image as ExactAssetImage).scale;
          final buttonSize = tester.getSize(target);
          expect(density, closeTo(276 / buttonSize.height, 1e-9));
          expect(image.centerSlice!.height * density, closeTo(276, 1e-9));
          expect(384 / density, lessThan(buttonSize.width),
              reason: 'Rounded artwork ends must fit without distortion');
          expectReadable(tester, target);
          await tester.tap(target);
        }
        expect(calls, ['next', 'replay', 'map']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
      testWidgets('menu actions fit $size / $scale', (tester) async {
        await mount(tester, const MainMenuScreen(), size, scale);
        expect(find.byKey(const ValueKey('menu_action_DEV QA Tools')),
            AppFlavorConfig.qaToolsEnabled ? findsOneWidget : findsNothing);
        final scroll = find.byKey(const ValueKey('main_menu_scroll'));
        final position = tester
            .state<ScrollableState>(
                find.descendant(of: scroll, matching: find.byType(Scrollable)))
            .position;
        if (scale == 1) {
          expect(position.maxScrollExtent, closeTo(0, .01));
          final viewport = tester.getRect(scroll);
          for (final key in ['menu_logo', 'menu_mascot', 'menu_coins']) {
            final art = find.byKey(ValueKey(key));
            expect(art, findsOneWidget);
            expectResultInside(viewport, resultGlobalRect(tester, art),
                '$key must be visible in the initial viewport');
          }
          expect(
              tester.getSize(find.byKey(const ValueKey('menu_mascot'))).height,
              greaterThan(40));
        }
        for (final label in [
          'Adventure',
          'Endless Mode',
          'Claim Daily Reward',
          'Daily Spin',
          'Booster Shop',
          'Profile',
          'Chests',
          'Daily Challenges',
          'Collection Book',
          'Achievements',
          'Statistics',
          'Settings',
          'Final Reward',
          if (AppFlavorConfig.qaToolsEnabled) 'DEV QA Tools',
        ]) {
          final target = find.byKey(ValueKey('menu_action_$label'));
          if (scale != 1) await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(target.hitTestable(), findsOneWidget);
          expectResultInside(
              Rect.fromLTRB(0, 24, size.width, size.height - 24),
              resultGlobalRect(tester, target),
              '$label must be fully reachable');
          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          expectReadable(tester, target);
          expectUnbrokenWords(tester, target, label);
        }
        final shop = find.byKey(const ValueKey('menu_shop_shortcut'));
        if (scale != 1) await tester.ensureVisible(shop);
        await tester.pumpAndSettle();
        expect(shop.hitTestable(), findsOneWidget);
        expectReadable(tester, shop);
        expectUnbrokenWords(tester, shop, 'Shop');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
      testWidgets('booster price and labels remain readable $size / $scale',
          (tester) async {
        var taps = 0;
        await mount(
            tester,
            Scaffold(
                body: Center(
                    child: SizedBox(
                        width: size.width - 32,
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final label in ['Undo', 'Hint', 'Shuffle'])
                                Expanded(
                                    child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: GameBoosterButton(
                                            label: label,
                                            badge: '150',
                                            action: switch (label) {
                                              'Undo' => BoosterAction.undo,
                                              'Hint' => BoosterAction.hint,
                                              _ => BoosterAction.shuffle,
                                            },
                                            onPressed: () => taps++))),
                            ])))),
            size,
            scale);
        expect(
            find.byKey(const ValueKey('booster_price_coin')), findsNWidgets(3));
        expect(find.byKey(const ValueKey('booster_icon_medallion')),
            findsNWidgets(3));
        final controlBounds = <Rect>[];
        for (final label in ['Undo', 'Hint', 'Shuffle']) {
          final target = find.byWidgetPredicate(
              (w) => w is GameBoosterButton && w.label == label);
          expectReadable(tester, target);
          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          final medallion = find.descendant(
              of: target,
              matching: find.byKey(const ValueKey('booster_icon_medallion')));
          final badge = find.descendant(
              of: target,
              matching: find.byKey(const ValueKey('booster_funding_badge')));
          final art = tester.widget<BoosterActionArtwork>(find.descendant(
              of: target, matching: find.byType(BoosterActionArtwork)));
          expect(
              art.action,
              switch (label) {
                'Undo' => BoosterAction.undo,
                'Hint' => BoosterAction.hint,
                _ => BoosterAction.shuffle,
              });
          expect(tester.widget<CustomPaint>(medallion).painter,
              isA<BoosterMedallionPainter>());
          final circleBounds = tester.getRect(medallion);
          final badgeBounds = tester.getRect(badge);
          final buttonBounds = tester.getRect(target);
          controlBounds.add(buttonBounds);
          expect(circleBounds.width, closeTo(circleBounds.height, 1e-9));
          expect(circleBounds.width, greaterThanOrEqualTo(56));
          expect(circleBounds.center.dx, closeTo(buttonBounds.center.dx, 1e-9),
              reason:
                  '$label circle must be centered in its allocated hit area');
          expect(badgeBounds.center.dx, closeTo(circleBounds.center.dx, 1e-9));
          expect(badgeBounds.top, lessThan(circleBounds.bottom));
          expect(badgeBounds.top, greaterThan(circleBounds.center.dy));
          expect(badgeBounds.bottom, greaterThan(circleBounds.bottom));
          expectResultInside(buttonBounds, circleBounds,
              'Complete circle: $label button=$buttonBounds circle=$circleBounds');
          expectResultInside(buttonBounds, badgeBounds,
              'Complete badge: $label button=$buttonBounds badge=$badgeBounds');
          expectResultInside(Rect.fromLTWH(0, 0, size.width, size.height),
              tester.getRect(target), 'Booster remains on screen');
          final coin = find.descendant(
              of: target,
              matching: find.byKey(const ValueKey('booster_price_coin')));
          final value = find.descendant(of: target, matching: find.text('150'));
          expect(value, findsOneWidget);
          expectUnbrokenWords(tester, target, '150');
          if (scale == 1) {
            expect(tester.getRect(coin).left,
                greaterThan(tester.getRect(value).right));
          }
          await tester.tap(target);
        }
        for (var i = 1; i < controlBounds.length; i++) {
          expect(controlBounds[i - 1].right, lessThan(controlBounds[i].left),
              reason: 'Complete controls must leave space between boosters');
        }
        expect(taps, 3);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('adaptive menu preserves every navigation destination',
      (tester) async {
    final visited = <String>[];
    await mount(tester, const MainMenuScreen(), const Size(320, 568), 2,
        onGenerateRoute: (settings) {
      visited.add(settings.name!);
      return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('Destination')));
    });
    final destinations = {
      'Adventure': '/worlds',
      'Endless Mode': '/endless',
      'Daily Spin': '/lucky-wheel',
      'Booster Shop': '/booster-shop',
      'Profile': '/player-profile',
      'Chests': '/treasure-chests',
      'Daily Challenges': '/daily-challenges',
      'Collection Book': '/collection-book',
      'Achievements': '/achievements',
      'Statistics': '/statistics',
      'Settings': '/settings',
      'Final Reward': '/final-code',
      if (AppFlavorConfig.qaToolsEnabled) 'DEV QA Tools': '/dev-qa',
    };
    final expectedVisits = <String>[];
    for (final entry in destinations.entries) {
      final action = find.byKey(ValueKey('menu_action_${entry.key}'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expectUnbrokenWords(tester, action, entry.key);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expectedVisits.add(entry.value);
      expect(visited, expectedVisits);
      Navigator.of(tester.element(find.text('Destination'))).pop();
      await tester.pumpAndSettle();
    }
    expect(visited, destinations.values.toList());
    final shop = find.byKey(const ValueKey('menu_shop_shortcut'));
    await tester.ensureVisible(shop);
    await tester.pumpAndSettle();
    await tester.tap(shop);
    await tester.pumpAndSettle();
    expect(visited, [...destinations.values, '/booster-shop']);
    Navigator.of(tester.element(find.text('Destination'))).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('coastal actions retain enabled and disabled semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Column(children: [
        CoastalButton(label: 'Adventure', onPressed: () => taps++),
        const CoastalButton(label: 'Next Spin Tomorrow', onPressed: null),
      ]))));
      expect(
          tester.getSemantics(find.bySemanticsLabel('Adventure')),
          matchesSemantics(
              label: 'Adventure',
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true));
      expect(
          tester.getSemantics(find.bySemanticsLabel('Next Spin Tomorrow')),
          matchesSemantics(
              label: 'Next Spin Tomorrow',
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              hasTapAction: false));
      await tester.tap(find.text('Adventure'));
      await tester.tap(find.text('Next Spin Tomorrow'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('booster funding badge and disabled semantics stay distinct',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var taps = 0;
      for (final badge in ['x2', '+3', '150', '225']) {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Center(
                    child: SizedBox(
                        width: 100,
                        child: GameBoosterButton(
                            label: 'Hint',
                            badge: badge,
                            action: BoosterAction.hint,
                            onPressed: () => taps++))))));
        final hint = find.byWidgetPredicate(
            (widget) => widget is GameBoosterButton && widget.label == 'Hint');
        expect(
            tester
                .widget<AnimatedOpacity>(find.descendant(
                    of: hint, matching: find.byType(AnimatedOpacity)))
                .opacity,
            1);
        final coin = find.descendant(
            of: hint,
            matching: find.byKey(const ValueKey('booster_price_coin')));
        expect(coin,
            ['150', '225'].contains(badge) ? findsOneWidget : findsNothing);
        expect(find.descendant(of: hint, matching: find.text(badge)),
            findsOneWidget);
        expect(
            tester.getSemantics(find.bySemanticsLabel('Hint $badge')),
            matchesSemantics(
                label: 'Hint $badge',
                isButton: true,
                hasEnabledState: true,
                isEnabled: true,
                hasTapAction: true));
        await tester.tap(find.byType(GameBoosterButton));
      }
      expect(taps, 4);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 100,
                      child: GameBoosterButton(
                          label: 'Hint',
                          badge: '150',
                          action: BoosterAction.hint,
                          onPressed: null))))));
      await tester.pumpAndSettle();
      final disabledHint = find.byWidgetPredicate(
          (widget) => widget is GameBoosterButton && widget.label == 'Hint');
      expect(
          tester
              .widget<AnimatedOpacity>(find.descendant(
                  of: disabledHint, matching: find.byType(AnimatedOpacity)))
              .opacity,
          .46);
      expect(
          find.descendant(
              of: disabledHint,
              matching: find.byKey(const ValueKey('booster_price_coin'))),
          findsOneWidget);
      expect(
          tester.getSemantics(find.bySemanticsLabel('Hint 150')),
          matchesSemantics(
              label: 'Hint 150',
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              hasTapAction: false));
      await tester.tap(find.byType(GameBoosterButton));
      expect(taps, 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });
}
