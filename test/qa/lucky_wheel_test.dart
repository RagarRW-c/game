import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/daily_wheel_reward.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/lucky_wheel_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_ui.dart';
import 'package:triple_tile_adventure/presentation/widgets/lucky_wheel_art.dart';
import 'package:triple_tile_adventure/presentation/widgets/wheel_motion.dart';
import 'package:triple_tile_adventure/presentation/widgets/wheel_reward_effects.dart';

class _SelectedRandom implements Random {
  _SelectedRandom(this.index);
  final int index;
  int selections = 0;
  @override
  int nextInt(int max) {
    expect(max, 9,
        reason: 'Every original segment remains equally selectable.');
    selections++;
    return index;
  }

  @override
  bool nextBool() => throw StateError('Unexpected random draw');
  @override
  double nextDouble() => throw StateError('Unexpected random draw');
}

class _Audio implements GameAudioService {
  final calls = <String>[];
  @override
  Future<void> playLuckyWheelSpin() async {
    calls.add('spin');
  }

  @override
  Future<void> playWheelTick() async {
    calls.add('tick');
  }

  @override
  Future<void> playWheelStop() async {
    calls.add('stop');
  }

  @override
  Future<void> playWheelReveal() async {
    calls.add('reveal');
  }

  @override
  Future<void> playWheelCollection() async {
    calls.add('collect');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _DelayedClaim extends ProgressRepository {
  final gate = Completer<void>();
  @override
  Future<DailyWheelClaim?> claimDailySpin(DateTime now,
      {required DailyWheelReward reward}) async {
    await gate.future;
    return super.claimDailySpin(now, reward: reward);
  }
}

class _UnavailableStorage extends ProgressRepository {
  @override
  Future<DailySpinStatus> dailySpinStatus(DateTime now) async =>
      throw StateError('Unavailable');
}

class _DelayedCoins extends ProgressRepository {
  final entered = Completer<void>();
  final gate = Completer<void>();
  @override
  Future<int> addCoins(int amount) async {
    entered.complete();
    await gate.future;
    return super.addCoins(amount);
  }
}

class _FailOnceCoins extends ProgressRepository {
  bool failNextWrite = true;

  @override
  Future<int> addCoins(int amount) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Write failed before changing the balance');
    }
    return super.addCoins(amount);
  }
}

class _FailingAudio extends _Audio {
  @override
  Future<void> playLuckyWheelSpin() async =>
      throw StateError('No audio device');
  @override
  Future<void> playWheelTick() async => throw StateError('No audio device');
  @override
  Future<void> playWheelStop() async => throw StateError('No audio device');
  @override
  Future<void> playWheelReveal() async => throw StateError('No audio device');
  @override
  Future<void> playWheelCollection() async =>
      throw StateError('No audio device');
}

Future<void> _mount(
  WidgetTester tester, {
  required _SelectedRandom random,
  ProgressRepository? repository,
  _Audio? audio,
  bool reducedMotion = false,
  Size size = const Size(360, 800),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(AppScope(
    progressRepository: repository ?? ProgressRepository(),
    levelRepository: LevelRepository(),
    audioService: audio ?? _Audio(),
    child: MaterialApp(
      theme: GameTheme.theme(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              disableAnimations: reducedMotion,
              textScaler: TextScaler.linear(textScale)),
          child: child!),
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => LuckyWheelScreen(random: random))),
                child: const Text('Open wheel'),
              ))),
    ),
  ));
  await tester.tap(find.text('Open wheel'));
  // Only the route transition and mocked availability lookup run here. Keep
  // settling real frames: a stuck spinner must fail, not be hidden by a delay.
  await tester.pumpAndSettle(const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2));
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.text('Checking spin...'), findsNothing);
  expect(find.byKey(const ValueKey('wheel_rotation')), findsOneWidget);
  expect(tester.binding.transientCallbackCount, 0,
      reason: 'The mounted, idle wheel must not leave an active ticker.');
}

Future<void> _tapSpin(WidgetTester tester) async {
  final button = find.widgetWithText(GameButton, 'Daily Spin');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'coins': 1000}));

  test('motion is monotone, continuous, and has a smooth launch and stop', () {
    const curve = WheelSpinCurve();
    var previous = 0.0;
    for (var i = 0; i <= 2000; i++) {
      final value = curve.transform(i / 2000);
      expect(value, inInclusiveRange(previous, 1.0));
      previous = value;
    }
    const h = .00001;
    const join = WheelSpinCurve.accelerationFraction;
    final leftSpeed = (curve.transform(join) - curve.transform(join - h)) / h;
    final rightSpeed = (curve.transform(join + h) - curve.transform(join)) / h;
    expect(leftSpeed, closeTo(rightSpeed, .001));
    expect(curve.transform(h) / h, lessThan(.001));
    expect((1 - curve.transform(1 - h)) / h, lessThan(.001));
    expect(curve.transform(.25), greaterThan(.25));
  });

  test('nine painted sectors contain only their own reward artwork', () {
    expect(DailyWheelReward.values, hasLength(LuckyWheelGeometry.count));
    expect(LuckyWheelGeometry.rewardCenter(0).dx,
        closeTo(LuckyWheelGeometry.center.dx, 1e-8));
    for (var index = 0; index < LuckyWheelGeometry.count; index++) {
      final rewardPoint = LuckyWheelGeometry.rewardCenter(index);
      for (var other = 0; other < LuckyWheelGeometry.count; other++) {
        expect(LuckyWheelGeometry.sectorPath(other).contains(rewardPoint),
            other == index,
            reason:
                'A reward symbol must be inside exactly its painted wedge.');
      }
    }
  });

  for (var index = 0; index < 9; index++) {
    test('segment $index lands under the pointer from any starting rotation',
        () {
      for (final start in [0.0, .37, 7.2]) {
        final end = WheelMotion.landingTurns(index, 9, from: start);
        final radians = (end + index / 9) * 2 * pi;
        expect(sin(radians), closeTo(0, 1e-10));
        expect(cos(radians), closeTo(1, 1e-10));
        expect(end - start, inInclusiveRange(5.0, 6.0));
      }
    });

    test('reward $index persists exactly once, including stats and inventory',
        () async {
      final now = DateTime.utc(2026, 10, 22, 10);
      final repository = ProgressRepository();
      final reward = DailyWheelReward.values[index];
      final claim = await repository.claimDailySpin(now, reward: reward);
      const amounts = [30, 50, 75, 100, 150, 200, 0, 0, 0];
      expect(claim!.reward, reward);
      expect(claim.coinsBefore, 1000);
      expect(claim.coinsAfter, 1000 + amounts[index]);
      expect(await repository.extraHintBoosters(), index == 6 ? 1 : 0);
      expect(await repository.extraShuffleBoosters(), index == 7 ? 1 : 0);
      expect(await repository.extraUndoBoosters(), index == 8 ? 1 : 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('stats_lucky_wheel_spins'), 1);
      expect(prefs.getBool('daily_challenge_lucky_wheel_used'), isTrue);
      expect(prefs.getInt('stats_coins_earned') ?? 0, amounts[index]);
      expect(prefs.getInt('daily_challenge_coins_earned') ?? 0, amounts[index]);
      final saved = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      // Reload native-store mock data as well as constructing a new repository.
      await prefs.reload();
      expect(await ProgressRepository().coins(), 1000 + amounts[index]);
      expect(
          await ProgressRepository()
              .claimDailySpin(now, reward: DailyWheelReward.coins200),
          isNull);
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, saved);
      expect(await repository.dailySpinAvailable(now), isFalse);
      expect(
          await repository.dailySpinAvailable(now.add(const Duration(days: 1))),
          isTrue);
    });

    testWidgets('visible landing and reveal agree with selected segment $index',
        (tester) async {
      final random = _SelectedRandom(index);
      await _mount(tester, random: random);
      await _tapSpin(tester);
      // Selection and persistence happen before the 4.6-second visual finish.
      expect(await ProgressRepository().dailySpinAvailable(DateTime.now()),
          isFalse);
      await tester.pump(const Duration(milliseconds: 4599));
      expect(find.text('Spinning...'), findsOneWidget);
      expect(find.byKey(const ValueKey('wheel_result')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      // At exactly 4600 ms the angle is final. This SDK's interpolation
      // simulation completes only when elapsed time is GREATER than duration.
      expect(find.byKey(const ValueKey('wheel_rotation')), findsOneWidget);
      final transform = tester
          .widget<Transform>(find.byKey(const ValueKey('wheel_rotation')));
      final angle =
          atan2(transform.transform.storage[1], transform.transform.storage[0]);
      expect(sin(angle + index * 2 * pi / 9), closeTo(0, 1e-8));
      expect(cos(angle + index * 2 * pi / 9), closeTo(1, 1e-8));
      expect(find.byKey(const ValueKey('wheel_result')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1)); // 4601 ms: complete.
      await tester
          .pump(); // Build the reveal scheduled by the completed future.
      final landed = tester
          .widget<Transform>(find.byKey(const ValueKey('wheel_rotation')));
      expect(
          landed.transform.storage, orderedEquals(transform.transform.storage),
          reason:
              'Completing the spin must not correct or snap the final angle.');
      const labels = [
        '+30 coins',
        '+50 coins',
        '+75 coins',
        '+100 coins',
        '+150 coins',
        '+200 coins',
        '+1 Hint booster',
        '+1 Shuffle booster',
        '+1 Undo booster'
      ];
      expect(find.byKey(const ValueKey('wheel_result')), findsOneWidget);
      expect(
          tester.widget<Text>(find.byKey(const ValueKey('wheel_result'))).data,
          labels[index]);
      expect(find.text('Reward'), findsNothing,
          reason: 'The inline reveal precedes the reward dialog.');
      final effect = find.byWidgetPredicate((widget) =>
          widget is CustomPaint && widget.painter is WheelRewardPainter);
      expect(effect, findsOneWidget);
      final painter =
          tester.widget<CustomPaint>(effect).painter! as WheelRewardPainter;
      final selectedCard = find.byKey(painter.winningSegmentKey);
      expect(selectedCard, findsOneWidget);
      expect(
          find.descendant(
              of: selectedCard,
              matching: find.byWidgetPredicate((widget) =>
                  widget is Semantics &&
                  widget.properties.label == labels[index])),
          findsOneWidget,
          reason: 'The selected wedge must announce the awarded reward.');
      final cardBounds = tester.getRect(selectedCard);
      final outline = painter.winningOutlinePath!;
      final outlineBounds = outline.getBounds();
      final effectOrigin = tester.getTopLeft(effect);
      final layerBox = tester.renderObject<RenderBox>(effect);
      final wheelBox =
          tester.renderObject<RenderBox>(find.byKey(painter.wheelArtKey));
      final rewardBox = tester.renderObject<RenderBox>(selectedCard);
      final rewardTransform = rewardBox.getTransformTo(layerBox).storage;
      expect(rewardTransform[1], closeTo(0, 1e-8));
      expect(rewardTransform[4], closeTo(0, 1e-8),
          reason: 'The winning reward label should finish upright.');
      final expected = LuckyWheelGeometry.sectorPath(index)
          .transform(wheelBox.getTransformTo(layerBox).storage);
      expect(outlineBounds.left, closeTo(expected.getBounds().left, .25));
      expect(outlineBounds.top, closeTo(expected.getBounds().top, .25));
      expect(outlineBounds.right, closeTo(expected.getBounds().right, .25));
      expect(outlineBounds.bottom, closeTo(expected.getBounds().bottom, .25));
      expect(outline.contains(painter.winningSectorCenter!), isTrue,
          reason:
              'The winning reward symbol must lie inside its outlined wedge.');
      expect(
          outlineBounds.shift(effectOrigin).contains(cardBounds.center), isTrue,
          reason: 'The selected reward art must remain inside its wedge.');
      expect(
          painter.winningSectorCenter!.dx + effectOrigin.dx,
          closeTo(
              tester
                  .getRect(find.byKey(const ValueKey('wheel_pointer')))
                  .center
                  .dx,
              .25),
          reason: 'The outlined wedge must land under the stationary pointer.');
      await tester.pump(const Duration(milliseconds: 350));
      final flight = painter.coinFlightBounds;
      if (index < 6) {
        expect(flight, isNotEmpty);
        expect(flight.length, lessThanOrEqualTo(7));
        for (final coin in flight) {
          expect(coin.width, greaterThan(17),
              reason: 'Coins must remain legible during collection.');
          expect((Offset.zero & tester.getSize(effect)).contains(coin.topLeft),
              isTrue);
          expect(
              (Offset.zero & tester.getSize(effect)).contains(coin.bottomRight),
              isTrue);
        }
      } else {
        expect(flight, isEmpty,
            reason: 'Booster rewards must not show currency particles.');
      }
      await tester.pumpAndSettle();
      expect(find.text('Reward'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(GameDialogFrame),
              matching: find.text(labels[index])),
          findsOneWidget);
      expect(random.selections, 1);
      await tester.tap(find.text('Nice'));
      await tester.pumpAndSettle();
      final button = tester.widget<GameButton>(
          find.widgetWithText(GameButton, 'Come Back Tomorrow'));
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    testWidgets('larger coin flight stays inside the effect layer at $size',
        (tester) async {
      await _mount(tester, random: _SelectedRandom(5), size: size);
      await _tapSpin(tester);
      await tester.pump(const Duration(milliseconds: 4601));
      await tester.pump();
      final effect = find.byWidgetPredicate((widget) =>
          widget is CustomPaint && widget.painter is WheelRewardPainter);
      expect(effect, findsOneWidget);
      final painter =
          tester.widget<CustomPaint>(effect).painter! as WheelRewardPainter;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final bounds = Offset.zero & tester.getSize(effect);
      expect(painter.coinFlightBounds, isNotEmpty);
      for (final coin in painter.coinFlightBounds) {
        expect(coin.width, greaterThan(17));
        expect(bounds.contains(coin.topLeft), isTrue);
        expect(bounds.contains(coin.bottomRight), isTrue);
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('concurrent claims across repository instances grant one reward',
      () async {
    final now = DateTime.utc(2026, 10, 22, 10);
    final results = await Future.wait(List.generate(
        20,
        (_) => ProgressRepository()
            .claimDailySpin(now, reward: DailyWheelReward.coins50)));
    expect(results.whereType<DailyWheelClaim>(), hasLength(1));
    expect(await ProgressRepository().coins(), 1050);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('stats_lucky_wheel_spins'), 1);
  });

  for (final failedClaim in [false, true]) {
    test('idle claim queue releases its scheduling zone (failed=$failedClaim)',
        () async {
      // SharedPreferences also caches an initialization Future. Keep that
      // unrelated cache in this live zone so this probe isolates the queue.
      await SharedPreferences.getInstance();
      // Model a previous widget test's clock being retired. No new dependency
      // or test-only repository reset: subsequent real operations must work.
      var retired = false;
      final stranded = <void Function()>[];
      final origin = Zone.current.fork(specification:
          ZoneSpecification(scheduleMicrotask: (self, parent, zone, callback) {
        if (retired) {
          stranded.add(() => zone.runGuarded(callback));
        } else {
          parent.scheduleMicrotask(zone, callback);
        }
      }));
      final repository = failedClaim ? _FailOnceCoins() : ProgressRepository();
      final now = DateTime.utc(2026, 10, 22, 10);
      final first = origin.run(() =>
          repository.claimDailySpin(now, reward: DailyWheelReward.coins30));
      if (failedClaim) {
        await expectLater(first, throwsStateError);
      } else {
        expect(await first, isNotNull);
      }
      retired = true;
      var completed = false;
      final reads = Future.wait<Object>([
        ProgressRepository().dailySpinStatus(now),
        ProgressRepository().coins(),
      ]).then((values) {
        expect((values[0] as DailySpinStatus).canSpin, failedClaim);
        expect(values[1], failedClaim ? 1000 : 1030);
        completed = true;
      });
      try {
        // One event turn drains current-zone microtasks, without advancing the
        // retired zone. This is a scheduler test, not an animation wait.
        await Future<void>.delayed(Duration.zero);
        expect(stranded, isEmpty,
            reason: 'Idle reads must not schedule work on a completed claim.');
        expect(completed, isTrue);
      } finally {
        // Even when the regression assertion fails, do not poison later tests.
        retired = false;
        for (final callback in stranded) {
          callback();
        }
        await reads;
      }
      expect(
          await repository.claimDailySpin(now.add(const Duration(days: 1)),
              reward: DailyWheelReward.coins50),
          isNotNull);
      expect(await repository.coins(), failedClaim ? 1050 : 1080);
    });
  }

  test('seventh spin preserves the existing achievement reward exactly once',
      () async {
    SharedPreferences.setMockInitialValues(
        {'coins': 1000, 'stats_lucky_wheel_spins': 6});
    final repository = ProgressRepository();
    final now = DateTime.now();
    final claim =
        await repository.claimDailySpin(now, reward: DailyWheelReward.coins50);
    expect(
        claim!.coinsAfter, 1300); // 50 from wheel + unchanged 250 achievement.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('stats_lucky_wheel_spins'), 7);
    expect(prefs.getInt('stats_coins_earned'), 300);
    expect(prefs.getInt('total_xp'), 75);
    expect(await repository.consumePendingAchievementPopups(), hasLength(1));
    expect(
        await repository.claimDailySpin(now, reward: DailyWheelReward.coins50),
        isNull);
    expect(await repository.coins(), 1300);
    expect(await repository.consumePendingAchievementPopups(), isEmpty);
  });

  test('a route-return balance read waits for an in-flight wheel grant',
      () async {
    final repository = _DelayedCoins();
    final grant = repository.claimDailySpin(DateTime.now(),
        reward: DailyWheelReward.coins50);
    await repository.entered.future;
    final returningMenuBalance = ProgressRepository().coins();
    // Drain the reader's microtasks while the mocked write remains pending.
    await Future<void>.delayed(Duration.zero);
    repository.gate.complete();
    await grant;
    expect(await returningMenuBalance, 1050);
  });

  test(
      'legacy claimed dates remain ineligible and Polish midnight is preserved',
      () async {
    final beforeMidnight = DateTime.utc(2026, 7, 1, 21, 59);
    final afterMidnight = DateTime.utc(2026, 7, 1, 22, 0);
    final repository = ProgressRepository();
    expect(await repository.markDailySpinClaimed(beforeMidnight), isTrue);
    expect(
        await repository.claimDailySpin(beforeMidnight,
            reward: DailyWheelReward.coins30),
        isNull);
    expect(
        await repository.claimDailySpin(afterMidnight,
            reward: DailyWheelReward.coins30),
        isNotNull);
    expect(await repository.coins(), 1030);
  });

  testWidgets('two callbacks before a rebuild still select and claim once',
      (tester) async {
    final random = _SelectedRandom(1);
    await _mount(tester, random: random);
    final action = tester
        .widget<GameButton>(find.widgetWithText(GameButton, 'Daily Spin'))
        .onPressed!;
    action();
    action();
    await tester.pumpAndSettle();
    expect(random.selections, 1);
    expect(await ProgressRepository().coins(), 1050);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('stats_lucky_wheel_spins'), 1);
    expect(find.text('Reward'), findsOneWidget);
  });

  testWidgets(
      'disposal before storage completes cannot cancel or repeat the grant',
      (tester) async {
    final repository = _DelayedClaim();
    final audio = _Audio();
    await _mount(tester,
        random: _SelectedRandom(5), repository: repository, audio: audio);
    await _tapSpin(tester);
    final backIcon = find.descendant(
        of: find.byType(GameHeader),
        matching: find.byIcon(Icons.arrow_back_rounded));
    expect(backIcon, findsOneWidget);
    await tester.tap(backIcon);
    await tester.pumpAndSettle();
    expect(find.byType(LuckyWheelScreen), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    final soundsAfterDisposal = audio.calls.length;
    repository.gate.complete();
    await tester.pumpAndSettle();
    expect(await repository.coins(), 1200);
    expect(await repository.dailySpinAvailable(DateTime.now()), isFalse);
    expect(find.text('Reward'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0,
        reason: 'Completing storage after disposal must not restart a ticker.');
    expect(audio.calls.length, soundsAfterDisposal,
        reason: 'Completing storage after disposal must not emit wheel audio.');
    await tester.tap(find.text('Open wheel'));
    await tester.pumpAndSettle();
    expect(find.text('Come Back Tomorrow'), findsOneWidget);
    expect(await repository.coins(), 1200);
  });

  testWidgets(
      'background interruption settles silently without changing the grant',
      (tester) async {
    final audio = _Audio();
    await _mount(tester, random: _SelectedRandom(2), audio: audio);
    await _tapSpin(tester);
    await tester.pump(const Duration(milliseconds: 400));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final sounds = audio.calls.length;
    await tester.pump(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(await ProgressRepository().coins(), 1075);
    expect(audio.calls.length, sounds);
    expect(find.text('Reward'), findsNothing);
    expect(find.byKey(const ValueKey('wheel_result')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('wheel_coins'))).data,
        '1075');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tick feedback is bounded and the counter follows presentation only',
      (tester) async {
    final audio = _Audio();
    await _mount(tester, random: _SelectedRandom(0), audio: audio);
    final pointer =
        tester.getCenter(find.byKey(const ValueKey('wheel_pointer')));
    await _tapSpin(tester);
    for (var frame = 0; frame < 287; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(await ProgressRepository().coins(), 1030);
    expect(tester.widget<Text>(find.byKey(const ValueKey('wheel_coins'))).data,
        '1000');
    final after = tester.getCenter(find.byKey(const ValueKey('wheel_pointer')));
    expect(after.dx, closeTo(pointer.dx, .01));
    final ticks = audio.calls.where((call) => call == 'tick').length;
    expect(ticks, inInclusiveRange(15, 56));
    await tester.pumpAndSettle();
    expect(audio.calls.where((call) => call == 'collect'), hasLength(1));
    await tester.tap(find.text('Nice'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('wheel_coins'))).data,
        '1030');
  });

  testWidgets(
      'availability errors fail closed rather than offering another spin',
      (tester) async {
    final random = _SelectedRandom(0);
    await _mount(tester, random: random, repository: _UnavailableStorage());
    expect(find.text('Daily Spin'), findsNothing);
    expect(find.text('Try Again'), findsOneWidget);
    expect(random.selections, 0);
    expect(await ProgressRepository().coins(), 1000);
  });

  testWidgets(
      'slow storage completing after resume does not restart celebration',
      (tester) async {
    final repository = _DelayedClaim();
    final audio = _Audio();
    await _mount(tester,
        random: _SelectedRandom(4), repository: repository, audio: audio);
    await _tapSpin(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final sounds = audio.calls.length;
    repository.gate.complete();
    await tester.pumpAndSettle();
    expect(await repository.coins(), 1150);
    expect(find.text('Reward'), findsNothing);
    expect(find.byKey(const ValueKey('wheel_result')), findsOneWidget);
    expect(audio.calls.length, sounds);
    expect(tester.takeException(), isNull);
  });

  testWidgets('audio failures cannot block landing or a committed reward',
      (tester) async {
    await _mount(tester, random: _SelectedRandom(0), audio: _FailingAudio());
    await _tapSpin(tester);
    await tester.pumpAndSettle();
    expect(await ProgressRepository().coins(), 1030);
    expect(find.text('Reward'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 915)
  ]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('reduced-motion reward is accessible at $size / $scale',
          (tester) async {
        final audio = _Audio();
        await _mount(tester,
            random: _SelectedRandom(7),
            audio: audio,
            reducedMotion: true,
            size: size,
            textScale: scale);
        await _tapSpin(tester);
        expect(tester.takeException(), isNull,
            reason:
                'Adding the currency counter must not overflow the header.');
        await tester.pumpAndSettle();
        expect(find.text('Reward'), findsOneWidget);
        expect(find.text('+1 Shuffle booster'), findsWidgets);
        expect(audio.calls.where((call) => call == 'tick'), isEmpty);
        expect(await ProgressRepository().extraShuffleBoosters(), 1);
        expect(tester.takeException(), isNull,
            reason: 'The scaled reward dialog must fit its scroll viewport.');
        await tester.ensureVisible(find.text('Nice'));
        expect(find.text('Nice').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Nice'));
        await tester.pumpAndSettle();
        expect(find.text('Come Back Tomorrow'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final viewport = (Offset.zero & size).inflate(.01);
        final header = find.byType(GameHeader);
        expect(header, findsOneWidget);
        final backIcon = find.descendant(
            of: header, matching: find.byIcon(Icons.arrow_back_rounded));
        expect(backIcon, findsOneWidget);
        final backButton = find.ancestor(
            of: backIcon, matching: find.byType(GameRoundIconButton));
        expect(backButton, findsOneWidget);
        expect(
            tester.widget<GameRoundIconButton>(backButton).onPressed, isNotNull,
            reason:
                'The visible header icon must remain a working Back control.');
        for (final target in [
          header,
          find.text('Lucky Wheel'),
          find.byKey(const ValueKey('wheel_coins')),
          backIcon,
        ]) {
          expect(target, findsOneWidget);
          final rect = tester.getRect(target);
          expect(rect.width, greaterThan(0));
          expect(rect.height, greaterThan(0));
          expect(
              viewport.contains(rect.topLeft) &&
                  viewport.contains(rect.bottomRight),
              isTrue,
              reason: 'The full header and currency must remain on screen.');
        }
        if (scale > 1.3) {
          final titleParagraph = find.descendant(
              of: find.text('Lucky Wheel'), matching: find.byType(RichText));
          expect(titleParagraph, findsOneWidget);
          expect(
              tester
                  .renderObject<RenderParagraph>(titleParagraph)
                  .didExceedMaxLines,
              isFalse,
              reason: 'The large-text header must show the full title.');
        }
        expect(
            tester
                .getSize(find.descendant(
                    of: find.byType(LuckyWheelScreen),
                    matching: find.byType(SingleChildScrollView)))
                .height,
            greaterThan(0),
            reason: 'The header must leave a usable scrolling body.');
        final result = find.byKey(const ValueKey('wheel_result'));
        await tester.ensureVisible(result);
        await tester.pump();
        final resultRect = tester.getRect(result);
        expect(
            viewport.contains(resultRect.topLeft) &&
                resultRect.right <= viewport.right,
            isTrue,
            reason:
                'The start of the full-width reward label must be reachable.');
        // A scaled paragraph may be taller than the viewport. Its final line
        // must also be reachable, without requiring every line on one screen.
        await Scrollable.ensureVisible(tester.element(result), alignment: 1);
        await tester.pump();
        expect(viewport.contains(tester.getRect(result).bottomRight), isTrue);
        final rewardParagraph =
            find.descendant(of: result, matching: find.byType(RichText));
        expect(rewardParagraph, findsOneWidget);
        expect(
            tester
                .renderObject<RenderParagraph>(rewardParagraph)
                .didExceedMaxLines,
            isFalse);
        expect(tester.widget<Text>(result).data, '+1 Shuffle booster');
        final claimedAction =
            find.widgetWithText(GameButton, 'Come Back Tomorrow');
        await tester.ensureVisible(claimedAction);
        await tester.pump();
        expect(claimedAction.hitTestable(), findsOneWidget);
        expect(tester.widget<GameButton>(claimedAction).onPressed, isNull);
        final ribbonTitle = find.text('Codzienny prezent');
        expect(ribbonTitle, findsOneWidget);
        await tester.ensureVisible(ribbonTitle);
        await tester.pump();
        final ribbonParagraph =
            find.descendant(of: ribbonTitle, matching: find.byType(RichText));
        expect(ribbonParagraph, findsOneWidget);
        expect(
            tester
                .renderObject<RenderParagraph>(ribbonParagraph)
                .didExceedMaxLines,
            isFalse,
            reason: 'The decorative title must remain fully readable.');
        final ribbonBounds = tester.getRect(find.byType(LuckyWheelRibbon));
        final titleBounds = tester.getRect(ribbonTitle);
        expect(ribbonBounds.contains(titleBounds.topLeft), isTrue);
        expect(ribbonBounds.contains(titleBounds.bottomRight), isTrue,
            reason: 'Scaled ribbon lettering must fit its painted banner.');
        final paintedBand = LuckyWheelRibbon.bandPath(ribbonBounds.size);
        final localTitle = titleBounds.shift(-ribbonBounds.topLeft);
        for (final corner in [
          localTitle.topLeft,
          localTitle.topRight,
          localTitle.bottomLeft,
          localTitle.bottomRight,
        ]) {
          expect(paintedBand.contains(corner), isTrue,
              reason: 'Every corner of the full title must lie on the ribbon.');
        }
        expect(find.byType(LuckyWheelFace), findsOneWidget);
        expect(find.byType(LuckyWheelPointer), findsOneWidget);
        if (scale > 1.3) {
          expect(find.text('Wheel rewards'), findsOneWidget);
          for (final label in const [
            '+30 coins',
            '+50 coins',
            '+75 coins',
            '+100 coins',
            '+150 coins',
            '+200 coins',
            '+1 Hint booster',
            '+1 Shuffle booster',
            '+1 Undo booster',
          ]) {
            expect(find.text(label), findsWidgets,
                reason: 'Large text must retain the full reward legend.');
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
