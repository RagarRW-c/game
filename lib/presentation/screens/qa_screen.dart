import 'package:flutter/material.dart';

import '../../core/app_flavor.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});

  static const route = '/dev-qa';

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  bool _busy = false;
  bool _progressChanged = false;

  Future<void> _run(String message, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _progressChanged = true;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _close() {
    Navigator.of(context).pop(_progressChanged);
  }

  Future<void> _confirmAndRun({
    required String title,
    required String body,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GameDialogFrame(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: GameColors.dangerRed,
              size: 64,
            ),
            const SizedBox(height: GameSpacing.md),
            Text(body, textAlign: TextAlign.center, style: GameTextStyles.body),
            const SizedBox(height: GameSpacing.xl),
            GameButton(
              label: 'Confirm',
              icon: Icons.check_rounded,
              variant: GameButtonVariant.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: GameSpacing.md),
            GameButton(
              label: 'Cancel',
              icon: Icons.close_rounded,
              variant: GameButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) await _run(successMessage, action);
  }

  @override
  Widget build(BuildContext context) {
    if (!AppFlavorConfig.qaToolsEnabled) {
      return const SizedBox.shrink();
    }

    final repository = AppScope.of(context).progressRepository;
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: Column(
              children: [
                GameHeader(
                  title: 'DEV QA Tools',
                  onBack: _close,
                  trailing: const GameBadge(
                    icon: Icons.science_rounded,
                    child: Text(
                      'DEV',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(GameSpacing.lg),
                    children: [
                      _QaSection(
                        title: 'Progress',
                        children: [
                          _QaAction(
                            icon: Icons.public_rounded,
                            label: 'Unlock All Worlds',
                            enabled: !_busy,
                            onTap: () => _run(
                              'All worlds unlocked',
                              repository.debugUnlockAllWorlds,
                            ),
                          ),
                          _QaAction(
                            icon: Icons.lock_open_rounded,
                            label: 'Unlock All Levels',
                            enabled: !_busy,
                            onTap: () => _run(
                              'All levels unlocked',
                              repository.debugUnlockAllLevels,
                            ),
                          ),
                          _QaAction(
                            icon: Icons.flag_rounded,
                            label: 'Complete Level 40 / Unlock Final Code',
                            enabled: !_busy,
                            onTap: () => _run(
                              'Level 40 and final code unlocked',
                              repository.debugCompleteLevel40,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: GameSpacing.lg),
                      _QaSection(
                        title: 'Resources',
                        children: [
                          _QaAction(
                            icon: Icons.monetization_on_rounded,
                            label: 'Add 10,000 Coins',
                            enabled: !_busy,
                            onTap: () => _run('Added 10,000 coins', () async {
                              await repository.debugAddCoins();
                            }),
                          ),
                          _QaAction(
                            icon: Icons.auto_awesome_rounded,
                            label: 'Add 10 of Each Booster',
                            enabled: !_busy,
                            onTap: () => _run(
                              'Boosters added',
                              repository.debugAddBoosters,
                            ),
                          ),
                          _QaAction(
                            icon: Icons.trending_up_rounded,
                            label: 'Add 1000 XP',
                            enabled: !_busy,
                            onTap: () => _run(
                              '1000 XP added',
                              repository.debugAddXp,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: GameSpacing.lg),
                      _QaSection(
                        title: 'Reset Tools',
                        children: [
                          _QaAction(
                            icon: Icons.casino_rounded,
                            label: 'Reset Daily Spin',
                            enabled: !_busy,
                            destructive: true,
                            onTap: () => _confirmAndRun(
                              title: 'Reset Daily Spin?',
                              body:
                                  'The daily spin will become available again.',
                              successMessage: 'Daily spin reset',
                              action: repository.debugResetDailySpin,
                            ),
                          ),
                          _QaAction(
                            icon: Icons.task_alt_rounded,
                            label: 'Reset Daily Challenges',
                            enabled: !_busy,
                            destructive: true,
                            onTap: () => _confirmAndRun(
                              title: 'Reset Daily Challenges?',
                              body:
                                  'Today\'s challenge progress and claims will be cleared.',
                              successMessage: 'Daily challenges reset',
                              action: repository.debugResetDailyChallenges,
                            ),
                          ),
                          _QaAction(
                            icon: Icons.inventory_2_rounded,
                            label: 'Reset Chests',
                            enabled: !_busy,
                            destructive: true,
                            onTap: () => _confirmAndRun(
                              title: 'Reset Chests?',
                              body:
                                  'Every stored treasure chest will be removed.',
                              successMessage: 'Chests reset',
                              action: repository.debugResetChests,
                            ),
                          ),
                          _QaAction(
                            icon: Icons.emoji_events_rounded,
                            label: 'Reset Achievements',
                            enabled: !_busy,
                            destructive: true,
                            onTap: () => _confirmAndRun(
                              title: 'Reset Achievements?',
                              body:
                                  'Achievement unlocks and related cosmetics will be cleared.',
                              successMessage: 'Achievements reset',
                              action: repository.debugResetAchievements,
                            ),
                          ),
                          _QaAction(
                            icon: Icons.collections_bookmark_rounded,
                            label: 'Reset Collection Book',
                            enabled: !_busy,
                            destructive: true,
                            onTap: () => _confirmAndRun(
                              title: 'Reset Collection Book?',
                              body:
                                  'All discovered collection entries will be cleared.',
                              successMessage: 'Collection Book reset',
                              action: repository.debugResetCollectionBook,
                            ),
                          ),
                          _QaAction(
                            icon: Icons.delete_forever_rounded,
                            label: 'Clear All Progress',
                            enabled: !_busy,
                            destructive: true,
                            onTap: () => _confirmAndRun(
                              title: 'Clear All Progress?',
                              body:
                                  'All game progress will be erased. Audio settings are kept.',
                              successMessage: 'All progress cleared',
                              action: repository.resetProgress,
                            ),
                          ),
                        ],
                      ),
                      if (_busy) ...[
                        const SizedBox(height: GameSpacing.lg),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QaSection extends StatelessWidget {
  const _QaSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GameTextStyles.h2.copyWith(fontSize: 22)),
          const SizedBox(height: GameSpacing.md),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const SizedBox(height: GameSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _QaAction extends StatelessWidget {
  const _QaAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? GameColors.dangerRed : GameColors.primaryBlue;
    return Material(
      color: Colors.white.withValues(alpha: enabled ? 0.78 : 0.44),
      borderRadius: GameRadius.largeRadius,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: GameRadius.largeRadius,
        child: Padding(
          padding: const EdgeInsets.all(GameSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: GameSpacing.md),
              Expanded(child: Text(label, style: GameTextStyles.body)),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
