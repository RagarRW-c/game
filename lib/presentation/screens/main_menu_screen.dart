import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';
import '../widgets/primary_button.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  static const route = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(GameSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      gradient: GameGradients.badge,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: GameShadows.glow(GameColors.accentGold),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 58,
                    ),
                  ),
                  const SizedBox(height: GameSpacing.lg),
                  const Text(
                    'Triple Tile\nAdventure',
                    textAlign: TextAlign.center,
                    style: GameTextStyles.h1,
                  ),
                  const SizedBox(height: GameSpacing.xxl),
                  PrimaryButton(
                    label: 'Play',
                    icon: Icons.map_rounded,
                    onPressed: () =>
                        Navigator.pushNamed(context, MapScreen.route),
                  ),
                  const SizedBox(height: GameSpacing.md),
                  PrimaryButton(
                    label: 'Settings',
                    icon: Icons.settings_rounded,
                    onPressed: () =>
                        Navigator.pushNamed(context, SettingsScreen.route),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
