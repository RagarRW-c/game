import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/level.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/game_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_over_dialog.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tray.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_ui.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_effects.dart';

// Complete triples, all exposed on the test geometry. A choice of seven
// distinct types loses regardless of the random permutation from setup Shuffle.
List<Tile> _layout() {
  const types = [
    'apple',
    'banana',
    'berry',
    'carrot',
    'star',
    'shell',
    'flower'
  ];
  return [
    for (var i = 0; i < 21; i++)
      Tile(
          id: 'recovery_$i',
          type: types[i % 7],
          x: (i % 4) * .23,
          y: (i ~/ 4) * .16,
          layer: 0),
  ];
}

class _Levels extends LevelRepository {
  @override
  Future<LevelDefinition> loadLevel(int level) async => LevelDefinition(
      level: level,
      name: 'Campaign recovery',
      timeBonusSeconds: 60,
      tiles: _layout());
}

class _Audio implements GameAudioService {
  int boosterSounds = 0;
  @override
  bool sfxEnabled = true;
  @override
  Future<void> playBooster() async {
    boosterSounds++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _PaymentHold {
  final entered = Completer<void>();
  final finished = Completer<void>();
  final _response = Completer<bool>();

  bool get waiting => entered.isCompleted && !_response.isCompleted;
  void release() => _response.complete(true);
  void cancelIfPending() {
    if (!_response.isCompleted) _response.complete(false);
  }
}

class _Progress extends ProgressRepository {
  _PaymentHold? _nextPayment;
  final holds = <_PaymentHold>[];
  final completions = <Completer<void>>[];
  final lateCalls = <String>[];
  final coinRequests = <int>[];
  final coinRefundAmounts = <int>[];
  final stockRefundAmounts = <int>[];
  final recordedKinds = <BoosterKind>[];
  final failures = <String>[];
  int inFlight = 0;
  bool closed = false;
  bool failBeforeDebit = false;
  int attempts = 0, coinDebits = 0, stockDebits = 0;
  int coinRefunds = 0, stockRefunds = 0;
  int get shuffleUses => recordedKinds.length;

  List<Object> get transactionSnapshot => [
        attempts,
        coinDebits,
        stockDebits,
        coinRefunds,
        stockRefunds,
        List<int>.of(coinRequests),
        List<int>.of(coinRefundAmounts),
        List<int>.of(stockRefundAmounts),
        List<BoosterKind>.of(recordedKinds),
        List<String>.of(failures),
      ];

  _PaymentHold holdNextPayment() {
    if (_nextPayment != null) throw StateError('Payment already armed');
    final hold = _PaymentHold();
    holds.add(hold);
    _nextPayment = hold;
    return hold;
  }

  // Repository callbacks run outside the WidgetTester's guard zone. They only
  // record evidence; assertions belong to the awaiting test, never this fake.
  Future<T> _track<T>(String name, Future<T> Function() operation) async {
    if (closed) lateCalls.add(name);
    final done = Completer<void>();
    completions.add(done);
    inFlight++;
    try {
      return await operation();
    } catch (_) {
      failures.add(name);
      rethrow; // Preserve the real transaction's error handling.
    } finally {
      inFlight--;
      done.complete();
    }
  }

  Future<bool> _debit(Future<bool> Function() spend) async {
    attempts++;
    final pending = _nextPayment;
    _nextPayment = null;
    pending?.entered.complete();
    try {
      if (pending != null && !await pending._response.future) return false;
      if (failBeforeDebit) {
        failBeforeDebit = false;
        throw StateError('Payment failed before deduction');
      }
      return await spend();
    } finally {
      pending?.finished.complete();
    }
  }

  @override
  Future<bool> spendCoins(int amount) => _track('coin payment', () {
        coinRequests.add(amount);
        return _debit(() async {
          final paid = await super.spendCoins(amount);
          if (paid) coinDebits++;
          return paid;
        });
      });

  @override
  Future<bool> useExtraShuffleBooster() => _track(
      'stock payment',
      () => _debit(() async {
            final paid = await super.useExtraShuffleBooster();
            if (paid) stockDebits++;
            return paid;
          }));

  @override
  Future<void> refundBoosterCoins(int amount) =>
      _track('coin refund', () async {
        coinRefundAmounts.add(amount);
        await super.refundBoosterCoins(amount);
        coinRefunds++;
      });

  @override
  Future<int> addExtraShuffleBoosters(int amount) =>
      _track('stock refund', () async {
        stockRefundAmounts.add(amount);
        final result = await super.addExtraShuffleBoosters(amount);
        stockRefunds++;
        return result;
      });

  @override
  Future<void> recordBoosterUsed(BoosterKind kind) =>
      _track('record booster', () async {
        recordedKinds.add(kind);
      });

  // Track the screen's fire-and-forget recording tail and refund refresh too.
  @override
  Future<int> coins() => _track('coins', super.coins);

  @override
  Future<int> extraHintBoosters() =>
      _track('hint stock', super.extraHintBoosters);

  @override
  Future<int> extraShuffleBoosters() =>
      _track('shuffle stock', super.extraShuffleBoosters);

  @override
  Future<int> extraUndoBoosters() =>
      _track('undo stock', super.extraUndoBoosters);

  @override
  Future<List<PendingAchievementPopup>> consumePendingAchievementPopups() =>
      _track('popups', () async => []);
}

// Zero-duration pumps flush FakeAsync microtasks. The bound detects a missing
// checkpoint; it does not advance time or guess a transaction's duration.
Future<void> _pumpUntil(
    WidgetTester tester, bool Function() reached, String checkpoint) async {
  for (var turn = 0; turn < 50; turn++) {
    await tester.pump();
    if (reached()) return;
  }
  fail('Transaction checkpoint not reached: $checkpoint');
}

Future<void> _paymentEntered(WidgetTester tester, _PaymentHold hold) async {
  await _pumpUntil(tester, () => hold.entered.isCompleted, 'payment entered');
  await hold.entered.future;
}

Future<void> _drain(WidgetTester tester, _Progress progress) async {
  for (var turn = 0; turn < 50; turn++) {
    await tester.pump();
    if (progress.inFlight != 0 || progress.holds.any((h) => h.waiting))
      continue;
    final count = progress.completions.length;
    await Future.wait(progress.completions.map((done) => done.future));
    // A repository return may schedule another screen continuation. Require
    // the call log to remain stable across a further microtask flush.
    await tester.pump();
    if (progress.inFlight == 0 && progress.completions.length == count) return;
  }
  fail('Repository did not drain: ${progress.inFlight} calls still active');
}

Future<void> _releasePayment(
    WidgetTester tester, _Progress progress, _PaymentHold hold) async {
  hold.release();
  await _pumpUntil(tester, () => hold.finished.isCompleted, 'payment returned');
  await hold.finished.future;
  await _drain(tester, progress); // Includes any refund and recording tail.
}

class _TestRun {
  _Progress? progress;
  List<String> expectedFailures = [];

  Future<void> finish(WidgetTester tester,
      {required bool bodyCompleted}) async {
    final p = progress;
    final transactionsAtEnd = bodyCompleted ? p?.transactionSnapshot : null;
    // This finally block also runs after an assertion failure. Dispose first,
    // then cancel a held response; never release a successful debit in teardown.
    await tester.pumpWidget(const SizedBox.shrink());
    if (p != null) {
      p._nextPayment = null;
      for (final hold in p.holds) {
        hold.cancelIfPending();
      }
      await _drain(tester, p);
      await Future.wait(p.holds
          .where((h) => h.entered.isCompleted)
          .map((h) => h.finished.future));
      expect(p.inFlight, 0);
      expect(p.coinRequests, everyElement(150));
      expect(p.coinRefundAmounts, List.filled(p.coinRefunds, 150));
      expect(p.stockRefundAmounts, List.filled(p.stockRefunds, 1));
      expect(p.recordedKinds, List.filled(p.shuffleUses, BoosterKind.shuffle));
      expect(p.failures, expectedFailures,
          reason: 'Only the explicitly injected payment failure is expected');
      if (transactionsAtEnd != null) {
        expect(p.transactionSnapshot, transactionsAtEnd,
            reason:
                'No payment, refund or use recording may finish after the body checks');
      }
      p.closed = true;
      await tester.pump();
      expect(p.lateCalls, isEmpty);
      expect(p.inFlight, 0);
    }
    expect(tester.takeException(), isNull);
  }
}

void _campaignTest(
    String name, Future<void> Function(WidgetTester, _TestRun) body) {
  testWidgets(name, (tester) async {
    final run = _TestRun();
    var bodyCompleted = false;
    try {
      await body(tester, run);
      bodyCompleted = true;
    } finally {
      await run.finish(tester, bodyCompleted: bodyCompleted);
    }
  });
}

Finder _board() =>
    find.byWidgetPredicate((w) => w is GameTileWidget && !w.trayTile,
        skipOffstage: false);
Finder _shuffle() => find.byWidgetPredicate(
    (w) => w is GameBoosterButton && w.label == 'Shuffle',
    skipOffstage: false);
List<Tile> _tray(WidgetTester tester) => tester
    .widget<GameTray>(find.byType(GameTray, skipOffstage: false))
    .trayTiles
    .whereType<Tile>()
    .toList();
List<String> _boardState(WidgetTester tester) => tester
    .widgetList<GameTileWidget>(_board())
    .map((w) => '${w.tile.id}:${w.tile.type}:${w.tile.state}')
    .toList();
Map<String, Object> _geometry(WidgetTester tester) => {
      for (final w in tester.widgetList<GameTileWidget>(_board()))
        w.tile.id: [w.tile.x, w.tile.y, w.tile.layer, w.blocked],
    };
Map<String, int> _inventory(WidgetTester tester) {
  final counts = <String, int>{};
  for (final w in tester.widgetList<GameTileWidget>(_board())) {
    counts.update(w.tile.type, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
}

Future<void> _mount(
    WidgetTester tester, _Progress progress, _Audio audio, _TestRun run,
    {bool stock = false}) async {
  run.progress = progress;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'coins': 500,
    'extra_shuffle_boosters': stock ? 1 : 0,
    'vibration_enabled': false,
    'level_one_tutorial_seen': true,
  });
  await tester.pumpWidget(AppScope(
    progressRepository: progress,
    levelRepository: _Levels(),
    audioService: audio,
    child: MaterialApp(
        theme: GameTheme.theme(),
        home: const Scaffold(body: Text('Campaign map fixture')),
        initialRoute: '/campaign',
        routes: {'/campaign': (_) => const GameScreen(level: 2)}),
  ));
  await _drain(tester, progress);
  await tester.pumpAndSettle();
  expect(_board(), findsNWidgets(21));
}

Future<void> _exhaustFree(WidgetTester tester, _Progress progress) async {
  for (var i = 0; i < 2; i++) {
    final before = progress.shuffleUses;
    tester.widget<GameBoosterButton>(_shuffle()).onPressed!();
    await _drain(tester, progress);
    expect(progress.shuffleUses, before + 1);
    expect(progress.attempts, 0);
    expect(
        tester.widget<GameBoosterButton>(_shuffle()).badge,
        i == 0
            ? 'x1'
            : (await progress.extraShuffleBoosters()) > 0
                ? '+1'
                : '150');
    // Transaction completion is established above; settle only its visuals.
    await tester.pumpAndSettle();
  }
}

Future<void> _fillTray(WidgetTester tester, int count) async {
  while (_tray(tester).length < count) {
    final used = _tray(tester).map((t) => t.type).toSet();
    final next = tester
        .widgetList<GameTileWidget>(_board())
        .firstWhere((w) => !w.blocked && !used.contains(w.tile.type));
    next.onTap!();
    await tester.pumpAndSettle();
  }
  expect(_tray(tester), hasLength(count));
}

Future<void> _dialogAction(WidgetTester tester, String action) async {
  final finder = find.byKey(ValueKey('game_over_$action'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Set<int> _observeShuffleCues(WidgetTester tester) {
  final effects =
      tester.widget<GameTileEffects>(find.byType(GameTileEffects)).controller;
  final cues = <int>{};
  void observe() {
    if (effects.boardCue case final cue?) cues.add(cue.serial);
  }

  effects.addListener(observe);
  addTearDown(() => effects.removeListener(observe));
  return cues;
}

void _expectGameOver(WidgetTester tester) {
  expect(find.byType(GameOverDialog), findsOneWidget);
  expect(find.text('Tray is full'), findsOneWidget);
  expect(find.byKey(const ValueKey('game_over_shuffle')), findsNothing);
  expect(find.text('Use Shuffle'), findsNothing);
  expect(_tray(tester), hasLength(7));
  expect(_tray(tester).map((t) => t.type).toSet(), hasLength(7));
  expect(_tray(tester).every((t) => t.state == TileState.tray), isTrue);
  final dialog = tester.widget<GameOverDialog>(find.byType(GameOverDialog));
  expect(dialog.canUseShuffle, isFalse);
  expect(dialog.onUseShuffle, isNull);
  expect(dialog.onRestart, isNotNull);
}

void main() {
  for (final exhausted in [false, true]) {
    for (final stock in [false, true]) {
      _campaignTest(
          'Campaign lost tray rejects stale Shuffle; exhausted=$exhausted stock=$stock',
          (tester, run) async {
        final p = _Progress();
        final audio = _Audio();
        await _mount(tester, p, audio, run, stock: stock);
        if (exhausted) await _exhaustFree(tester, p);
        final button = tester.widget<GameBoosterButton>(_shuffle());
        final staleShuffle = button.onPressed!;
        await _fillTray(tester, 7);
        _expectGameOver(tester);
        final before = _boardState(tester);
        final trayBefore = _tray(tester).map((t) => t.id).toList();
        final sounds = audio.boosterSounds;
        final cues = _observeShuffleCues(tester);
        // A retained callback cannot bypass the action precondition, even if
        // the wallet would throw. No payment should be attempted at all.
        p.failBeforeDebit = true;
        staleShuffle();
        staleShuffle();
        staleShuffle();
        await _drain(tester, p);
        await tester.pumpAndSettle();
        tester.widgetList<GameTileWidget>(_board()).first.onTap!();
        await tester.pumpAndSettle();
        _expectGameOver(tester);
        expect(_boardState(tester), before);
        expect(_tray(tester).map((t) => t.id), trayBefore);
        expect(
            tester.widget<GameBoosterButton>(_shuffle()).badge, button.badge);
        expect(p.attempts, 0);
        expect(
            p.coinDebits + p.stockDebits + p.coinRefunds + p.stockRefunds, 0);
        expect(p.shuffleUses, exhausted ? 2 : 0);
        expect(audio.boosterSounds, sounds);
        expect(cues, isEmpty);
        expect(await p.coins(), 500);
        expect(await p.extraShuffleBoosters(), stock ? 1 : 0);

        await _dialogAction(tester, 'restart');
        expect(find.byType(GameOverDialog), findsNothing);
        expect(_boardState(tester),
            _layout().map((t) => '${t.id}:${t.type}:${t.state}'));
        expect(_tray(tester), isEmpty);
        expect(tester.widget<GameBoosterButton>(_shuffle()).badge, 'x2');
        await _fillTray(tester, 1);
        expect(await p.coins(), 500);
        expect(await p.extraShuffleBoosters(), stock ? 1 : 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final action in ['map', 'close']) {
    _campaignTest('Campaign Game Over $action returns to map without payment',
        (tester, run) async {
      final p = _Progress();
      await _mount(tester, p, _Audio(), run, stock: true);
      await _fillTray(tester, 7);
      _expectGameOver(tester);
      await _dialogAction(tester, action);
      expect(find.text('Campaign map fixture'), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
      expect(find.byType(GameOverDialog), findsNothing);
      expect(p.attempts, 0);
      expect(await p.coins(), 500);
      expect(await p.extraShuffleBoosters(), 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final funding in ['free', 'stock', 'coins']) {
    _campaignTest(
        'Active Campaign Shuffle preserves tray and geometry, once: $funding',
        (tester, run) async {
      final p = _Progress();
      final audio = _Audio();
      await _mount(tester, p, audio, run, stock: funding == 'stock');
      if (funding != 'free') await _exhaustFree(tester, p);
      await _fillTray(tester, 6);
      final geometry = _geometry(tester);
      final inventory = _inventory(tester);
      final trayBefore = _tray(tester);
      final uses = p.shuffleUses;
      final sounds = audio.boosterSounds;
      final cues = _observeShuffleCues(tester);
      final hold = funding == 'free' ? null : p.holdNextPayment();
      final callback = tester.widget<GameBoosterButton>(_shuffle()).onPressed!;
      callback();
      callback();
      if (hold != null) {
        await _paymentEntered(tester, hold);
        expect(p.attempts, 1);
        expect(hold.waiting, isTrue);
        expect(p.coinDebits + p.stockDebits, 0);
        expect(p.shuffleUses, uses);
        expect(cues, isEmpty);
        expect(audio.boosterSounds, sounds);
        await _releasePayment(tester, p, hold);
      } else {
        await _drain(tester, p);
      }
      await tester.pumpAndSettle();
      expect(_geometry(tester), geometry);
      expect(_inventory(tester), inventory);
      expect(_tray(tester), trayBefore);
      expect(find.byType(GameOverDialog), findsNothing);
      expect(p.shuffleUses, uses + 1);
      expect(cues, hasLength(1));
      expect(audio.boosterSounds, sounds + 1);
      expect(p.attempts, funding == 'free' ? 0 : 1);
      expect(p.coinDebits, funding == 'coins' ? 1 : 0);
      expect(p.stockDebits, funding == 'stock' ? 1 : 0);
      expect(p.coinRefunds + p.stockRefunds, 0);
      expect(await p.coins(), funding == 'coins' ? 350 : 500);
      expect(await p.extraShuffleBoosters(), 0);
      if (funding == 'free') {
        expect(tester.widget<GameBoosterButton>(_shuffle()).badge, 'x1');
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final stock in [false, true]) {
    for (final interruption in [
      'lost',
      'restart',
      'map',
      'dispose',
      'failure'
    ]) {
      _campaignTest(
          'Pending Campaign Shuffle cancels on loss: stock=$stock $interruption',
          (tester, run) async {
        final p = _Progress();
        final audio = _Audio();
        await _mount(tester, p, audio, run, stock: stock);
        await _exhaustFree(tester, p);
        await _fillTray(tester, 6);
        final hold = p.holdNextPayment();
        p.failBeforeDebit = interruption == 'failure';
        if (interruption == 'failure') {
          run.expectedFailures = [stock ? 'stock payment' : 'coin payment'];
        }
        final cues = _observeShuffleCues(tester);
        final sounds = audio.boosterSounds;
        final callback =
            tester.widget<GameBoosterButton>(_shuffle()).onPressed!;
        callback();
        callback();
        await _paymentEntered(tester, hold);
        expect(p.attempts, 1);
        expect(hold.waiting, isTrue);
        expect(p.coinDebits + p.stockDebits, 0);
        await _fillTray(tester, 7);
        _expectGameOver(tester);
        final lostBoard = _boardState(tester);
        callback();
        callback();
        if (interruption == 'restart' || interruption == 'map') {
          await _dialogAction(tester, interruption);
        } else if (interruption == 'dispose') {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        // The request reached payment while the board was still playing.
        // Losing/restarting/leaving now requires compensation after a debit;
        // it is different from invoking Shuffle on an already lost board.
        expect(hold.waiting, isTrue);
        expect(p.coinDebits + p.stockDebits, 0);
        await _releasePayment(tester, p, hold);
        await tester.pumpAndSettle();
        final failed = interruption == 'failure';
        expect(p.attempts, 1);
        expect(p.coinDebits, !stock && !failed ? 1 : 0);
        expect(p.stockDebits, stock && !failed ? 1 : 0);
        expect(p.coinRefunds, !stock && !failed ? 1 : 0);
        expect(p.stockRefunds, stock && !failed ? 1 : 0);
        expect(await p.coins(), 500);
        expect(await p.extraShuffleBoosters(), stock ? 1 : 0);
        expect((await p.statistics()).totalCoinsEarned, 0);
        expect(p.shuffleUses, 2);
        expect(audio.boosterSounds, sounds);
        expect(cues, isEmpty);
        if (interruption == 'lost' || failed) {
          _expectGameOver(tester);
          expect(_boardState(tester), lostBoard);
        } else if (interruption == 'restart') {
          expect(find.byType(GameOverDialog), findsNothing);
          expect(_boardState(tester),
              _layout().map((t) => '${t.id}:${t.type}:${t.state}'));
          expect(_tray(tester), isEmpty);
          expect(tester.widget<GameBoosterButton>(_shuffle()).badge, 'x2');
          await _fillTray(tester, 1);
        } else {
          expect(find.byType(GameOverDialog), findsNothing);
          expect(find.byType(GameScreen), findsNothing);
          if (interruption == 'map')
            expect(find.text('Campaign map fixture'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    _campaignTest(
        'Active Campaign Shuffle payment failure stays quiet and retry works: stock=$stock',
        (tester, run) async {
      final p = _Progress();
      final audio = _Audio();
      await _mount(tester, p, audio, run, stock: stock);
      await _exhaustFree(tester, p);
      final before = _boardState(tester);
      final badge = tester.widget<GameBoosterButton>(_shuffle()).badge;
      final cues = _observeShuffleCues(tester);
      final sounds = audio.boosterSounds;
      p.failBeforeDebit = true;
      run.expectedFailures = [stock ? 'stock payment' : 'coin payment'];
      tester.widget<GameBoosterButton>(_shuffle()).onPressed!();
      await _drain(tester, p);
      await tester.pumpAndSettle();
      expect(_boardState(tester), before);
      expect(tester.widget<GameBoosterButton>(_shuffle()).badge, badge);
      expect(p.attempts, 1);
      expect(p.coinDebits + p.stockDebits, 0);
      expect(p.shuffleUses, 2);
      expect(cues, isEmpty);
      expect(audio.boosterSounds, sounds);
      expect(await p.coins(), 500);
      expect(await p.extraShuffleBoosters(), stock ? 1 : 0);
      tester.widget<GameBoosterButton>(_shuffle()).onPressed!();
      await _drain(tester, p);
      await tester.pumpAndSettle();
      expect(p.attempts, 2);
      expect(p.shuffleUses, 3);
      expect(p.coinDebits, stock ? 0 : 1);
      expect(p.stockDebits, stock ? 1 : 0);
      expect(p.coinRefunds + p.stockRefunds, 0);
      expect(await p.coins(), stock ? 500 : 350);
      expect(await p.extraShuffleBoosters(), 0);
      expect(cues, hasLength(1));
      expect(audio.boosterSounds, sounds + 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 1.6, 2.0]) {
    _campaignTest(
        'Campaign retry/exit-only dialog remains reachable at text scale $scale',
        (tester, run) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: GameTheme.theme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: GameOverDialog(
                  canUseShuffle: false,
                  onUseShuffle: null,
                  onBackToMap: () {},
                  onRestart: () {}))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game_over_shuffle')), findsNothing);
      for (final action in ['restart', 'map', 'close']) {
        final target = find.byKey(ValueKey('game_over_$action'));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
        if (action != 'close')
          expect(tester.widget<GameButton>(target).onPressed, isNotNull);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
