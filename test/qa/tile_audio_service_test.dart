import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';

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
}
