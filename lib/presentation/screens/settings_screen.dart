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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final music = await scope.progressRepository.musicEnabled();
    final sfx = await scope.progressRepository.sfxEnabled();
    if (!mounted) return;
    setState(() {
      _music = music;
      _sfx = sfx;
    });
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
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _SettingsIcon(icon: Icons.music_note_rounded),
                              _SettingsIcon(icon: Icons.volume_up_rounded),
                              _SettingsIcon(icon: Icons.notifications_rounded),
                            ],
                          ),
                          const SizedBox(height: GameSpacing.lg),
                          _SettingsSwitch(
                            icon: Icons.music_note_rounded,
                            label: 'Background music',
                            value: _music,
                            onChanged: (value) async {
                              setState(() => _music = value);
                              await scope.progressRepository
                                  .setMusicEnabled(value);
                              await scope.audioService.setMusicEnabled(value);
                            },
                          ),
                          const SizedBox(height: GameSpacing.sm),
                          _SettingsSwitch(
                            icon: Icons.volume_up_rounded,
                            label: 'Sound effects',
                            value: _sfx,
                            onChanged: (value) async {
                              setState(() => _sfx = value);
                              scope.audioService.sfxEnabled = value;
                              await scope.progressRepository
                                  .setSfxEnabled(value);
                            },
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
  const _SettingsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: GameGradients.successButton,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: GameShadows.medium(GameColors.successGreen),
      ),
      child: Icon(icon, color: Colors.white, size: 30),
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
