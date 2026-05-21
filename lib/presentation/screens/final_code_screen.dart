import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';

class FinalCodeScreen extends StatelessWidget {
  const FinalCodeScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Padding(
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
                  'Adventure Complete!',
                  textAlign: TextAlign.center,
                  style: GameTextStyles.h1,
                ),
                const SizedBox(height: GameSpacing.xl),
                GameCard(
                  child: Column(
                    children: [
                      const Text('Your reward code is',
                          style: GameTextStyles.body),
                      const SizedBox(height: GameSpacing.md),
                      GameBadge(
                        gradient: GameGradients.badge,
                        child: Text(
                          code,
                          style: GameTextStyles.h2.copyWith(
                            letterSpacing: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: GameSpacing.xxl),
                GameButton(
                  label: 'Back to Menu',
                  icon: Icons.home_rounded,
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  variant: GameButtonVariant.success,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
