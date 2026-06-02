import 'package:flutter/material.dart';

import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';
import 'booster_shop_screen.dart';
import 'game_screen.dart';
import 'lucky_wheel_screen.dart';
import 'world_selection_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.world});

  static const route = '/map';
  final GameWorld world;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<int> _highestFuture;
  bool _dailySpinAvailable = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _highestFuture =
        AppScope.of(context).progressRepository.highestUnlockedLevel();
    _loadDailySpin();
  }

  Future<void> _loadDailySpin() async {
    final available = await AppScope.of(context)
        .progressRepository
        .dailySpinAvailable(DateTime.now());
    if (!mounted) return;
    setState(() => _dailySpinAvailable = available);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        worldTheme: widget.world.visualTheme,
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(
                title: widget.world.name,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GameSpacing.lg,
                  0,
                  GameSpacing.lg,
                  GameSpacing.md,
                ),
                child: _WorldMapBanner(world: widget.world),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: GameSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: GameButton(
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
                                if (mounted) await _loadDailySpin();
                              }
                            : null,
                        variant: GameButtonVariant.gold,
                      ),
                    ),
                    const SizedBox(width: GameSpacing.md),
                    Expanded(
                      child: GameButton(
                        label: 'Shop',
                        icon: Icons.storefront_rounded,
                        onPressed: () => Navigator.pushNamed(
                          context,
                          BoosterShopScreen.route,
                        ),
                        variant: GameButtonVariant.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<int>(
                  future: _highestFuture,
                  builder: (context, snapshot) {
                    final highest = snapshot.data ?? 1;
                    return GridView.builder(
                      padding: const EdgeInsets.all(GameSpacing.lg),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: GameSpacing.lg,
                        crossAxisSpacing: GameSpacing.lg,
                      ),
                      itemCount: 10,
                      itemBuilder: (context, index) {
                        final level = widget.world.startLevel + index;
                        final unlocked = level <= highest;
                        return _LevelCard(
                          level: level,
                          unlocked: unlocked,
                          status: level < highest
                              ? 'Cleared'
                              : unlocked
                                  ? 'Ready'
                                  : 'Locked',
                          onTap: unlocked
                              ? () async {
                                  await Navigator.pushNamed(
                                    context,
                                    GameScreen.route,
                                    arguments: level,
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _highestFuture = AppScope.of(context)
                                          .progressRepository
                                          .highestUnlockedLevel();
                                    });
                                  }
                                }
                              : null,
                        );
                      },
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

class _WorldMapBanner extends StatelessWidget {
  const _WorldMapBanner({required this.world});

  final GameWorld world;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      padding: const EdgeInsets.all(GameSpacing.lg),
      gradient: world.gradient,
      shadow: GameShadows.glow(world.visualTheme.primaryAccent),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: GameShadows.light(),
            ),
            child: Icon(world.icon, color: Colors.white, size: 34),
          ),
          const SizedBox(width: GameSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  world.name,
                  style: GameTextStyles.h2.copyWith(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: GameSpacing.xs),
                Text(
                  'Levels ${world.startLevel}-${world.endLevel}',
                  style: GameTextStyles.body.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 112,
            child: GameButton(
              label: 'Worlds',
              icon: Icons.public_rounded,
              onPressed: () => Navigator.of(context).maybePop(),
              variant: GameButtonVariant.secondary,
              height: 46,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.unlocked,
    required this.status,
    required this.onTap,
  });

  final int level;
  final bool unlocked;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: GameDurations.normal,
      opacity: unlocked ? 1 : 0.58,
      child: InkWell(
        borderRadius: GameRadius.extraLargeRadius,
        onTap: onTap,
        child: GameCard(
          padding: const EdgeInsets.all(GameSpacing.lg),
          shadow: GameShadows.medium(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                unlocked ? Icons.star_rounded : Icons.lock_rounded,
                color: unlocked ? GameColors.accentGold : GameColors.mutedInk,
                size: 46,
              ),
              const SizedBox(height: GameSpacing.sm),
              Text(
                'Level $level',
                textAlign: TextAlign.center,
                style: GameTextStyles.h2.copyWith(fontSize: 23),
              ),
              Text(status, style: GameTextStyles.body),
            ],
          ),
        ),
      ),
    );
  }
}
