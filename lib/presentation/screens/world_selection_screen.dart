import 'package:flutter/material.dart';

import '../../main.dart';
import '../theme/game_theme.dart';
import '../theme/world_theme.dart';
import '../widgets/game_ui.dart';
import '../widgets/game_decoration.dart';
import '../widgets/world_atmosphere.dart';
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
  GameWorld(
    name: 'Desert World',
    subtitle: 'Levels 41-50',
    startLevel: 41,
    endLevel: 50,
    unlockAfterLevel: 40,
    icon: Icons.wb_sunny_rounded,
    gradient: GameGradients.goldButton,
    visualTheme: WorldThemes.desert,
  ),
  GameWorld(
    name: 'Ice World',
    subtitle: 'Levels 51-60',
    startLevel: 51,
    endLevel: 60,
    unlockAfterLevel: 50,
    icon: Icons.ac_unit_rounded,
    gradient: GameGradients.primaryButton,
    visualTheme: WorldThemes.ice,
  ),
  GameWorld(
    name: 'Jungle World',
    subtitle: 'Levels 61-70',
    startLevel: 61,
    endLevel: 70,
    unlockAfterLevel: 60,
    icon: Icons.forest_rounded,
    gradient: GameGradients.successButton,
    visualTheme: WorldThemes.jungle,
  ),
  GameWorld(
    name: 'Volcano World',
    subtitle: 'Levels 71-80',
    startLevel: 71,
    endLevel: 80,
    unlockAfterLevel: 70,
    icon: Icons.local_fire_department_rounded,
    gradient: GameGradients.dangerButton,
    visualTheme: WorldThemes.volcano,
  ),
  GameWorld(
    name: 'Dream World',
    subtitle: 'Levels 81-90',
    startLevel: 81,
    endLevel: 90,
    unlockAfterLevel: 80,
    icon: Icons.cloud_rounded,
    gradient: GameGradients.dialogHeader,
    visualTheme: WorldThemes.dream,
  ),
  GameWorld(
    name: 'Crystal World',
    subtitle: 'Levels 91-100',
    startLevel: 91,
    endLevel: 100,
    unlockAfterLevel: 90,
    icon: Icons.diamond_rounded,
    gradient: GameGradients.primaryButton,
    visualTheme: WorldThemes.crystal,
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
    final theme = world.visualTheme;
    return GameEntrance(
      child: Semantics(
        button: true,
        enabled: unlocked,
        child: InkWell(
          borderRadius: GameRadius.extraLargeRadius,
          onTap: onTap,
          child: GameCard(
            padding: EdgeInsets.zero,
            gradient: unlocked ? theme.hudGradient : GameGradients.darkBadge,
            borderColor:
                unlocked ? theme.secondaryAccent : const Color(0xFF99A6B9),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(children: [
                if (unlocked)
                  Positioned.fill(child: WorldAtmosphere(theme: theme)),
                Padding(
                  padding: const EdgeInsets.all(GameSpacing.lg),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: unlocked
                                  ? theme.actionGradient
                                  : GameGradients.disabled,
                              borderRadius: BorderRadius.circular(24),
                              border:
                                  Border.all(color: Colors.white70, width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    offset: const Offset(0, 4)),
                                ...GameShadows.light(),
                              ],
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
                                  style: GameTextStyles.title
                                      .copyWith(fontSize: 22),
                                ),
                                const SizedBox(height: GameSpacing.xs),
                                Text(world.subtitle,
                                    style: GameTextStyles.body.copyWith(
                                        color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 18),
                        Row(children: [
                          Expanded(
                              child: Text(
                            unlocked
                                ? 'Adventure progress'
                                : 'Complete Level ${world.unlockAfterLevel} to unlock',
                            style: GameTextStyles.caption
                                .copyWith(color: Colors.white),
                          )),
                          const SizedBox(width: 8),
                          Text('$completed/10',
                              style: GameTextStyles.button.copyWith(
                                  color: unlocked
                                      ? theme.secondaryAccent
                                      : Colors.white70)),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: completed / 10,
                            backgroundColor: const Color(0x550A1737),
                            color: unlocked
                                ? theme.secondaryAccent
                                : Colors.white38,
                          ),
                        ),
                      ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
