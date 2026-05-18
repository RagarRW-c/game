import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

class GameAudioService {
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();
  final Map<String, String> _generatedAudioPaths = <String, String>{};
  bool musicEnabled = true;
  bool sfxEnabled = true;

  Future<void> startMusic() async {
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(0.35);
    if (musicEnabled) {
      await _music.play(DeviceFileSource(await _audioPath('background')));
    }
  }

  Future<void> setMusicEnabled(bool enabled) async {
    musicEnabled = enabled;
    if (enabled) {
      await startMusic();
    } else {
      await _music.stop();
    }
  }

  Future<void> playTap() => _play('tap');
  Future<void> playMatch() => _play('match');
  Future<void> playWin() => _play('win');
  Future<void> playLose() => _play('lose');
  Future<void> playBooster() => _play('booster');

  Future<void> _play(String cue) async {
    if (!sfxEnabled) return;
    await _sfx.stop();
    await _sfx.play(DeviceFileSource(await _audioPath(cue)));
  }

  Future<String> _audioPath(String cue) async {
    final existing = _generatedAudioPaths[cue];
    if (existing != null && File(existing).existsSync()) return existing;

    final file = File('${Directory.systemTemp.path}/triple_tile_$cue.wav');
    await file.writeAsBytes(_buildWav(_notesForCue(cue)), flush: true);
    _generatedAudioPaths[cue] = file.path;
    return file.path;
  }

  /// Generates tiny WAV cues at runtime so the repository stays text-only while
  /// still shipping sound effects and looping background music in the app.
  Uint8List _buildWav(List<({double frequency, double seconds})> notes) {
    const sampleRate = 22050;
    final samples = <int>[];
    for (final note in notes) {
      final count = (sampleRate * note.seconds).round();
      for (var i = 0; i < count; i++) {
        final t = i / sampleRate;
        final envelope = sin(pi * i / max(1, count));
        final value = 0.23 * envelope * sin(2 * pi * note.frequency * t);
        samples.add((32767 * value).round());
      }
    }

    final dataSize = samples.length * 2;
    final bytes = BytesBuilder(copy: false)
      ..add('RIFF'.codeUnits)
      ..add(_u32(36 + dataSize))
      ..add('WAVEfmt '.codeUnits)
      ..add(_u32(16))
      ..add(_u16(1))
      ..add(_u16(1))
      ..add(_u32(sampleRate))
      ..add(_u32(sampleRate * 2))
      ..add(_u16(2))
      ..add(_u16(16))
      ..add('data'.codeUnits)
      ..add(_u32(dataSize));

    for (final sample in samples) {
      bytes.add(_i16(sample));
    }
    return bytes.toBytes();
  }

  List<({double frequency, double seconds})> _notesForCue(String cue) {
    switch (cue) {
      case 'tap':
        return [(frequency: 880, seconds: 0.07)];
      case 'match':
        return [
          (frequency: 660, seconds: 0.08),
          (frequency: 990, seconds: 0.1),
          (frequency: 1320, seconds: 0.12),
        ];
      case 'win':
        return [
          (frequency: 523, seconds: 0.12),
          (frequency: 659, seconds: 0.12),
          (frequency: 784, seconds: 0.12),
          (frequency: 1046, seconds: 0.25),
        ];
      case 'lose':
        return [
          (frequency: 330, seconds: 0.15),
          (frequency: 220, seconds: 0.25),
        ];
      case 'booster':
        return [
          (frequency: 700, seconds: 0.05),
          (frequency: 1000, seconds: 0.08),
        ];
      case 'background':
      default:
        return [
          for (final frequency in <double>[392, 523, 659, 784, 659, 523, 440, 587])
            (frequency: frequency, seconds: 0.25),
        ];
    }
  }

  Uint8List _u16(int value) => Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);
  Uint8List _u32(int value) => Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);
  Uint8List _i16(int value) => Uint8List(2)..buffer.asByteData().setInt16(0, value, Endian.little);

  Future<void> dispose() async {
    await _music.dispose();
    await _sfx.dispose();
  }
}
