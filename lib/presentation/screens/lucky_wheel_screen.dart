import 'dart:math';

import 'package:flutter/material.dart';

import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';

class LuckyWheelScreen extends StatefulWidget {
  const LuckyWheelScreen({super.key});

  static const route = '/lucky-wheel';

  @override
  State<LuckyWheelScreen> createState() => _LuckyWheelScreenState();
}

class _LuckyWheelScreenState extends State<LuckyWheelScreen>
    with SingleTickerProviderStateMixin {
  static const _rewards = <_WheelReward>[
    _WheelReward.coins(30),
    _WheelReward.coins(50),
    _WheelReward.coins(75),
    _WheelReward.coins(100),
    _WheelReward.coins(150),
    _WheelReward.coins(200),
    _WheelReward.booster(_WheelBooster.hint),
    _WheelReward.booster(_WheelBooster.shuffle),
    _WheelReward.booster(_WheelBooster.undo),
  ];

  late final AnimationController _controller;
  late Animation<double> _rotation;
  bool _available = false;
  bool _loading = true;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GameDurations.slow,
    );
    _rotation = const AlwaysStoppedAnimation<double>(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAvailability());
  }

  Future<void> _loadAvailability() async {
    debugPrint('LuckyWheel init start');
    var canSpin = true;
    try {
      final status = await AppScope.of(context)
          .progressRepository
          .dailySpinStatus(DateTime.now());
      debugPrint('LuckyWheel prefs loaded');
      debugPrint('LuckyWheel lastSpinDate=${status.lastSpinDate}');
      debugPrint('LuckyWheel canSpin=${status.canSpin}');
      canSpin = status.canSpin;
    } catch (error, stackTrace) {
      debugPrint('LuckyWheel error: $error');
      debugPrint('$stackTrace');
    } finally {
      debugPrint('LuckyWheel init complete');
      if (mounted) {
        setState(() {
          _available = canSpin;
          _loading = false;
        });
      }
    }
  }

  Future<void> _spin() async {
    if (_spinning || !_available) return;
    final repository = AppScope.of(context).progressRepository;
    setState(() => _spinning = true);
    final canSpin = await repository.dailySpinAvailable(DateTime.now());
    if (!mounted) return;
    if (!canSpin) {
      setState(() {
        _available = false;
        _spinning = false;
      });
      return;
    }

    final random = Random();
    final selectedIndex = random.nextInt(_rewards.length);
    final fullTurns = 4 + random.nextInt(2);
    final segmentTurn = selectedIndex / _rewards.length;
    final target = fullTurns + segmentTurn;

    setState(() {
      _rotation = Tween<double>(
        begin: 0,
        end: target,
      ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    });

    _controller
      ..reset()
      ..forward();
    await _controller.forward(from: 0);
    if (!mounted) return;

    final reward = _rewards[selectedIndex];
    await _applyReward(reward);
    await repository.markDailySpinClaimed(DateTime.now());
    await repository.recordDailyLuckyWheelUsed();
    if (!mounted) return;

    setState(() {
      _available = false;
      _spinning = false;
    });
    await _showRewardDialog(reward);
  }

  Future<void> _applyReward(_WheelReward reward) async {
    final repository = AppScope.of(context).progressRepository;
    if (reward.coins != null) {
      await repository.addCoins(reward.coins!);
      return;
    }
    switch (reward.booster) {
      case _WheelBooster.hint:
        await repository.addExtraHintBoosters(1);
      case _WheelBooster.shuffle:
        await repository.addExtraShuffleBoosters(1);
      case _WheelBooster.undo:
        await repository.addExtraUndoBoosters(1);
      case null:
        break;
    }
  }

  Future<void> _showRewardDialog(_WheelReward reward) async {
    await showDialog<void>(
      context: context,
      builder: (_) => GameDialogFrame(
        title: 'Reward',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(reward.icon, color: GameColors.accentGold, size: 72),
            const SizedBox(height: GameSpacing.md),
            Text(reward.label, style: GameTextStyles.h2),
            const SizedBox(height: GameSpacing.xl),
            GameButton(
              label: 'Nice',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(),
              variant: GameButtonVariant.success,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(
                title: 'Lucky Wheel',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Center(
                  child: GameCard(
                    margin: const EdgeInsets.all(GameSpacing.lg),
                    child: _loading
                        ? const _WheelLoadingState()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _rotation,
                                    builder: (context, child) {
                                      return Transform.rotate(
                                        angle: _rotation.value * 2 * pi,
                                        child: child,
                                      );
                                    },
                                    child: const _Wheel(rewards: _rewards),
                                  ),
                                  const Positioned(
                                    top: 0,
                                    child: Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: GameColors.dangerRed,
                                      size: 54,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: GameSpacing.xl),
                              Text(
                                _available
                                    ? 'Spin once today'
                                    : 'Next spin tomorrow',
                                style: GameTextStyles.body,
                              ),
                              const SizedBox(height: GameSpacing.lg),
                              GameButton(
                                label: _available
                                    ? 'Daily Spin'
                                    : 'Come Back Tomorrow',
                                icon: Icons.casino_rounded,
                                onPressed:
                                    _available && !_spinning ? _spin : null,
                                variant: GameButtonVariant.gold,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

class _Wheel extends StatelessWidget {
  const _Wheel({required this.rewards});

  final List<_WheelReward> rewards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var index = 0; index < rewards.length; index++)
            Transform.rotate(
              angle: (2 * pi / rewards.length) * index,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 86,
                  height: 126,
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: GameSpacing.md),
                  decoration: BoxDecoration(
                    color: _segmentColor(index),
                    borderRadius: GameRadius.largeRadius,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: GameShadows.light(),
                  ),
                  child: Transform.rotate(
                    angle: -(2 * pi / rewards.length) * index,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(rewards[index].icon,
                            color: Colors.white, size: 24),
                        const SizedBox(height: GameSpacing.xs),
                        Text(
                          rewards[index].shortLabel,
                          textAlign: TextAlign.center,
                          style: GameTextStyles.caption.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: GameGradients.badge,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: GameShadows.medium(GameColors.accentGold),
            ),
            child: const Icon(
              Icons.casino_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  Color _segmentColor(int index) {
    const colors = <Color>[
      GameColors.primaryBlue,
      GameColors.secondaryPurple,
      GameColors.successGreen,
      GameColors.warningOrange,
      GameColors.dangerRed,
      GameColors.accentGoldDark,
    ];
    return colors[index % colors.length];
  }
}

enum _WheelBooster { hint, shuffle, undo }

class _WheelReward {
  const _WheelReward.coins(this.coins) : booster = null;
  const _WheelReward.booster(this.booster) : coins = null;

  final int? coins;
  final _WheelBooster? booster;

  String get label {
    if (coins != null) return '+$coins coins';
    return '+1 ${_boosterName(booster!)} booster';
  }

  String get shortLabel {
    if (coins != null) return '$coins';
    return '+1 ${_boosterName(booster!)}';
  }

  IconData get icon {
    if (coins != null) return Icons.monetization_on_rounded;
    switch (booster!) {
      case _WheelBooster.hint:
        return Icons.pets_rounded;
      case _WheelBooster.shuffle:
        return Icons.air_rounded;
      case _WheelBooster.undo:
        return Icons.arrow_back_rounded;
    }
  }

  String _boosterName(_WheelBooster booster) {
    switch (booster) {
      case _WheelBooster.hint:
        return 'Hint';
      case _WheelBooster.shuffle:
        return 'Shuffle';
      case _WheelBooster.undo:
        return 'Undo';
    }
  }
}
