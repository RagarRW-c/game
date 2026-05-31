import 'package:flutter/material.dart';

import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';
import '../widgets/primary_button.dart';
import 'booster_shop_screen.dart';
import 'lucky_wheel_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  static const route = '/';

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _dailyRewardAvailable = false;
  bool _dailySpinAvailable = false;
  int _coins = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    final repository = AppScope.of(context).progressRepository;
    final coins = await repository.coins();
    final available = await repository.dailyRewardAvailable(DateTime.now());
    final spinAvailable = await repository.dailySpinAvailable(DateTime.now());
    if (!mounted) return;
    setState(() {
      _coins = coins;
      _dailyRewardAvailable = available;
      _dailySpinAvailable = spinAvailable;
    });
  }

  Future<void> _claimDailyReward() async {
    final repository = AppScope.of(context).progressRepository;
    final updated = await repository.claimDailyReward(DateTime.now());
    if (!mounted) return;
    if (updated == null) {
      setState(() => _dailyRewardAvailable = false);
      return;
    }
    setState(() {
      _coins = updated;
      _dailyRewardAvailable = false;
    });
    await showDialog<void>(
      context: context,
      builder: (_) => GameDialogFrame(
        title: 'Daily Reward',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monetization_on_rounded,
              color: GameColors.accentGold,
              size: 72,
            ),
            const SizedBox(height: GameSpacing.md),
            const Text('+100 coins', style: GameTextStyles.h2),
            const SizedBox(height: GameSpacing.xl),
            GameButton(
              label: 'Claimed',
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(GameSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      gradient: GameGradients.badge,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: GameShadows.glow(GameColors.accentGold),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 58,
                    ),
                  ),
                  const SizedBox(height: GameSpacing.lg),
                  const Text(
                    'Triple Tile\nAdventure',
                    textAlign: TextAlign.center,
                    style: GameTextStyles.h1,
                  ),
                  const SizedBox(height: GameSpacing.md),
                  GameBadge(
                    icon: Icons.monetization_on_rounded,
                    gradient: GameGradients.badge,
                    child: Text(
                      '$_coins',
                      style: GameTextStyles.button.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: GameSpacing.xxl),
                  if (_dailyRewardAvailable) ...[
                    PrimaryButton(
                      label: 'Claim Daily Reward',
                      icon: Icons.card_giftcard_rounded,
                      onPressed: _claimDailyReward,
                    ),
                    const SizedBox(height: GameSpacing.md),
                  ],
                  PrimaryButton(
                    label: _dailySpinAvailable
                        ? 'Daily Spin'
                        : 'Next Spin Tomorrow',
                    icon: Icons.casino_rounded,
                    onPressed: _dailySpinAvailable
                        ? () async {
                            await Navigator.pushNamed(
                              context,
                              LuckyWheelScreen.route,
                            );
                            if (mounted) await _loadRewards();
                          }
                        : null,
                  ),
                  const SizedBox(height: GameSpacing.md),
                  PrimaryButton(
                    label: 'Play',
                    icon: Icons.map_rounded,
                    onPressed: () =>
                        Navigator.pushNamed(context, MapScreen.route),
                  ),
                  const SizedBox(height: GameSpacing.md),
                  PrimaryButton(
                    label: 'Booster Shop',
                    icon: Icons.storefront_rounded,
                    onPressed: () async {
                      await Navigator.pushNamed(
                        context,
                        BoosterShopScreen.route,
                      );
                      if (mounted) await _loadRewards();
                    },
                  ),
                  const SizedBox(height: GameSpacing.md),
                  PrimaryButton(
                    label: 'Settings',
                    icon: Icons.settings_rounded,
                    onPressed: () =>
                        Navigator.pushNamed(context, SettingsScreen.route),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
