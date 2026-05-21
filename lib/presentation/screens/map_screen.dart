import 'package:flutter/material.dart';

import '../../data/level_repository.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';
import 'game_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  static const route = '/map';

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<int> _highestFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _highestFuture =
        AppScope.of(context).progressRepository.highestUnlockedLevel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(
                title: 'Adventure Map',
                onBack: () => Navigator.of(context).maybePop(),
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
                      itemCount: LevelRepository.levelCount,
                      itemBuilder: (context, index) {
                        final level = index + 1;
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
