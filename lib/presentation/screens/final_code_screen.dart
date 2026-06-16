import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/progress_repository.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';

class FinalCodeScreen extends StatefulWidget {
  const FinalCodeScreen({super.key});

  static const route = '/final-code';

  @override
  State<FinalCodeScreen> createState() => _FinalCodeScreenState();
}

class _FinalCodeScreenState extends State<FinalCodeScreen> {
  late Future<FinalRewardSummary?> _summaryFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _summaryFuture =
        AppScope.of(context).progressRepository.finalRewardSummary();
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copied')),
    );
  }

  void _backToMainMenu() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: FutureBuilder<FinalRewardSummary?>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              final summary = snapshot.data;
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (summary == null) {
                return _LockedFinalReward(onBack: _backToMainMenu);
              }
              return _FinalRewardContent(
                summary: summary,
                onCopyCode: () => _copyCode(summary.code),
                onBackToMainMenu: _backToMainMenu,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FinalRewardContent extends StatelessWidget {
  const _FinalRewardContent({
    required this.summary,
    required this.onCopyCode,
    required this.onBackToMainMenu,
  });

  final FinalRewardSummary summary;
  final VoidCallback onCopyCode;
  final VoidCallback onBackToMainMenu;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.88, end: 1),
      duration: GameDurations.normal,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Opacity(
          opacity: scale.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GameSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  gradient: GameGradients.badge,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: GameShadows.glow(GameColors.accentGold),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 62,
                ),
              ),
              const SizedBox(height: GameSpacing.lg),
              const Text(
                'Congratulations!',
                textAlign: TextAlign.center,
                style: GameTextStyles.h1,
              ),
              const SizedBox(height: GameSpacing.sm),
              Text(
                'You completed all worlds.',
                textAlign: TextAlign.center,
                style: GameTextStyles.title.copyWith(fontSize: 20),
              ),
              const SizedBox(height: GameSpacing.xl),
              GameCard(
                child: Column(
                  children: [
                    const Text('Your reward code', style: GameTextStyles.body),
                    const SizedBox(height: GameSpacing.md),
                    GameBadge(
                      gradient: GameGradients.badge,
                      child: Text(
                        summary.code,
                        style: GameTextStyles.h2.copyWith(
                          letterSpacing: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: GameSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryBadge(
                            icon: Icons.star_rounded,
                            label: 'Total stars',
                            value: '${summary.totalStars}',
                          ),
                        ),
                        const SizedBox(width: GameSpacing.sm),
                        Expanded(
                          child: _SummaryBadge(
                            icon: Icons.flag_rounded,
                            label: 'Levels completed',
                            value: '${summary.levelsCompleted}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: GameSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryBadge(
                            icon: Icons.emoji_events_rounded,
                            label: 'Achievements unlocked',
                            value: '${summary.achievementsUnlocked}',
                          ),
                        ),
                        const SizedBox(width: GameSpacing.sm),
                        Expanded(
                          child: _SummaryBadge(
                            icon: Icons.collections_bookmark_rounded,
                            label: 'Collections completed',
                            value: '${summary.collectionsCompleted}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: GameSpacing.xxl),
              GameButton(
                label: 'Copy Code',
                icon: Icons.copy_rounded,
                onPressed: onCopyCode,
                variant: GameButtonVariant.gold,
              ),
              const SizedBox(height: GameSpacing.md),
              GameButton(
                label: 'Back to Main Menu',
                icon: Icons.home_rounded,
                onPressed: onBackToMainMenu,
                variant: GameButtonVariant.success,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GameBadge(
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GameTextStyles.caption.copyWith(color: Colors.white)),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameTextStyles.button.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

class _LockedFinalReward extends StatelessWidget {
  const _LockedFinalReward({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GameCard(
        margin: const EdgeInsets.all(GameSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_rounded,
              color: GameColors.mutedInk,
              size: 72,
            ),
            const SizedBox(height: GameSpacing.md),
            const Text('Reward Locked', style: GameTextStyles.h2),
            const SizedBox(height: GameSpacing.sm),
            const Text(
              'Complete Level 40 to unlock the final reward.',
              textAlign: TextAlign.center,
              style: GameTextStyles.body,
            ),
            const SizedBox(height: GameSpacing.xl),
            GameButton(
              label: 'Back to Main Menu',
              icon: Icons.home_rounded,
              onPressed: onBack,
              variant: GameButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
