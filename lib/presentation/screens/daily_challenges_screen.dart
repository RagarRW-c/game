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
    final result = await repository.claimDailyChallengeReward(id);
    final state = await repository.dailyChallenges();
    if (!mounted) return;
    if (result.message != null) _showMessage(result.message!);
    setState(() {
      _coins = result.coins;
      _state = state;
    });
  }

  Future<void> _claimBonus() async {
    final repository = AppScope.of(context).progressRepository;
    final result = await repository.claimDailyChallengeBonus();
    final state = await repository.dailyChallenges();
    if (!mounted) return;
    if (result.message != null) _showMessage(result.message!);
    setState(() {
      _coins = result.coins;
      _state = state;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                                Row(
                                  children: [
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        gradient: GameGradients.primaryButton,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        boxShadow: GameShadows.light(),
                                      ),
                                      child: const Icon(
                                        Icons.task_alt_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(width: GameSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Today',
                                            style: GameTextStyles.h2.copyWith(
                                              fontSize: 24,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: GameSpacing.xs,
                                          ),
                                          Text(
                                            state.dateKey,
                                            style: GameTextStyles.body,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: GameSpacing.lg),
                          for (final challenge in state.challenges) ...[
                            _ChallengeCard(
                              entry: challenge,
                              onClaim: challenge.complete && !challenge.claimed
                                  ? () => _claim(challenge.definition.id)
                                  : null,
                            ),
                            const SizedBox(height: GameSpacing.md),
                          ],
                          _BonusCard(
                            state: state,
                            onClaim: state.bonusAvailable
                                ? () => _claimBonus()
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
    required this.entry,
    required this.onClaim,
  });

  final DailyChallengeEntry entry;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final complete = entry.complete;
    final definition = entry.definition;
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
                child: Icon(
                  _challengeIcon(definition.id),
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: GameSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.title,
                      style: GameTextStyles.body.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: GameSpacing.xs),
                    Text(
                      '${entry.cappedProgress}/${definition.target}',
                      style: GameTextStyles.caption,
                    ),
                  ],
                ),
              ),
              _RewardBadge(definition: definition),
            ],
          ),
          const SizedBox(height: GameSpacing.md),
          ClipRRect(
            borderRadius: GameRadius.smallRadius,
            child: LinearProgressIndicator(
              minHeight: 10,
              value: (entry.cappedProgress / definition.target)
                  .clamp(0, 1)
                  .toDouble(),
              backgroundColor: GameColors.borderBlue,
              color:
                  complete ? GameColors.successGreen : GameColors.primaryBlue,
            ),
          ),
          const SizedBox(height: GameSpacing.lg),
          GameButton(
            label: entry.claimed ? 'Claimed' : 'Claim',
            icon: entry.claimed
                ? Icons.check_rounded
                : Icons.card_giftcard_rounded,
            onPressed: entry.claimed ? null : onClaim,
            variant: complete
                ? GameButtonVariant.success
                : GameButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}

class _BonusCard extends StatelessWidget {
  const _BonusCard({required this.state, required this.onClaim});

  final DailyChallengesState state;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final complete = state.allClaimed;
    return GameCard(
      padding: const EdgeInsets.all(GameSpacing.lg),
      borderColor: complete ? GameColors.accentGold : Colors.white,
      shadow: complete
          ? GameShadows.glow(GameColors.accentGold)
          : GameShadows.medium(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient:
                      complete ? GameGradients.badge : GameGradients.darkBadge,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: GameShadows.light(),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
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
                      'Daily Bonus',
                      style: GameTextStyles.body.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: GameSpacing.xs),
                    Text(
                      '+300 coins and Silver Chest',
                      style: GameTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: GameSpacing.lg),
          GameButton(
            label: state.bonusClaimed ? 'Claimed' : 'Claim Bonus',
            icon:
                state.bonusClaimed ? Icons.check_rounded : Icons.redeem_rounded,
            onPressed: state.bonusClaimed ? null : onClaim,
            variant:
                complete ? GameButtonVariant.gold : GameButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}

class _RewardBadge extends StatelessWidget {
  const _RewardBadge({required this.definition});

  final DailyChallengeDefinition definition;

  @override
  Widget build(BuildContext context) {
    return GameBadge(
      icon: _rewardIcon(definition.rewardType),
      gradient: GameGradients.badge,
      child: Text(
        definition.rewardLabel,
        style: GameTextStyles.caption.copyWith(color: Colors.white),
      ),
    );
  }
}

IconData _challengeIcon(DailyChallengeId id) {
  switch (id) {
    case DailyChallengeId.completeTwoLevels:
      return Icons.flag_rounded;
    case DailyChallengeId.matchTiles:
      return Icons.grid_view_rounded;
    case DailyChallengeId.useLuckyWheel:
      return Icons.casino_rounded;
    case DailyChallengeId.openChest:
      return Icons.inventory_2_rounded;
    case DailyChallengeId.earnCoins:
      return Icons.monetization_on_rounded;
    case DailyChallengeId.useBooster:
      return Icons.auto_awesome_rounded;
    case DailyChallengeId.completeBossLevel:
      return Icons.workspace_premium_rounded;
  }
}

IconData _rewardIcon(DailyChallengeRewardType type) {
  switch (type) {
    case DailyChallengeRewardType.coins:
      return Icons.monetization_on_rounded;
    case DailyChallengeRewardType.hintBooster:
      return Icons.lightbulb_rounded;
    case DailyChallengeRewardType.shuffleBooster:
      return Icons.shuffle_rounded;
    case DailyChallengeRewardType.silverChest:
    case DailyChallengeRewardType.goldChest:
      return Icons.inventory_2_rounded;
  }
}
