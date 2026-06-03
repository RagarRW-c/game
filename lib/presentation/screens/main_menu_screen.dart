import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/achievement_popup.dart';
import '../widgets/game_ui.dart';
import '../widgets/primary_button.dart';
import 'achievements_screen.dart';
import 'booster_shop_screen.dart';
import 'collection_book_screen.dart';
import 'daily_challenges_screen.dart';
import 'final_code_screen.dart';
import 'lucky_wheel_screen.dart';
import 'player_profile_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'treasure_chests_screen.dart';
import 'world_selection_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  static const route = '/';

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _dailyRewardAvailable = false;
  bool _dailySpinAvailable = false;
  bool _finalRewardUnlocked = false;
  int _coins = 0;
  bool _loginStreakPromptQueued = false;
  bool _loginStreakPromptShowing = false;

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
    final finalRewardUnlocked = await repository.finalRewardUnlocked();
    final loginStreakStatus =
        await repository.dailyLoginStreakStatus(DateTime.now());
    if (!mounted) return;
    setState(() {
      _coins = coins;
      _dailyRewardAvailable = available;
      _dailySpinAvailable = spinAvailable;
      _finalRewardUnlocked = finalRewardUnlocked;
    });
    _queueLoginStreakPopup(loginStreakStatus);
    await showPendingAchievementPopups(context, repository);
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

  void _queueLoginStreakPopup(DailyLoginStreakStatus status) {
    if (!status.available || _loginStreakPromptQueued) return;
    _loginStreakPromptQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showLoginStreakPopup(status);
    });
  }

  Future<void> _showLoginStreakPopup(DailyLoginStreakStatus status) async {
    if (_loginStreakPromptShowing) return;
    _loginStreakPromptShowing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DailyLoginStreakDialog(
        status: status,
        onClaim: () async {
          final repository = AppScope.of(context).progressRepository;
          final claim = await repository.claimDailyLoginStreak(DateTime.now());
          if (!mounted) return;
          if (claim != null) {
            setState(() {
              _coins = claim.coins;
            });
          }
          Navigator.of(context).pop();
        },
      ),
    );
    _loginStreakPromptShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: GameSpacing.lg),
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
                      onPressed: () => Navigator.pushNamed(
                          context, WorldSelectionScreen.route),
                    ),
                    const SizedBox(height: GameSpacing.md),
                    if (_finalRewardUnlocked) ...[
                      PrimaryButton(
                        label: 'Final Reward',
                        icon: Icons.emoji_events_rounded,
                        onPressed: () => Navigator.pushNamed(
                          context,
                          FinalCodeScreen.route,
                        ),
                      ),
                      const SizedBox(height: GameSpacing.md),
                    ],
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
                    Row(
                      children: [
                        Expanded(
                          child: GameButton(
                            label: 'Profile',
                            icon: Icons.person_rounded,
                            onPressed: () => Navigator.pushNamed(
                              context,
                              PlayerProfileScreen.route,
                            ),
                            variant: GameButtonVariant.primary,
                          ),
                        ),
                        const SizedBox(width: GameSpacing.md),
                        Expanded(
                          child: GameButton(
                            label: 'Chests',
                            icon: Icons.inventory_2_rounded,
                            onPressed: () => Navigator.pushNamed(
                              context,
                              TreasureChestsScreen.route,
                            ),
                            variant: GameButtonVariant.gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: GameSpacing.md),
                    PrimaryButton(
                      label: 'Daily Challenges',
                      icon: Icons.task_alt_rounded,
                      onPressed: () async {
                        await Navigator.pushNamed(
                          context,
                          DailyChallengesScreen.route,
                        );
                        if (mounted) await _loadRewards();
                      },
                    ),
                    const SizedBox(height: GameSpacing.md),
                    PrimaryButton(
                      label: 'Collection Book',
                      icon: Icons.collections_bookmark_rounded,
                      onPressed: () => Navigator.pushNamed(
                        context,
                        CollectionBookScreen.route,
                      ),
                    ),
                    const SizedBox(height: GameSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: GameButton(
                            label: 'Achievements',
                            icon: Icons.emoji_events_rounded,
                            onPressed: () async {
                              await Navigator.pushNamed(
                                context,
                                AchievementsScreen.route,
                              );
                              if (mounted) await _loadRewards();
                            },
                            variant: GameButtonVariant.gold,
                          ),
                        ),
                        const SizedBox(width: GameSpacing.md),
                        Expanded(
                          child: GameButton(
                            label: 'Statistics',
                            icon: Icons.bar_chart_rounded,
                            onPressed: () => Navigator.pushNamed(
                              context,
                              StatisticsScreen.route,
                            ),
                            variant: GameButtonVariant.secondary,
                          ),
                        ),
                      ],
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
      ),
    );
  }
}

class _DailyLoginStreakDialog extends StatelessWidget {
  const _DailyLoginStreakDialog({
    required this.status,
    required this.onClaim,
  });

  final DailyLoginStreakStatus status;
  final Future<void> Function() onClaim;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.9, end: 1),
      duration: GameDurations.normal,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Opacity(
          opacity: scale.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: GameDialogFrame(
        title: 'Daily Login',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                gradient: GameGradients.badge,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: GameShadows.glow(GameColors.accentGold),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: GameSpacing.lg),
            Text('Day ${status.claimDay}', style: GameTextStyles.h2),
            const SizedBox(height: GameSpacing.sm),
            Text(
              '+${status.reward} coins',
              style: GameTextStyles.title.copyWith(
                color: GameColors.accentGold,
              ),
            ),
            const SizedBox(height: GameSpacing.lg),
            _StreakRewardRow(activeDay: status.claimDay),
            const SizedBox(height: GameSpacing.xl),
            GameButton(
              label: 'Claim',
              icon: Icons.card_giftcard_rounded,
              onPressed: () {
                onClaim();
              },
              variant: GameButtonVariant.gold,
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakRewardRow extends StatelessWidget {
  const _StreakRewardRow({required this.activeDay});

  final int activeDay;

  @override
  Widget build(BuildContext context) {
    const rewards = <int>[50, 75, 100, 125, 150, 200, 300];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < rewards.length; index++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: GameSpacing.xs),
                decoration: BoxDecoration(
                  gradient: index + 1 == activeDay
                      ? GameGradients.badge
                      : GameGradients.darkBadge,
                  borderRadius: GameRadius.smallRadius,
                  border: Border.all(color: Colors.white30, width: 1.5),
                  boxShadow: index + 1 == activeDay
                      ? GameShadows.glow(GameColors.accentGold)
                      : GameShadows.light(),
                ),
                child: Column(
                  children: [
                    Text(
                      'D${index + 1}',
                      style:
                          GameTextStyles.caption.copyWith(color: Colors.white),
                    ),
                    Text(
                      '${rewards[index]}',
                      style:
                          GameTextStyles.caption.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
