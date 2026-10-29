import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/win_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/map_screen.dart';
import 'package:triple_tile_adventure/presentation/screens/world_selection_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_ui.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
import 'package:triple_tile_adventure/presentation/widgets/victory_video.dart';
import 'package:triple_tile_adventure/presentation/widgets/victory_premium.dart';

import 'support/tile_asset_images.dart';
import 'support/result_layout.dart';

/// Counts subscriptions through ChangeNotifier's public listener methods.
/// The victory widget must release its music preference listener on disposal.
class _TrackedMusicPreference extends ValueNotifier<bool> {
  _TrackedMusicPreference(super.value);

  int activeListenerCount = 0;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    activeListenerCount++;
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    activeListenerCount--;
  }
}

class _VideoPlatform extends VideoPlayerPlatform {
  final streams = <int, StreamController<VideoEvent>>{};
  final disposed = <int>[];
  final cancelledSubscriptions = <int>[];
  final cancellationCompletion = <int, Completer<void>>{};
  final playing = <int, bool>{};
  final volumes = <double>[];
  final volumesAtPlay = <double?>[];
  final loopingValues = <bool>[];
  int loopCount = 0;

  // ExoPlayer REPEAT_MODE_ALL wraps internally without STATE_ENDED. A Dart
  // completed event would incorrectly model non-looping native playback.
  void loopBoundary() {
    if (loopingValues.last != true || playing[1] != true) {
      throw StateError('Native loop requires looping and active playback');
    }
    loopCount++;
  }

  final sources = <DataSource>[];
  final seeks = <Duration>[];
  int playCalls = 0;
  bool? mix;
  Completer<int?>? creation;

  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    sources.add(options.dataSource);
    final id = sources.length;
    cancellationCompletion[id] = Completer<void>();
    // A void onCancel makes StreamSubscription.cancel() return Dart's shared
    // Future._nullFuture, which belongs to the root zone. In a widget test its
    // await continuation runs outside FakeAsync, so tester.pump() cannot
    // advance VideoPlayerController.dispose() to native platform disposal.
    // Return a test-zone Future and complete it at the explicit cleanup gate.
    streams[id] = StreamController<VideoEvent>(onCancel: () {
      cancelledSubscriptions.add(id);
      return cancellationCompletion[id]!.future;
    });
    return creation == null ? id : await creation!.future;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    // Android's native dispose cancels its event subscription; it does not
    // await close() on the single-subscription stream after its listener left.
    // The controller's cancellation is asserted separately in each test.
    playing[playerId] = false;
    disposed.add(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    loopingValues.add(looping);
  }

  @override
  Future<void> play(int playerId) async {
    volumesAtPlay.add(volumes.isEmpty ? null : volumes.last);
    playCalls++;
    playing[playerId] = true;
  }

  @override
  Future<void> pause(int playerId) async {
    playing[playerId] = false;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seeks.add(position);
  }

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {
    mix = mixWithOthers;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => ColoredBox(
      key: ValueKey('video_texture_${options.playerId}'), color: Colors.blue);

  void initialize([int id = 1]) => streams[id]!.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(milliseconds: 5040),
      size: const Size(720, 1280)));
}

class _Levels extends LevelRepository {
  @override
  Future<LevelDefinition> loadLevel(int level) async => LevelDefinition(
      level: level,
      name: 'Victory fixture',
      timeBonusSeconds: 60,
      tiles: List.generate(
          3,
          (i) =>
              Tile(id: 'v$i', type: 'apple', x: .1 + i * .3, y: .2, layer: 0)));
}

class _Progress extends ProgressRepository {
  int completionCalls = 0;
  final completionCoinGrants = <int>[];
  late PlayerProfileSummary beforeCampaign;
  int campaignLevel = 1;

  @override
  Future<int> addCoins(int amount) async {
    completionCoinGrants.add(amount);
    return super.addCoins(amount);
  }

  @override
  Future<void> recordLevelCompleted(int level, int stars) async {
    completionCalls++;
    await super.recordLevelCompleted(level, stars);
  }

  @override
  Future<List<PendingAchievementPopup>>
      consumePendingAchievementPopups() async {
    await super.consumePendingAchievementPopups();
    return [];
  }
}

class _Audio implements GameAudioService {
  @override
  final ValueNotifier<bool> musicPreference = ValueNotifier(true);
  @override
  bool get musicEnabled => musicPreference.value;
  @override
  set musicEnabled(bool value) => musicPreference.value = value;
  @override
  Future<void> setMusicEnabled(bool enabled) async {
    musicPreference.value = enabled;
  }

  final completionCues = <String>[];
  final musicStarts = <int>[];
  int victoryPauses = 0;
  @override
  bool sfxEnabled = false;
  @override
  Future<void> playLevelComplete() async =>
      completionCues.add('level_complete');
  @override
  Future<void> playWorldUnlocked() async => completionCues.add('world_unlock');
  @override
  Future<void> startGameplayMusic({int level = 1, Object? owner}) async {
    musicStarts.add(level);
  }

  @override
  Future<void> pauseGameplayMusicForVictory({required Object owner}) async {
    victoryPauses++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// Real Campaign route and result screen, with only native video/audio and the
/// deterministic three-tile level supplied by fakes. No result widget shortcut.
Future<GlobalKey<NavigatorState>> _completeCampaign(WidgetTester tester,
    _VideoPlatform platform, _Progress progress, _Audio audio,
    {int level = 1,
    bool rootGame = false,
    int initialCoins = 0,
    Size size = const Size(360, 800),
    double textScale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(
      {'coins': initialCoins, 'vibration_enabled': false});
  await progress.setLevelOneTutorialSeen();
  progress.campaignLevel = level;
  progress.beforeCampaign = await progress.playerProfile();
  expect(progress.beforeCampaign.coins, initialCoins);
  expect(progress.beforeCampaign.totalXp, 0);
  expect(progress.beforeCampaign.levelsCompleted, 0);
  expect(progress.beforeCampaign.achievementsUnlocked, 0);
  final navigator = GlobalKey<NavigatorState>();
  GameScreen game(int number) => GameScreen(
      level: number,
      victoryVideoControllerFactory: VictoryVideo.createController);
  await tester.pumpWidget(AppScope(
      levelRepository: _Levels(),
      progressRepository: progress,
      audioService: audio,
      child: MaterialApp(
          navigatorKey: navigator,
          theme: GameTheme.theme(),
          navigatorObservers: [appRouteObserver],
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  padding: const EdgeInsets.only(top: 24, bottom: 24)),
              child: child!),
          home: rootGame ? game(level) : MapScreen(world: gameWorlds.first),
          onGenerateRoute: (settings) => settings.name == GameScreen.route
              ? MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => game(settings.arguments! as int))
              : null)));
  if (!rootGame) {
    // The route result completes only when leaving gameplay; do not await it
    // before exercising the screen. No guarded tester operation is detached.
    unawaited(navigator.currentState!
        .pushNamed<void>(GameScreen.route, arguments: level));
  }
  await tester.pumpAndSettle();
  await loadVisibleTileImages(tester);
  await _expectGameplayControls(tester, size: size, textScale: textScale);
  for (var i = 0; i < 3; i++) {
    final tile = find.byWidgetPredicate(
        (w) => w is GameTileWidget && !w.trayTile && w.tile.id == 'v$i');
    final tap = tester.widget<GameTileWidget>(tile).onTap!;
    await tester.tap(tile);
    tap();
    await tester.pumpAndSettle();
  }
  expect(find.byType(WinScreen), findsOneWidget);
  expect(progress.completionCalls, 1);
  await _expectCampaignRewards(progress,
      result: tester.widget<WinScreen>(find.byType(WinScreen)));
  expect(audio.completionCues.where((cue) => cue == 'level_complete'), isEmpty);
  expect(audio.victoryPauses, 1);
  if (level == 1) {
    await _pumpUntil(tester, 'production victory player creation',
        () => platform.sources.length == 1, () => _platformState(platform));
  }
  return navigator;
}

Future<void> _expectGameplayControls(WidgetTester tester,
    {required Size size, required double textScale}) async {
  final hud = find.byKey(const ValueKey('game_hud_scroll'));
  final scroll = tester
      .state<ScrollableState>(
          find.descendant(of: hud, matching: find.byType(Scrollable)))
      .position;
  if (size == const Size(320, 568) && textScale >= 1.6) {
    expect(scroll.maxScrollExtent, greaterThan(0),
        reason:
            'Large HUD content must scroll, not overflow the gameplay column');
  }
  final title = tester.widget<GameHeader>(find.byType(GameHeader)).title;
  final paragraph = tester.renderObject<RenderParagraph>(find.descendant(
      of: find.descendant(of: hud, matching: find.text(title)),
      matching: find.byType(RichText)));
  if (textScale > 1.3) {
    expect(paragraph.didExceedMaxLines, isFalse,
        reason: 'The expanded large-text title must remain fully scrollable');
  }
  for (final icon in [Icons.arrow_back_rounded, Icons.pause_rounded]) {
    final control = find.descendant(
        of: hud,
        matching: find.byWidgetPredicate(
            (widget) => widget is GameRoundIconButton && widget.icon == icon));
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    expect(control.hitTestable(), findsOneWidget);
    expect(tester.getSize(control), const Size(48, 48));
    final viewport = tester.getRect(hud).inflate(.01);
    final bounds = tester.getRect(control);
    expect(viewport.contains(bounds.topLeft), isTrue);
    expect(viewport.contains(bounds.bottomRight), isTrue);
  }
  final counter = find.descendant(of: hud, matching: find.text('3 left'));
  await tester.ensureVisible(counter);
  await tester.pumpAndSettle();
  final viewport = tester.getRect(hud).inflate(.01);
  final bounds = tester.getRect(counter);
  expect(viewport.contains(bounds.topLeft), isTrue);
  expect(viewport.contains(bounds.bottomRight), isTrue);
  expect(find.byType(GameBoosterButton).hitTestable(), findsNWidgets(3));
  final tiles = find.byWidgetPredicate(
      (widget) => widget is GameTileWidget && !widget.trayTile);
  expect(tiles.hitTestable(), findsNWidgets(3));
  for (final element in tiles.evaluate()) {
    final side = (size.width * .16).clamp(50.0, 70.0).toDouble();
    final dimensions = tester.getSize(find.byWidget(element.widget));
    // Subpixel roundoff only; scrolling cannot resize logical board tiles.
    expect(dimensions.width, closeTo(side, 1e-7));
    expect(dimensions.height, closeTo(side, 1e-7));
  }
  expect(tester.takeException(), isNull);
}

/// Completion rewards are only one part of a fresh player's balance. First
/// Match/First Win (and Garden World at level 10) grant coins and XP immediately,
/// before their popups are consumed. Hiding those popups does not undo grants.
Future<void> _expectCampaignRewards(_Progress progress,
    {WinScreen? result}) async {
  final boss = progress.campaignLevel == 10;
  final completionCoins = 50 + (boss ? 300 : 0);
  final achievementCoins = 50 + 100 + (boss ? 300 : 0);
  final achievementIds = {
    AchievementId.firstMatch,
    AchievementId.firstWin,
    if (boss) AchievementId.gardenWorld,
  };
  final completionXp = 150 + (boss ? 200 : 0);
  // One apple collection discovery, plus 75 XP for each new achievement.
  final totalXp = 20 + completionXp + 75 * achievementIds.length;
  final persisted = ProgressRepository();
  final after = await persisted.playerProfile();
  expect(after.coins - progress.beforeCampaign.coins,
      completionCoins + achievementCoins);
  expect(await progress.coins(), after.coins,
      reason:
          'The displayed repository and a new reader share persisted coins');
  expect(after.totalXp - progress.beforeCampaign.totalXp, totalXp);
  expect(after.levelsCompleted - progress.beforeCampaign.levelsCompleted, 1);
  expect(after.totalTilesMatched, 3);
  expect(after.collectionUnlocked, 1);
  expect((await persisted.statistics()).totalCoinsEarned,
      completionCoins + achievementCoins);
  expect(
      (await persisted.achievements())
          .where((achievement) => achievement.unlocked)
          .map((achievement) => achievement.definition.id)
          .toSet(),
      achievementIds);
  expect(await persisted.bestStarsForLevel(progress.campaignLevel), 3);
  expect(await persisted.highestUnlockedLevel(), progress.campaignLevel + 1);
  expect(progress.completionCalls, 1);
  expect(progress.completionCoinGrants, [completionCoins],
      reason: 'Rapid taps and navigation must not repeat the completion grant');
  if (result != null) {
    expect(result.coinsEarned, completionCoins);
    // The victory XP snapshot starts after First Match and the discovery.
    expect(result.xpEarned, completionXp + 75 * (achievementIds.length - 1));
    expect(result.starsEarned, 3);
  }
}

void _expectInitialVideoBounds(WidgetTester tester) {
  final frame = tester.getRect(find.byKey(const ValueKey('victory_cat_frame')));
  final viewport = tester.getRect(find.byKey(const ValueKey('victory_scroll')));
  final position = tester
      .state<ScrollableState>(find.descendant(
          of: find.byKey(const ValueKey('victory_scroll')),
          matching: find.byType(Scrollable)))
      .position;
  expect(position.pixels, 0, reason: 'The cat must not require scrolling');
  expect(frame.height, greaterThan(100));
  expect(frame.width / frame.height, closeTo(9 / 16, 1e-9));
  expect(viewport.inflate(.01).contains(frame.topLeft), isTrue);
  expect(viewport.inflate(.01).contains(frame.bottomRight), isTrue,
      reason: 'A mounted but clipped/offscreen cat is a regression');
  expect(
      tester
          .getRect(find.byKey(const ValueKey('victory_next')))
          .overlaps(frame),
      isFalse);

  // Before and after decoder initialization, the full normal-text result must
  // fit together. Enlarging the cat cannot hide rewards or push actions away.
  final victory = find.byType(WinScreen);
  if (MediaQuery.textScalerOf(tester.element(victory)).scale(1) <= 1.2) {
    expect(position.maxScrollExtent, closeTo(0, .01));
    final result = tester.widget<WinScreen>(victory);
    for (final entry in {
      'Coins': result.coinsEarned,
      'XP': result.xpEarned,
    }.entries) {
      final key = 'victory_reward_${entry.key}';
      expect(tester.widget<Text>(find.byKey(ValueKey(key))).data,
          '+${entry.value}');
      expectResultTextVisible(tester, key, 'victory_scroll');
    }
    // The approved static heading is lettering in the banner. Check the real
    // asset and its complete painted bounds; rewards remain live text.
    final banner = find.byKey(const ValueKey('victory_title'));
    expect(tester.widget(banner), isA<PremiumVictoryBanner>());
    final bannerImage = tester.widget<Image>(
        find.descendant(of: banner, matching: find.byType(Image)));
    expect((bannerImage.image as AssetImage).assetName,
        VictoryPremiumAssets.banner);
    final bannerBounds = resultGlobalRect(tester, banner);
    expect(bannerBounds.width / bannerBounds.height, closeTo(1240 / 317, 1e-9));
    expectResultInside(viewport, bannerBounds,
        'All illustrated lettering must remain visible');
    expect(find.byKey(const ValueKey('victory_world')), findsNothing);
    expect(find.byKey(const ValueKey('victory_description')), findsNothing);
    if (result.chestLabel != null) {
      expectResultTextVisible(tester, 'victory_chest', 'victory_scroll');
    }
    final regions = <String, Rect>{
      'cat': frame,
      'stars': resultGlobalRect(tester, find.byType(VictoryStars)),
      for (final key in [
        'victory_title',
        'victory_rewards',
        'victory_next',
        'victory_replay',
        'victory_map',
      ])
        key: resultGlobalRect(tester, find.byKey(ValueKey(key))),
    };
    final entries = regions.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      expectResultInside(viewport, entries[i].value,
          '${entries[i].key} must be fully visible initially');
      for (var j = i + 1; j < entries.length; j++) {
        final intersection = entries[i].value.intersect(entries[j].value);
        // Only ignore subpixel roundoff at shared transformed edges.
        expect(intersection.width > .01 && intersection.height > .01, isFalse,
            reason: '${entries[i].key} must not overlap ${entries[j].key}');
      }
    }
    for (final key in ['victory_next', 'victory_replay', 'victory_map']) {
      final button = find.byKey(ValueKey(key));
      expect(button.hitTestable(), findsOneWidget);
      expect(regions[key]!.height, greaterThanOrEqualTo(48));
      final label = find.descendant(of: button, matching: find.byType(Text));
      final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: label, matching: find.byType(RichText)));
      expect(paragraph.didExceedMaxLines, isFalse);
      expectResultInside(regions[key]!, resultGlobalRect(tester, label),
          '$key must contain its complete label');
    }
    expect(tester.takeException(), isNull);
  }
}

Future<void> _cleanupCampaign(
    WidgetTester tester, _VideoPlatform platform) async {
  await tester.pumpWidget(const SizedBox.shrink());
  if (platform.sources.isNotEmpty && platform.disposed.isEmpty) {
    await _finishNativeDisposal(tester, platform, 'Campaign cleanup');
  }
  if (platform.sources.isNotEmpty) {
    expect(platform.disposed, [1]);
    expect(platform.cancelledSubscriptions, [1]);
    expect(platform.streams[1]!.hasListener, isFalse);
  }
  await _flush(tester);
}

const _fallback =
    SizedBox(key: ValueKey('static_victory'), width: 100, height: 100);

Future<void> _mount(WidgetTester tester,
    {bool reduced = false, ValueListenable<bool>? musicPreference}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: VictoryVideo(
                  maxHeight: 280,
                  musicPreference: musicPreference,
                  fallback: _fallback,
                  controllerFactory: VictoryVideo.createController)))));
  await tester.pump();
}

Future<void> _flush(WidgetTester tester) async {
  // Flush asynchronous platform replies without advancing movie time.
  await tester.pump();
  await tester.pump();
}

/// Advance only the fake async microtask/frame queue, never the movie clock.
/// A blocked platform operation fails with its name instead of hanging or
/// passing after an arbitrary elapsed-time delay.
Future<void> _pumpUntil(WidgetTester tester, String operation,
    bool Function() completed, String Function() state) async {
  for (var frame = 0; frame < 12; frame++) {
    if (completed()) return;
    await tester.pump();
  }
  if (!completed()) {
    fail(
        '$operation did not complete after 12 zero-time frame pumps: ${state()}');
  }
}

String _platformState(_VideoPlatform platform) =>
    'created=${platform.sources.length}, playing=${platform.playing}, '
    'playCalls=${platform.playCalls}, cancelled=${platform.cancelledSubscriptions}, '
    'disposed=${platform.disposed}';

/// Model an asynchronous EventChannel cancellation and control its completion.
/// The controller must await that Future before it calls native dispose.
Future<void> _finishNativeDisposal(
    WidgetTester tester, _VideoPlatform platform, String operation) async {
  await _pumpUntil(
      tester,
      '$operation: subscription cancellation',
      () => platform.cancelledSubscriptions.length == 1,
      () => _platformState(platform));
  expect(platform.cancelledSubscriptions, [1]);
  expect(platform.streams[1]!.hasListener, isFalse);
  expect(platform.disposed, isEmpty,
      reason: 'Native disposal must await event subscription cancellation');
  platform.cancellationCompletion[1]!.complete();
  await _pumpUntil(tester, '$operation: native disposal',
      () => platform.disposed.length == 1, () => _platformState(platform));
  expect(platform.disposed, [1]);
  expect(platform.streams[1]!.hasListener, isFalse);
}

void main() {
  late VideoPlayerPlatform previous;
  late _VideoPlatform platform;
  setUp(() {
    previous = VideoPlayerPlatform.instance;
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() {
    VideoPlayerPlatform.instance = previous;
  });

  testWidgets('approved movie is registered as a bundled MP4', (tester) async {
    final data = await rootBundle.load(VictoryVideo.asset);
    expect(data.lengthInBytes, greaterThan(0));
    expect(String.fromCharCodes(data.buffer.asUint8List(4, 4)), 'ftyp');
    // A fake native player cannot reject the original High 4:4:4 master.
    // Inspect the AVC decoder configuration in the bundled playback asset so
    // accidentally registering that unsupported master is a test failure.
    final configurations = <int>[];
    for (var i = 4; i + 8 <= data.lengthInBytes; i++) {
      if (data.getUint32(i) != 0x61766343) continue; // 'avcC'
      final boxSize = data.getUint32(i - 4);
      if (boxSize >= 12 && i - 4 + boxSize <= data.lengthInBytes) {
        configurations.add(i + 4);
      }
    }
    expect(configurations, hasLength(1));
    final configuration = configurations.single;
    expect(data.getUint8(configuration), 1,
        reason: 'AVC configuration version');
    expect(data.getUint8(configuration + 1), 77,
        reason: 'H.264 Main profile, not the High 4:4:4 original');
    expect(data.getUint8(configuration + 3), 31, reason: 'H.264 level 3.1');
    final handlers = <String>[];
    var aacSampleEntries = 0;
    for (var i = 4; i + 16 <= data.lengthInBytes; i++) {
      if (data.getUint32(i) == 0x6d703461 &&
          data.getUint32(i - 4) >= 36 &&
          i - 4 + data.getUint32(i - 4) <= data.lengthInBytes) {
        aacSampleEntries++; // 'mp4a' MPEG-4 audio sample entry
      }
      if (data.getUint32(i) != 0x68646c72) continue; // 'hdlr'
      final boxSize = data.getUint32(i - 4);
      if (boxSize >= 24 && i - 4 + boxSize <= data.lengthInBytes) {
        handlers.add(String.fromCharCodes(
            data.buffer.asUint8List(data.offsetInBytes + i + 12, 4)));
      }
    }
    expect(handlers.where((h) => h == 'vide'), hasLength(1));
    expect(handlers.where((h) => h == 'soun'), hasLength(1));
    expect(aacSampleEntries, 1);
    expect(VictoryVideo.asset, endsWith('cat_victory_android_audio.mp4'));
  });

  testWidgets('one native looping asset player; rebuilds never restart it',
      (tester) async {
    try {
      await _mount(tester);
      expect(platform.sources.single.asset, VictoryVideo.asset);
      expect(platform.sources.single.sourceType, DataSourceType.asset);
      expect(platform.mix, isTrue);
      platform.initialize();
      await _pumpUntil(
          tester,
          'initial playback',
          () =>
              platform.playCalls == 1 &&
              find.byType(VideoPlayer).evaluate().isNotEmpty,
          () => _platformState(platform));
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(platform.playCalls, 1);
      expect(platform.volumesAtPlay, [0]);
      expect(platform.loopingValues.last, isTrue);
      expect(platform.loopingValues.where((value) => value), hasLength(1));
      final size =
          tester.getSize(find.byKey(const ValueKey('victory_cat_frame')));
      expect(size.width / size.height, closeTo(9 / 16, 1e-9));
      expect(size.height, 280);
      await _mount(tester);
      expect(platform.sources, hasLength(1));
      for (var loop = 0; loop < 3; loop++) {
        await tester.pump(const Duration(microseconds: 5041667));
        platform.loopBoundary();
        await _flush(tester);
        expect(platform.sources, hasLength(1));
        expect(platform.playCalls, 1);
        expect(platform.playing[1], isTrue);
        expect(platform.seeks, isEmpty);
        expect(find.byType(VideoPlayer), findsOneWidget);
      }
      expect(platform.loopCount, 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _flush(tester);
      expect(platform.playCalls, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await _finishNativeDisposal(tester, platform, 'video exit');
    }
    expect(platform.disposed, [1]);
    expect(platform.cancelledSubscriptions, [1]);
    expect(platform.streams[1]!.hasListener, isFalse);
  });

  testWidgets('music mute and unmute change volume without replay or seek',
      (tester) async {
    final preference = _TrackedMusicPreference(false);
    try {
      await _mount(tester, musicPreference: preference);
      expect(preference.activeListenerCount, 1,
          reason: 'VictoryVideo must subscribe exactly once');
      platform.initialize();
      await _pumpUntil(tester, 'muted playback', () => platform.playCalls == 1,
          () => _platformState(platform));
      expect(platform.volumesAtPlay, [0]);
      preference.value = true;
      await _pumpUntil(tester, 'music unmute', () => platform.volumes.last == 1,
          () => _platformState(platform));
      platform.loopBoundary();
      preference.value = false;
      await _pumpUntil(tester, 'music mute', () => platform.volumes.last == 0,
          () => _platformState(platform));
      expect(platform.playing[1], isTrue);
      expect(platform.playCalls, 1);
      expect(platform.sources, hasLength(1));
      expect(platform.seeks, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await _finishNativeDisposal(tester, platform, 'music preference exit');
      expect(preference.activeListenerCount, 0,
          reason: 'VictoryVideo must remove its music listener on disposal');
      preference.dispose();
    }
  });

  testWidgets(
      'background during initialization cannot autoplay; resume and routes are respected',
      (tester) async {
    try {
      await _mount(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(tester.binding.framesEnabled, isFalse);
      platform.initialize();
      await _pumpUntil(
          tester,
          'background initialization',
          // VideoPlayerController applies looping when it consumes the
          // initialized event. A paused app cannot schedule the rebuild that
          // would make find.byType(VideoPlayer) visible until it resumes.
          () => platform.loopingValues.contains(true),
          () => _platformState(platform));
      expect(platform.loopingValues.last, isTrue);
      expect(find.byType(VideoPlayer), findsNothing);
      expect(platform.playCalls, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(tester.binding.framesEnabled, isTrue);
      await _pumpUntil(
          tester,
          'foreground playback and video rendering',
          () =>
              platform.playing[1] == true &&
              find.byType(VideoPlayer).evaluate().isNotEmpty,
          () => _platformState(platform));
      expect(platform.playing[1], isTrue);
      final navigator = Navigator.of(tester.element(find.byType(VictoryVideo)));
      final awayRoute = navigator.push(PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => const Scaffold(body: Text('Away'))));
      await _pumpUntil(
          tester,
          'offstage pause',
          () =>
              platform.playing[1] == false &&
              find.text('Away').evaluate().isNotEmpty,
          () => _platformState(platform));
      expect(platform.playing[1], isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _flush(tester);
      expect(platform.playing[1], isFalse);
      navigator.pop();
      await _pumpUntil(tester, 'visible route resume',
          () => platform.playing[1] == true, () => _platformState(platform));
      await awayRoute;
      expect(platform.playing[1], isTrue);
      expect(platform.sources, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await _flush(tester);
      expect(platform.playing[1], isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _finishNativeDisposal(tester, platform, 'navigation');
    }
    expect(platform.disposed, [1]);
    expect(platform.cancelledSubscriptions, [1]);
    expect(platform.streams[1]!.hasListener, isFalse);
  });

  testWidgets(
      'reduced motion uses static celebration and toggling never duplicates the player',
      (tester) async {
    try {
      await _mount(tester, reduced: true);
      expect(platform.sources, isEmpty);
      expect(find.byKey(const ValueKey('static_victory')), findsOneWidget);
      await _mount(tester);
      platform.initialize();
      await _flush(tester);
      expect(platform.playing[1], isTrue);
      await _mount(tester, reduced: true);
      expect(platform.playing[1], isFalse);
      expect(find.byType(VideoPlayer), findsNothing);
      await _mount(tester);
      expect(platform.sources, hasLength(1));
      expect(platform.playing[1], isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await _finishNativeDisposal(tester, platform, 'reduced-motion toggling');
    }
    expect(platform.disposed, [1]);
    expect(platform.cancelledSubscriptions, [1]);
    expect(platform.streams[1]!.hasListener, isFalse);
  });

  for (final failure in ['decode error', 'timeout', 'late native creation']) {
    testWidgets('$failure releases resources without blocking fallback or exit',
        (tester) async {
      if (failure == 'late native creation') {
        platform.creation = Completer<int?>();
      }
      try {
        await _mount(tester);
        if (failure == 'decode error') {
          platform.streams[1]!.addError(PlatformException(
              code: 'decode', message: 'Fixture decoder failure'));
          await _flush(tester);
          expect(find.byKey(const ValueKey('static_victory')), findsOneWidget);
        } else if (failure == 'timeout') {
          await tester.pump(VictoryVideo.initializationTimeout);
          await _flush(tester);
          expect(find.byKey(const ValueKey('static_victory')), findsOneWidget);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        if (platform.creation != null && !platform.creation!.isCompleted) {
          platform.creation!.complete(1);
        }
        await _finishNativeDisposal(tester, platform, failure);
      }
      expect(platform.playCalls, 0);
      expect(platform.disposed, [1]);
      expect(platform.cancelledSubscriptions, [1]);
      expect(platform.streams[1]!.hasListener, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 915),
  ]) {
    testWidgets('full portrait video fits $size without cropping',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await _mount(tester);
        platform.initialize();
        await _flush(tester);
        final frame =
            tester.getRect(find.byKey(const ValueKey('victory_cat_frame')));
        final texture =
            tester.getRect(find.byKey(const ValueKey('video_texture_1')));
        expect(frame.width / frame.height, closeTo(9 / 16, 1e-9));
        expect(frame.left, greaterThanOrEqualTo(0));
        expect(frame.right, lessThanOrEqualTo(size.width));
        expect(frame.top, greaterThanOrEqualTo(0));
        expect(frame.bottom, lessThanOrEqualTo(size.height));
        expect(texture, frame);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _finishNativeDisposal(tester, platform, '$size layout');
      }
      expect(platform.disposed, [1]);
      expect(platform.cancelledSubscriptions, [1]);
      expect(platform.streams[1]!.hasListener, isFalse);
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 915)
  ]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('Campaign Level 1 cat is initially visible at $size / $scale',
          (tester) async {
        final progress = _Progress();
        final audio = _Audio();
        try {
          await _completeCampaign(tester, platform, progress, audio,
              size: size, textScale: scale);
          _expectInitialVideoBounds(tester);
          final before =
              tester.getRect(find.byKey(const ValueKey('victory_cat_frame')));
          final starts = audio.musicStarts.length;
          platform.initialize();
          await _pumpUntil(
              tester,
              'production video playback',
              () =>
                  find.byType(VideoPlayer).evaluate().isNotEmpty &&
                  platform.playCalls == 1,
              () => _platformState(platform));
          _expectInitialVideoBounds(tester);
          expect(
              tester.getRect(find.byKey(const ValueKey('victory_cat_frame'))),
              before,
              reason: 'Decoder initialization must not change reserved layout');
          expect(platform.volumesAtPlay, [1]);
          expect(audio.musicStarts, hasLength(starts),
              reason: 'Victory rebuilds must not restart Campaign music');
          await _expectCampaignRewards(progress);
          expect(await progress.highestUnlockedLevel(), 2);
          expect(progress.completionCalls, 1);
          expect(tester.takeException(), isNull);
        } finally {
          await _cleanupCampaign(tester, platform);
        }
      });
    }
  }

  for (final action in [
    'system Back',
    'Back to Map',
    'Next Level',
    'Replay',
    'root Back'
  ]) {
    testWidgets('real Campaign victory $action is safe and grants once',
        (tester) async {
      final progress = _Progress();
      final audio = _Audio();
      try {
        final navigator = await _completeCampaign(
            tester, platform, progress, audio,
            rootGame: action == 'root Back',
            initialCoins: action == 'root Back' ? 137 : 0);
        platform.initialize();
        await _pumpUntil(tester, 'playing before navigation',
            () => platform.playCalls == 1, () => _platformState(platform));
        for (var loop = 0; loop < 3; loop++) {
          platform.loopBoundary();
          await tester.pump(const Duration(microseconds: 5041667));
        }
        expect(platform.sources, hasLength(1));
        expect(platform.playCalls, 1);
        await _expectCampaignRewards(progress);
        await audio.setMusicEnabled(false);
        await _pumpUntil(tester, 'Campaign victory music mute',
            () => platform.volumes.last == 0, () => _platformState(platform));
        expect(platform.playing[1], isTrue);
        await audio.setMusicEnabled(true);
        await _pumpUntil(tester, 'Campaign victory music unmute',
            () => platform.volumes.last == 1, () => _platformState(platform));
        expect(platform.playCalls, 1);
        expect(platform.seeks, isEmpty);
        expect(audio.victoryPauses, 1);
        final result = tester.widget<WinScreen>(find.byType(WinScreen));
        final callback = action == 'Next Level'
            ? result.onNext
            : action == 'Replay'
                ? result.onRestart
                : result.onMap;
        if (action == 'system Back' || action == 'root Back') {
          await tester.binding.handlePopRoute();
        } else {
          final key = action == 'Next Level'
              ? 'victory_next'
              : action == 'Replay'
                  ? 'victory_replay'
                  : 'victory_map';
          await tester.ensureVisible(find.byKey(ValueKey(key)));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey(key)));
        }
        callback(); // Stale second tap during the reverse route transition.
        await tester.pumpAndSettle();
        await _finishNativeDisposal(tester, platform, action);
        expect(find.byType(WinScreen, skipOffstage: false), findsNothing);
        if (action == 'Next Level' || action == 'Replay') {
          expect(tester.widget<GameScreen>(find.byType(GameScreen)).level,
              action == 'Next Level' ? 2 : 1);
          expect(
              find.byWidgetPredicate((w) => w is GameTileWidget && !w.trayTile),
              findsNWidgets(3));
          expect(audio.musicStarts.last, action == 'Next Level' ? 2 : 1);
          expect(navigator.currentState!.canPop(), isTrue);
        } else {
          expect(find.byType(MapScreen), findsOneWidget);
          expect(find.byType(GameScreen, skipOffstage: false), findsNothing);
          expect(navigator.currentState!.canPop(), isFalse);
        }
        await _expectCampaignRewards(progress);
        expect(progress.completionCalls, 1);
        expect(audio.completionCues, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await _cleanupCampaign(tester, platform);
      }
    });
  }

  testWidgets('production decode failure retains layout, rewards and safe Back',
      (tester) async {
    final progress = _Progress();
    final audio = _Audio();
    try {
      await _completeCampaign(tester, platform, progress, audio);
      final before =
          tester.getRect(find.byKey(const ValueKey('victory_cat_frame')));
      platform.streams[1]!.addError(PlatformException(
          code: 'decode', message: 'Fixture decoder failure'));
      await _pumpUntil(
          tester,
          'production decoder failure cleanup',
          () => platform.cancelledSubscriptions.isNotEmpty,
          () => _platformState(platform));
      await _flush(tester);
      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
      expect(tester.getRect(find.byKey(const ValueKey('victory_cat_frame'))),
          before);
      _expectInitialVideoBounds(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.byType(GameScreen, skipOffstage: false), findsNothing);
      await _expectCampaignRewards(progress);
      expect(progress.completionCalls, 1);
    } finally {
      await _cleanupCampaign(tester, platform);
    }
  });

  testWidgets(
      'Garden Boss rewards and unlock cue survive chime removal and system Back',
      (tester) async {
    final progress = _Progress();
    final audio = _Audio();
    try {
      await _completeCampaign(tester, platform, progress, audio, level: 10);
      expect(platform.sources, isEmpty);
      expect(find.byType(VictoryVideo), findsNothing);
      expect(tester.widget<WinScreen>(find.byType(WinScreen)).coinsEarned, 350);
      await _expectCampaignRewards(progress);
      expect(await progress.highestUnlockedLevel(), 11);
      expect(audio.completionCues, ['world_unlock']);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.byType(GameScreen, skipOffstage: false), findsNothing);
      expect(progress.completionCalls, 1);
      await _expectCampaignRewards(progress);
    } finally {
      await _cleanupCampaign(tester, platform);
    }
  });

  testWidgets(
      'duplicate completion and Continue callbacks grant once and navigate once',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'coins': 0, 'vibration_enabled': false});
    final progress = _Progress();
    await progress.setLevelOneTutorialSeen();
    var nextRoutes = 0;
    Object? nextRouteArguments;
    try {
      await tester.pumpWidget(AppScope(
          levelRepository: _Levels(),
          progressRepository: progress,
          audioService: _Audio(),
          child: MaterialApp(
              home: const GameScreen(level: 1),
              onGenerateRoute: (settings) {
                if (settings.name != GameScreen.route) return null;
                nextRoutes++;
                nextRouteArguments = settings.arguments;
                return MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Next level')));
              })));
      await tester.pumpAndSettle();
      await loadVisibleTileImages(tester);
      for (var i = 0; i < 3; i++) {
        final tile = find.byWidgetPredicate(
            (w) => w is GameTileWidget && !w.trayTile && w.tile.id == 'v$i');
        final tap = tester.widget<GameTileWidget>(tile).onTap!;
        tap();
        tap();
        await tester.pumpAndSettle();
      }
      expect(find.byType(WinScreen), findsOneWidget);
      expect(find.byType(VictoryVideo), findsOneWidget);
      expect(progress.completionCalls, 1);
      // Keep this test's default 800x600 viewport: unlike the portrait fixtures,
      // it exposes width-scaled artwork starving the vertical hero at h == 600.
      // Verify the result BEFORE navigation, so a layout error cannot be hidden
      // behind route replacement or a zero-height but mounted video widget.
      expect(tester.takeException(), isNull,
          reason: 'The settled victory layout must fit before Continue');
      final content = tester.renderObject<RenderFlex>(
          find.byKey(const ValueKey('victory_content')));
      expect(content.constraints.maxWidth, 496); // 520 cap minus 2x12 padding.
      expect(content.constraints.minHeight, 600);
      expect(content.constraints.maxHeight, 600);
      _expectInitialVideoBounds(tester);
      final coins = await progress.coins();
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('victory_reward_Coins')))
              .data,
          '+50');
      final next = tester.widget<WinScreen>(find.byType(WinScreen)).onNext;
      next();
      next();
      await tester.pumpAndSettle();
      expect(nextRoutes, 1);
      expect(nextRouteArguments, 2);
      expect(find.text('Next level'), findsOneWidget);
      expect(progress.completionCalls, 1);
      expect(await progress.coins(), coins);
      expect(await progress.highestUnlockedLevel(), 2);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await _flush(tester);
    }
  });
}
