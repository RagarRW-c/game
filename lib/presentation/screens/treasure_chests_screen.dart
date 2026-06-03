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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chestsFuture = AppScope.of(context).progressRepository.treasureChests();
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
    _reload();
    await showDialog<void>(
      context: context,
      builder: (_) => GameDialogFrame(
        title: 'Chest Opened',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForType(chest.type),
                color: GameColors.accentGold, size: 74),
            const SizedBox(height: GameSpacing.md),
            Text('+${reward.coins} coins', style: GameTextStyles.h2),
            const SizedBox(height: GameSpacing.md),
            Text(
              _boosterSummary(reward),
              textAlign: TextAlign.center,
              style: GameTextStyles.body,
            ),
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
  });

  final TreasureChest? chest;
  final Future<void> Function(TreasureChest chest) onOpen;

  @override
  Widget build(BuildContext context) {
    final value = chest;
    if (value == null) {
      return GameCard(
        shadow: GameShadows.light(),
        child: Row(
          children: [
            const Icon(Icons.inventory_2_rounded,
                color: GameColors.mutedInk, size: 54),
            const SizedBox(width: GameSpacing.md),
            Expanded(
              child: Text('Empty chest slot',
                  style: GameTextStyles.h2.copyWith(fontSize: 22)),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final unlocked = value.isUnlocked(now);
    return GameCard(
      borderColor: _accentForType(value.type),
      shadow: GameShadows.glow(_accentForType(value.type)),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: _gradientForType(value.type),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: GameShadows.medium(),
            ),
            child:
                Icon(_iconForType(value.type), color: Colors.white, size: 38),
          ),
          const SizedBox(width: GameSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value.title,
                    style: GameTextStyles.h2.copyWith(fontSize: 23)),
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
            width: 96,
            child: GameButton(
              label: unlocked ? 'Open' : 'Locked',
              icon: unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              onPressed: unlocked ? () => onOpen(value) : null,
              variant: unlocked
                  ? GameButtonVariant.gold
                  : GameButtonVariant.secondary,
              height: 48,
            ),
          ),
        ],
      ),
    );
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
      return GameColors.warningOrange;
    case TreasureChestType.silver:
      return GameColors.primaryBlueLight;
    case TreasureChestType.gold:
      return GameColors.accentGold;
  }
}

Gradient _gradientForType(TreasureChestType type) {
  switch (type) {
    case TreasureChestType.wood:
      return GameGradients.dangerButton;
    case TreasureChestType.silver:
      return GameGradients.primaryButton;
    case TreasureChestType.gold:
      return GameGradients.badge;
  }
}

String _formatDuration(Duration duration) {
  if (duration.inSeconds <= 0) return 'Ready to open';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours h $minutes min';
  return '${duration.inMinutes + 1} min remaining';
}

String _boosterSummary(ChestOpenReward reward) {
  final parts = <String>[
    if (reward.undo > 0) '+${reward.undo} Undo',
    if (reward.hint > 0) '+${reward.hint} Hint',
    if (reward.shuffle > 0) '+${reward.shuffle} Shuffle',
  ];
  if (parts.isEmpty) return 'No booster this time';
  return parts.join('  ');
}
