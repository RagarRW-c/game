import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/core/game_music.dart';

class _Deck implements AudioPlayer {
  late final completion = StreamController<void>.broadcast(
    sync: true,
    onCancel: () => completionCancellations++,
  );
  final sources = <String>[];
  final modes = <ReleaseMode>[];
  final volumes = <double>[];
  final resumes = <String>[];
  final callsAfterDisposal = <String>[];
  Duration position = Duration.zero;
  Duration? length = const Duration(seconds: 10);
  bool playing = false;
  bool disposed = false;
  bool disposalCompleted = false;
  int disposeCalls = 0;
  int completionsWhileStopped = 0;
  int completionCancellations = 0;
  int pauses = 0;
  Completer<void>? sourceGate;
  final sourceEntered = Completer<void>();

  @override
  Stream<void> get onPlayerComplete => completion.stream;

  void _recordCall(String operation) {
    // These methods can resume in an earlier zone during tester.pump().
    // Record violations here; guarded assertions belong after awaited pumps.
    if (disposed) {
      callsAfterDisposal.add(operation);
    }
  }

  void completePlayback() {
    _recordCall('completePlayback');
    if (!playing) {
      completionsWhileStopped++;
    }
    playing = modes.last == ReleaseMode.loop;
    position = playing ? Duration.zero : length ?? position;
    completion.add(null);
  }

  @override
  Future<void> setSource(Source source) async {
    _recordCall('setSource');
    sources.add((source as AssetSource).path);
    position = Duration.zero;
    if (!sourceEntered.isCompleted) sourceEntered.complete();
    await sourceGate?.future;
  }

  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {
    _recordCall('setReleaseMode');
    modes.add(mode);
  }

  @override
  Future<void> setVolume(double volume) async {
    _recordCall('setVolume');
    volumes.add(volume);
  }

  @override
  Future<void> resume() async {
    _recordCall('resume');
    playing = true;
    resumes.add(sources.last);
  }

  @override
  Future<void> pause() async {
    _recordCall('pause');
    pauses++;
    playing = false;
  }

  @override
  Future<void> stop() async {
    _recordCall('stop');
    playing = false;
    position = Duration.zero;
  }

  @override
  Future<Duration?> getDuration() async {
    _recordCall('getDuration');
    return length;
  }

  @override
  Future<Duration?> getCurrentPosition() async {
    _recordCall('getCurrentPosition');
    return position;
  }

  @override
  Future<void> dispose() async {
    _recordCall('dispose');
    disposeCalls++;
    disposed = true;
    playing = false;
    await completion.close();
    disposalCompleted = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    _recordCall(invocation.memberName.toString());
    return Future<void>.value();
  }
}

Future<void> _fade(WidgetTester tester) => TestAsyncUtils.guard<void>(() async {
      // Flush source setup, then advance the 600 ms fade in explicit 50 ms steps.
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    });

class _PendingOperation<T> {
  _PendingOperation(this.name, Future<T> future) {
    unawaited(future.then<void>((_) {
      completed = true;
    }, onError: (Object error, StackTrace stack) {
      _error = error;
      _stack = stack;
      completed = true;
    }));
  }

  final String name;
  bool completed = false;
  Object? _error;
  StackTrace? _stack;

  void verifyCompleted() {
    final error = _error;
    if (error != null) Error.throwWithStackTrace(error, _stack!);
    expect(completed, isTrue,
        reason: '$name is still pending after 8 scheduler drains. '
            'No virtual time was advanced; check an unreleased source gate, '
            'fade timer or player completion.');
  }
}

Future<void> _finish<T>(WidgetTester tester, Future<T> future, String name) =>
    TestAsyncUtils.guard<void>(() async {
      final pending = _PendingOperation(name, future);
      // This helper owns its awaited pump scopes. Player/Future callbacks only
      // record state; verifyCompleted runs after all nested pumps have closed.
      // Broadcast cancellation returns a root-zone Future; stream close then
      // continues in FakeAsync. Drain both queues without advancing music time.
      // Never await `future` inside runAsync: it needs the following fake pump.
      for (var round = 0; round < 8; round++) {
        await tester.pump();
        if (pending.completed) break;
        await tester.runAsync(() async {});
        await tester.pump();
        if (pending.completed) break;
      }
      pending.verifyCompleted();
    });

void _verifyDisposed(List<_Deck> decks) {
  // Called in the main test flow after awaited cleanup, including in finally.
  // No fake-player callback or pump scope is active while asserting the records.
  for (final deck in decks) {
    expect(deck.callsAfterDisposal, isEmpty,
        reason: 'No player operation may run after disposal starts');
    expect(deck.completionsWhileStopped, 0,
        reason: 'Simulated playback completion requires a playing deck');
    expect(deck.disposeCalls, 1,
        reason: 'A native deck is disposed exactly once');
    expect(deck.disposed, isTrue);
    expect(deck.disposalCompleted, isTrue,
        reason: 'Disposal must finish awaiting stream closure');
    expect(deck.playing, isFalse);
    expect(deck.completion.hasListener, isFalse);
    expect(deck.completion.isClosed, isTrue);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every campaign level maps to its ten-level world', () {
    for (var world = 1; world <= 10; world++) {
      final expected =
          'audio/triotrek/music/world_${world.toString().padLeft(2, '0')}.mp3';
      for (var level = (world - 1) * 10 + 1; level <= world * 10; level++) {
        expect(GameMusic.campaignAsset(level), expected,
            reason: 'world $world / level $level');
      }
    }
    expect(() => GameMusic.campaignAsset(0), throwsRangeError);
    expect(() => GameMusic.campaignAsset(101), throwsRangeError);
  });

  test('all 16 approved assets are bundled as nonempty MP3s', () async {
    final paths = [
      GameMusic.menuA,
      GameMusic.menuB,
      for (var level = 1; level <= 100; level += 10)
        GameMusic.campaignAsset(level),
      for (final name in [
        'tile_tap_b',
        'triple_match_c',
        'wheel_tick_a',
        'wheel_prize_coins'
      ])
        'audio/triotrek/sfx/$name.mp3',
    ];
    expect(paths.toSet(), hasLength(16));
    for (final path in paths) {
      final data = await rootBundle.load('assets/$path');
      expect(data.lengthInBytes, greaterThan(3), reason: path);
      // Both ID3-prefixed and bare MPEG audio frame headers are valid.
      final id3 = data.getUint8(0) == 0x49 &&
          data.getUint8(1) == 0x44 &&
          data.getUint8(2) == 0x33;
      final frame =
          data.getUint8(0) == 0xff && (data.getUint8(1) & 0xe0) == 0xe0;
      expect(id3 || frame, isTrue, reason: path);
      expect(File('assets/$path').lengthSync(), data.lengthInBytes);
    }
  });

  testWidgets('menu A/B alternates with preloaded decks and bounded crossfade',
      (tester) async {
    final a = _Deck();
    final b = _Deck();
    var created = 0;
    final music = GameMusic(
        primary: a,
        createDeck: () {
          created++;
          return b;
        });
    try {
      final start = music.menu();
      await _fade(tester);
      await _finish(tester, start, 'initial menu A fade and menu B preload');
      expect(a.resumes, [GameMusic.menuA]);
      expect(b.sources, [GameMusic.menuB]);
      expect(b.resumes, isEmpty, reason: 'Preload must remain silent');
      expect(a.modes, [ReleaseMode.stop]);
      expect(b.modes, [ReleaseMode.stop]);
      await _finish(tester, music.menu(), 'unchanged menu A request');
      expect(a.resumes, hasLength(1));

      // Fake position is zero at scheduling: deadline is length minus 600 ms.
      await tester.pump(const Duration(milliseconds: 9399));
      expect(b.resumes, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(b.resumes, [GameMusic.menuB]);
      expect(a.playing && b.playing, isTrue);
      expect(a.volumes.last + b.volumes.last, closeTo(.35, 1e-9));
      await _finish(tester, music.setForeground(false),
          'background cancellation of A to B fade');
      expect(a.playing || b.playing, isFalse);
      final resume = music.setForeground(true);
      await _fade(tester);
      await _finish(tester, resume, 'resume menu B fade and menu A preload');
      expect(b.playing, isTrue);
      expect(a.playing, isFalse);
      expect(a.sources.last, GameMusic.menuA,
          reason: 'The return track is preloaded before B finishes');

      // Completion is the fallback if native duration/deadline is unavailable.
      b.completePlayback();
      expect(b.playing, isFalse);
      b.completion.add(null); // Duplicate native event must not advance twice.
      var returnedToA = false;
      final returning = music.menu().then((_) => returnedToA = true);
      await tester.pump();
      for (var step = 0; step < 11; step++) {
        expect(a.volumes.last + b.volumes.last, closeTo(.35, 1e-9));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 49));
      expect(returnedToA, isFalse, reason: 'The fade is pending at 599 ms');
      await tester.pump(const Duration(milliseconds: 1));
      expect(returnedToA, isTrue, reason: 'The fade completes at 600 ms');
      await _finish(tester, returning, 'menu B to A completion and B preload');
      expect(a.resumes.last, GameMusic.menuA);
      expect(a.resumes.where((s) => s == GameMusic.menuA), hasLength(2));
      expect(b.playing, isFalse);
      expect(
          [...a.volumes, ...b.volumes], everyElement(inInclusiveRange(0, .35)));
      expect(created, 1, reason: 'Exactly one additional reusable music deck');
      await _finish(tester, music.dispose(), 'menu A/B disposal');
      await tester.pump(const Duration(minutes: 5));
      expect(a.disposed && b.disposed, isTrue);
      expect(a.completion.hasListener || b.completion.hasListener, isFalse);
      expect(a.completionCancellations, 1);
      expect(b.completionCancellations, 1);
    } finally {
      await _finish(tester, music.dispose(), 'menu A/B finally cleanup');
      _verifyDisposed([a, b]);
    }
  });

  testWidgets(
      'same world continues; new world changes; old route cannot stop it',
      (tester) async {
    final a = _Deck();
    final b = _Deck();
    final sfx = List.generate(4, (_) => _Deck());
    final audio = GameAudioService(
        musicPlayer: a, createMusicDeck: () => b, sfxPlayers: sfx);
    try {
      final oldRoute = Object();
      final nextRoute = Object();
      final start = audio.startGameplayMusic(level: 9, owner: oldRoute);
      await _fade(tester);
      await _finish(tester, start, 'world 1 startup');
      await _finish(tester,
          audio.startGameplayMusic(level: 10, owner: nextRoute), 'same world');
      await _finish(tester, audio.stopGameplayMusic(owner: oldRoute),
          'outdated route return');
      expect(a.sources, [GameMusic.campaignAsset(9)]);
      expect(a.resumes, hasLength(1));
      expect(a.modes.single, ReleaseMode.loop);
      final change = audio.startGameplayMusic(level: 11, owner: nextRoute);
      await _fade(tester);
      await _finish(tester, change, 'world 1 to world 2 fade');
      expect(b.resumes, [GameMusic.campaignAsset(11)]);
      expect(b.modes.last, ReleaseMode.loop);
      // Late startup must preserve the active route.
      await _finish(tester, audio.startMusic(), 'late audio startup');
      expect(b.playing, isTrue);
      expect(a.playing, isFalse);
      final back = audio.stopGameplayMusic(owner: nextRoute);
      await _fade(tester);
      await _finish(tester, back, 'world 2 return to menu');
      expect(a.resumes.last, GameMusic.menuA);
      expect(a.modes.last, ReleaseMode.stop);
    } finally {
      await _finish(tester, audio.dispose(), 'route audio finally cleanup');
      _verifyDisposed([a, b, ...sfx]);
    }
  });

  testWidgets('mute, background and rapid requests cannot restart stale tracks',
      (tester) async {
    final a = _Deck();
    final b = _Deck();
    final music = GameMusic(primary: a, createDeck: () => b);
    try {
      await _finish(tester, music.setEnabled(false), 'initial music mute');
      await _finish(tester, music.menu(), 'muted menu selection');
      expect(a.sources, isEmpty);
      final enable = music.setEnabled(true);
      await _fade(tester);
      await _finish(tester, enable, 'music unmute fade');
      await _finish(tester, music.setForeground(false), 'background pause');
      await _finish(tester, music.setForeground(false), 'repeated pause');
      await _finish(tester, music.setEnabled(false), 'background mute');
      await _finish(tester, music.setEnabled(true), 'background unmute');
      await _finish(tester, music.campaign(11), 'background world 2 request');
      await _finish(tester, music.campaign(51), 'background world 6 request');
      await tester.pump(const Duration(minutes: 3));
      expect(b.resumes, isEmpty);
      expect(a.resumes, hasLength(1));
      final resume = music.setForeground(true);
      await _fade(tester);
      await _finish(tester, resume, 'foreground world 6 fade');
      expect(b.resumes, [GameMusic.campaignAsset(51)]);
      expect(a.playing, isFalse);
      await _finish(tester, music.setEnabled(false), 'active world mute');
      final resumes = b.resumes.length;
      b.completion.add(null); // Late native completion after muting is ignored.
      await tester.pump(const Duration(minutes: 3));
      expect(b.resumes, hasLength(resumes));
    } finally {
      await _finish(tester, music.dispose(), 'mute/lifecycle finally cleanup');
      _verifyDisposed([a, b]);
    }
  });

  testWidgets('dispose invalidates a source load before it can resume',
      (tester) async {
    final a = _Deck()..sourceGate = Completer<void>();
    final b = _Deck();
    final music = GameMusic(primary: a, createDeck: () => b);
    try {
      final start = music.menu();
      await tester.pump();
      expect(a.sourceEntered.isCompleted, isTrue);
      final disposal = music.dispose();
      expect(identical(music.dispose(), disposal), isTrue,
          reason: 'Concurrent disposal callers share pending cleanup');
      await tester.pump();
      expect(a.disposed || b.disposed, isFalse,
          reason: 'Pending source setup finishes before decks are disposed');
      a.sourceGate!.complete();
      await tester.pump();
      await _finish(tester, Future.wait([start, disposal]),
          'cancelled source load and pending disposal');
      await _finish(tester, music.menu(), 'menu request after disposal');
      await _finish(
          tester, music.setForeground(true), 'foreground after disposal');
      await tester.pump(const Duration(minutes: 5));
      expect(a.resumes, isEmpty);
      expect(b.resumes, isEmpty);
      expect(a.disposed && b.disposed, isTrue);
      expect(a.completion.hasListener, isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      if (!a.sourceGate!.isCompleted) a.sourceGate!.complete();
      await _finish(tester, music.dispose(), 'source gate finally cleanup');
      _verifyDisposed([a, b]);
    }
  });

  testWidgets('rapid route requests discard stale asynchronous music loads',
      (tester) async {
    final a = _Deck()..sourceGate = Completer<void>();
    final b = _Deck();
    final music = GameMusic(primary: a, createDeck: () => b);
    try {
      final menu = music.menu();
      await tester.pump();
      expect(a.sourceEntered.isCompleted, isTrue);
      final stale = music.campaign(11);
      final latest = music.campaign(21);
      a.sourceGate!.complete();
      await _fade(tester);
      await _finish(tester, Future.wait([menu, stale, latest]),
          'rapid menu/world 2/world 3 requests');
      expect(a.resumes, [GameMusic.campaignAsset(21)]);
      expect(a.sources, [GameMusic.menuA, GameMusic.campaignAsset(21)]);
      expect(b.resumes, isEmpty);
      a.completePlayback(); // World loop completion must not select menu B.
      expect(a.playing, isTrue);
      await tester.pump(const Duration(seconds: 30));
      expect(a.resumes, hasLength(1));
      expect(a.modes.last, ReleaseMode.loop);
    } finally {
      if (!a.sourceGate!.isCompleted) a.sourceGate!.complete();
      await _finish(tester, music.dispose(), 'rapid routes finally cleanup');
      _verifyDisposed([a, b]);
    }
  });

  testWidgets('blocked music operations fail with a bounded named diagnostic',
      (tester) async {
    final blocked = Completer<void>();
    final before = tester.binding.clock.now();
    try {
      TestFailure? failure;
      // Evaluating _finish as an expectLater argument starts a guarded pump
      // before expectLater's guardSync. Await it directly, including failure,
      // so its guard is closed before assertions or finally can start a pump.
      try {
        await _finish(tester, blocked.future, 'held source preparation');
      } on TestFailure catch (error) {
        failure = error;
      }
      TestAsyncUtils.verifyAllScopesClosed();
      expect(
          failure,
          isA<TestFailure>().having((failure) => failure.message,
              'operation name', contains('held source preparation')));
      expect(tester.binding.clock.now(), before,
          reason: 'Diagnostic drains cannot advance a fade or music deadline');
    } finally {
      blocked.complete();
      await tester.pump();
      TestAsyncUtils.verifyAllScopesClosed();
    }
  });

  testWidgets('broadcast cancellation drains before fake player disposal',
      (tester) async {
    final deck = _Deck();
    final subscription = deck.onPlayerComplete.listen((_) {});
    final before = tester.binding.clock.now();
    final cleanup = () async {
      // Same root-zone cancel -> fake-zone close chain as GameMusic._dispose.
      await subscription.cancel();
      await deck.dispose();
    }();
    await _finish(tester, cleanup, 'broadcast cancellation and player close');
    TestAsyncUtils.verifyAllScopesClosed();
    _verifyDisposed([deck]);
    expect(deck.completionCancellations, 1);
    expect(deck.disposed, isTrue);
    expect(deck.completion.isClosed, isTrue);
    expect(tester.binding.clock.now(), before);
  });
}
