import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/data/level_repository.dart';
import 'package:triple_tile_adventure/data/progress_repository.dart';
import 'package:triple_tile_adventure/domain/endless_board_generator.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/main.dart';
import 'package:triple_tile_adventure/presentation/screens/endless_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';

class _SilentAudio implements GameAudioService {
  @override
  bool sfxEnabled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Boards extends EndlessBoardGenerator {
  _Boards({this.lose = false});

  final bool lose;

  @override
  List<Tile> generate({required int round, required TileVisualTheme theme}) {
    final types = lose
        ? tileCatalog.keys.take(7).toList()
        : const ['apple', 'apple', 'apple'];
    return List.generate(
      types.length,
      (index) => Tile(
        id: 'round_${round}_$index',
        type: types[index],
        x: (index % 3) * .3,
        y: (index ~/ 3) * .25,
        layer: 0,
      ),
    );
  }
}

class _HeldRewards extends ProgressRepository {
  Completer<void>? coinGate;
  Completer<void>? chestGate;
  bool failNextCoinBeforeWrite = false;
  bool failNextChestBeforeWrite = false;
  bool timeOutNextCoinBeforeWrite = false;
  int coinAttempts = 0;
  int coinCommits = 0;
  int chestAttempts = 0;
  int chestCommits = 0;

  @override
  Future<int> addCoins(int amount) async {
    coinAttempts++;
    final gate = coinGate;
    if (gate != null) {
      coinGate = null;
      await gate.future;
    }
    if (failNextCoinBeforeWrite) {
      failNextCoinBeforeWrite = false;
      throw StateError('Simulated failure before coin write');
    }
    if (timeOutNextCoinBeforeWrite) {
      timeOutNextCoinBeforeWrite = false;
      throw TimeoutException('Simulated timeout before coin write');
    }
    final balance = await super.addCoins(amount);
    coinCommits++;
    return balance;
  }

  @override
  Future<ChestGrantResult> grantEndlessSilverChest() async {
    chestAttempts++;
    final gate = chestGate;
    if (gate != null) {
      chestGate = null;
      await gate.future;
    }
    if (failNextChestBeforeWrite) {
      failNextChestBeforeWrite = false;
      throw StateError('Simulated failure before chest write');
    }
    final result = await super.grantEndlessSilverChest();
    if (result.granted) chestCommits++;
    return result;
  }
}

Finder _boardTile(int round, int index) => find.byWidgetPredicate((widget) =>
    widget is GameTileWidget &&
    !widget.trayTile &&
    widget.tile.id == 'round_${round}_$index');

Future<void> _mount(WidgetTester tester, _HeldRewards rewards,
    {required int initialScore, bool lose = false}) async {
  await rewards.setVibrationEnabled(false);
  await tester.pumpWidget(AppScope(
    progressRepository: rewards,
    levelRepository: LevelRepository(),
    audioService: _SilentAudio(),
    child: MaterialApp(
      theme: GameTheme.theme(),
      home: EndlessScreen.forTesting(
        boardGenerator: _Boards(lose: lose),
        initialScore: initialScore,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, int round, int index) async {
  tester.widget<GameTileWidget>(_boardTile(round, index)).onTap!();
  await tester.pump();
}

Future<void> _pumpUntil(
    WidgetTester tester, bool Function() reached, String milestone) async {
  for (var frame = 0; frame < 30 && !reached(); frame++) {
    await tester.pump();
  }
  expect(reached(), isTrue, reason: '$milestone did not complete in 30 frames');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'vibration_enabled': false}));

  testWidgets('one scoring threshold grants once without held persistence',
      (tester) async {
    final rewards = _HeldRewards();
    await _mount(tester, rewards, initialScore: 995);
    await _tap(tester, 1, 0);
    await tester.pumpAndSettle();
    expect(find.text('Score 1000'), findsOneWidget);
    expect(rewards.coinAttempts, 1);
    expect(rewards.coinCommits, 1);
    expect(await rewards.coins(), 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same-frame taps cannot skip a newly crossed threshold',
      (tester) async {
    final rewards = _HeldRewards();
    await _mount(tester, rewards, initialScore: 990);
    final first = tester.widget<GameTileWidget>(_boardTile(1, 0)).onTap!;
    final second = tester.widget<GameTileWidget>(_boardTile(1, 1)).onTap!;
    first(); // 995: the first no-reward drain may already have returned.
    second(); // 1,000: this call must be included in the same flight.
    await tester.pumpAndSettle();
    expect(find.text('Score 1000'), findsOneWidget);
    expect(rewards.coinAttempts, 1);
    expect(rewards.coinCommits, 1);
    expect(await rewards.coins(), 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('concurrent scoring cannot grant the same coin milestone twice',
      (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final rewards = _HeldRewards()..coinGate = gate;
    await _mount(tester, rewards, initialScore: 995);
    await _tap(tester, 1, 0);
    expect(rewards.coinAttempts, 1);
    expect(rewards.coinCommits, 0);
    await _tap(tester, 1, 1);
    expect(rewards.coinAttempts, 1,
        reason: 'Both accepted moves reached the real screen reward handler.');
    expect(find.text('Score 1005'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(rewards.coinAttempts, 1);
    expect(rewards.coinCommits, 1);
    expect(await rewards.coins(), 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('concurrent scoring cannot grant the same chest milestone twice',
      (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final rewards = _HeldRewards()..chestGate = gate;
    await _mount(tester, rewards, initialScore: 4995);
    await _tap(tester, 1, 0);
    await _pumpUntil(tester, () => rewards.chestAttempts == 1,
        'Initial chest persistence attempt');
    expect(rewards.coinCommits, 1);
    expect(rewards.chestAttempts, 1);
    await _tap(tester, 1, 1);
    expect(rewards.chestAttempts, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(rewards.chestAttempts, 1);
    expect(rewards.chestCommits, 1);
    expect(await rewards.treasureChests(), hasLength(1));
    expect(await rewards.coins(), 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('later earned coin milestones still pay after a held first grant',
      (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final rewards = _HeldRewards()..coinGate = gate;
    await _mount(tester, rewards, initialScore: 995);
    await _tap(tester, 1, 0);
    await _tap(tester, 1, 1);
    await _tap(tester, 1, 2);
    expect(rewards.coinAttempts, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Score 1810'), findsOneWidget);
    expect(_boardTile(2, 0), findsOneWidget);
    for (var index = 0; index < 3; index++) {
      await _tap(tester, 2, index);
    }
    await tester.pumpAndSettle();
    expect(rewards.coinAttempts, 2);
    expect(rewards.coinCommits, 2);
    expect(await rewards.coins(), 50);
    expect(find.text('Score 2625'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid coin and chest milestones retain their exact amounts',
      (tester) async {
    final rewards = _HeldRewards();
    await _mount(tester, rewards, initialScore: 4995);
    for (var round = 1; round <= 2; round++) {
      for (var index = 0; index < 3; index++) {
        await _tap(tester, round, index);
      }
      await tester.pumpAndSettle();
    }
    expect(find.text('Score 6625'), findsOneWidget);
    expect(rewards.coinAttempts, 2); // 5,000 and 6,000.
    expect(rewards.coinCommits, 2);
    expect(rewards.chestAttempts, 1); // 5,000 only.
    expect(rewards.chestCommits, 1);
    expect(await rewards.coins(), 50);
    expect(await rewards.treasureChests(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pre-write failure leaves the threshold due for the next move',
      (tester) async {
    final rewards = _HeldRewards()..failNextCoinBeforeWrite = true;
    await _mount(tester, rewards, initialScore: 995);
    await _tap(tester, 1, 0);
    await tester.pumpAndSettle();
    expect(rewards.coinAttempts, 1);
    expect(rewards.coinCommits, 0);
    expect(await rewards.coins(), 0);
    await _tap(tester, 1, 1);
    await tester.pumpAndSettle();
    expect(rewards.coinAttempts, 2);
    expect(rewards.coinCommits, 1);
    expect(await rewards.coins(), 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pre-write timeout leaves a coin milestone retryable',
      (tester) async {
    final rewards = _HeldRewards()..timeOutNextCoinBeforeWrite = true;
    await _mount(tester, rewards, initialScore: 995);
    await _tap(tester, 1, 0);
    await tester.pumpAndSettle();
    expect(rewards.coinAttempts, 1);
    expect(rewards.coinCommits, 0);
    await _tap(tester, 1, 1);
    await tester.pumpAndSettle();
    expect(rewards.coinAttempts, 2);
    expect(rewards.coinCommits, 1);
    expect(await rewards.coins(), 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pre-write chest failure retries without a second coin grant',
      (tester) async {
    final rewards = _HeldRewards()..failNextChestBeforeWrite = true;
    await _mount(tester, rewards, initialScore: 4995);
    await _tap(tester, 1, 0);
    await tester.pumpAndSettle();
    expect(rewards.coinAttempts, 1);
    expect(rewards.chestAttempts, 1);
    expect(rewards.chestCommits, 0);
    await _tap(tester, 1, 1);
    await tester.pumpAndSettle();
    expect(rewards.coinAttempts, 1);
    expect(rewards.chestAttempts, 2);
    expect(rewards.chestCommits, 1);
    expect(await rewards.coins(), 25);
    expect(await rewards.treasureChests(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposal does not cancel an already earned coin grant',
      (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final rewards = _HeldRewards()..coinGate = gate;
    await _mount(tester, rewards, initialScore: 995);
    await _tap(tester, 1, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete();
    await tester.pumpAndSettle();
    expect(rewards.coinAttempts, 1);
    expect(rewards.coinCommits, 1);
    expect(await rewards.coins(), 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route disposal does not cancel an earned chest grant',
      (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final rewards = _HeldRewards()..chestGate = gate;
    await _mount(tester, rewards, initialScore: 4995);
    await _tap(tester, 1, 0);
    await _pumpUntil(tester, () => rewards.chestAttempts == 1,
        'Initial chest persistence attempt');
    expect(rewards.chestAttempts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete();
    await tester.pumpAndSettle();
    expect(rewards.chestAttempts, 1);
    expect(rewards.chestCommits, 1);
    expect(await rewards.treasureChests(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('restart after a held reward begins a fresh scoring run',
      (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final rewards = _HeldRewards()..coinGate = gate;
    await _mount(tester, rewards, initialScore: 995, lose: true);
    for (var index = 0; index < 7; index++) {
      await _tap(tester, 1, index);
    }
    expect(rewards.coinAttempts, 1);
    expect(find.text('Try Again'), findsNothing,
        reason: 'Restart cannot reset milestones before the earned write settles.');
    gate.complete();
    await _pumpUntil(tester, () => find.text('Endless Results').evaluate().isNotEmpty,
        'Endless results after the held reward');
    await tester.pumpAndSettle();
    expect(find.text('Endless Results'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Score 0'), findsOneWidget);
    expect(rewards.coinAttempts, 1);
    expect(rewards.coinCommits, 1);
    expect(await rewards.coins(), 25);
    expect(tester.takeException(), isNull);
  });
}
