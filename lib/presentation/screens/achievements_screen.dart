import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  static const route = '/achievements';

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late Future<List<AchievementState>> _achievementsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _achievementsFuture =
        AppScope.of(context).progressRepository.achievements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(
                title: 'Achievements',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: FutureBuilder<List<AchievementState>>(
                  future: _achievementsFuture,
                  builder: (context, snapshot) {
                    final achievements =
                        snapshot.data ?? const <AchievementState>[];
                    return ListView.separated(
                      padding: const EdgeInsets.all(GameSpacing.lg),
                      itemCount: achievements.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: GameSpacing.md),
                      itemBuilder: (context, index) {
                        return _AchievementCard(
                          achievement: achievements[index],
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

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final AchievementState achievement;

  @override
  Widget build(BuildContext context) {
    final definition = achievement.definition;
    final unlocked = achievement.unlocked;
    return AnimatedOpacity(
      duration: GameDurations.normal,
      opacity: unlocked ? 1 : 0.62,
      child: GameCard(
        padding: const EdgeInsets.all(GameSpacing.md),
        shadow: unlocked
            ? GameShadows.glow(GameColors.accentGold)
            : GameShadows.medium(),
        borderColor: unlocked ? GameColors.accentGold : Colors.white,
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient:
                    unlocked ? GameGradients.badge : GameGradients.disabled,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: GameShadows.light(),
              ),
              child: Icon(
                unlocked ? Icons.emoji_events_rounded : Icons.lock_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: GameSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.name,
                    style: GameTextStyles.h2.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: GameSpacing.xs),
                  Text(definition.description, style: GameTextStyles.body),
                  const SizedBox(height: GameSpacing.sm),
                  GameBadge(
                    icon: Icons.monetization_on_rounded,
                    gradient: unlocked
                        ? GameGradients.badge
                        : GameGradients.darkBadge,
                    child: Text(
                      unlocked
                          ? 'Unlocked +${definition.reward}'
                          : 'Reward ${definition.reward}',
                      style: GameTextStyles.caption.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
