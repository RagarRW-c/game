import 'package:flutter/material.dart';

import '../../main.dart';
import '../models/adventure_progress.dart';
import '../theme/game_theme.dart';
import '../theme/world_theme.dart';
import '../widgets/adventure_world_destination_card.dart';
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
  late Future<AdventureProgress> _progressFuture;
  final _scrollController = ScrollController();
  bool _loaded = false;
  bool _openingWorld = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _progressFuture =
          AdventureProgress.load(AppScope.of(context).progressRepository);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openWorld(GameWorld world) async {
    if (_openingWorld) return;
    _openingWorld = true;
    try {
      await Navigator.pushNamed(context, MapScreen.route, arguments: world);
      if (!mounted) return;
      setState(() {
        _progressFuture =
            AdventureProgress.load(AppScope.of(context).progressRepository);
      });
    } finally {
      _openingWorld = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(children: [
                    Tooltip(
                      message: 'Back',
                      child: GameRoundIconButton(
                        key: const ValueKey('worlds_back'),
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text('Worlds',
                            style:
                                GameTextStyles.title.copyWith(fontSize: 24))),
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
                            _progressFuture = AdventureProgress.load(
                                AppScope.of(context).progressRepository);
                          }),
                          child: const Text('Retry loading worlds'),
                        ));
                      }
                      final progress = snapshot.data;
                      if (progress == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ListView.separated(
                        key: const PageStorageKey('adventure_worlds'),
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: gameWorlds.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 22),
                        itemBuilder: (context, index) {
                          final world = gameWorlds[index];
                          final unlocked = progress.highestUnlockedLevel >
                              world.unlockAfterLevel;
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: AdventureWorldDestinationCard(
                                key: ValueKey('world_${world.startLevel}'),
                                world: world,
                                unlocked: unlocked,
                                current: progress.highestUnlockedLevel >=
                                        world.startLevel &&
                                    progress.highestUnlockedLevel <=
                                        world.endLevel,
                                completed: progress.completedIn(
                                    world.startLevel, world.endLevel),
                                onTap:
                                    unlocked ? () => _openWorld(world) : null,
                              ),
                            ),
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
