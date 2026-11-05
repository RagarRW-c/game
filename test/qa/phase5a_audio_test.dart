import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/core/campaign_feedback_audio.dart';

class _Voice implements AudioPlayer {
  final played = <Source>[];
  @override
  Source? source;
  @override
  double volume = 1;
  Completer<void>? sourceGate;
  Completer<void>? entered;
  @override
  Future<void> setSource(Source value) async {
    source = value;
    if (sourceGate != null) {
      entered!.complete();
      await sourceGate!.future;
    }
  }

  @override
  Future<void> setVolume(double value) async => volume = value;
  @override
  Future<void> resume() async => played.add(source!);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Phase 5A simultaneous SFX retain conservative mix headroom', () {
    final perVoice = <int, double>{};
    for (final entry in campaignFeedbackSounds.entries) {
      final originalWav = entry.key != CampaignFeedbackEvent.selection &&
          entry.key != CampaignFeedbackEvent.match;
      final peak = entry.value.volume * (originalWav ? .35 : 1.0);
      perVoice[entry.value.voice] =
          math.max(perVoice[entry.value.voice] ?? 0, peak);
    }
    expect(perVoice.length, 3);
    expect(perVoice.values.reduce((a, b) => a + b), lessThan(.9));
  });
  for (final event in CampaignFeedbackEvent.values) {
    test('Phase 5A $event routes once to its declared asset and bounded voice',
        () async {
      final voices = List.generate(4, (_) => _Voice());
      final audio = GameAudioService(musicPlayer: _Voice(), sfxPlayers: voices);
      addTearDown(audio.dispose);
      await audio.playCampaignFeedback(event);
      final sounding = voices.where((v) => v.played.isNotEmpty).single;
      final spec = campaignFeedbackSounds[event]!;
      expect((sounding.played.single as AssetSource).path, spec.asset);
      expect(sounding.volume, spec.volume);
      expect(voices.indexOf(sounding), spec.voice);
    });
  }

  test('muted Phase 5A produces no native playback for any event', () async {
    final voices = List.generate(4, (_) => _Voice());
    final audio = GameAudioService(musicPlayer: _Voice(), sfxPlayers: voices);
    addTearDown(audio.dispose);
    audio.sfxEnabled = false;
    for (final event in CampaignFeedbackEvent.values) {
      await audio.playCampaignFeedback(event);
    }
    expect(voices.expand((v) => v.played), isEmpty);
  });

  for (final interruption in ['mute', 'background', 'cancel', 'dispose']) {
    test('Phase 5A $interruption rejects delayed native source completion',
        () async {
      final voices = List.generate(4, (_) => _Voice());
      final audio = GameAudioService(musicPlayer: _Voice(), sfxPlayers: voices);
      addTearDown(audio.dispose);
      await audio.prepareTileFeedback();
      voices[1].sourceGate = Completer<void>();
      voices[1].entered = Completer<void>();
      final pending =
          audio.playCampaignFeedback(CampaignFeedbackEvent.collection);
      await voices[1].entered!.future;
      switch (interruption) {
        case 'mute':
          audio.sfxEnabled = false;
        case 'background':
          await audio.pauseMusicForBackground();
        case 'cancel':
          audio.cancelPendingTileFeedback();
        case 'dispose':
          await audio.dispose();
      }
      voices[1].sourceGate!.complete();
      await pending;
      expect(voices.expand((v) => v.played), isEmpty);
    });
  }

  test('Campaign and legacy match allocation cannot corrupt each other',
      () async {
    final voices = List.generate(4, (_) => _Voice());
    final audio = GameAudioService(musicPlayer: _Voice(), sfxPlayers: voices);
    addTearDown(audio.dispose);
    for (var i = 0; i < 12; i++) {
      await audio.playCampaignFeedback(CampaignFeedbackEvent.match);
      await audio.playMatch();
      await audio.playCampaignFeedback(CampaignFeedbackEvent.selection);
    }
    expect(voices[0].played, hasLength(12));
    expect(voices.skip(1).expand((v) => v.played), hasLength(24));
    expect(
        voices[0]
            .played
            .every((s) => (s as AssetSource).path.contains('tile_tap')),
        true);
  });

  for (final kind in ['entrance', 'landing', 'collect']) {
    test('original $kind WAV has bounded amplitude, duration and silent edges',
        () {
      final bytes =
          File('assets/audio/campaign_${kind}_v2.wav').readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(data.getUint32(24, Endian.little), 22050);
      expect(data.getUint16(22, Endian.little), 1);
      final samples = [
        for (var i = 44; i < bytes.length; i += 2)
          data.getInt16(i, Endian.little) / 32767
      ];
      expect(samples.first, 0);
      expect(samples.last, 0);
      expect(samples.length / 22050, inInclusiveRange(.08, .25));
      final peak = samples.fold<double>(0, (a, b) => math.max(a, b.abs()));
      final rms = math
          .sqrt(samples.fold<double>(0, (a, b) => a + b * b) / samples.length);
      expect(peak, inExclusiveRange(.10, .35));
      expect(rms, inExclusiveRange(.015, .12));
    });
  }
}
