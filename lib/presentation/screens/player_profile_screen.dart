import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';

class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({super.key});

  static const route = '/player-profile';

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  late Future<PlayerProfileSummary> _profileFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profileFuture = AppScope.of(context).progressRepository.playerProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(
                title: 'Player Profile',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: FutureBuilder<PlayerProfileSummary>(
                  future: _profileFuture,
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    if (profile == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ListView(
                      padding: const EdgeInsets.all(GameSpacing.lg),
                      children: [
                        _ProfileHeader(profile: profile),
                        const SizedBox(height: GameSpacing.lg),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: GameSpacing.md,
                          crossAxisSpacing: GameSpacing.md,
                          childAspectRatio: 1.1,
                          children: [
                            _ProfileStatCard(
                              icon: Icons.monetization_on_rounded,
                              label: 'Coins',
                              value: '${profile.coins}',
                            ),
                            _ProfileStatCard(
                              icon: Icons.star_rounded,
                              label: 'Total Stars',
                              value: '${profile.totalStars}',
                            ),
                            _ProfileStatCard(
                              icon: Icons.flag_rounded,
                              label: 'Levels Completed',
                              value: '${profile.levelsCompleted}',
                            ),
                            _ProfileStatCard(
                              icon: Icons.emoji_events_rounded,
                              label: 'Achievements',
                              value:
                                  '${profile.achievementsUnlocked}/${profile.achievementsTotal}',
                            ),
                            _ProfileStatCard(
                              icon: Icons.collections_bookmark_rounded,
                              label: 'Collection',
                              value:
                                  '${profile.collectionUnlocked}/${profile.collectionTotal}',
                            ),
                            _ProfileStatCard(
                              icon: Icons.casino_rounded,
                              label: 'Wheel Spins',
                              value: '${profile.luckyWheelSpins}',
                            ),
                            _ProfileStatCard(
                              icon: Icons.local_fire_department_rounded,
                              label: 'Daily Streak',
                              value: '${profile.dailyStreak}',
                            ),
                            _ProfileStatCard(
                              icon: Icons.auto_awesome_rounded,
                              label: 'Boosters Used',
                              value: '${profile.totalBoostersUsed}',
                            ),
                            _ProfileStatCard(
                              icon: Icons.check_circle_rounded,
                              label: 'Tiles Matched',
                              value: '${profile.totalTilesMatched}',
                            ),
                          ],
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
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final PlayerProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    final progress = (profile.totalXp % 500) / 500;
    return GameCard(
      shadow: GameShadows.glow(GameColors.primaryBlueLight),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: GameGradients.badge,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: GameShadows.medium(),
            ),
            child:
                const Icon(Icons.person_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(width: GameSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Player Level ${profile.playerLevel}',
                  style: GameTextStyles.h2.copyWith(fontSize: 24),
                ),
                const SizedBox(height: GameSpacing.xs),
                Text('${profile.totalXp} XP', style: GameTextStyles.body),
                const SizedBox(height: GameSpacing.sm),
                ClipRRect(
                  borderRadius: GameRadius.smallRadius,
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress,
                    backgroundColor: GameColors.borderBlue,
                    color: GameColors.accentGold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      padding: const EdgeInsets.all(GameSpacing.md),
      shadow: GameShadows.medium(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: GameColors.primaryBlue, size: 34),
          const SizedBox(height: GameSpacing.sm),
          Text(value, style: GameTextStyles.h2.copyWith(fontSize: 25)),
          const SizedBox(height: GameSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GameTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
