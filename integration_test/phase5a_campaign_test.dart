import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/core/campaign_feedback_audio.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/campaign_entrance.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_effects.dart';

import 'fixtures.dart';

/// Observes event dispatch while retaining real native playback and settings.
class _NativeAudio extends GameAudioService {
  final events = <String>[];
  @override
  Future<void> playCampaignFeedback(CampaignFeedbackEvent event) {
    events.add(event.name);
    return super.playCampaignFeedback(event);
  }

  @override
  Future<void> playTap() {
    events.add('legacy_selection');
    return super.playTap();
  }

  @override
  Future<void> playMatch() {
    events.add('legacy_match');
    return super.playMatch();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('GAME_FEEL_V2');
  testWidgets('Phase 5A real Campaign flag=$enabled', (tester) async {
    expect(const bool.fromEnvironment('LEVEL96_QA_INSTALL'), true);
    expect(const String.fromEnvironment('FLAVOR'), 'dev');
    final report = <String, dynamic>{
      'schema': 'phase5a-android/v1',
      'flag': enabled,
      'build_mode': kProfileMode ? 'profile' : 'debug',
      'input':
          'Flutter pointer events through real Campaign GameScreen; no engine moves',
      'checks': <String, String>{},
      'audio_perception':
          'Native calls exercised; speaker timbre and perceived synchronization require listening',
    };
    binding.reportData = report;
    Future<void> check(String name, Future<void> Function() action) async {
      debugPrint('PHASE5A START $name');
      try {
        await action();
        expect(tester.takeException(), isNull);
        (report['checks'] as Map)[name] = 'PASS';
        debugPrint('PHASE5A PASS $name');
      } catch (error, stack) {
        (report['checks'] as Map)[name] = 'FAIL';
        report['error'] = '$error';
        report['stack'] = '$stack';
        rethrow;
      }
    }

    final audio = _NativeAudio()..musicEnabled = false;
    addTearDown(audio.dispose);
    final progress = ProgressRepository();
    final levels = LevelRepository();
    final frames = <FrameTiming>[];
    void onFrames(List<FrameTiming> incoming) => frames.addAll(incoming);
    binding.addTimingsCallback(onFrames);
    addTearDown(() => binding.removeTimingsCallback(onFrames));
    final prefs = await SharedPreferences.getInstance();
    await check('fresh_isolated_storage_and_native_audio', () async {
      expect(prefs.getKeys(), isEmpty);
      await prefs.setString('phase5a_sentinel', 'isolated');
      await progress.setVibrationEnabled(false);
      await progress.setLevelOneTutorialSeen();
      // Seed only this fresh QA account's first-match achievement, so its
      // unrelated reward dialog cannot mask the gameplay effects under test.
      await progress.recordMatchedTiles(3);
      await progress.consumePendingAchievementPopups();
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (enabled) {
        await audio.prepareCampaignFeedback();
      } else {
        await audio.prepareTileFeedback();
      }
    });

    Finder tile(String id) => find.byWidgetPredicate(
        (w) => w is GameTileWidget && !w.trayTile && w.tile.id == id);
    Finder board() =>
        find.byWidgetPredicate((w) => w is GameTileWidget && !w.trayTile);
    TileEffectsController effects() =>
        tester.widget<GameTileEffects>(find.byType(GameTileEffects)).controller;
    Future<void> settle() => tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15));
    Future<void> mount({required bool muted}) async {
      await tester.pumpWidget(const SizedBox());
      await progress.setSfxEnabled(!muted);
      audio.sfxEnabled = await progress.sfxEnabled();
      audio.events.clear();
      await tester.pumpWidget(AppScope(
          audioService: audio,
          progressRepository: progress,
          levelRepository: levels,
          child: MaterialApp(
              theme: GameTheme.theme(),
              navigatorObservers: [appRouteObserver],
              home: const GameScreen(level: 96))));
      for (var i = 0; i < 600 && board().evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(board(), findsNWidgets(99));
    }

    Future<void> tap(String id, int count, {bool finish = true}) async {
      final target = tile(id);
      expect(target, findsOneWidget, reason: 'Witness tap $count: $id');
      expect(tester.widget<GameTileWidget>(target).enabled, true);
      expect(target.hitTestable(), findsOneWidget);
      await tester.tap(target);
      await tester.pump();
      expect(board(), findsNWidgets(99 - count),
          reason: 'Actual board after UI tap $count: $id');
      if (finish) await settle();
    }

    for (final muted in [false, true]) {
      await check('entry_muted_$muted', () async {
        await mount(muted: muted);
        expect(tester.widget<GameScreen>(find.byType(GameScreen)).gameFeelV2,
            enabled);
        if (enabled) {
          final entrance = tester
              .widget<CampaignEntranceGate>(find.byType(CampaignEntranceGate))
              .controller;
          expect(entrance.running, true);
          await tester.tapAt(tester.getCenter(tile('L96_T098')));
          await tester.pump();
          expect(board(), findsNWidgets(99));
          expect(
              tester
                  .widget<GameTray>(find.byType(GameTray))
                  .trayTiles
                  .whereType<Object>(),
              isEmpty);
          await settle();
          expect(entrance.running, false);
        } else {
          expect(find.byType(CampaignEntranceGate), findsNothing);
          await settle();
        }
        final original = await levels.loadLevel(96);
        for (final t in original.tiles) {
          final actual = tester.widget<GameTileWidget>(tile(t.id));
          expect([
            actual.tile.id,
            actual.tile.type,
            actual.tile.x,
            actual.tile.y,
            actual.tile.layer
          ], [
            t.id,
            t.type,
            t.x,
            t.y,
            t.layer
          ]);
          if (actual.blocked) expect(actual.onTap, isNull);
        }
        if (muted) expect(audio.events, isEmpty);
        if (enabled && !muted) {
          expect(audio.events.where((e) => e == 'entrance'), hasLength(1));
          expect(audio.events.where((e) => e == 'landing').length,
              inInclusiveRange(1, 3),
              reason: 'A delayed frame coalesces stale landing accents');
        }
      });
      await check('selection_and_triple_muted_$muted', () async {
        audio.events.clear();
        final width =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        final source = width < 340
            ? 'small_320x568'
            : width < 390
                ? 'medium_360x800'
                : 'tall_412x915';
        final path = (historicalPaths['wins'][source] as List)
            .take(7)
            .cast<String>()
            .toList();
        for (var i = 0; i < path.length; i++) {
          await tap(path[i], i + 1);
        }
        final tray = tester.widget<GameTray>(find.byType(GameTray));
        expect(tray.trayTiles.whereType<Object>(), hasLength(4));
        expect(effects().flights, isEmpty);
        expect(effects().bursts, isEmpty);
        expect(find.byType(GameScreen), findsOneWidget);
        if (muted) {
          expect(audio.events, isEmpty);
        } else {
          expect(
              audio.events.where(
                  (e) => e == (enabled ? 'selection' : 'legacy_selection')),
              hasLength(7));
          expect(
              audio.events
                  .where((e) => e == (enabled ? 'match' : 'legacy_match')),
              hasLength(1));
          if (enabled) {
            expect(audio.events.where((e) => e == 'collection'), hasLength(6));
          }
        }
        report['events_muted_$muted'] = List.of(audio.events);
        report['screen'] = {
          'width': width,
          'height':
              tester.view.physicalSize.height / tester.view.devicePixelRatio
        };
        report['path_source'] = source;
        report['accepted_path'] = path;
        expect(prefs.getString('phase5a_sentinel'), 'isolated');
      });
    }

    binding.removeTimingsCallback(onFrames);
    Map<String, Object> metric(List<int> values) {
      values.sort();
      int percentile(double p) =>
          values.isEmpty ? 0 : values[((values.length - 1) * p).round()];
      return {
        'samples': values.length,
        'p50_us': percentile(.5),
        'p90_us': percentile(.9),
        'p99_us': percentile(.99),
        'over_16667us': values.where((x) => x > 16667).length
      };
    }

    report['frame_timings'] = {
      'build':
          metric(frames.map((f) => f.buildDuration.inMicroseconds).toList()),
      'raster':
          metric(frames.map((f) => f.rasterDuration.inMicroseconds).toList()),
      'scope':
          'Profile-mode scripted entry and taps; screenshot conversion excluded. Not a sustained FPS or perceptual verdict.',
    };
    await check('screenshots_after_performance_sampling', () async {
      await binding.convertFlutterSurfaceToImage();
      await mount(muted: true);
      final captureProgress = <String, double>{};
      report['capture_progress'] = captureProgress;
      if (enabled) {
        final clock = tester
            .widget<CampaignEntranceGate>(find.byType(CampaignEntranceGate))
            .controller
            .clock;
        for (var i = 0; i < 100 && clock.value < .42; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(clock.value, inExclusiveRange(.40, .95));
        captureProgress['entrance'] = clock.value;
      } else {
        await settle();
      }
      await binding.takeScreenshot('entrance');
      await settle();
      await binding.takeScreenshot('settled');
      final path = (historicalPaths['wins'][report['path_source']] as List)
          .take(7)
          .cast<String>()
          .toList();
      await tap(path.first, 1, finish: false);
      for (var i = 0; i < 100; i++) {
        final visual = tester
            .widget<TileFlightVisual>(find.byType(TileFlightVisual).first);
        if (visual.progress >= .42) {
          expect(visual.progress, lessThan(.75));
          captureProgress['collection'] = visual.progress;
          break;
        }
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(captureProgress.containsKey('collection'), true);
      await binding.takeScreenshot('collection');
      await settle();
      for (var i = 1; i < 6; i++) {
        await tap(path[i], i + 1);
      }
      await tap(path[6], 7, finish: false);
      for (var i = 0; i < 100; i++) {
        final visual = tester
            .widget<MatchedTileVisual>(find.byType(MatchedTileVisual).first);
        if (visual.progress >= visual.burst.release + .02) {
          expect(visual.progress, lessThan(.9));
          captureProgress['triple'] = visual.progress;
          break;
        }
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(captureProgress.containsKey('triple'), true);
      await binding.takeScreenshot('triple');
      await settle();
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
