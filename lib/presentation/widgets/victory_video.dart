import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_flavor.dart';
import '../../main.dart';

typedef VictoryVideoControllerFactory = VideoPlayerController Function();

/// Looping, presentation-only celebration. It cannot claim rewards or navigate.
/// Its lifetime belongs to the result route, never a shared/global player.
class VictoryVideo extends StatefulWidget {
  const VictoryVideo({
    super.key,
    required this.fallback,
    required this.maxHeight,
    this.controllerFactory,
    this.musicPreference,
  });

  // Playback derivative of the approved original; H.264 Main / 4:2:0 is
  // supported by Android decoders. The original 4:4:4 master stays unchanged.
  static const asset = 'assets/video/triotrek/cat_victory_android_audio.mp4';
  static const initializationTimeout = Duration(seconds: 8);
  final Widget fallback;
  final double maxHeight;

  /// Uses the app music preference in production; injectable without audio players.
  final ValueListenable<bool>? musicPreference;

  /// Injection keeps lifecycle tests on the actual VideoPlayerController API
  /// with a fake native platform, rather than waiting for a real decoder.
  @visibleForTesting
  final VictoryVideoControllerFactory? controllerFactory;

  static VideoPlayerController createController() =>
      VideoPlayerController.asset(
        asset,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          // This widget owns lifecycle AND route visibility. Disable the
          // plugin's independent resume observer so it cannot resume a video
          // behind another route. _syncPlayback explicitly pauses backgrounding.
          allowBackgroundPlayback: true,
        ),
      );

  @override
  State<VictoryVideo> createState() => _VictoryVideoState();
}

class _VictoryVideoState extends State<VictoryVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Animation<double>? _routeAnimation;
  Future<void> _operations = Future<void>.value();
  final Completer<void> _cancelInitialization = Completer<void>();
  Timer? _initializationTimer;
  bool _ready = false;
  bool _failed = false;
  ValueListenable<bool>? _musicPreference;
  bool _reducedMotion = false;
  bool _visible = false;
  bool _foreground = true;
  final Set<String> _diagnostics = {};

  void _diagnostic(String event) {
    // Fixed categories only: no platform error messages, paths or user data.
    // At most ten unique messages per presentation, and none in PROD.
    if (AppFlavorConfig.isDev &&
        _diagnostics.length < 10 &&
        _diagnostics.add(event)) {
      debugPrint('VictoryVideo: $event');
    }
  }

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    final route = ModalRoute.of(context);
    _visible = TickerMode.of(context) && (route?.isCurrent ?? true);
    if (_routeAnimation != route?.animation) {
      _routeAnimation?.removeStatusListener(_routeStatusChanged);
      _routeAnimation = route?.animation;
      _routeAnimation?.addStatusListener(_routeStatusChanged);
    }
    // Native video is unavailable on Windows/Linux desktop. Keep the existing
    // trophy there; Android uses the asset decoder. No test-binding detection.
    final supported =
        kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    _bindMusicPreference(supported || widget.controllerFactory != null);
    if (_reducedMotion) _diagnostic('reduced_motion');
    if (!supported && widget.controllerFactory == null) {
      _diagnostic('unsupported_platform');
    }
    if (!_reducedMotion &&
        !_failed &&
        _controller == null &&
        (supported || widget.controllerFactory != null)) {
      _start();
    }
    _syncPlayback();
  }

  @override
  void didUpdateWidget(VictoryVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.musicPreference != widget.musicPreference) {
      _bindMusicPreference(_controller != null);
      _syncPlayback();
    }
  }

  void _bindMusicPreference(bool supported) {
    final preference = widget.musicPreference ??
        (supported
            ? context
                .dependOnInheritedWidgetOfExactType<AppScope>()
                ?.audioService
                .musicPreference
            : null);
    if (identical(preference, _musicPreference)) return;
    _musicPreference?.removeListener(_syncPlayback);
    _musicPreference = preference;
    _musicPreference?.addListener(_syncPlayback);
  }

  void _start() {
    try {
      final controller =
          (widget.controllerFactory ?? VictoryVideo.createController)();
      _controller = controller;
      _diagnostic('initializing');
      controller.addListener(_videoChanged);
      unawaited(_initialize(controller));
    } catch (_) {
      // didChangeDependencies is already followed by build.
      _failed = true;
      _diagnostic('creation_error');
    }
  }

  Future<void> _initialize(VideoPlayerController controller) async {
    try {
      // Start muted. Apply the latest music preference before the first play,
      // after initialization, so muted players never leak an audible frame.
      await controller.setVolume(0);
      if (!mounted || !identical(controller, _controller)) return;
      _initializationTimer = Timer(VictoryVideo.initializationTimeout, () {
        if (mounted && identical(controller, _controller)) _fail('timeout');
      });
      await Future.any<void>([
        controller.initialize(),
        _cancelInitialization.future,
      ]);
      _initializationTimer?.cancel();
      if (!mounted || !identical(controller, _controller)) return;
      await controller.setLooping(true);
      if (!mounted || !identical(controller, _controller)) return;
      if (controller.value.hasError || controller.value.size.isEmpty) {
        _fail('invalid_video');
        return;
      }
      setState(() => _ready = true);
      _diagnostic('ready');
      _syncPlayback();
    } catch (_) {
      if (mounted && identical(controller, _controller))
        _fail('initialization_error');
    }
  }

  void _videoChanged() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    if (controller.value.hasError) {
      _fail('decoder_error');
    }
  }

  void _routeStatusChanged(AnimationStatus status) => _syncPlayback();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  void _syncPlayback() {
    final controller = _controller;
    if (!_ready || controller == null || _failed) return;
    // Re-read desired state when commands execute. Rapid pause/resume changes
    // cannot enqueue a stale play behind a newer pause or route disposal.
    _operations = _operations.then((_) async {
      if (!mounted || !identical(controller, _controller)) return;
      final play = _foreground &&
          _visible &&
          !_reducedMotion &&
          _routeAnimation?.status != AnimationStatus.reverse;
      final volume = (_musicPreference?.value ?? false) ? 1.0 : 0.0;
      if (controller.value.volume != volume) {
        await controller.setVolume(volume);
        if (!mounted || !identical(controller, _controller)) return;
        // A lifecycle/preference change while awaiting a platform reply queues
        // a fresh command. Never start from this obsolete permission snapshot.
        _syncPlayback();
        return;
      }
      if (play && !controller.value.isPlaying) {
        _diagnostic('playing');
        await controller.play();
      } else if (!play && controller.value.isPlaying) {
        await controller.pause();
      }
    }).catchError((Object _) {
      if (mounted && identical(controller, _controller))
        _fail('playback_error');
    });
  }

  void _fail(String reason) {
    if (_failed) return;
    _diagnostic(reason);
    setState(() {
      _failed = true;
      _ready = false;
    });
    _release();
  }

  void _release() {
    _initializationTimer?.cancel();
    if (!_cancelInitialization.isCompleted) _cancelInitialization.complete();
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    controller.removeListener(_videoChanged);
    // Dispose immediately, not behind initialization or the playback queue.
    // The plugin releases a pending native creation when it eventually returns.
    unawaited(controller.dispose().catchError((Object _) {
      _diagnostic('dispose_error');
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _musicPreference?.removeListener(_syncPlayback);
    _routeAnimation?.removeStatusListener(_routeStatusChanged);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return LayoutBuilder(builder: (context, constraints) {
      final ratio =
          _ready && controller != null ? controller.value.aspectRatio : 9 / 16;
      final height =
          widget.maxHeight.clamp(0.0, constraints.maxWidth / ratio).toDouble();
      return Center(
          child: SizedBox(
        key: const ValueKey('victory_cat_frame'),
        height: height,
        width: height * ratio,
        child: _ready && !_reducedMotion && !_failed && controller != null
            ? Semantics(
                label: 'Dancing cat celebration',
                image: true,
                child: ExcludeSemantics(child: VideoPlayer(controller)))
            : Center(
                child:
                    FittedBox(fit: BoxFit.scaleDown, child: widget.fallback)),
      ));
    });
  }
}
