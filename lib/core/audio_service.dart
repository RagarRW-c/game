import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

enum _MusicTrack { menu, gameplay }

class GameAudioService {
  GameAudioService({AudioPlayer? musicPlayer, List<AudioPlayer>? sfxPlayers})
      : assert(sfxPlayers == null || sfxPlayers.length == _sfxPoolSize),
        _music = musicPlayer ?? AudioPlayer(),
        _sfxPlayers =
            sfxPlayers ?? List.generate(_sfxPoolSize, (_) => AudioPlayer());
  static const String _backgroundMusicAsset = 'audio/background.mp3';
  static const int _sfxPoolSize = 4;

  final AudioPlayer _music;
  final List<AudioPlayer> _sfxPlayers;
  final Map<String, String> _generatedAudioPaths = <String, String>{};
  bool musicEnabled = true;
  bool sfxEnabled = true;
  bool _musicConfigured = false;
  bool _sfxConfigured = false;
  Future<void>? _sfxConfiguration;
  Future<void>? _tilePreparation;
  final Map<String, Future<String>> _pendingAudioPaths = {};
  final List<int> _sfxRequests = List.filled(_sfxPoolSize, 0);
  bool _disposed = false;
  bool _sfxSuspended = false;
  int _tileEpoch = 0;
  int _nextMatchPlayer = 1;
  bool _musicPlaying = false;
  bool _pausedByLifecycle = false;
  int _nextSfxPlayer = 0;
  int _nextTapVariant = 0;
  _MusicTrack? _activeMusicTrack;
  Future<void> _musicQueue = Future<void>.value();

  Future<void> startMenuMusic() =>
      _runMusicOperation(() => _startMusic(_MusicTrack.menu));

  Future<void> startGameplayMusic() =>
      _runMusicOperation(() => _startMusic(_MusicTrack.gameplay));

  Future<void> startMusic() => startMenuMusic();

  Future<void> _runMusicOperation(Future<void> Function() operation) {
    final next = _musicQueue.then((_) => operation());
    _musicQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _startMusic(_MusicTrack track) async {
    await _configureMusic(track);
    if (!musicEnabled || _musicPlaying) return;

    await _music.resume();
    _musicPlaying = true;
  }

  Future<void> _configureMusic(_MusicTrack track) async {
    if (_musicConfigured && _activeMusicTrack == track) return;

    if (_musicPlaying) await _music.stop();
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(0.35);
    await _music.setSource(AssetSource(_backgroundMusicAsset));
    _activeMusicTrack = track;
    _musicConfigured = true;
    _musicPlaying = false;
  }

  Future<void> _resumeMusic() async {
    if (_activeMusicTrack == null) return;
    if (!_musicConfigured) await _configureMusic(_activeMusicTrack!);
    if (!musicEnabled || _musicPlaying) return;

    await _music.resume();
    _musicPlaying = true;
  }

  Future<void> _pauseMusic({bool clearTrack = false}) async {
    if (!_musicConfigured && !_musicPlaying) return;

    await _music.pause();
    _musicPlaying = false;
    if (clearTrack) {
      _activeMusicTrack = null;
      _musicConfigured = false;
    }
  }

  Future<void> stopGameplayMusic() async {
    await _runMusicOperation(() async {
      if (_activeMusicTrack != _MusicTrack.gameplay) return;
      await _pauseMusic(clearTrack: true);
    });
  }

  Future<void> pauseMusicForBackground() async {
    if (_disposed) return;
    _sfxSuspended = true;
    cancelPendingTileFeedback();
    for (var i = 0; i < _sfxPlayers.length; i++) {
      _sfxRequests[i]++;
    }
    final musicPause = _runMusicOperation(() async {
      _pausedByLifecycle = _pausedByLifecycle || _musicPlaying;
      await _pauseMusic();
    });
    await Future.wait([
      musicPause,
      for (final player in _sfxPlayers) player.stop().catchError((_) {}),
    ]);
  }

  Future<void> resumeMusicFromBackground() async {
    if (_disposed) return;
    _sfxSuspended = false;
    await _runMusicOperation(() async {
      if (!_pausedByLifecycle) return;
      _pausedByLifecycle = false;
      await _resumeMusic();
    });
  }

  Future<void> setMusicEnabled(bool enabled) async {
    await _runMusicOperation(() async {
      if (musicEnabled == enabled) return;

      musicEnabled = enabled;
      if (enabled) {
        await _resumeMusic();
      } else {
        await _pauseMusic();
      }
    });
  }

  Future<void> playTap() {
    final cue = 'tap_${_nextTapVariant++ % 3}';
    return _play(cue);
  }

  Future<void> playMatch() => _play('match');

  /// Prepare once on gameplay entry, away from the visual impact frame.
  Future<void> prepareTileFeedback() =>
      _tilePreparation ??= _prepareTileFeedback().catchError((Object error) {
        _tilePreparation = null;
        throw error;
      });

  Future<void> _prepareTileFeedback() async {
    if (_disposed) return;
    await _configureSfx();
    for (final cue in ['tap_0', 'tap_1', 'tap_2', 'match']) {
      if (_disposed) return;
      await _audioPath(cue);
    }
  }

  /// Invalidates asynchronous setup already dispatched by an outgoing board.
  /// Already-playing short cues may finish; no stale pending cue may start.
  void cancelPendingTileFeedback() => _tileEpoch++;
  Future<void> playWin() => _play('win');
  Future<void> playLose() => _play('lose');
  Future<void> playBooster() => _play('booster');
  Future<void> playLevelComplete() => _play('level_complete');
  Future<void> playGameOver() => _play('game_over');
  Future<void> playChestOpen() => _play('chest_open');
  Future<void> playLuckyWheelSpin() => _play('wheel_spin');
  Future<void> playWheelTick() => _play('wheel_tick');
  Future<void> playWheelStop() => _play('wheel_stop');
  Future<void> playWheelReveal() => _play('wheel_reveal');
  Future<void> playWheelCollection() => _play('wheel_collection');
  Future<void> playAchievementUnlocked() => _play('achievement');
  Future<void> playWorldUnlocked() => _play('world_unlock');

  Future<void> _play(String cue) async {
    if (!sfxEnabled || _disposed || _sfxSuspended) return;
    final tileCue = cue.startsWith('tap') || cue == 'match';
    final epoch = _tileEpoch;
    // One replaceable tap voice, three match voices: a tap cannot steal the
    // main burst cue, and the three retained visual bursts can sound together.
    final int index;
    if (cue.startsWith('tap')) {
      index = 0;
    } else if (cue == 'match') {
      index = _nextMatchPlayer;
      _nextMatchPlayer = 1 + _nextMatchPlayer % (_sfxPoolSize - 1);
    } else {
      index = _nextSfxPlayer;
      _nextSfxPlayer = (_nextSfxPlayer + 1) % _sfxPlayers.length;
    }
    final request = ++_sfxRequests[index];
    bool current() =>
        !_disposed &&
        !_sfxSuspended &&
        sfxEnabled &&
        _sfxRequests[index] == request &&
        (!tileCue || epoch == _tileEpoch);
    await _configureSfx();
    if (!current()) return;
    final path = await _audioPath(cue);
    if (!current()) return;
    final player = _sfxPlayers[index];
    await player.stop();
    if (!current()) return;
    await player.setVolume(_volumeForCue(cue));
    if (!current()) return;
    await player.play(DeviceFileSource(path));
  }

  Future<void> _configureSfx() =>
      _sfxConfiguration ??= _configureSfxOnce().catchError((Object error) {
        _sfxConfiguration = null;
        throw error;
      });

  Future<void> _configureSfxOnce() async {
    if (_sfxConfigured || _disposed) return;

    final sfxContext = AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build();

    for (final player in _sfxPlayers) {
      if (_disposed) return;
      await player.setReleaseMode(ReleaseMode.stop);
      if (_disposed) return;
      await player.setPlayerMode(PlayerMode.lowLatency);
      if (_disposed) return;
      await player.setAudioContext(sfxContext);
      if (_disposed) return;
      await player.setVolume(1);
    }
    _sfxConfigured = true;
  }

  Future<String> _audioPath(String cue) async {
    final existing = _generatedAudioPaths[cue];
    if (existing != null && File(existing).existsSync()) return existing;

    return _pendingAudioPaths.putIfAbsent(cue, () async {
      try {
        final file =
            File('${Directory.systemTemp.path}/triple_tile_v2_$cue.wav');
        await file.writeAsBytes(_buildWav(_notesForCue(cue)), flush: true);
        _generatedAudioPaths[cue] = file.path;
        return file.path;
      } finally {
        _pendingAudioPaths.remove(cue);
      }
    });
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
    if (cue.startsWith('tap')) {
      switch (cue) {
        case 'tap_1':
          return [
            (frequency: 494, seconds: 0.025),
            (frequency: 660, seconds: 0.045),
          ];
        case 'tap_2':
          return [
            (frequency: 523, seconds: 0.025),
            (frequency: 698, seconds: 0.04),
          ];
        default:
          return [
            (frequency: 440, seconds: 0.02),
            (frequency: 587, seconds: 0.045),
          ];
      }
    }

    switch (cue) {
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
      // Original synthesized cues; no reference audio or external assets.
      case 'wheel_tick':
        return [(frequency: 1100, seconds: 0.018)];
      case 'wheel_stop':
        return [(frequency: 440, seconds: 0.045)];
      case 'wheel_reveal':
        return [
          (frequency: 659, seconds: 0.07),
          (frequency: 880, seconds: 0.1),
        ];
      case 'wheel_collection':
        return [
          (frequency: 1046, seconds: 0.035),
          (frequency: 1318, seconds: 0.06),
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

  double _volumeForCue(String cue) {
    if (cue == 'wheel_tick') return .25;
    if (cue == 'wheel_stop') return .55;
    if (cue == 'wheel_reveal' || cue == 'wheel_collection') return .65;
    if (cue.startsWith('tap')) return 0.58;
    if (cue == 'match') return 0.78;
    if (cue == 'level_complete') return 0.90;
    if (cue == 'game_over') return 0.70;
    return 1;
  }

  Uint8List _u16(int value) =>
      Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);
  Uint8List _u32(int value) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);
  Uint8List _i16(int value) =>
      Uint8List(2)..buffer.asByteData().setInt16(0, value, Endian.little);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    cancelPendingTileFeedback();
    final configuring = _sfxConfiguration;
    if (configuring != null) {
      try {
        await configuring;
      } catch (_) {
        // A failed setup must not prevent releasing the players.
      }
    }
    await _music.dispose();
    for (final player in _sfxPlayers) {
      await player.dispose();
    }
  }
}
