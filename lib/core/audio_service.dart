import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

class GameAudioService {
  static const String _backgroundMusicAsset = 'audio/background.mp3';
  static const int _sfxPoolSize = 4;

  final AudioPlayer _music = AudioPlayer();
  final List<AudioPlayer> _sfxPlayers = List<AudioPlayer>.generate(
    _sfxPoolSize,
    (_) => AudioPlayer(),
  );
  final Map<String, String> _generatedAudioPaths = <String, String>{};
  bool musicEnabled = true;
  bool sfxEnabled = true;
  bool _musicConfigured = false;
  bool _sfxConfigured = false;
  bool _musicPlaying = false;
  int _nextSfxPlayer = 0;

  Future<void> startMusic() async {
    await _configureMusic();
    if (!musicEnabled || _musicPlaying) return;

    await _music.resume();
    _musicPlaying = true;
  }

  Future<void> _configureMusic() async {
    if (_musicConfigured) return;

    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(0.35);
    await _music.setSource(AssetSource(_backgroundMusicAsset));
    _musicConfigured = true;
  }

  Future<void> _resumeMusic() async {
    await _configureMusic();
    if (_musicPlaying) return;

    await _music.resume();
    _musicPlaying = true;
  }

  Future<void> _stopMusic() async {
    if (!_musicConfigured && !_musicPlaying) return;

    await _music.pause();
    _musicPlaying = false;
  }

  Future<void> setMusicEnabled(bool enabled) async {
    if (musicEnabled == enabled) return;

    musicEnabled = enabled;
    if (enabled) {
      await _resumeMusic();
    } else {
      await _stopMusic();
    }
  }

  Future<void> playTap() => _play('tap');
  Future<void> playMatch() => _play('match');
  Future<void> playWin() => _play('win');
  Future<void> playLose() => _play('lose');
  Future<void> playBooster() => _play('booster');
  Future<void> playLevelComplete() => _play('level_complete');
  Future<void> playGameOver() => _play('game_over');
  Future<void> playChestOpen() => _play('chest_open');
  Future<void> playLuckyWheelSpin() => _play('wheel_spin');
  Future<void> playAchievementUnlocked() => _play('achievement');
  Future<void> playWorldUnlocked() => _play('world_unlock');

  Future<void> _play(String cue) async {
    if (!sfxEnabled) return;
    await _configureSfx();

    final player = _sfxPlayers[_nextSfxPlayer];
    _nextSfxPlayer = (_nextSfxPlayer + 1) % _sfxPlayers.length;

    await player.stop();
    await player.play(DeviceFileSource(await _audioPath(cue)));
  }

  Future<void> _configureSfx() async {
    if (_sfxConfigured) return;

    final sfxContext = AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build();

    for (final player in _sfxPlayers) {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setAudioContext(sfxContext);
      await player.setVolume(1);
    }
    _sfxConfigured = true;
  }

  Future<String> _audioPath(String cue) async {
    final existing = _generatedAudioPaths[cue];
    if (existing != null && File(existing).existsSync()) return existing;

    final file = File('${Directory.systemTemp.path}/triple_tile_$cue.wav');
    await file.writeAsBytes(_buildWav(_notesForCue(cue)), flush: true);
    _generatedAudioPaths[cue] = file.path;
    return file.path;
  }

  /// Generates tiny WAV cues at runtime for short sound effects.
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
      case 'level_complete':
        return [
          (frequency: 523, seconds: 0.12),
          (frequency: 659, seconds: 0.12),
          (frequency: 784, seconds: 0.12),
          (frequency: 1046, seconds: 0.25),
        ];
      case 'lose':
      case 'game_over':
        return [
          (frequency: 330, seconds: 0.15),
          (frequency: 220, seconds: 0.25),
        ];
      case 'booster':
        return [
          (frequency: 700, seconds: 0.05),
          (frequency: 1000, seconds: 0.08),
        ];
      case 'chest_open':
        return [
          (frequency: 392, seconds: 0.08),
          (frequency: 784, seconds: 0.08),
          (frequency: 1175, seconds: 0.16),
        ];
      case 'wheel_spin':
        return [
          (frequency: 740, seconds: 0.04),
          (frequency: 830, seconds: 0.04),
          (frequency: 932, seconds: 0.04),
          (frequency: 1046, seconds: 0.08),
        ];
      case 'achievement':
        return [
          (frequency: 659, seconds: 0.08),
          (frequency: 880, seconds: 0.08),
          (frequency: 1318, seconds: 0.16),
        ];
      case 'world_unlock':
        return [
          (frequency: 523, seconds: 0.08),
          (frequency: 784, seconds: 0.08),
          (frequency: 1046, seconds: 0.08),
          (frequency: 1568, seconds: 0.2),
        ];
      default:
        return [(frequency: 880, seconds: 0.07)];
    }
  }

  Uint8List _u16(int value) =>
      Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);
  Uint8List _u32(int value) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);
  Uint8List _i16(int value) =>
      Uint8List(2)..buffer.asByteData().setInt16(0, value, Endian.little);

  Future<void> dispose() async {
    await _music.dispose();
    for (final player in _sfxPlayers) {
      await player.dispose();
    }
  }
}
