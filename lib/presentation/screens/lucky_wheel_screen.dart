import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/audio_service.dart';
import '../../domain/daily_wheel_reward.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/achievement_popup.dart';
import '../widgets/game_ui.dart';
import '../widgets/lucky_wheel_art.dart';
import '../widgets/wheel_motion.dart';
import '../widgets/wheel_reward_effects.dart';

class LuckyWheelScreen extends StatefulWidget {
  const LuckyWheelScreen({
    super.key,
    this.spinDuration = const Duration(milliseconds: 4600),
    this.random,
  });

  static const route = '/lucky-wheel';
  final Duration spinDuration;
  // Injection controls selection in deterministic widget tests, never the odds.
  final Random? random;

  @override
  State<LuckyWheelScreen> createState() => _LuckyWheelScreenState();
}

class _LuckyWheelScreenState extends State<LuckyWheelScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _rewards = DailyWheelReward.values;
  late final AnimationController _controller;
  late final AnimationController _celebration;
  late GameAudioService _audio;
  final _layerKey = GlobalKey();
  final _wheelArtKey = GlobalKey();
  final _counterKey = GlobalKey();
  final _segmentKeys = List<GlobalKey>.generate(
      DailyWheelReward.values.length, (_) => GlobalKey());
  late final Widget _wheelArtwork = RepaintBoundary(
      child: LuckyWheelFace(
          rewards: _rewards, artKey: _wheelArtKey, segmentKeys: _segmentKeys));
  bool _available = false;
  bool _loading = true;
  bool _spinning = false;
  bool _settled = false;
  bool _reducedMotion = false;
  bool _foreground = true;
  bool _presentationInterrupted = false;
  bool _collectedSound = false;
  String? _error;
  int _coins = 0;
  int _boundary = 0;
  int _lastTickMicros = -100000;
  int _lastCrossingMicros = -100000;
  double _fromTurns = 0;
  double _targetTurns = 0;
  DailyWheelClaim? _claim;
  int? _winningSegment;

  double get _turns =>
      _fromTurns +
      (_targetTurns - _fromTurns) *
          const WheelSpinCurve().transform(_controller.value);
  bool get _visible =>
      mounted && _foreground && (ModalRoute.of(context)?.isCurrent ?? true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller =
        AnimationController(vsync: this, duration: widget.spinDuration)
          ..addListener(_onRotation);
    _celebration = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_onCelebration);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadAvailability());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audio = AppScope.of(context).audioService;
    _reducedMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    // The wheel's own reward dialog opens after _spinning becomes false. Its
    // appearance must not invalidate reduced-motion cues still being prepared.
    if (_spinning && !(ModalRoute.of(context)?.isCurrent ?? true)) {
      _audio.cancelPendingWheelFeedback();
      _presentationInterrupted = true;
      _finishMotion();
    }
    if (_reducedMotion) _finishMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Finish presentation only. Never cancel or repeat a repository claim.
    if (!_foreground) {
      _audio.cancelPendingWheelFeedback();
      if (_spinning) _presentationInterrupted = true;
      _finishMotion();
    }
  }

  void _finishMotion() {
    if (_controller.isAnimating) _controller.value = 1;
    if (_celebration.isAnimating) _celebration.value = 1;
  }

  void _cancelUnconfirmedMotion() {
    final current = _turns;
    _controller.stop(canceled: true);
    _fromTurns = _targetTurns = current;
  }

  Future<void> _sound(Future<void> Function() play) async {
    if (!_visible || _presentationInterrupted) return;
    try {
      await play();
    } catch (_) {
      // Optional audio must never turn a committed reward into a failed claim.
    }
  }

  void _onRotation() {
    if (!_controller.isAnimating || !_visible || _reducedMotion) return;
    final crossing = WheelMotion.crossedBoundary(_turns, _rewards.length);
    if (crossing == _boundary) return;
    _boundary = crossing;
    final micros = _controller.lastElapsedDuration?.inMicroseconds ?? 0;
    _lastCrossingMicros = micros;
    // At most one sound per frame and one per 80 ms, no catch-up sound queue.
    if (micros - _lastTickMicros >= 80000) {
      _lastTickMicros = micros;
      unawaited(_sound(_audio.playWheelTick));
    }
  }

  void _onCelebration() {
    if (!_collectedSound && _celebration.value >= .76) {
      _collectedSound = true;
      if (_claim?.reward.coins != null) {
        unawaited(_sound(_audio.playWheelCollection));
      }
    }
  }

  Future<void> _loadAvailability() async {
    final repository = AppScope.of(context).progressRepository;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await repository.dailySpinStatus(DateTime.now());
      final coins = await repository.coins();
      if (!mounted) return;
      setState(() {
        _available = status.canSpin;
        _coins = coins;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _available = false;
        _loading = false;
        _error = 'Could not check your daily spin. Please try again.';
      });
    }
  }

  Future<void> _animate(AnimationController controller) async {
    if (_reducedMotion || !_visible || _presentationInterrupted) {
      controller.value = 1;
      return;
    }
    try {
      await controller.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Disposal cancels only the visual wait; the grant has its own future.
    }
  }

  Future<void> _spin() async {
    if (_spinning || !_available || _loading || !_visible) return;
    final repository = AppScope.of(context).progressRepository;
    final now = DateTime.now();
    final selected = (widget.random ?? Random()).nextInt(_rewards.length);
    _winningSegment = selected;
    _fromTurns = _turns;
    _targetTurns =
        WheelMotion.landingTurns(selected, _rewards.length, from: _fromTurns);
    _boundary = WheelMotion.crossedBoundary(_fromTurns, _rewards.length);
    _lastTickMicros = _lastCrossingMicros = -100000;
    _collectedSound = false;
    _presentationInterrupted = false;
    _controller.duration = widget.spinDuration;
    setState(() {
      _spinning = true;
      _settled = false;
      _error = null;
    });
    // Immediate visual response, with the result chosen before either operation.
    // The grant is not conditional on controller completion, mounted or foreground.
    final motion = _animate(_controller);
    unawaited(_sound(_audio.playLuckyWheelSpin));
    try {
      final claim =
          await repository.claimDailySpin(now, reward: _rewards[selected]);
      if (!mounted) return;
      if (claim == null) {
        _cancelUnconfirmedMotion();
        final balance = await repository.coins();
        if (!mounted) return;
        setState(() {
          _available = false;
          _spinning = false;
          _coins = balance;
        });
        return;
      }
      setState(() {
        _claim = claim;
        _coins = claim.coinsBefore;
        _available = false;
      });
      await motion;
      if (!mounted) return;
      setState(() => _settled = true);
      // STOP B is the complete landing/reveal cue; do not layer the old chime.
      unawaited(_sound(_audio.playWheelStop));
      await _animate(_celebration);
      if (!mounted) return;
      setState(() {
        _spinning = false;
        _coins = claim.coinsAfter;
      });
      if (!_visible || _presentationInterrupted) return;
      final acknowledged = await _showRewardDialog(claim.reward);
      if (!mounted || !_visible) return;
      // Explicit confirmation has its own cue. Keep earned popups, without
      // layering the legacy achievement chime over that button's piano sound.
      await showPendingAchievementPopups(context, repository,
          onPopup: acknowledged == true
              ? null
              : () => _sound(_audio.playAchievementUnlocked));
    } catch (_) {
      if (!mounted) return;
      _cancelUnconfirmedMotion();
      if (_celebration.isAnimating) _celebration.value = 1;
      setState(() {
        _spinning = false;
        _available = false;
        _error = 'Could not confirm your reward. Recheck your saved spin.';
      });
    }
  }

  Future<bool?> _showRewardDialog(DailyWheelReward reward) {
    // Outside the builder so a rebuild cannot reset the rapid-tap guard.
    var acknowledged = false;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => GameDialogFrame(
        title: 'Reward',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GameRewardEmblem(icon: reward.icon),
          const SizedBox(height: GameSpacing.md),
          Text(reward.label, style: GameTextStyles.h2),
          const SizedBox(height: GameSpacing.xl),
          GameButton(
              label: 'Nice',
              icon: Icons.check_rounded,
              onPressed: () {
                if (acknowledged ||
                    !mounted ||
                    !dialogContext.mounted ||
                    !_foreground ||
                    !(ModalRoute.of(dialogContext)?.isCurrent ?? false)) {
                  return;
                }
                acknowledged = true;
                // The dialog is current; the underlying wheel is not. Do
                // not use _sound's wheel-route visibility guard here.
                unawaited(_audio.playWheelRewardOk().catchError((Object _) {
                  // Optional audio must never block dismissal or a reward.
                }));
                Navigator.of(dialogContext).pop(true);
              },
              variant: GameButtonVariant.success),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audio.cancelPendingWheelFeedback();
    _controller.dispose();
    _celebration.dispose();
    super.dispose();
  }

  Widget _counter() => AnimatedBuilder(
        animation: _celebration,
        builder: (context, _) {
          final claim = _claim;
          final t = _reducedMotion
              ? 1.0
              : Curves.easeOutCubic.transform(
                  ((_celebration.value - .70) / .30).clamp(0.0, 1.0));
          final coins = claim == null
              ? _coins
              : (claim.coinsBefore + (claim.coinsAfter - claim.coinsBefore) * t)
                  .round();
          return Semantics(
            label: '$coins coins',
            liveRegion: !_spinning,
            child: ExcludeSemantics(
                child: GameBadge(
              key: _counterKey,
              icon: Icons.monetization_on_rounded,
              child: Text('$coins',
                  key: const ValueKey('wheel_coins'),
                  style: GameTextStyles.caption.copyWith(color: Colors.white)),
            )),
          );
        },
      );

  Widget _header() {
    final showCounter = _spinning || _claim != null;
    // A scaled counter beside the title can leave only a few pixels per line
    // at narrow widths. Give both their full width without shrinking text.
    final stackCounter = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final header = GameHeader(
        title: 'Lucky Wheel',
        onBack: () => Navigator.of(context).maybePop(),
        trailing: showCounter && !stackCounter ? _counter() : null);
    if (!showCounter || !stackCounter) return header;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      header,
      Padding(
          padding: const EdgeInsets.fromLTRB(
              GameSpacing.lg, 0, GameSpacing.lg, GameSpacing.sm),
          child: Align(alignment: Alignment.centerRight, child: _counter())),
    ]);
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _audio.cancelPendingWheelFeedback();
      },
      child: Scaffold(
        body: GameBackground(
            child: SafeArea(
                child: Stack(children: [
          Column(children: [
            _header(),
            Expanded(
                child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                    child: GameCard(
                  margin: const EdgeInsets.all(GameSpacing.lg),
                  child: _loading
                      ? const _WheelLoadingState()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LuckyWheelRibbon(),
                            SizedBox(
                              width: MediaQuery.sizeOf(context).width < 360
                                  ? 240
                                  : 280,
                              height: MediaQuery.sizeOf(context).width < 360
                                  ? 324
                                  : 378,
                              child: FittedBox(
                                  child: SizedBox(
                                width: 280,
                                height: 378,
                                child: Stack(children: [
                                  const Positioned(
                                      top: 298, child: LuckyWheelPedestal()),
                                  Positioned(
                                      top: 35,
                                      child: AnimatedBuilder(
                                          animation: _controller,
                                          builder: (context, child) =>
                                              Transform.rotate(
                                                  key: const ValueKey(
                                                      'wheel_rotation'),
                                                  angle: _turns * 2 * pi,
                                                  child: child),
                                          child: _wheelArtwork)),
                                  Positioned(
                                      left: 116,
                                      top: 0,
                                      child: AnimatedBuilder(
                                        animation: _controller,
                                        child: const LuckyWheelPointer(
                                            key: ValueKey('wheel_pointer')),
                                        builder: (context, child) {
                                          final age = ((_controller
                                                          .lastElapsedDuration
                                                          ?.inMicroseconds ??
                                                      0) -
                                                  _lastCrossingMicros) /
                                              85000;
                                          final pulse =
                                              _controller.isAnimating &&
                                                      !_reducedMotion &&
                                                      _foreground
                                                  ? (1 - age).clamp(0.0, 1.0)
                                                  : 0.0;
                                          return Transform.scale(
                                              scale: 1 + .08 * pulse,
                                              alignment: Alignment.topCenter,
                                              child: child);
                                        },
                                      )),
                                ]),
                              )),
                            ),
                            const SizedBox(height: GameSpacing.xl),
                            Text(
                                _available
                                    ? 'Spin once today'
                                    : 'Next spin tomorrow',
                                style: GameTextStyles.body),
                            if (_settled && _claim != null) ...[
                              const SizedBox(height: GameSpacing.sm),
                              Semantics(
                                  liveRegion: true,
                                  child: Text(_claim!.reward.label,
                                      key: const ValueKey('wheel_result'),
                                      style: GameTextStyles.h2)),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: GameSpacing.sm),
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: GameTextStyles.body),
                            ],
                            const SizedBox(height: GameSpacing.lg),
                            GameButton(
                                label: _error != null
                                    ? 'Try Again'
                                    : _spinning
                                        ? 'Spinning...'
                                        : _available
                                            ? 'Daily Spin'
                                            : 'Come Back Tomorrow',
                                icon: Icons.casino_rounded,
                                onPressed: _spinning
                                    ? null
                                    : _error != null
                                        ? _loadAvailability
                                        : _available
                                            ? _spin
                                            : null,
                                variant: GameButtonVariant.gold),
                            if (MediaQuery.textScalerOf(context).scale(1) >
                                1.3) ...[
                              const SizedBox(height: GameSpacing.xl),
                              Semantics(
                                header: true,
                                child: const Text('Wheel rewards',
                                    style: GameTextStyles.body),
                              ),
                              for (final reward in _rewards)
                                Text(reward.label,
                                    textAlign: TextAlign.center,
                                    style: GameTextStyles.body),
                            ],
                          ],
                        ),
                )),
              )),
            )),
          ]),
          if (_settled &&
              _claim != null &&
              !_reducedMotion &&
              !_celebration.isCompleted)
            Positioned.fill(
                child: IgnorePointer(
                    child: RepaintBoundary(
              child: CustomPaint(
                  key: _layerKey,
                  painter: WheelRewardPainter(
                      animation: _celebration,
                      layerKey: _layerKey,
                      wheelArtKey: _wheelArtKey,
                      winningSegmentKey: _segmentKeys[_winningSegment!],
                      winningIndex: _winningSegment!,
                      counterKey: _counterKey,
                      coins: _claim!.reward.coins != null)),
            ))),
        ]))),
      ));
}

class _WheelLoadingState extends StatelessWidget {
  const _WheelLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: GameSpacing.lg),
        Text('Checking spin...', style: GameTextStyles.body),
      ],
    );
  }
}
