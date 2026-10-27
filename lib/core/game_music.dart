import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Two reusable streaming decks. Only music owns timers; game/SFX clocks never
/// wait on this queue. All route, mute and lifecycle changes invalidate fades.
class GameMusic {
  GameMusic({required AudioPlayer primary, AudioPlayer Function()? createDeck})
      : _decks = [_Deck(primary)],
        _createDeck = createDeck ?? AudioPlayer.new;

  static const menuA = 'audio/triotrek/music/menu_a.mp3';
  static const menuB = 'audio/triotrek/music/menu_b.mp3';
  static const fadeDuration = Duration(milliseconds: 600);
  static const _gain = .35;
  static const _step = Duration(milliseconds: 50);

  static String campaignAsset(int level) {
    RangeError.checkValueInInterval(level, 1, 100, 'level');
    final world = ((level - 1) ~/ 10 + 1).toString().padLeft(2, '0');
    return 'audio/triotrek/music/world_$world.mp3';
  }

  final List<_Deck> _decks;
  final AudioPlayer Function() _createDeck;
  Future<void> _queue = Future<void>.value();
  Future<void>? _disposal;
  Timer? _deadline;
  Timer? _fadeTimer;
  Completer<void>? _fadeWait;
  int _generation = 0;
  int _active = 0;
  bool _enabled = true;
  bool _foreground = true;
  bool _presentationPaused = false;
  bool _disposed = false;
  bool _failed = false;
  bool _advancing = false;
  String? _wanted;
  String _menuAsset = menuA;

  bool get _allowed =>
      !_disposed && _enabled && _foreground && !_presentationPaused;
  bool _current(int generation) => _allowed && generation == _generation;
  bool _isMenu(String? asset) => asset == menuA || asset == menuB;

  Future<void> menu() => _select(_menuAsset);
  Future<void> campaign(int level) => _select(campaignAsset(level));
  // Late startup preferences must not replace a route's already selected world.
  Future<void> start() => _wanted == null ? menu() : _queue;

  Future<void> _select(String asset) {
    if (_disposed) return Future<void>.value();
    if (_wanted == asset && !_failed) return _queue;
    _wanted = asset;
    final generation = _invalidate();
    return _enqueue(() => _reconcile(generation));
  }

  Future<void> setEnabled(bool enabled) {
    if (_disposed || _enabled == enabled) return _queue;
    _enabled = enabled;
    final generation = _invalidate();
    return _enqueue(() => _reconcile(generation));
  }

  Future<void> setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return _queue;
    _foreground = foreground;
    final generation = _invalidate();
    return _enqueue(() => _reconcile(generation));
  }

  /// A result screen can be silent without changing the player's music setting
  /// or pretending that the whole application has gone into the background.
  Future<void> setPresentationPaused(bool paused) {
    if (_disposed || _presentationPaused == paused) return _queue;
    _presentationPaused = paused;
    final generation = _invalidate();
    return _enqueue(() => _reconcile(generation));
  }

  int _invalidate() {
    _deadline?.cancel();
    _deadline = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _fadeWait?.complete();
    _fadeWait = null;
    _advancing = false;
    return ++_generation;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    // Audio failure must not escape fire-and-forget navigation callbacks.
    _queue = _queue.then((_) async {
      _failed = false;
      await operation();
    }).catchError((Object _) {
      _failed = true;
    });
    return _queue;
  }

  void _connect(_Deck deck) {
    if (deck.completion != null) return;
    // Only the one-shot menu deadline needs position, queried on start/resume.
    deck.player.positionUpdater = null;
    deck.completion = deck.player.onPlayerComplete.listen((_) {
      if (_allowed &&
          identical(deck, _decks[_active]) &&
          deck.asset == _wanted &&
          _isMenu(_wanted)) {
        _advanceMenu(_generation);
      }
    }, onError: (Object _, StackTrace __) {
      // The next explicit request may retry; plugin errors never affect play.
      _failed = true;
    });
  }

  Future<void> _load(_Deck deck, String asset, int generation) async {
    _connect(deck);
    if (deck.asset == asset) return;
    deck.asset = null; // A partially configured deck is never reusable.
    await deck.player.stop();
    deck.playing = false;
    if (!_current(generation)) return;
    await deck.player.setVolume(0);
    deck.gain = 0;
    if (!_current(generation)) return;
    // Independent focus requests can pause the outgoing deck on Android.
    // Both decks mix; the app lifecycle owns foreground/background suspension.
    await deck.player.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build());
    if (!_current(generation)) return;
    await deck.player
        .setReleaseMode(_isMenu(asset) ? ReleaseMode.stop : ReleaseMode.loop);
    if (!_current(generation)) return;
    await deck.player.setSource(AssetSource(asset));
    if (!_current(generation)) return;
    deck.asset = asset;
  }

  Future<void> _reconcile(int generation) async {
    if (_disposed || generation != _generation) return;
    if (!_allowed) {
      for (final deck in _decks) {
        if (deck.playing) await deck.player.pause();
        deck.playing = false;
      }
      return;
    }
    final asset = _wanted;
    if (asset == null) return;
    if (_decks.length == 1) _decks.add(_Deck(_createDeck()));
    final old = _decks[_active];
    final targetIndex =
        old.asset == asset || old.asset == null ? _active : 1 - _active;
    final target = _decks[targetIndex];
    await _load(target, asset, generation);
    if (!_current(generation)) return;
    if (!target.playing) {
      await target.player.resume();
      target.playing = true;
    }
    if (!_current(generation)) return;
    // Incoming deck becomes the resumable owner even if a fade is interrupted.
    _active = targetIndex;
    final other = _decks[1 - _active];
    final fromGain = target.gain;
    final otherGain = other.gain;
    for (var step = 1; step <= 12; step++) {
      if (!_current(generation)) return;
      final t = step / 12;
      target.gain = fromGain + (_gain - fromGain) * t;
      await target.player.setVolume(target.gain);
      if (!_current(generation)) return;
      if (other.playing) {
        other.gain = otherGain * (1 - t);
        await other.player.setVolume(other.gain);
      }
      if (!_current(generation)) return;
      await _waitStep();
    }
    if (!_current(generation)) return;
    if (other.playing) await other.player.stop();
    other.playing = false;
    other.asset = null; // Stopped tracks restart only when selected again.
    other.gain = 0;
    if (!_current(generation)) return;
    await _scheduleMenu(generation);
  }

  Future<void> _waitStep() {
    final wait = Completer<void>();
    _fadeWait = wait;
    _fadeTimer = Timer(_step, () {
      _fadeTimer = null;
      _fadeWait = null;
      wait.complete();
    });
    return wait.future;
  }

  Future<void> _scheduleMenu(int generation) async {
    if (!_current(generation) || !_isMenu(_wanted)) return;
    final deck = _decks[_active];
    final duration = await deck.player.getDuration();
    if (!_current(generation)) return;
    final position = await deck.player.getCurrentPosition() ?? Duration.zero;
    if (!_current(generation)) return;
    // Measured approved-file durations are a fallback for missing native metadata.
    final length = duration ??
        Duration(milliseconds: deck.asset == menuA ? 116428 : 144300);
    final remaining = length - position - fadeDuration;
    _deadline?.cancel();
    _deadline = Timer(remaining.isNegative ? Duration.zero : remaining,
        () => _advanceMenu(generation));
    // Load the next menu source while the active song is playing, not at its end.
    await _load(
        _decks[1 - _active], deck.asset == menuA ? menuB : menuA, generation);
  }

  void _advanceMenu(int generation) {
    if (!_current(generation) || !_isMenu(_wanted) || _advancing) return;
    _advancing = true;
    _deadline?.cancel();
    _deadline = null;
    _menuAsset = _wanted == menuA ? menuB : menuA;
    _wanted = _menuAsset;
    // New generation also makes a duplicate completion/deadline callback inert.
    final next = ++_generation;
    unawaited(_enqueue(() async {
      try {
        await _reconcile(next);
      } finally {
        if (next == _generation) _advancing = false;
      }
    }));
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _invalidate();
    // Pending native setup returns into a generation check, then releases its
    // queue slot. No deck is disposed while it is still being configured.
    await _queue;
    for (final deck in _decks) {
      await deck.completion?.cancel();
      await deck.player.dispose();
    }
  }
}

class _Deck {
  _Deck(this.player);
  final AudioPlayer player;
  StreamSubscription<void>? completion;
  String? asset;
  bool playing = false;
  double gain = 0;
}
