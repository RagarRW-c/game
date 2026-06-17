import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  static const route = '/statistics';

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<GameStatistics> _statisticsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _statisticsFuture = AppScope.of(context).progressRepository.statistics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(
                title: 'Statistics',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: FutureBuilder<GameStatistics>(
                  future: _statisticsFuture,
                  builder: (context, snapshot) {
                    final stats = snapshot.data;
                    if (stats == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return GridView.count(
                      padding: const EdgeInsets.all(GameSpacing.lg),
                      crossAxisCount: 2,
                      mainAxisSpacing: GameSpacing.md,
                      crossAxisSpacing: GameSpacing.md,
                      childAspectRatio: 1.1,
                      children: [
                        _StatCard(
                          icon: Icons.flag_rounded,
                          label: 'Levels Completed',
                          value: '${stats.levelsCompleted}',
                        ),
                        _StatCard(
                          icon: Icons.check_circle_rounded,
                          label: 'Tiles Matched',
                          value: '${stats.totalTilesMatched}',
                        ),
                        _StatCard(
                          icon: Icons.monetization_on_rounded,
                          label: 'Coins Earned',
                          value: '${stats.totalCoinsEarned}',
                        ),
                        _StatCard(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Boosters Used',
                          value: '${stats.totalBoostersUsed}',
                        ),
                        _StatCard(
                          icon: Icons.pets_rounded,
                          label: 'Hints Used',
                          value: '${stats.hintsUsed}',
                        ),
                        _StatCard(
                          icon: Icons.air_rounded,
                          label: 'Shuffles Used',
                          value: '${stats.shufflesUsed}',
                        ),
                        _StatCard(
                          icon: Icons.arrow_back_rounded,
                          label: 'Undos Used',
                          value: '${stats.undosUsed}',
                        ),
                        _StatCard(
                          icon: Icons.casino_rounded,
                          label: 'Wheel Spins',
                          value: '${stats.luckyWheelSpins}',
                        ),
                        _StatCard(
                          icon: Icons.star_rounded,
                          label: 'Best Stars',
                          value: '${stats.bestStarsTotal}',
                        ),
                        _StatCard(
                          icon: Icons.all_inclusive_rounded,
                          label: 'Best Endless',
                          value: '${stats.bestEndlessScore}',
                        ),
                        _StatCard(
                          icon: Icons.replay_rounded,
                          label: 'Endless Runs',
                          value: '${stats.totalEndlessRuns}',
                        ),
                        _StatCard(
                          icon: Icons.grid_view_rounded,
                          label: 'Endless Boards',
                          value: '${stats.totalEndlessBoardsCleared}',
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

class _StatCard extends StatelessWidget {
  const _StatCard({
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: GameGradients.badge,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: GameShadows.light(),
            ),
            child: Icon(icon, color: Colors.white, size: 27),
          ),
          const SizedBox(height: GameSpacing.sm),
          Text(
            value,
            style: GameTextStyles.h2.copyWith(fontSize: 26),
          ),
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
