import 'package:flutter/material.dart';

import '../../main.dart';
import '../theme/game_theme.dart';
import '../theme/world_theme.dart';
import '../widgets/game_ui.dart';
import 'map_screen.dart';

class GameWorld {
  const GameWorld({
    required this.name,
    required this.subtitle,
    required this.startLevel,
    required this.endLevel,
    required this.unlockAfterLevel,
    required this.icon,
    required this.gradient,
    required this.visualTheme,
  });

  final String name;
  final String subtitle;
  final int startLevel;
  final int endLevel;
  final int unlockAfterLevel;
  final IconData icon;
  final Gradient gradient;
  final WorldVisualTheme visualTheme;
}

const gameWorlds = <GameWorld>[
  GameWorld(
    name: 'Garden World',
    subtitle: 'Levels 1-10',
    startLevel: 1,
    endLevel: 10,
    unlockAfterLevel: 0,
    icon: Icons.local_florist_rounded,
    gradient: GameGradients.successButton,
    visualTheme: WorldThemes.garden,
  ),
  GameWorld(
    name: 'Ocean World',
    subtitle: 'Levels 11-20',
    startLevel: 11,
    endLevel: 20,
    unlockAfterLevel: 10,
    icon: Icons.waves_rounded,
    gradient: GameGradients.primaryButton,
    visualTheme: WorldThemes.ocean,
  ),
  GameWorld(
    name: 'Candy World',
    subtitle: 'Levels 21-30',
    startLevel: 21,
    endLevel: 30,
    unlockAfterLevel: 20,
    icon: Icons.cookie_rounded,
    gradient: GameGradients.goldButton,
    visualTheme: WorldThemes.candy,
  ),
  GameWorld(
    name: 'Space World',
    subtitle: 'Levels 31-40',
    startLevel: 31,
    endLevel: 40,
    unlockAfterLevel: 30,
    icon: Icons.auto_awesome_rounded,
    gradient: GameGradients.dialogHeader,
    visualTheme: WorldThemes.space,
  ),
];

class WorldSelectionScreen extends StatefulWidget {
  const WorldSelectionScreen({super.key});

  static const route = '/worlds';

  @override
  State<WorldSelectionScreen> createState() => _WorldSelectionScreenState();
}

class _WorldSelectionScreenState extends State<WorldSelectionScreen> {
  late Future<int> _highestFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _highestFuture =
        AppScope.of(context).progressRepository.highestUnlockedLevel();
  }

  int _completedInWorld(GameWorld world, int highest) {
    final completedThrough = highest - 1;
    if (completedThrough < world.startLevel) return 0;
    return (completedThrough - world.startLevel + 1).clamp(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(
                title: 'Select World',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: FutureBuilder<int>(
                  future: _highestFuture,
                  builder: (context, snapshot) {
                    final highest = snapshot.data ?? 1;
                    return ListView.separated(
                      padding: const EdgeInsets.all(GameSpacing.lg),
                      itemBuilder: (context, index) {
                        final world = gameWorlds[index];
                        final unlocked = highest > world.unlockAfterLevel;
                        return _WorldCard(
                          world: world,
                          unlocked: unlocked,
                          completed: _completedInWorld(world, highest),
                          onTap: unlocked
                              ? () async {
                                  await Navigator.pushNamed(
                                    context,
                                    MapScreen.route,
                                    arguments: world,
                                  );
                                  if (!mounted) return;
                                  setState(() {
                                    _highestFuture = AppScope.of(context)
                                        .progressRepository
                                        .highestUnlockedLevel();
                                  });
                                }
                              : null,
                        );
                      },
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: GameSpacing.md),
                      itemCount: gameWorlds.length,
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

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.world,
    required this.unlocked,
    required this.completed,
    required this.onTap,
  });

  final GameWorld world;
  final bool unlocked;
  final int completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: GameDurations.normal,
      opacity: unlocked ? 1 : 0.55,
      child: InkWell(
        borderRadius: GameRadius.extraLargeRadius,
        onTap: onTap,
        child: GameCard(
          padding: const EdgeInsets.all(GameSpacing.lg),
          gradient:
              unlocked ? world.visualTheme.boardGradient : GameGradients.panel,
          shadow: GameShadows.medium(),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: unlocked ? world.gradient : GameGradients.disabled,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: GameShadows.light(),
                ),
                child: Icon(
                  unlocked ? world.icon : Icons.lock_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(width: GameSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      world.name,
                      style: GameTextStyles.h2.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: GameSpacing.xs),
                    Text(world.subtitle, style: GameTextStyles.body),
                    const SizedBox(height: GameSpacing.sm),
                    ClipRRect(
                      borderRadius: GameRadius.smallRadius,
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: completed / 10,
                        backgroundColor: GameColors.borderBlue,
                        color: world.visualTheme.primaryAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GameSpacing.md),
              GameBadge(
                icon: Icons.check_circle_rounded,
                child: Text(
                  '$completed/10',
                  style: GameTextStyles.caption.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
