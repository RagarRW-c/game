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

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
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
                    GameButton(
                      label: 'Reset progress',
                      icon: Icons.restart_alt_rounded,
                      onPressed: () async {
                        await scope.progressRepository.reset();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Progress reset')),
                          );
                        }
                      },
                      variant: GameButtonVariant.danger,
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
