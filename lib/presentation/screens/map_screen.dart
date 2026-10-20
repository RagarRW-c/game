import 'package:flutter/material.dart';

import '../../domain/level.dart';
import '../../main.dart';
import '../models/adventure_progress.dart';
import '../theme/game_theme.dart';
import '../widgets/adventure_map_path.dart';
import '../widgets/game_decoration.dart';
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
  late Future<AdventureProgress> _progressFuture;
  final _scrollController = ScrollController();
  final _nodeKeys = List.generate(10, (_) => GlobalKey());
  AdventureProgress? _progress;
  bool _loaded = false;
  bool _positioned = false;
  bool _openingLevel = false;
  bool _openingUtility = false;
  bool _dailySpinAvailable = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _progressFuture = _loadMapProgress();
      _loadDailySpin();
    }
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.world != widget.world) {
      _positioned = false;
      _progressFuture = _loadMapProgress();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<AdventureProgress> _loadMapProgress() =>
      AdventureProgress.load(AppScope.of(context).progressRepository);

  Future<void> _loadDailySpin() async {
    final available = await AppScope.of(context)
        .progressRepository
        .dailySpinAvailable(DateTime.now());
    if (mounted) setState(() => _dailySpinAvailable = available);
  }

  void _findCurrent({bool animate = true}) {
    final progress = _progress;
    if (progress == null) return;
    final index =
        (progress.highestUnlockedLevel - widget.world.startLevel).clamp(0, 9);
    final target = _nodeKeys[index].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target,
        alignment: .35,
        duration: animate && !MediaQuery.disableAnimationsOf(context)
            ? const Duration(milliseconds: 420)
            : Duration.zero,
        curve: Curves.easeOutCubic);
  }

  Future<void> _openUtility(String route) async {
    if (_openingUtility || _openingLevel) return;
    _openingUtility = true;
    try {
      await Navigator.pushNamed(context, route);
      if (mounted) await _loadDailySpin();
    } finally {
      _openingUtility = false;
    }
  }

  Future<void> _openLevelPreview(int level) async {
    if (_openingLevel ||
        _openingUtility ||
        !(_progress?.isUnlocked(level) ?? false)) return;
    _openingLevel = true;
    try {
      // Keep the existing preview -> Start -> named game route contract.
      final levelFuture = AppScope.of(context).levelRepository.loadLevel(level);
      final started = await showDialog<bool>(
        context: context,
        builder: (_) => _LevelPreviewDialog(
          levelFuture: levelFuture,
          world: widget.world,
        ),
      );
      if (!mounted || started != true) return;
      await Navigator.pushNamed(context, GameScreen.route, arguments: level);
      if (!mounted) return;
      // Start I/O outside setState. Returning this Future from an arrow
      // callback throws before Flutter can schedule the progress rebuild.
      final progressFuture = _loadMapProgress();
      setState(() {
        _progressFuture = progressFuture;
      });
    } finally {
      _openingLevel = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GameBackground(
          worldTheme: widget.world.visualTheme,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(children: [
                    Tooltip(
                      message: 'Back to worlds',
                      child: GameRoundIconButton(
                        key: const ValueKey('map_back'),
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    Expanded(
                      child: Text('Map',
                          textAlign: TextAlign.center,
                          style: GameTextStyles.title.copyWith(fontSize: 20)),
                    ),
                    Tooltip(
                      message: 'Find latest level in this world',
                      child: GameRoundIconButton(
                        key: const ValueKey('find_current_level'),
                        icon: Icons.my_location_rounded,
                        onPressed: () => _findCurrent(),
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: FutureBuilder<AdventureProgress>(
                    future: _progressFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child: TextButton(
                          onPressed: () => setState(() {
                            _progressFuture = _loadMapProgress();
                          }),
                          child: const Text('Retry loading your journey'),
                        ));
                      }
                      final progress = snapshot.data;
                      if (progress == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      _progress = progress;
                      if (!_positioned) {
                        _positioned = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _findCurrent(animate: false);
                        });
                      }
                      return CustomScrollView(
                        key: PageStorageKey(
                            'adventure_${widget.world.startLevel}'),
                        controller: _scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(widget.world.name,
                                      textAlign: TextAlign.center,
                                      style: GameTextStyles.title
                                          .copyWith(fontSize: 30)),
                                  const SizedBox(height: 6),
                                  Text(
                                      '${widget.world.subtitle} • '
                                      '${progress.completedIn(widget.world.startLevel, widget.world.endLevel)}/10 cleared',
                                      textAlign: TextAlign.center,
                                      style: GameTextStyles.body
                                          .copyWith(color: Colors.white)),
                                  const SizedBox(height: 18),
                                  LayoutBuilder(
                                      builder: (context, constraints) {
                                    final stacked =
                                        constraints.maxWidth < 360 ||
                                            MediaQuery.textScalerOf(context)
                                                    .scale(16) >
                                                21;
                                    final spin = GameButton(
                                      label: _dailySpinAvailable
                                          ? 'Daily Spin'
                                          : 'Next Spin Tomorrow',
                                      icon: Icons.casino_rounded,
                                      wrapLabel: true,
                                      onPressed: _dailySpinAvailable
                                          ? () => _openUtility(
                                              LuckyWheelScreen.route)
                                          : null,
                                      variant: GameButtonVariant.gold,
                                    );
                                    final shop = GameButton(
                                      label: 'Shop',
                                      icon: Icons.storefront_rounded,
                                      wrapLabel: true,
                                      onPressed: () =>
                                          _openUtility(BoosterShopScreen.route),
                                    );
                                    return stacked
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                                spin,
                                                const SizedBox(height: 10),
                                                shop
                                              ])
                                        : Row(children: [
                                            Expanded(child: spin),
                                            const SizedBox(width: 12),
                                            Expanded(child: shop)
                                          ]);
                                  }),
                                ],
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: AdventureMapPath(
                              startLevel: widget.world.startLevel,
                              theme: widget.world.visualTheme,
                              progress: progress,
                              nodeKeys: _nodeKeys,
                              onLevelTap: _openLevelPreview,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                              child: GameButton(
                                label: 'Explore worlds',
                                icon: Icons.public_rounded,
                                wrapLabel: true,
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                variant: GameButtonVariant.secondary,
                              ),
                            ),
                          ),
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

class _LevelPreviewDialog extends StatefulWidget {
  const _LevelPreviewDialog({
    required this.levelFuture,
    required this.world,
  });

  final Future<LevelDefinition> levelFuture;
  final GameWorld world;

  @override
  State<_LevelPreviewDialog> createState() => _LevelPreviewDialogState();
}

class _LevelPreviewDialogState extends State<_LevelPreviewDialog> {
  bool _closing = false;

  void _finish(bool start) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(start);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LevelDefinition>(
      future: widget.levelFuture,
      builder: (context, snapshot) {
        final level = snapshot.data;
        return Dialog(
          key: const ValueKey('level_preview'),
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: GameEntrance(
              child: GameCard(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          level == null
                              ? 'Level Preview'
                              : 'Level ${level.level}',
                          textAlign: TextAlign.center,
                          style: GameTextStyles.h2),
                      const SizedBox(height: 16),
                      if (snapshot.hasError) ...[
                        const Text(
                            'This level could not be loaded. Please try again.'),
                        TextButton(
                            onPressed: () => _finish(false),
                            child: const Text('Back')),
                      ] else if (level == null)
                        const Padding(
                          padding: EdgeInsets.all(GameSpacing.lg),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        _LevelPreviewContent(
                          level: level,
                          world: widget.world,
                          onStart: () => _finish(true),
                          onBack: () => _finish(false),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LevelPreviewContent extends StatelessWidget {
  const _LevelPreviewContent({
    required this.level,
    required this.world,
    required this.onStart,
    required this.onBack,
  });

  final LevelDefinition level;
  final GameWorld world;
  final VoidCallback onStart;
  final VoidCallback onBack;

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
        if (bossInfo != null)
          Text(bossInfo.title,
              textAlign: TextAlign.center, style: GameTextStyles.body),
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
          key: const ValueKey('preview_start'),
          label: 'Start',
          wrapLabel: true,
          icon: Icons.play_arrow_rounded,
          onPressed: onStart,
          variant: GameButtonVariant.success,
        ),
        const SizedBox(height: GameSpacing.md),
        GameButton(
          key: const ValueKey('preview_back'),
          label: 'Back',
          wrapLabel: true,
          icon: Icons.arrow_back_rounded,
          onPressed: onBack,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GameTextStyles.body),
                  Text(value,
                      style: GameTextStyles.button
                          .copyWith(color: GameColors.ink)),
                ],
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
