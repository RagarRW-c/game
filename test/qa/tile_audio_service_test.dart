import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/core/achievement_chime.dart';

class _Player implements AudioPlayer {
  final played = <Source>[];
  final prepared = <Source>[];
  final configured = <PlayerMode>[];
  double volume = 0;
  bool disposed = false;
  int stops = 0;
  Completer<void>? volumeGate;
  Completer<void>? volumeEntered;
  Source? loadedSource;
  Completer<void>? sourceGate;
  Completer<void>? sourceEntered;

  @override
  Future<void> setVolume(double value) async {
    volume = value;
    if (value != 1 && volumeGate != null) {
      volumeEntered!.complete();
      await volumeGate!.future;
    }
  }

  @override
  Future<void> setPlayerMode(PlayerMode mode) async => configured.add(mode);

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> setSource(Source source) async {
    prepared.add(source);
    loadedSource = source;
    if (sourceGate != null) {
      sourceEntered!.complete();
      await sourceGate!.future;
    }
  }

  @override
  Future<void> resume() async {
    expect(disposed, isFalse);
    played.add(loadedSource!);
  }

  @override
  Future<void> play(Source source,
      {double? volume,
      double? balance,
      AudioContext? ctx,
      Duration? position,
      PlayerMode? mode}) async {
    expect(disposed, isFalse);
    played.add(source);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('original chime generator remains deterministic with a silent tail', () {
    final bytes = buildAchievementChime();
    expect(bytes, buildAchievementChime());
    final data = ByteData.sublistView(bytes);
    expect(data.getUint32(24, Endian.little), 22050);
    final samples = [
      for (var i = 44; i < bytes.length; i += 2)
        data.getInt16(i, Endian.little) / 32767
    ];
    expect(samples.length / 22050, .44);
    expect(samples.first, 0);
    expect(samples.last, 0);
    final peak = samples.map((x) => x.abs()).reduce(math.max);
    final rms = math
        .sqrt(samples.fold<double>(0, (v, x) => v + x * x) / samples.length);
    expect(peak, inExclusiveRange(.1, .35));
    expect(rms, inExclusiveRange(.025, .10));
    expect(
        samples.take(110).map((x) => x.abs()).reduce(math.max), lessThan(.04));
    expect(
        samples.skip(samples.length - 220).map((x) => x.abs()).reduce(math.max),
        lessThan(.005));
    expect(
        [
          for (var i = 1; i < samples.length; i++)
            (samples[i] - samples[i - 1]).abs()
        ].reduce(math.max),
        lessThan(.06),
        reason: 'No impulse or discontinuity at note boundaries');
  });

  test(
      'achievement and world rewards use approved piano; wheel confirmation stays intact',
      () async {
    final voices = List.generate(4, (_) => _Player());
    final audio = GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
    addTearDown(audio.dispose);
    await audio.playAchievementUnlocked();
    expect(voices.expand((v) => v.played), hasLength(1));
    final source = voices[0].played.single as AssetSource;
    expect(source.path, 'audio/triotrek/sfx/reward_ok_d.mp3');
    expect(voices[0].volume, .65);
    await audio.playWheelRewardOk();
    expect((voices[1].played.single as AssetSource).path,
        'audio/triotrek/sfx/reward_ok_d.mp3');
    expect(voices[1].volume, .65);
    await audio.playWorldUnlocked();
    expect((voices[2].played.single as AssetSource).path, source.path);
    expect(voices[2].volume, .65);
    expect(voices.expand((v) => v.played), hasLength(3));
    expect(voices.expand((v) => v.played), everyElement(isA<AssetSource>()),
        reason: 'Neither reward can fall back to a synthesized WAV fanfare.');
    audio.sfxEnabled = false;
    await Future.wait([
      audio.playAchievementUnlocked(),
      audio.playWorldUnlocked(),
    ]);
    expect(voices.expand((v) => v.played), hasLength(3),
        reason: 'Muted achievement and world rewards never start playback.');
  });

  for (final world in [false, true]) {
    for (final cancellation in ['popup', 'mute', 'background', 'dispose']) {
      test('reward world=$world $cancellation rejects pending native setup',
          () async {
        final voices = List.generate(4, (_) => _Player());
        final audio =
            GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
        addTearDown(audio.dispose);
        await audio.prepareTileFeedback();
        final gate = Completer<void>();
        voices[0].sourceGate = gate;
        voices[0].sourceEntered = Completer<void>();
        final owner = Object();
        audio.beginAchievementFeedback(owner);
        final pending =
            world ? audio.playWorldUnlocked() : audio.playAchievementUnlocked();
        try {
          await voices[0].sourceEntered!.future;
          switch (cancellation) {
            case 'popup':
              audio.cancelAchievementFeedback(owner: owner);
            case 'mute':
              audio.sfxEnabled = false;
            case 'background':
              await audio.pauseMusicForBackground();
            case 'dispose':
              await audio.dispose();
          }
        } finally {
          gate.complete();
        }
        await pending;
        expect(voices.expand((v) => v.played), isEmpty);
      });
    }
  }

  test('achievement cancellation never stops a voice reassigned to tile taps',
      () async {
    final voices = List.generate(4, (_) => _Player());
    final audio = GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
    addTearDown(audio.dispose);
    audio.sfxEnabled = false;
    await audio.playAchievementUnlocked();
    expect(voices.expand((v) => v.played), isEmpty);
    audio.sfxEnabled = true;
    await audio.playAchievementUnlocked();
    await audio.playTap();
    final stops = voices.map((v) => v.stops).toList();
    audio.cancelAchievementFeedback();
    expect(voices.map((v) => v.stops), stops);
    expect((voices[0].played.last as AssetSource).path,
        'audio/triotrek/sfx/tile_tap_b.mp3');
  });

  for (final pendingOld in [false, true]) {
    test(
        'popup ownership supersedes ${pendingOld ? 'pending' : 'playing'} chime',
        () async {
      final voices = List.generate(4, (_) => _Player());
      final audio =
          GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
      addTearDown(audio.dispose);
      await audio.prepareTileFeedback();
      final oldOwner = Object();
      final newOwner = Object();
      final oldGate = Completer<void>();
      if (pendingOld) {
        voices[0].sourceGate = oldGate;
        voices[0].sourceEntered = Completer<void>();
      }
      audio.beginAchievementFeedback(oldOwner);
      final oldPlayback = audio.playAchievementUnlocked();
      try {
        if (pendingOld) {
          await voices[0].sourceEntered!.future;
        } else {
          await oldPlayback;
        }
        final oldStops = voices[0].stops;
        audio.beginAchievementFeedback(newOwner);
        expect(voices[0].stops, oldStops + 1,
            reason:
                'Superseding the popup cancels its pending or active voice.');

        // Hold the successor at native setup: a late dismissal must not
        // invalidate either its request epoch or its eventual active voice.
        final newGate = Completer<void>();
        voices[1].sourceGate = newGate;
        voices[1].sourceEntered = Completer<void>();
        final newPlayback = audio.playWorldUnlocked();
        try {
          await voices[1].sourceEntered!.future;
          final stops = voices.map((v) => v.stops).toList();
          audio.cancelAchievementFeedback(owner: oldOwner);
          expect(voices.map((v) => v.stops), stops);
        } finally {
          newGate.complete();
        }
        await newPlayback;
        expect(voices[1].played, hasLength(1));
        expect((voices[1].played.single as AssetSource).path,
            'audio/triotrek/sfx/reward_ok_d.mp3');
        final newStops = voices[1].stops;
        audio.cancelAchievementFeedback(owner: oldOwner);
        expect(voices[1].stops, newStops);
        audio.cancelAchievementFeedback(owner: newOwner);
        expect(voices[1].stops, newStops + 1);
        audio.cancelAchievementFeedback(owner: newOwner);
        expect(voices[1].stops, newStops + 1,
            reason: 'Repeated close/dispose is idempotent.');
      } finally {
        oldGate.complete();
      }
      await oldPlayback;
      expect(voices[0].played, hasLength(pendingOld ? 0 : 1),
          reason: 'A superseded pending request must never resume.');
      expect(voices.skip(2).expand((v) => v.played), isEmpty);
    });
  }

  test('preparation is shared; tap voice cannot steal three match voices',
      () async {
    final voices = List.generate(4, (_) => _Player());
    final audio = GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
    addTearDown(audio.dispose);
    await Future.wait(
        [audio.prepareTileFeedback(), audio.prepareTileFeedback()]);
    for (final player in voices) {
      expect(player.configured, [PlayerMode.lowLatency]);
      expect(player.prepared, hasLength(1));
      expect(
          (player.prepared.single as AssetSource).path,
          identical(player, voices.first)
              ? 'audio/triotrek/sfx/tile_tap_b.mp3'
              : 'audio/triotrek/sfx/triple_match_c.mp3');
    }
    await Future.wait(
        [audio.playMatch(), audio.playMatch(), audio.playMatch()]);
    await audio.playTap();
    await audio.playTap();
    expect(voices[0].played, hasLength(2));
    expect(voices[0].volume, .58);
    expect(voices[0].played.map((s) => (s as AssetSource).path),
        everyElement('audio/triotrek/sfx/tile_tap_b.mp3'));
    for (final player in voices.skip(1)) {
      expect(player.played, hasLength(1));
      expect((player.played.single as AssetSource).path,
          'audio/triotrek/sfx/triple_match_c.mp3');
      expect(player.volume, .78);
    }
  });

  for (final cancellation in [
    'board',
    'mute',
    'mute_toggle',
    'background',
    'dispose'
  ]) {
    test('$cancellation rejects a match whose async setup is still pending',
        () async {
      final voices = List.generate(4, (_) => _Player());
      final audio =
          GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
      addTearDown(audio.dispose);
      await audio.prepareTileFeedback();
      final gate = Completer<void>();
      voices[1].volumeGate = gate;
      voices[1].volumeEntered = Completer<void>();
      final pending = audio.playMatch();
      try {
        await voices[1].volumeEntered!.future;
        switch (cancellation) {
          case 'board':
            audio.cancelPendingTileFeedback();
          case 'mute':
            audio.sfxEnabled = false;
          case 'mute_toggle':
            audio.sfxEnabled = false;
            audio.sfxEnabled = true;
          case 'background':
            await audio.pauseMusicForBackground();
          case 'dispose':
            await audio.dispose();
        }
      } finally {
        gate.complete();
        await pending;
      }
      expect(voices.expand((p) => p.played), isEmpty);
      if (cancellation == 'background') await audio.resumeMusicFromBackground();
      audio.sfxEnabled = true;
      if (cancellation != 'dispose') {
        await audio.playMatch();
        expect(voices[2].played, hasLength(1));
        expect(voices[1].played, isEmpty, reason: 'Old cues must never replay');
      }
    });
  }

  for (final cancellation in ['route', 'mute', 'background', 'dispose']) {
    test('selection and Undo tap reject pending setup on $cancellation',
        () async {
      final voices = List.generate(4, (_) => _Player());
      final audio =
          GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
      addTearDown(audio.dispose);
      await audio.prepareTileFeedback();
      final gate = Completer<void>();
      voices[0].sourceGate = gate;
      voices[0].sourceEntered = Completer<void>();
      final pending = audio.playTap();
      try {
        await voices[0].sourceEntered!.future;
        expect((voices[0].loadedSource as AssetSource).path,
            'audio/triotrek/sfx/tile_tap_b.mp3');
        expect(voices[0].volume, .58);
        switch (cancellation) {
          case 'route':
            audio.cancelPendingTileFeedback();
          case 'mute':
            audio.sfxEnabled = false;
          case 'background':
            await audio.pauseMusicForBackground();
          case 'dispose':
            await audio.dispose();
        }
      } finally {
        gate.complete();
        await pending;
      }
      expect(voices.expand((v) => v.played), isEmpty);
      if (cancellation != 'dispose') {
        voices[0].sourceGate = null;
        audio.sfxEnabled = true;
        if (cancellation == 'background')
          await audio.resumeMusicFromBackground();
        await audio.playTap();
        expect(voices[0].played, hasLength(1));
        expect((voices[0].played.single as AssetSource).path,
            'audio/triotrek/sfx/tile_tap_b.mp3');
        expect(voices[0].volume, .58);
        expect(voices.skip(1).expand((v) => v.played), isEmpty);
      }
    });
  }

  test('muted preparation and repeated taps never create extra voices',
      () async {
    final voices = List.generate(4, (_) => _Player());
    final audio = GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
    addTearDown(audio.dispose);
    audio.sfxEnabled = false;
    await audio.prepareTileFeedback();
    await Future.wait([audio.playTap(), audio.playMatch()]);
    expect(voices.expand((p) => p.played), isEmpty);
    audio.sfxEnabled = true;
    await Future.wait(List.generate(20, (_) => audio.playTap()));
    expect(voices[0].played, hasLength(1),
        reason: 'Superseded tap setup must not produce a delayed sound queue');
    expect(voices.skip(1).expand((p) => p.played), isEmpty);
  });

  test('approved wheel sources retain bounded tick and collection allocation',
      () async {
    final voices = List.generate(4, (_) => _Player());
    final audio = GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
    addTearDown(audio.dispose);
    await audio.prepareTileFeedback();
    await Future.wait(List.generate(20, (_) => audio.playWheelTick()));
    expect(voices[0].played, hasLength(1),
        reason: 'Superseded tick setup cannot flood all four voices');
    expect((voices[0].played.single as AssetSource).path,
        'audio/triotrek/sfx/wheel_tick_a.mp3');
    expect(voices[0].volume, .25);
    expect(voices.skip(1).expand((p) => p.played), isEmpty);
    await audio.playWheelCollection();
    expect((voices[0].played.last as AssetSource).path,
        'audio/triotrek/sfx/wheel_prize_coins.mp3');
    expect(voices[0].volume, .65);
    final stops = voices.map((p) => p.stops).toList();
    audio.sfxEnabled = false;
    for (var i = 0; i < voices.length; i++) {
      expect(voices[i].stops, stops[i] + 1,
          reason: 'Muting stops already-playing approved tails');
    }
    await Future.wait([audio.playWheelTick(), audio.playWheelCollection()]);
    expect(voices[0].played, hasLength(2));
  });

  test('navigation cancels a match awaiting native asset preparation',
      () async {
    final voices = List.generate(4, (_) => _Player());
    final audio = GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
    addTearDown(audio.dispose);
    await audio.prepareTileFeedback();
    voices[1].sourceGate = Completer<void>();
    voices[1].sourceEntered = Completer<void>();
    final pending = audio.playMatch();
    try {
      await voices[1].sourceEntered!.future;
      audio.cancelPendingTileFeedback();
    } finally {
      voices[1].sourceGate!.complete();
      await pending;
    }
    expect(voices.expand((p) => p.played), isEmpty);
    await audio.playMatch();
    expect(voices[2].played, hasLength(1));
  });

  test('STOP B uses one approved asset voice, distinct from Prize Coins',
      () async {
    final voices = List.generate(4, (_) => _Player());
    final audio = GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
    addTearDown(audio.dispose);
    await audio.playWheelStop();
    expect(voices[0].played, hasLength(1));
    expect((voices[0].played.single as AssetSource).path,
        'audio/triotrek/sfx/wheel_stop_b.mp3');
    expect(voices[0].volume, .55);
    expect(voices.skip(1).expand((p) => p.played), isEmpty,
        reason: 'Landing must not layer a second synthesized cue.');

    await audio.playWheelCollection();
    expect(voices[1].played, hasLength(1));
    expect((voices[1].played.single as AssetSource).path,
        'audio/triotrek/sfx/wheel_prize_coins.mp3');
    expect(voices[1].volume, .65);
    expect(voices.expand((p) => p.played), hasLength(2));
    expect(voices.expand((p) => p.played), everyElement(isA<AssetSource>()));

    final stops = voices.map((p) => p.stops).toList();
    audio.sfxEnabled = false;
    await audio.playWheelStop();
    expect(voices.expand((p) => p.played), hasLength(2));
    for (var i = 0; i < voices.length; i++) {
      expect(voices[i].stops, stops[i] + 1);
    }
    audio.sfxEnabled = true;
    await audio.playWheelStop();
    expect((voices[2].played.single as AssetSource).path,
        'audio/triotrek/sfx/wheel_stop_b.mp3');
    expect(voices.expand((p) => p.played), hasLength(3));
    for (final player in voices) {
      expect(player.configured, [PlayerMode.lowLatency]);
    }
  });

  test(
      'Reward OK D has its own asset and honors mute without replacing wheel cues',
      () async {
    final voices = List.generate(4, (_) => _Player());
    final audio = GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
    addTearDown(audio.dispose);
    await audio.playWheelTick();
    expect((voices[0].played.single as AssetSource).path,
        'audio/triotrek/sfx/wheel_tick_a.mp3');
    expect(voices[0].volume, .25);
    await audio.playWheelStop();
    expect((voices[0].played.last as AssetSource).path,
        'audio/triotrek/sfx/wheel_stop_b.mp3');
    expect(voices[0].volume, .55);
    await audio.playWheelCollection();
    expect((voices[1].played.single as AssetSource).path,
        'audio/triotrek/sfx/wheel_prize_coins.mp3');
    expect(voices[1].volume, .65);
    await audio.playWheelRewardOk();
    expect((voices[2].played.single as AssetSource).path,
        'audio/triotrek/sfx/reward_ok_d.mp3');
    expect(voices[2].volume, .65);
    expect(voices[3].played, isEmpty);
    expect(voices.expand((p) => p.played), hasLength(4));
    expect(voices.expand((p) => p.played), everyElement(isA<AssetSource>()),
        reason: 'Confirmation must not add a legacy synthesized cue.');

    final stops = voices.map((p) => p.stops).toList();
    audio.sfxEnabled = false;
    await audio.playWheelRewardOk();
    expect(voices.expand((p) => p.played), hasLength(4));
    for (var i = 0; i < voices.length; i++) {
      expect(voices[i].stops, stops[i] + 1);
    }
    audio.sfxEnabled = true;
    await audio.playWheelRewardOk();
    expect((voices[3].played.single as AssetSource).path,
        'audio/triotrek/sfx/reward_ok_d.mp3');
    expect(voices.expand((p) => p.played), hasLength(5));
    for (final player in voices) {
      expect(player.configured, [PlayerMode.lowLatency]);
    }
  });

  for (final rewardOk in [false, true]) {
    final cue = rewardOk ? 'Reward OK D' : 'STOP B';
    final asset = rewardOk ? 'reward_ok_d.mp3' : 'wheel_stop_b.mp3';
    for (final cancellation in [
      'route',
      'mute',
      'mute_toggle',
      'background',
      'background_resume',
      'dispose',
    ]) {
      test('$cancellation rejects $cue awaiting native asset preparation',
          () async {
        final voices = List.generate(4, (_) => _Player());
        final audio =
            GameAudioService(musicPlayer: _Player(), sfxPlayers: voices);
        addTearDown(audio.dispose);
        await audio.prepareTileFeedback();
        voices[0].sourceGate = Completer<void>();
        voices[0].sourceEntered = Completer<void>();
        final playCue =
            rewardOk ? audio.playWheelRewardOk : audio.playWheelStop;
        final pending = playCue();
        try {
          await voices[0].sourceEntered!.future;
          expect((voices[0].loadedSource! as AssetSource).path,
              'audio/triotrek/sfx/$asset');
          switch (cancellation) {
            case 'route':
              audio.cancelPendingWheelFeedback();
            case 'mute':
              audio.sfxEnabled = false;
            case 'mute_toggle':
              audio.sfxEnabled = false;
              audio.sfxEnabled = true;
            case 'background':
              await audio.pauseMusicForBackground();
            case 'background_resume':
              await audio.pauseMusicForBackground();
              await audio.resumeMusicFromBackground();
            case 'dispose':
              await audio.dispose();
          }
        } finally {
          voices[0].sourceGate!.complete();
          await pending;
        }
        expect(voices.expand((p) => p.played), isEmpty,
            reason: 'The invalidated $cue cue must never start or replay.');
        if (cancellation == 'background') {
          await audio.resumeMusicFromBackground();
        }
        audio.sfxEnabled = true;
        if (cancellation != 'dispose') {
          await playCue();
          expect((voices[1].played.single as AssetSource).path,
              'audio/triotrek/sfx/$asset');
          expect(voices[0].played, isEmpty);
        }
      });
    }
  }
}
