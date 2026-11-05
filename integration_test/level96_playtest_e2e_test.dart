import 'dart:convert';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/main_level96_playtest.dart' as entry;
import 'package:triple_tile_adventure/level96_playtest/session.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';

import 'fixtures.dart';
import 'ui_driver.dart';

const scenarioNames = [
  'startup_and_opt_in',
  'select_original',
  'select_a',
  'select_b',
  'covered_and_selectable_touch',
  'restart',
  'variant_switching',
  'win_original',
  'win_a',
  'win_b',
  'loss_original',
  'android_clipboard_export',
  'persistence_and_assistance_isolation',
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Level 96 physical Android real-UI scenarios', (tester) async {
    final results = {
      for (final name in scenarioNames)
        name: <String, Object?>{
          'status': 'NOT RUN',
          'reason': 'A prior critical scenario did not complete',
        }
    };
    final data = <String, dynamic>{
      'schema': 'level96-android-e2e/v1',
      'scenarios': results,
      'sessions': <Object?>[],
      'witness_provenance': {
        'source': historicalPaths['witness_source'],
        'sha256': historicalPaths['witness_sha256'],
        'loss_source': historicalPaths['loss_source'],
        'loss_sha256': historicalPaths['loss_sha256'],
      },
      'input_method':
          'WidgetTester.tap dispatched through real Flutter gesture/hit-test UI on Android',
      'native_adb_touch': false,
    };
    binding.reportData = data;
    final timings = <FrameTiming>[];
    void timingCallback(List<FrameTiming> frames) => timings.addAll(frames);
    binding.addTimingsCallback(timingCallback);
    addTearDown(() {
      binding.removeTimingsCallback(timingCallback);
      data['frame_timings'] = {
        'build_mode': 'debug',
        'sample_count': timings.length,
        'build_over_16_67ms':
            timings.where((f) => f.buildDuration.inMicroseconds > 16667).length,
        'raster_over_16_67ms': timings
            .where((f) => f.rasterDuration.inMicroseconds > 16667)
            .length,
        'claim':
            'Diagnostic samples only; not a release performance or perceived smoothness verdict',
      };
    });
    Future<void> scenario(String name, Future<void> Function() action) async {
      debugPrint('LEVEL96_QA_SCENARIO START $name');
      try {
        await action();
        expect(tester.takeException(), isNull, reason: name);
        results[name] = {'status': 'PASS'};
        debugPrint('LEVEL96_QA_SCENARIO PASS $name');
      } catch (error, stack) {
        debugPrint('LEVEL96_QA_SCENARIO FAIL $name: $error');
        results[name] = {
          'status': 'FAIL',
          'error': '$error',
          'stack': '$stack'
        };
        rethrow;
      }
    }

    late PlaytestLevels levels;
    late SharedPreferences prefs;
    late Map<String, Object?> savedBefore;
    PlaytestSession current() {
      final screen = tester.widget<GameScreen>(find.byType(GameScreen));
      // Observation only: this returns the screen's existing recorded engine.
      // All state-changing gameplay operations below are rendered widget taps.
      return (screen.sessionHooks!
                  .createEngine(levels.create(PlaytestVariant.original))
              as RecordedGameEngine)
          .session;
    }

    final ui = Level96UiDriver(tester);
    final visible = ui.visible;
    final tap = ui.tap;

    Future<void> pause() => tap(find.byIcon(Icons.pause_rounded));
    Future<void> selection() async {
      if (find.byType(GameScreen).evaluate().isNotEmpty) {
        if (find
            .byKey(const ValueKey('variant_selection'))
            .evaluate()
            .isEmpty) {
          await pause();
        }
        await tap(find.byKey(const ValueKey('variant_selection')));
      }
      await visible(find.text('Level 96 playtest'), 'selection');
    }

    Future<void> start(PlaytestVariant variant) async {
      await selection();
      await ui.selectVariant(variant.name);
      await tap(find.byKey(const ValueKey('start_session')));
      await visible(find.byType(GameScreen), 'real GameScreen');
      await visible(find.byKey(ValueKey(levels.create(variant).tiles.last.id)),
          'loaded 99-tile board');
      final s = current();
      expect(s.variant, variant);
      expect(s.engine.boardTiles.length, 99);
      expect(s.engine.tray, isEmpty);
      expect(s.acceptedTaps, 0);
      final expected = levels.create(variant);
      for (var i = 0; i < 99; i++) {
        final a = s.engine.tiles[i], b = expected.tiles[i];
        expect([a.id, a.type, a.x, a.y, a.layer],
            [b.id, b.type, b.x, b.y, b.layer]);
      }
    }

    String sourceScreen(PlaytestSession s) => s.screen.width < 340
        ? 'small_320x568'
        : s.screen.width < 390
            ? 'medium_360x800'
            : 'tall_412x915';
    Future<void> replay(List<dynamic> path, {int? limit}) async {
      final s = current();
      for (var i = 0; i < (limit ?? path.length); i++) {
        final id = path[i] as String;
        final finder = find.descendant(
            of: find.byKey(ValueKey(id)),
            matching: find.byType(GameTileWidget));
        final reason = 'Witness tap ${i + 1}, $id, variant ${s.variant.label}, '
            'screen ${s.screen}, board ${s.board}, tile ${s.tile}';
        expect(finder, findsOneWidget,
            reason: '$reason: target is not rendered');
        expect(tester.widget<GameTileWidget>(finder).enabled, true,
            reason:
                '$reason: target is covered/nonselectable at actual device geometry');
        await tap(finder);
        expect(s.acceptedTaps, i + 1,
            reason: '$reason: pointer did not collect target');
        final trace = s.toJson()['analyst_only_accepted_trace'] as List;
        expect(trace.last['tile_id'], id,
            reason: '$reason: another tile received the tap');
      }
    }

    await scenario('startup_and_opt_in', () async {
      expect(const bool.fromEnvironment('LEVEL96_QA_INSTALL'), true);
      expect(const String.fromEnvironment('FLAVOR'), 'dev');
      expect(() => requirePlaytestOptIn(enabled: false), throwsStateError);
      expect(() => requirePlaytestOptIn(enabled: true, release: true),
          throwsStateError);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty,
          reason:
              'Dedicated installation must have fresh test-only preferences');
      await prefs.setString('qa_sentinel', 'level96-test-only');
      await prefs.setInt('coins', 12345);
      await prefs.setInt('highest_unlocked_level', 23);
      await prefs.setInt('extra_hint_boosters', 7);
      await prefs.setInt('extra_shuffle_boosters', 8);
      await prefs.setInt('extra_undo_boosters', 9);
      savedBefore = {for (final k in prefs.getKeys()) k: prefs.get(k)};
      levels = await PlaytestLevels.load();
      await entry.main();
      await ui.settle();
      await visible(
          find.byKey(const ValueKey('start_session')), 'dedicated entrypoint');
    });
    for (final pair in [
      ('select_original', PlaytestVariant.original),
      ('select_a', PlaytestVariant.candidateA),
      ('select_b', PlaytestVariant.candidateB)
    ]) {
      await scenario(pair.$1, () => start(pair.$2));
    }
    await scenario('covered_and_selectable_touch', () async {
      final s = current();
      // Find a physically reachable point on a covered tile, excluding all
      // selectable bodies. Do not invoke the covered widget's null callback.
      final covered = tester
          .widgetList<GameTileWidget>(find.byType(GameTileWidget))
          .where((w) => w.blocked && !w.trayTile)
          .toList();
      final selectable = tester
          .widgetList<GameTileWidget>(find.byType(GameTileWidget))
          .where((w) => w.enabled && !w.blocked && !w.trayTile)
          .toList();
      Rect rect(String id) {
        final box = tester.renderObject<RenderBox>(find.byKey(ValueKey(id)));
        return Rect.fromPoints(box.localToGlobal(Offset.zero),
            box.localToGlobal(box.size.bottomRight(Offset.zero)));
      }

      Offset? point;
      for (final w in covered.reversed) {
        final r = rect(w.tile.id);
        for (final dx in [.25, .5, .75]) {
          for (final dy in [.25, .5, .75]) {
            final p = Offset(r.left + r.width * dx, r.top + r.height * dy);
            if (selectable.every((t) => !rect(t.tile.id).contains(p))) {
              point ??= p;
            }
          }
        }
      }
      expect(point, isNotNull,
          reason: 'No exposed area of a covered tile was reachable');
      await tester.tapAt(point!);
      await ui.settle();
      expect(s.acceptedTaps, 0);
      expect(s.engine.boardTiles.length, 99);
      expect(s.rejectedTaps, 1);
      final path = historicalPaths['wins'][sourceScreen(s)] as List;
      await replay(path, limit: 2);
      expect(s.engine.tray.length, 2);
    });
    await scenario('restart', () async {
      final old = current();
      await pause();
      await tap(find.byKey(const ValueKey('restart_session')));
      final fresh = current();
      expect(old.outcome, 'ABORTED');
      expect(old.toJson()['restart'], true);
      expect(fresh.id, isNot(old.id));
      expect(fresh.engine.boardTiles.length, 99);
      expect(fresh.engine.tray, isEmpty);
      expect(fresh.acceptedTaps, 0);
    });
    await scenario('variant_switching', () async {
      await start(PlaytestVariant.candidateA);
      final old = current();
      await replay(historicalPaths['wins'][sourceScreen(old)] as List,
          limit: 2);
      await start(PlaytestVariant.candidateB);
      expect(old.outcome, 'ABORTED');
      expect(current().id, isNot(old.id));
      await start(PlaytestVariant.original);
      expect(current().engine.tileById('L96_T094')!.type, 'heart');
      expect(current().engine.tileById('L96_T071')!.type, 'banana');
    });
    for (final pair in [
      ('win_original', PlaytestVariant.original),
      ('win_a', PlaytestVariant.candidateA),
      ('win_b', PlaytestVariant.candidateB)
    ]) {
      await scenario(pair.$1, () async {
        await start(pair.$2);
        final s = current();
        final source = sourceScreen(s);
        await replay(historicalPaths['wins'][source] as List);
        expect(s.outcome, 'WIN');
        expect(s.acceptedTaps, 99);
        expect(s.rejectedTaps, 0);
        expect(s.engine.boardTiles, isEmpty);
        expect(s.engine.tray, isEmpty);
        expect(s.firstTripleTap, isNotNull);
        final trace = s.toJson()['analyst_only_accepted_trace'] as List;
        expect(trace.where((t) => (t['matched_ids'] as List).isNotEmpty).length,
            33);
        expect(trace.map((t) => t['tile_id']).toSet().length, 99);
        await visible(
            find.byKey(const ValueKey('restart_session')), 'WIN summary');
        (data['sessions'] as List)
            .add({...s.toJson(), 'driver_source_screen': source});
      });
    }
    await scenario('loss_original', () async {
      await start(PlaytestVariant.original);
      final s = current();
      final path = historicalPaths['losses'][sourceScreen(s)] as List;
      await replay(path);
      expect(s.outcome, 'LOSS');
      expect(s.toJson()['failure_tap'], path.length);
      expect(s.engine.tray.length, 7);
      expect(s.maxTrayOccupancy, 7);
      expect(s.rejectedTaps, 0);
      await visible(
          find.byKey(const ValueKey('restart_session')), 'LOSS summary');
      (data['sessions'] as List).add(s.toJson());
    });
    await scenario('android_clipboard_export', () async {
      await tap(find.text('Copy JSON'));
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboard?.text, isNotEmpty);
      final exported = jsonDecode(clipboard!.text!) as Map<String, dynamic>;
      expect(exported.keys.toSet(), {'schema', 'audience', 'sessions'});
      expect(exported['schema'], playtestSchema);
      final sessions = exported['sessions'] as List;
      expect(sessions.where((s) => s['outcome'] == 'WIN').length, 3);
      expect(sessions.last['outcome'], 'LOSS');
      // Independent schema allowlist: adding a field to the exporter must not
      // silently authorize personal data or solver information here.
      const allowed = {
        'schema',
        'session_id',
        'variant',
        'original_asset_fnv1a32',
        'started_utc',
        'duration_ms',
        'screen_width',
        'screen_height',
        'board_width',
        'board_height',
        'tile_width',
        'tile_height',
        'geometry_history',
        'accepted_taps',
        'rejected_taps',
        'first_triple_tap',
        'first_triple_ids',
        'max_tray_occupancy',
        'max_tray_before_resolution',
        'final_tray_occupancy',
        'outcome',
        'failure_tap',
        'remaining_board_tiles',
        'assisted',
        'booster_usage',
        'end_reason',
        'departure',
        'restart',
        'abandoned',
        'analyst_only_accepted_trace',
      };
      for (final raw in sessions) {
        final s = raw as Map;
        expect(s.keys.toSet(), allowed);
        expect(DateTime.tryParse(s['started_utc'] as String), isNotNull);
        expect(s['duration_ms'], greaterThanOrEqualTo(0));
        final trace = s['analyst_only_accepted_trace'] as List;
        expect(trace.length, s['accepted_taps']);
        var previousElapsed = 0;
        for (var i = 0; i < trace.length; i++) {
          final event = trace[i] as Map;
          expect(event.keys.toSet(), {
            'tap',
            'elapsed_ms',
            'tile_id',
            'visible_symbol',
            'tray_before',
            'tray_after',
            'matched_ids',
            'remaining_board_tiles',
            'geometry_index'
          });
          expect(event['tap'], i + 1);
          expect(event['elapsed_ms'], greaterThanOrEqualTo(previousElapsed));
          expect(
              event['elapsed_ms'], lessThanOrEqualTo(s['duration_ms'] as int));
          previousElapsed = event['elapsed_ms'] as int;
        }
        expect(s['assisted'], false);
        expect(s['booster_usage'], {'hint': 0, 'shuffle': 0, 'undo': 0});
      }
      data['exported_json'] = exported;
      expect(clipboard.text, isNot(contains('RZCTA0TPGDD')));
      expect(clipboard.text, isNot(contains('rankings')));
      expect(clipboard.text, isNot(contains('legal_tokens')));
    });
    await scenario('persistence_and_assistance_isolation', () async {
      await start(PlaytestVariant.candidateB);
      final s = current();
      for (final button in tester
          .widgetList<GameBoosterButton>(find.byType(GameBoosterButton))) {
        expect(button.onPressed, isNull);
      }
      for (final label in ['Undo', 'Hint', 'Shuffle']) {
        await ui.tapDisabledBooster(label);
      }
      expect(s.acceptedTaps, 0);
      expect(s.engine.boardTiles.length, 99);
      await selection();
      await prefs.reload();
      expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, savedBefore);
      data['test_package_preferences_unchanged'] = true;
      data['production_storage_accessed'] = false;
    });
  }, timeout: const Timeout(Duration(minutes: 18)));
}
