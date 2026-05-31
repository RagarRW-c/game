import 'package:flutter/material.dart';

import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';

class BoosterShopScreen extends StatefulWidget {
  const BoosterShopScreen({super.key});

  static const route = '/booster-shop';

  @override
  State<BoosterShopScreen> createState() => _BoosterShopScreenState();
}

class _BoosterShopScreenState extends State<BoosterShopScreen> {
  static const _undoPrice = 100;
  static const _hintPrice = 150;
  static const _shufflePrice = 150;
  static const _packPrice = 300;

  int _coins = 0;
  int _undoBoosters = 0;
  int _hintBoosters = 0;
  int _shuffleBoosters = 0;
  bool _loading = true;
  bool _buying = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadShopState();
  }

  Future<void> _loadShopState() async {
    final repository = AppScope.of(context).progressRepository;
    final coins = await repository.coins();
    final undo = await repository.extraUndoBoosters();
    final hint = await repository.extraHintBoosters();
    final shuffle = await repository.extraShuffleBoosters();
    if (!mounted) return;
    setState(() {
      _coins = coins;
      _undoBoosters = undo;
      _hintBoosters = hint;
      _shuffleBoosters = shuffle;
      _loading = false;
    });
  }

  Future<void> _buy({
    required int price,
    int undo = 0,
    int hint = 0,
    int shuffle = 0,
  }) async {
    if (_buying) return;
    setState(() => _buying = true);

    final repository = AppScope.of(context).progressRepository;
    final paid = await repository.spendCoins(price);

    if (!paid) {
      if (!mounted) return;
      setState(() => _buying = false);
      _showNotEnoughCoins();
      return;
    }

    if (undo > 0) await repository.addExtraUndoBoosters(undo);
    if (hint > 0) await repository.addExtraHintBoosters(hint);
    if (shuffle > 0) await repository.addExtraShuffleBoosters(shuffle);
    if (!mounted) return;

    setState(() {
      _coins -= price;
      _undoBoosters += undo;
      _hintBoosters += hint;
      _shuffleBoosters += shuffle;
      _buying = false;
    });
  }

  void _showNotEnoughCoins() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Not enough coins')),
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
                title: 'Booster Shop',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: GameBadge(
                  icon: Icons.monetization_on_rounded,
                  gradient: GameGradients.badge,
                  child: Text(
                    '$_coins',
                    style: GameTextStyles.button.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(GameSpacing.lg),
                        children: [
                          _InventoryPanel(
                            undo: _undoBoosters,
                            hint: _hintBoosters,
                            shuffle: _shuffleBoosters,
                          ),
                          const SizedBox(height: GameSpacing.lg),
                          _ShopItemCard(
                            title: '+1 Undo booster',
                            subtitle: 'Restore one selected tile',
                            icon: Icons.arrow_back_rounded,
                            price: _undoPrice,
                            onBuy: _buying
                                ? null
                                : () => _buy(price: _undoPrice, undo: 1),
                          ),
                          const SizedBox(height: GameSpacing.md),
                          _ShopItemCard(
                            title: '+1 Hint booster',
                            subtitle: 'Find a helpful match',
                            icon: Icons.pets_rounded,
                            price: _hintPrice,
                            onBuy: _buying
                                ? null
                                : () => _buy(price: _hintPrice, hint: 1),
                          ),
                          const SizedBox(height: GameSpacing.md),
                          _ShopItemCard(
                            title: '+1 Shuffle booster',
                            subtitle: 'Refresh board tile types',
                            icon: Icons.air_rounded,
                            price: _shufflePrice,
                            onBuy: _buying
                                ? null
                                : () => _buy(price: _shufflePrice, shuffle: 1),
                          ),
                          const SizedBox(height: GameSpacing.md),
                          _ShopItemCard(
                            title: 'Booster Pack',
                            subtitle: '+1 Undo, +1 Hint, +1 Shuffle',
                            icon: Icons.auto_awesome_rounded,
                            price: _packPrice,
                            featured: true,
                            onBuy: _buying
                                ? null
                                : () => _buy(
                                      price: _packPrice,
                                      undo: 1,
                                      hint: 1,
                                      shuffle: 1,
                                    ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({
    required this.undo,
    required this.hint,
    required this.shuffle,
  });

  final int undo;
  final int hint;
  final int shuffle;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      padding: const EdgeInsets.all(GameSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inventory', style: GameTextStyles.h2.copyWith(fontSize: 24)),
          const SizedBox(height: GameSpacing.md),
          Row(
            children: [
              Expanded(
                child: _InventoryBadge(
                  icon: Icons.arrow_back_rounded,
                  label: 'Undo',
                  count: undo,
                ),
              ),
              const SizedBox(width: GameSpacing.sm),
              Expanded(
                child: _InventoryBadge(
                  icon: Icons.pets_rounded,
                  label: 'Hint',
                  count: hint,
                ),
              ),
              const SizedBox(width: GameSpacing.sm),
              Expanded(
                child: _InventoryBadge(
                  icon: Icons.air_rounded,
                  label: 'Shuffle',
                  count: shuffle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryBadge extends StatelessWidget {
  const _InventoryBadge({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GameSpacing.md),
      decoration: BoxDecoration(
        gradient: GameGradients.darkBadge,
        borderRadius: GameRadius.largeRadius,
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: GameShadows.light(),
      ),
      child: Column(
        children: [
          Icon(icon, color: GameColors.accentGold, size: 28),
          const SizedBox(height: GameSpacing.xs),
          Text(
            'x$count',
            style: GameTextStyles.button.copyWith(color: Colors.white),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameTextStyles.caption.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  const _ShopItemCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.price,
    required this.onBuy,
    this.featured = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int price;
  final VoidCallback? onBuy;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      padding: const EdgeInsets.all(GameSpacing.lg),
      shadow: featured
          ? GameShadows.glow(GameColors.accentGold)
          : GameShadows.medium(),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient:
                  featured ? GameGradients.badge : GameGradients.primaryButton,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: GameShadows.light(),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: GameSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GameTextStyles.body.copyWith(fontSize: 18)),
                const SizedBox(height: GameSpacing.xs),
                Text(subtitle, style: GameTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: GameSpacing.md),
          SizedBox(
            width: 104,
            child: GameButton(
              label: '$price',
              icon: Icons.monetization_on_rounded,
              onPressed: onBuy,
              variant:
                  featured ? GameButtonVariant.gold : GameButtonVariant.primary,
              height: 48,
            ),
          ),
        ],
      ),
    );
  }
}
