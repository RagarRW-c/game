import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';

class DailyChallengesScreen extends StatefulWidget {
  const DailyChallengesScreen({super.key});

  static const route = '/daily-challenges';

  @override
  State<DailyChallengesScreen> createState() => _DailyChallengesScreenState();
}

class _DailyChallengesScreenState extends State<DailyChallengesScreen> {
  DailyChallengesState? _state;
  int _coins = 0;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    final repository = AppScope.of(context).progressRepository;
    final state = await repository.dailyChallenges();
    final coins = await repository.coins();
    if (!mounted) return;
    setState(() {
      _state = state;
      _coins = coins;
      _loading = false;
    });
  }

  Future<void> _claim(DailyChallengeId id) async {
    final repository = AppScope.of(context).progressRepository;
    final updatedCoins = await repository.claimDailyChallenge(id);
    final state = await repository.dailyChallenges();
    if (!mounted) return;
    if (updatedCoins == null) {
      setState(() => _state = state);
      return;
    }
    setState(() {
      _coins = updatedCoins;
      _state = state;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(
                title: 'Daily Challenges',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: GameBadge(
                  icon: Icons.monetization_on_rounded,
                  gradient: GameGradients.badge,
                  child: Text(
                    '$_coins',
                    style: GameTextStyles.button.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading || state == null
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(GameSpacing.lg),
                        children: [
                          GameCard(
                            padding: const EdgeInsets.all(GameSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Today',
                                  style: GameTextStyles.h2.copyWith(
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: GameSpacing.xs),
                                Text(
                                  state.dateKey,
                                  style: GameTextStyles.body,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: GameSpacing.lg),
                          _ChallengeCard(
                            icon: Icons.emoji_events_rounded,
                            title: 'Complete 1 level',
                            progress: state.completedLevels > 1
                                ? 1
                                : state.completedLevels,
                            target: 1,
                            reward: 100,
                            claimed: state.completeLevelClaimed,
                            onClaim: state.completedLevels >= 1 &&
                                    !state.completeLevelClaimed
                                ? () => _claim(DailyChallengeId.completeLevel)
                                : null,
                          ),
                          const SizedBox(height: GameSpacing.md),
                          _ChallengeCard(
                            icon: Icons.grid_view_rounded,
                            title: 'Match 30 tiles',
                            progress: state.matchedTiles > 30
                                ? 30
                                : state.matchedTiles,
                            target: 30,
                            reward: 75,
                            claimed: state.matchTilesClaimed,
                            onClaim: state.matchedTiles >= 30 &&
                                    !state.matchTilesClaimed
                                ? () => _claim(DailyChallengeId.matchTiles)
                                : null,
                          ),
                          const SizedBox(height: GameSpacing.md),
                          _ChallengeCard(
                            icon: Icons.casino_rounded,
                            title: 'Use Lucky Wheel',
                            progress: state.luckyWheelUsed ? 1 : 0,
                            target: 1,
                            reward: 50,
                            claimed: state.luckyWheelClaimed,
                            onClaim: state.luckyWheelUsed &&
                                    !state.luckyWheelClaimed
                                ? () => _claim(DailyChallengeId.useLuckyWheel)
                                : null,
                          ),
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

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.icon,
    required this.title,
    required this.progress,
    required this.target,
    required this.reward,
    required this.claimed,
    required this.onClaim,
  });

  final IconData icon;
  final String title;
  final int progress;
  final int target;
  final int reward;
  final bool claimed;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final complete = progress >= target;
    return GameCard(
      padding: const EdgeInsets.all(GameSpacing.lg),
      shadow: complete ? GameShadows.glow(GameColors.successGreen) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: complete
                      ? GameGradients.successButton
                      : GameGradients.primaryButton,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: GameShadows.light(),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: GameSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GameTextStyles.body.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: GameSpacing.xs),
                    Text(
                      '$progress/$target',
                      style: GameTextStyles.caption,
                    ),
                  ],
                ),
              ),
              GameBadge(
                icon: Icons.monetization_on_rounded,
                gradient: GameGradients.badge,
                child: Text(
                  '$reward',
                  style: GameTextStyles.caption.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: GameSpacing.md),
          ClipRRect(
            borderRadius: GameRadius.smallRadius,
            child: LinearProgressIndicator(
              minHeight: 10,
              value: (progress / target).clamp(0, 1).toDouble(),
              backgroundColor: GameColors.borderBlue,
              color:
                  complete ? GameColors.successGreen : GameColors.primaryBlue,
            ),
          ),
          const SizedBox(height: GameSpacing.lg),
          GameButton(
            label: claimed ? 'Claimed' : 'Claim',
            icon: claimed ? Icons.check_rounded : Icons.card_giftcard_rounded,
            onPressed: claimed ? null : onClaim,
            variant: complete
                ? GameButtonVariant.success
                : GameButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}
