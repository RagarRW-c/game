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
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';

import 'golden_fixtures.dart';
import '../../qa/support/tile_asset_images.dart';

class GoldenViewport {
  const GoldenViewport(this.size, {this.textScale = 1});
  final Size size;
  final double textScale;
  String get suffix =>
      '${size.width.toInt()}x${size.height.toInt()}_text${textScale.toStringAsFixed(1)}';
}

const phone = GoldenViewport(Size(360, 800));
const smallPhone = GoldenViewport(Size(320, 568));
const largePhone = GoldenViewport(Size(412, 915));
const largeText = GoldenViewport(Size(360, 800), textScale: 1.6);
const smallLargeText = GoldenViewport(Size(320, 568), textScale: 2);
const goldenBoundaryKey = ValueKey('golden_full_viewport');

/// Register once in each golden file. Ordinary tests retain their configuration.
void configureGoldens() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!Platform.isWindows) {
      throw StateError(
          'These baselines require Windows. See qa/VISUAL_REGRESSION.md.');
    }
    if (AppFlavorConfig.current != AppFlavor.prod) {
      throw StateError('Run goldens with --dart-define=FLAVOR=prod.');
    }
    if (autoUpdateGoldenFiles &&
        Platform.environment['GOLDEN_REVIEW'] != 'candidate') {
      throw StateError('Baseline writes require GOLDEN_REVIEW=candidate. '
          'Generated files still need human review; see qa/VISUAL_REGRESSION.md.');
    }
    await _loadFonts();
  });
}

Future<void> _loadFonts() async {
  final configFile = File('.dart_tool/package_config.json').absolute;
  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
  final flutter = packages.singleWhere((p) => p['name'] == 'flutter');
  final packageUri = configFile.uri.resolve(flutter['rootUri'] as String);
  final fonts = Directory.fromUri(packageUri)
      .uri
      .resolve('../../bin/cache/artifacts/material_fonts/');

  // Explicit real fonts, never Ahem or an implicit OS lookup. These files are
  // part of the installed Flutter SDK; nothing is downloaded by this helper.
  for (final entry in {
    'Roboto': [
      'roboto-regular.ttf',
      'roboto-light.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
      'roboto-black.ttf',
      'roboto-italic.ttf',
    ],
    'MaterialIcons': ['materialicons-regular.otf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final name in entry.value) {
      final file = File.fromUri(fonts.resolve(name));
      if (!file.existsSync()) {
        throw StateError(
            'Missing SDK font: ${file.path}. Use the baseline SDK.');
      }
      loader
          .addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }
}

Future<void> settleGolden(WidgetTester tester) async {
  // Bounded settling fails on a newly introduced infinite animation instead
  // of silently capturing an arbitrary frame. Reduced motion is harness-only.
  await tester.pumpAndSettle(const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
  await loadVisibleTileImages(tester);
  expect(tester.takeException(), isNull);
  expect(find.byType(CircularProgressIndicator), findsNothing,
      reason: 'Never approve a loading screen as the requested UI.');
}

/// Cleanup must run inside the test callback: Flutter checks debug globals
/// and pending timers BEFORE package:test's addTearDown callbacks.
void goldenTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    final previousShadows = debugDisableShadows;
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      debugDisableShadows = false;
      await body(tester);
    } finally {
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      } finally {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugDefaultTargetPlatformOverride = previousPlatform;
        debugDisableShadows = previousShadows;
        SharedPreferences.setMockInitialValues({});
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
    }
  }, tags: ['golden']);
}

Future<void> pumpGolden(
  WidgetTester tester,
  Widget screen, {
  GoldenViewport viewport = phone,
  GoldenProgress? progress,
  Map<String, WidgetBuilder> routes = const {},
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport.size;
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(AppScope(
    progressRepository: progress ?? GoldenProgress(),
    levelRepository: GoldenLevels(),
    audioService: GoldenAudio(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: GameTheme.theme(),
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      navigatorObservers: [appRouteObserver],
      routes: routes,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(viewport.textScale),
          disableAnimations: true,
          platformBrightness: Brightness.light,
          boldText: false,
          highContrast: false,
          padding: const EdgeInsets.only(top: 24, bottom: 24),
          viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
          viewInsets: EdgeInsets.zero,
        ),
        // Above the Navigator, so real dialog routes and scrims are captured.
        child: RepaintBoundary(key: goldenBoundaryKey, child: child!),
      ),
      home: screen,
    ),
  ));
  await settleGolden(tester);
}

Future<void> expectGolden(
    WidgetTester tester, String name, GoldenViewport viewport) async {
  await settleGolden(tester);
  final boundary = find.byKey(goldenBoundaryKey);
  expect(boundary, findsOneWidget);
  expect(tester.getSize(boundary), viewport.size);
  expect(tester.renderObject<RenderRepaintBoundary>(boundary).debugNeedsPaint,
      isFalse);
  // Flutter's strict LocalFileComparator: no tolerance override or auto-accept.
  await expectLater(boundary,
      matchesGoldenFile('baselines/windows/${name}_${viewport.suffix}.png'));
}

Future<void> revealGolden(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await settleGolden(tester);
  expect(target.hitTestable(), findsOneWidget);
}

// Include FittedBox transforms, following the existing screen-fit QA helper.
Rect goldenGlobalRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return Rect.fromPoints(box.localToGlobal(Offset.zero),
      box.localToGlobal(Offset(box.size.width, box.size.height)));
}
