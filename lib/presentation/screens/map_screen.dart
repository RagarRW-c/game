import 'package:flutter/material.dart';

import '../../domain/level.dart';
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
  late Future<_MapProgress> _progressFuture;
  bool _dailySpinAvailable = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progressFuture = _loadMapProgress();
    _loadDailySpin();
  }

  Future<_MapProgress> _loadMapProgress() async {
    final repository = AppScope.of(context).progressRepository;
    final highest = await repository.highestUnlockedLevel();
    final stars = await repository.bestStarsByLevel(
        widget.world.startLevel, widget.world.endLevel);
    return _MapProgress(highestUnlockedLevel: highest, starsByLevel: stars);
  }

  Future<void> _loadDailySpin() async {
    final available = await AppScope.of(context)
        .progressRepository
        .dailySpinAvailable(DateTime.now());
    if (!mounted) return;
    setState(() => _dailySpinAvailable = available);
  }

  Future<void> _openLevelPreview(int level) async {
    final started = await showDialog<bool>(
      context: context,
      builder: (_) => _LevelPreviewDialog(
        levelFuture: AppScope.of(context).levelRepository.loadLevel(level),
        world: widget.world,
      ),
    );
    if (!mounted || started != true) return;
    await Navigator.pushNamed(
      context,
      GameScreen.route,
      arguments: level,
    );
    if (mounted) {
      setState(() {
        _progressFuture = _loadMapProgress();
      });
    }
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
                child: FutureBuilder<_MapProgress>(
                  future: _progressFuture,
                  builder: (context, snapshot) {
                    final progress = snapshot.data ?? const _MapProgress();
                    final highest = progress.highestUnlockedLevel;
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
                          stars: progress.starsByLevel[level] ?? 0,
                          bossInfo: _BossMapInfo.forLevel(level),
                          status: level < highest
                              ? 'Cleared'
                              : unlocked
                                  ? 'Ready'
                                  : 'Locked',
                          onTap:
                              unlocked ? () => _openLevelPreview(level) : null,
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

class _MapProgress {
  const _MapProgress({
    this.highestUnlockedLevel = 1,
    this.starsByLevel = const <int, int>{},
  });

  final int highestUnlockedLevel;
  final Map<int, int> starsByLevel;
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
    required this.stars,
    required this.bossInfo,
    required this.status,
    required this.onTap,
  });

  final int level;
  final bool unlocked;
  final int stars;
  final _BossMapInfo? bossInfo;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isBoss = bossInfo != null;
    return AnimatedOpacity(
      duration: GameDurations.normal,
      opacity: unlocked ? 1 : 0.58,
      child: InkWell(
        borderRadius: GameRadius.extraLargeRadius,
        onTap: onTap,
        child: GameCard(
          padding: EdgeInsets.all(isBoss ? GameSpacing.md : GameSpacing.lg),
          borderColor: isBoss ? GameColors.accentGold : Colors.white,
          shadow: isBoss
              ? GameShadows.glow(GameColors.accentGold)
              : GameShadows.medium(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isBoss)
                Positioned(
                  right: -4,
                  top: -4,
                  child: GameBadge(
                    icon: Icons.workspace_premium_rounded,
                    gradient: GameGradients.badge,
                    child: Text(
                      'Boss',
                      style: GameTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      unlocked
                          ? isBoss
                              ? bossInfo!.icon
                              : Icons.star_rounded
                          : Icons.lock_rounded,
                      color: unlocked
                          ? isBoss
                              ? GameColors.accentGoldDark
                              : GameColors.accentGold
                          : GameColors.mutedInk,
                      size: isBoss ? 54 : 46,
                    ),
                    const SizedBox(height: GameSpacing.sm),
                    Text(
                      'Level $level',
                      textAlign: TextAlign.center,
                      style: GameTextStyles.h2.copyWith(
                        fontSize: isBoss ? 22 : 23,
                      ),
                    ),
                    if (isBoss) ...[
                      const SizedBox(height: GameSpacing.xs),
                      Text(
                        bossInfo!.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GameTextStyles.caption.copyWith(
                          color: GameColors.accentGoldDark,
                        ),
                      ),
                    ],
                    const SizedBox(height: GameSpacing.xs),
                    _StarRow(stars: stars),
                    const SizedBox(height: GameSpacing.xs),
                    Text(status, style: GameTextStyles.body),
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

class _LevelPreviewDialog extends StatelessWidget {
  const _LevelPreviewDialog({
    required this.levelFuture,
    required this.world,
  });

  final Future<LevelDefinition> levelFuture;
  final GameWorld world;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LevelDefinition>(
      future: levelFuture,
      builder: (context, snapshot) {
        final level = snapshot.data;
        return GameDialogFrame(
          title: level == null ? 'Level Preview' : 'Level ${level.level}',
          child: level == null
              ? const Padding(
                  padding: EdgeInsets.all(GameSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _LevelPreviewContent(level: level, world: world),
        );
      },
    );
  }
}

class _LevelPreviewContent extends StatelessWidget {
  const _LevelPreviewContent({
    required this.level,
    required this.world,
  });

  final LevelDefinition level;
  final GameWorld world;

  @override
  Widget build(BuildContext context) {
    final bossInfo = _BossMapInfo.forLevel(level.level);
    final difficulty = _difficultyForLevel(level.level);
    final chestLabel = _chestPreviewForLevel(level.level);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            gradient: bossInfo == null ? world.gradient : GameGradients.badge,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: GameShadows.glow(world.visualTheme.primaryAccent),
          ),
          child: Icon(
            bossInfo?.icon ?? world.icon,
            color: Colors.white,
            size: 46,
          ),
        ),
        const SizedBox(height: GameSpacing.lg),
        Text(world.name, textAlign: TextAlign.center, style: GameTextStyles.h2),
        const SizedBox(height: GameSpacing.sm),
        _PreviewRow(
          icon: Icons.speed_rounded,
          label: 'Difficulty',
          value: difficulty,
        ),
        _PreviewRow(
          icon: Icons.monetization_on_rounded,
          label: 'Coins',
          value: '+${_coinRewardForLevel(level.level)}',
        ),
        _PreviewRow(
          icon: Icons.bolt_rounded,
          label: 'XP',
          value: _xpRewardPreviewForLevel(level.level),
        ),
        if (chestLabel != null)
          _PreviewRow(
            icon: Icons.inventory_2_rounded,
            label: 'Chest',
            value: chestLabel,
          ),
        if (level.objective != null)
          _PreviewRow(
            icon: Icons.track_changes_rounded,
            label: 'Objective',
            value: '${level.objective!.target} ${level.objective!.type}',
          ),
        const SizedBox(height: GameSpacing.xl),
        GameButton(
          label: 'Start',
          icon: Icons.play_arrow_rounded,
          onPressed: () => Navigator.of(context).pop(true),
          variant: GameButtonVariant.success,
        ),
        const SizedBox(height: GameSpacing.md),
        GameButton(
          label: 'Back',
          icon: Icons.arrow_back_rounded,
          onPressed: () => Navigator.of(context).pop(false),
          variant: GameButtonVariant.secondary,
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: GameSpacing.sm),
      child: GameCard(
        padding: const EdgeInsets.all(GameSpacing.md),
        shadow: GameShadows.light(),
        child: Row(
          children: [
            Icon(icon, color: GameColors.primaryBlue),
            const SizedBox(width: GameSpacing.md),
            Expanded(child: Text(label, style: GameTextStyles.body)),
            Flexible(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: GameTextStyles.button.copyWith(color: GameColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _difficultyForLevel(int level) {
  if (level % 10 == 0) return 'Boss';
  final worldIndex = (level - 1) % 10;
  if (worldIndex <= 2) return 'Easy';
  if (worldIndex <= 5) return 'Medium';
  if (worldIndex <= 7) return 'Hard';
  return 'Very Hard';
}

int _coinRewardForLevel(int level) => level % 10 == 0 ? 350 : 50;

String _xpRewardPreviewForLevel(int level) =>
    level % 10 == 0 ? '+300-350' : '+100-150';

String? _chestPreviewForLevel(int level) {
  if (level % 10 == 0) return 'Gold Chest';
  if (level % 5 == 0) return 'Silver Chest';
  return null;
}

class _BossMapInfo {
  const _BossMapInfo({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  static _BossMapInfo? forLevel(int level) {
    switch (level) {
      case 10:
        return const _BossMapInfo(
          title: 'Garden Boss',
          icon: Icons.local_florist_rounded,
        );
      case 20:
        return const _BossMapInfo(
          title: 'Ocean Boss',
          icon: Icons.water_rounded,
        );
      case 30:
        return const _BossMapInfo(
          title: 'Candy Boss',
          icon: Icons.icecream_rounded,
        );
      case 40:
        return const _BossMapInfo(
          title: 'Space Boss',
          icon: Icons.auto_awesome_rounded,
        );
      case 50:
        return const _BossMapInfo(
          title: 'Desert Boss',
          icon: Icons.wb_sunny_rounded,
        );
      case 60:
        return const _BossMapInfo(
          title: 'Ice Boss',
          icon: Icons.ac_unit_rounded,
        );
      case 70:
        return const _BossMapInfo(
          title: 'Jungle Boss',
          icon: Icons.forest_rounded,
        );
      case 80:
        return const _BossMapInfo(
          title: 'Volcano Boss',
          icon: Icons.local_fire_department_rounded,
        );
      case 90:
        return const _BossMapInfo(
          title: 'Dream Boss',
          icon: Icons.cloud_rounded,
        );
      case 100:
        return const _BossMapInfo(
          title: 'Crystal Boss',
          icon: Icons.diamond_rounded,
        );
      default:
        return null;
    }
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 1; index <= 3; index++)
          Icon(
            index <= stars ? Icons.star_rounded : Icons.star_border_rounded,
            color: index <= stars ? GameColors.accentGold : GameColors.mutedInk,
            size: 20,
          ),
      ],
    );
  }
}
