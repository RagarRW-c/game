import 'package:flutter/material.dart';

import '../screens/world_selection_screen.dart';
import '../theme/game_theme.dart';
import 'adventure_level_node.dart';
import 'adventure_world_scenery.dart';
import 'game_decoration.dart';

class AdventureWorldDestinationCard extends StatelessWidget {
  const AdventureWorldDestinationCard({
    super.key,
    required this.world,
    required this.unlocked,
    required this.current,
    required this.completed,
    required this.onTap,
  });

  final GameWorld world;
  final bool unlocked;
  final bool current;
  final int completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GameEntrance(
        child: Semantics(
          container: true,
          button: true,
          enabled: unlocked,
          onTap: unlocked ? onTap : null,
          label: '${world.name}, ${world.subtitle}, $completed of 10 cleared. '
              '${current ? 'Current world. ' : ''}'
              '${unlocked ? 'Explore' : 'Complete Level ${world.unlockAfterLevel} to unlock'}',
          excludeSemantics: true,
          child: AdventurePressable(
            borderRadius: BorderRadius.circular(32),
            onTap: unlocked ? onTap : null,
            // Retain the decorated body while entrance/press transforms and
            // Material ink animate above it. This boundary does not clip shadows.
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  gradient: world.visualTheme.hudGradient,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                      width: current ? 3 : 2,
                      color: current ? GameColors.accentGold : Colors.white54),
                  boxShadow: const [
                    BoxShadow(color: Color(0x660D2036), offset: Offset(0, 6)),
                    BoxShadow(
                        color: Color(0x330D2036),
                        blurRadius: 16,
                        offset: Offset(0, 10)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(29),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 112,
                        child: Stack(
                          children: [
                            Positioned.fill(
                                child: AdventureWorldScenery(
                                    theme: world.visualTheme, panorama: true)),
                            if (!unlocked)
                              const Positioned.fill(
                                  child: IgnorePointer(
                                      child: ColoredBox(
                                          color: Color(0x660C2034)))),
                            Positioned(
                              right: 16,
                              bottom: 10,
                              child: ExcludeSemantics(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: world.visualTheme.actionGradient,
                                    border: Border.all(
                                        color: Colors.white70, width: 2),
                                    boxShadow: GameShadows.light(),
                                  ),
                                  child: Icon(
                                      unlocked
                                          ? world.icon
                                          : Icons.lock_rounded,
                                      color: Colors.white,
                                      size: 30),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (current)
                              Text('YOUR JOURNEY',
                                  style: GameTextStyles.caption.copyWith(
                                      color: GameColors.accentGold,
                                      letterSpacing: 1)),
                            Text(world.name,
                                style: GameTextStyles.title
                                    .copyWith(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text('${world.subtitle}  •  $completed/10 cleared',
                                style: GameTextStyles.body.copyWith(
                                    color: Colors.white, fontSize: 14)),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: completed / 10,
                                minHeight: 6,
                                color: world.visualTheme.secondaryAccent,
                                backgroundColor: Colors.white12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    unlocked
                                        ? 'Explore world'
                                        : 'Complete Level ${world.unlockAfterLevel} to unlock',
                                    style: GameTextStyles.button.copyWith(
                                        fontSize: 15, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                    unlocked
                                        ? Icons.east_rounded
                                        : Icons.lock_rounded,
                                    color: Colors.white70,
                                    size: 24),
                              ],
                            ),
                          ],
                        ),
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
