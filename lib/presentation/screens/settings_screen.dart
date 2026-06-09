import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const route = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _music = true;
  bool _sfx = true;
  bool _vibration = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final music = await scope.progressRepository.musicEnabled();
    final sfx = await scope.progressRepository.sfxEnabled();
    final vibration = await scope.progressRepository.vibrationEnabled();
    if (!mounted) return;
    setState(() {
      _music = music;
      _sfx = sfx;
      _vibration = vibration;
    });
  }

  Future<void> _setMusicEnabled(bool value) async {
    final scope = AppScope.of(context);
    setState(() => _music = value);
    await scope.progressRepository.setMusicEnabled(value);
    await scope.audioService.setMusicEnabled(value);
  }

  Future<void> _setSfxEnabled(bool value) async {
    final scope = AppScope.of(context);
    setState(() => _sfx = value);
    scope.audioService.sfxEnabled = value;
    await scope.progressRepository.setSfxEnabled(value);
  }

  Future<void> _setVibrationEnabled(bool value) async {
    final scope = AppScope.of(context);
    setState(() => _vibration = value);
    await scope.progressRepository.setVibrationEnabled(value);
  }

  Future<void> _showInfoDialog({
    required String title,
    required IconData icon,
    required String body,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => GameDialogFrame(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: GameColors.primaryBlue, size: 64),
            const SizedBox(height: GameSpacing.lg),
            Text(body, textAlign: TextAlign.center, style: GameTextStyles.body),
            const SizedBox(height: GameSpacing.xl),
            GameButton(
              label: 'Close',
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
              variant: GameButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GameDialogFrame(
        title: 'Reset Progress?',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: GameColors.dangerRed,
              size: 68,
            ),
            const SizedBox(height: GameSpacing.md),
            const Text(
              'This removes levels, coins, boosters, rewards, achievements, '
              'statistics, chests, and cosmetics. Audio settings are kept.',
              textAlign: TextAlign.center,
              style: GameTextStyles.body,
            ),
            const SizedBox(height: GameSpacing.xl),
            GameButton(
              label: 'Reset Progress',
              icon: Icons.delete_forever_rounded,
              onPressed: () => Navigator.of(context).pop(true),
              variant: GameButtonVariant.danger,
            ),
            const SizedBox(height: GameSpacing.md),
            GameButton(
              label: 'Cancel',
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(false),
              variant: GameButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppScope.of(context).progressRepository.resetProgress();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress reset')),
    );
  }

  Future<void> _runQaAction(
    String message,
    Future<void> Function() action,
  ) async {
    await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(
                title: 'Settings',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(GameSpacing.lg),
                  children: [
                    GameCard(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _SettingsIcon(
                                icon: Icons.music_note_rounded,
                                label: 'Music',
                                enabled: _music,
                                onTap: () => _setMusicEnabled(!_music),
                              ),
                              _SettingsIcon(
                                icon: Icons.volume_up_rounded,
                                label: 'Sound effects',
                                enabled: _sfx,
                                onTap: () => _setSfxEnabled(!_sfx),
                              ),
                              _SettingsIcon(
                                icon: Icons.vibration_rounded,
                                label: 'Vibration',
                                enabled: _vibration,
                                onTap: () => _setVibrationEnabled(!_vibration),
                              ),
                            ],
                          ),
                          const SizedBox(height: GameSpacing.lg),
                          _SettingsSwitch(
                            icon: Icons.music_note_rounded,
                            label: 'Background music',
                            value: _music,
                            onChanged: _setMusicEnabled,
                          ),
                          const SizedBox(height: GameSpacing.sm),
                          _SettingsSwitch(
                            icon: Icons.volume_up_rounded,
                            label: 'Sound effects',
                            value: _sfx,
                            onChanged: _setSfxEnabled,
                          ),
                          const SizedBox(height: GameSpacing.sm),
                          _SettingsSwitch(
                            icon: Icons.vibration_rounded,
                            label: 'Vibration',
                            value: _vibration,
                            onChanged: _setVibrationEnabled,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: GameSpacing.lg),
                    _SettingsSection(
                      title: 'About',
                      children: [
                        _SettingsAction(
                          icon: Icons.privacy_tip_rounded,
                          label: 'Privacy Policy',
                          onTap: () => _showInfoDialog(
                            title: 'Privacy Policy',
                            icon: Icons.privacy_tip_rounded,
                            body: 'Triple Tile Adventure stores game progress '
                                'and preferences locally on your device. The '
                                'game does not require an account or collect '
                                'personal information.',
                          ),
                        ),
                        _SettingsAction(
                          icon: Icons.description_rounded,
                          label: 'Terms of Service',
                          onTap: () => _showInfoDialog(
                            title: 'Terms of Service',
                            icon: Icons.description_rounded,
                            body: 'Triple Tile Adventure is provided for '
                                'personal entertainment. Progress and rewards '
                                'are stored locally and may be lost when app '
                                'data is removed.',
                          ),
                        ),
                        _SettingsAction(
                          icon: Icons.favorite_rounded,
                          label: 'Credits',
                          onTap: () => _showInfoDialog(
                            title: 'Credits',
                            icon: Icons.favorite_rounded,
                            body: 'Triple Tile Adventure\n'
                                'Design, development, and original game assets.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: GameSpacing.lg),
                    _SettingsSection(
                      title: 'Data',
                      children: [
                        _SettingsAction(
                          icon: Icons.restart_alt_rounded,
                          label: 'Reset Progress',
                          color: GameColors.dangerRed,
                          onTap: _confirmResetProgress,
                        ),
                      ],
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: GameSpacing.lg),
                      const _QaMenu(),
                    ],
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

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

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = GameColors.primaryBlue,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.74),
      borderRadius: GameRadius.largeRadius,
      child: InkWell(
        borderRadius: GameRadius.largeRadius,
        onTap: onTap,
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

class _QaMenu extends StatelessWidget {
  const _QaMenu();

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).progressRepository;
    final state = context.findAncestorStateOfType<_SettingsScreenState>()!;
    return _SettingsSection(
      title: 'Debug QA',
      children: [
        _SettingsAction(
          icon: Icons.lock_open_rounded,
          label: 'Unlock All Worlds',
          onTap: () => state._runQaAction(
            'All worlds unlocked',
            repository.debugUnlockAllWorlds,
          ),
        ),
        _SettingsAction(
          icon: Icons.monetization_on_rounded,
          label: 'Add 1000 Coins',
          onTap: () => state._runQaAction('1000 coins added', () async {
            await repository.debugAddCoins();
          }),
        ),
        _SettingsAction(
          icon: Icons.casino_rounded,
          label: 'Reset Daily Spin',
          onTap: () => state._runQaAction(
            'Daily spin reset',
            repository.debugResetDailySpin,
          ),
        ),
        _SettingsAction(
          icon: Icons.task_alt_rounded,
          label: 'Reset Daily Challenges',
          onTap: () => state._runQaAction(
            'Daily challenges reset',
            repository.debugResetDailyChallenges,
          ),
        ),
        _SettingsAction(
          icon: Icons.delete_forever_rounded,
          label: 'Reset Progress',
          color: GameColors.dangerRed,
          onTap: state._confirmResetProgress,
        ),
      ],
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedOpacity(
          duration: GameDurations.quick,
          opacity: enabled ? 1 : 0.62,
          child: AnimatedContainer(
            duration: GameDurations.normal,
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: enabled
                  ? GameGradients.successButton
                  : GameGradients.disabled,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: GameShadows.medium(
                enabled ? GameColors.successGreen : GameColors.mutedInk,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GameSpacing.md,
        vertical: GameSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: GameRadius.largeRadius,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: GameColors.primaryBlue),
          const SizedBox(width: GameSpacing.md),
          Expanded(child: Text(label, style: GameTextStyles.body)),
          Switch(
            value: value,
            activeThumbColor: GameColors.successGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
