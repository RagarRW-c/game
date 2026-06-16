import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';

class TreasureChestsScreen extends StatefulWidget {
  const TreasureChestsScreen({super.key});

  static const route = '/treasure-chests';

  @override
  State<TreasureChestsScreen> createState() => _TreasureChestsScreenState();
}

class _TreasureChestsScreenState extends State<TreasureChestsScreen> {
  late Future<List<TreasureChest>> _chestsFuture;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chestsFuture = AppScope.of(context).progressRepository.treasureChests();
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _chestsFuture = AppScope.of(context).progressRepository.treasureChests();
    });
  }

  Future<void> _openChest(TreasureChest chest) async {
    final repository = AppScope.of(context).progressRepository;
    final reward = await repository.openTreasureChest(chest.id);
    if (!mounted || reward == null) return;
    unawaited(AppScope.of(context).audioService.playChestOpen());
    _reload();
    await _showRewardDialog(chest, reward);
  }

  Future<void> _openNow(TreasureChest chest) async {
    final repository = AppScope.of(context).progressRepository;
    final result = await repository.openTreasureChestNow(chest.id);
    if (!mounted) return;
    if (result.notEnoughCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins')),
      );
      return;
    }
    final reward = result.reward;
    if (reward == null) return;
    unawaited(AppScope.of(context).audioService.playChestOpen());
    _reload();
    await _showRewardDialog(chest, reward);
  }

  Future<void> _showRewardDialog(
    TreasureChest chest,
    ChestOpenReward reward,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ChestRewardDialog(chest: chest, reward: reward),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(
                title: 'Treasure Chests',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: FutureBuilder<List<TreasureChest>>(
                  future: _chestsFuture,
                  builder: (context, snapshot) {
                    final chests = snapshot.data ?? const <TreasureChest>[];
                    return ListView(
                      padding: const EdgeInsets.all(GameSpacing.lg),
                      children: [
                        for (var index = 0; index < 3; index++) ...[
                          _ChestSlotCard(
                            chest: index < chests.length ? chests[index] : null,
                            onOpen: _openChest,
                            onOpenNow: _openNow,
                          ),
                          const SizedBox(height: GameSpacing.md),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChestSlotCard extends StatelessWidget {
  const _ChestSlotCard({
    required this.chest,
    required this.onOpen,
    required this.onOpenNow,
  });

  final TreasureChest? chest;
  final Future<void> Function(TreasureChest chest) onOpen;
  final Future<void> Function(TreasureChest chest) onOpenNow;

  @override
  Widget build(BuildContext context) {
    final value = chest;
    if (value == null) {
      return GameCard(
        shadow: GameShadows.light(),
        borderColor: Colors.white70,
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: GameGradients.disabled,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: GameShadows.light(),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(width: GameSpacing.md),
            Expanded(
              child: Text(
                'Empty chest slot',
                style: GameTextStyles.h2.copyWith(fontSize: 22),
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final unlocked = value.isUnlocked(now);
    final accent = _accentForType(value.type);
    return GameCard(
      borderColor: accent,
      gradient: _panelGradientForType(value.type),
      shadow: value.type == TreasureChestType.gold
          ? GameShadows.glow(GameColors.accentGold)
          : GameShadows.medium(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: _gradientForType(value.type),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    ...GameShadows.medium(accent),
                    if (value.type == TreasureChestType.gold)
                      ...GameShadows.glow(GameColors.accentGold),
                  ],
                ),
                child: Icon(
                  _iconForType(value.type),
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(width: GameSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.title,
                      style: GameTextStyles.h2.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: GameSpacing.xs),
                    Text(
                      unlocked
                          ? 'Ready to open'
                          : _formatDuration(value.remaining(now)),
                      style: GameTextStyles.body,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 104,
                child: GameButton(
                  label: unlocked ? 'Open' : 'Locked',
                  icon: unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  onPressed: unlocked ? () => onOpen(value) : null,
                  variant: unlocked
                      ? GameButtonVariant.gold
                      : GameButtonVariant.secondary,
                  height: 50,
                ),
              ),
            ],
          ),
          const SizedBox(height: GameSpacing.lg),
          _RewardPreview(type: value.type),
          if (!unlocked) ...[
            const SizedBox(height: GameSpacing.lg),
            GameButton(
              label: 'Open Now ${_instantCostForType(value.type)}',
              icon: Icons.monetization_on_rounded,
              onPressed: () => onOpenNow(value),
              variant: GameButtonVariant.gold,
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardPreview extends StatelessWidget {
  const _RewardPreview({required this.type});

  final TreasureChestType type;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      padding: const EdgeInsets.all(GameSpacing.md),
      shadow: GameShadows.light(),
      borderColor: Colors.white70,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Possible rewards',
            style: GameTextStyles.caption.copyWith(color: GameColors.ink),
          ),
          const SizedBox(height: GameSpacing.sm),
          Wrap(
            spacing: GameSpacing.sm,
            runSpacing: GameSpacing.sm,
            children: _previewItems(type)
                .map(
                  (item) => GameBadge(
                    icon: item.icon,
                    gradient: GameGradients.darkBadge,
                    child: Text(
                      item.label,
                      style:
                          GameTextStyles.caption.copyWith(color: Colors.white),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ChestRewardDialog extends StatelessWidget {
  const _ChestRewardDialog({
    required this.chest,
    required this.reward,
  });

  final TreasureChest chest;
  final ChestOpenReward reward;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.88, end: 1),
      duration: GameDurations.normal,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Opacity(
          opacity: scale.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: GameDialogFrame(
        title: 'Treasure Chest Opened',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: _gradientForType(chest.type),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: GameShadows.glow(_accentForType(chest.type)),
              ),
              child: Icon(
                _iconForType(chest.type),
                color: Colors.white,
                size: 52,
              ),
            ),
            const SizedBox(height: GameSpacing.lg),
            const Text('You got:', style: GameTextStyles.body),
            const SizedBox(height: GameSpacing.lg),
            _RewardLine(
              icon: Icons.monetization_on_rounded,
              label: '+${reward.coins} Coins',
              color: GameColors.accentGold,
            ),
            if (reward.undo > 0)
              const _RewardLine(
                icon: Icons.arrow_back_rounded,
                label: '+1 Undo',
                color: GameColors.warningOrange,
              ),
            if (reward.hint > 0)
              const _RewardLine(
                icon: Icons.pets_rounded,
                label: '+1 Hint',
                color: GameColors.secondaryPurple,
              ),
            if (reward.shuffle > 0)
              const _RewardLine(
                icon: Icons.air_rounded,
                label: '+1 Shuffle',
                color: GameColors.primaryBlueLight,
              ),
            const SizedBox(height: GameSpacing.xl),
            GameButton(
              label: 'Collect',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(),
              variant: GameButtonVariant.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardLine extends StatelessWidget {
  const _RewardLine({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GameSpacing.sm),
      child: GameCard(
        padding: const EdgeInsets.all(GameSpacing.md),
        shadow: GameShadows.light(color),
        borderColor: color,
        child: Row(
          children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(width: GameSpacing.md),
            Expanded(
              child: Text(
                label,
                style: GameTextStyles.h2.copyWith(fontSize: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewItem {
  const _PreviewItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

List<_PreviewItem> _previewItems(TreasureChestType type) {
  switch (type) {
    case TreasureChestType.wood:
      return const [
        _PreviewItem(Icons.monetization_on_rounded, '30-80 Coins'),
        _PreviewItem(Icons.arrow_back_rounded, 'Chance Undo'),
      ];
    case TreasureChestType.silver:
      return const [
        _PreviewItem(Icons.monetization_on_rounded, '80-180 Coins'),
        _PreviewItem(Icons.pets_rounded, 'Hint'),
        _PreviewItem(Icons.air_rounded, 'Shuffle'),
      ];
    case TreasureChestType.gold:
      return const [
        _PreviewItem(Icons.monetization_on_rounded, '200-500 Coins'),
        _PreviewItem(Icons.pets_rounded, 'Hint'),
        _PreviewItem(Icons.air_rounded, 'Shuffle'),
        _PreviewItem(Icons.arrow_back_rounded, 'Undo'),
      ];
  }
}

IconData _iconForType(TreasureChestType type) {
  switch (type) {
    case TreasureChestType.wood:
      return Icons.inventory_2_rounded;
    case TreasureChestType.silver:
      return Icons.card_giftcard_rounded;
    case TreasureChestType.gold:
      return Icons.workspace_premium_rounded;
  }
}

Color _accentForType(TreasureChestType type) {
  switch (type) {
    case TreasureChestType.wood:
      return const Color(0xFFB66A2C);
    case TreasureChestType.silver:
      return GameColors.primaryBlueLight;
    case TreasureChestType.gold:
      return GameColors.accentGold;
  }
}

Gradient _gradientForType(TreasureChestType type) {
  switch (type) {
    case TreasureChestType.wood:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD79A50), Color(0xFF8A4F24)],
      );
    case TreasureChestType.silver:
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE8F4FF), Color(0xFF5FA8FF)],
      );
    case TreasureChestType.gold:
      return GameGradients.badge;
  }
}

Gradient _panelGradientForType(TreasureChestType type) {
  switch (type) {
    case TreasureChestType.wood:
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF5DF), Color(0xFFFFD8A8)],
      );
    case TreasureChestType.silver:
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFEAF8FF)],
      );
    case TreasureChestType.gold:
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF7D7), Color(0xFFFFD166)],
      );
  }
}

int _instantCostForType(TreasureChestType type) {
  switch (type) {
    case TreasureChestType.wood:
      return 50;
    case TreasureChestType.silver:
      return 100;
    case TreasureChestType.gold:
      return 200;
  }
}

String _formatDuration(Duration duration) {
  if (duration.inSeconds <= 0) return 'Ready to open';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours h $minutes min';
  if (duration.inMinutes > 0) return '$minutes:$seconds remaining';
  return '00:$seconds remaining';
}
