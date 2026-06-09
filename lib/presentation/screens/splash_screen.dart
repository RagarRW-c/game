import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';
import 'main_menu_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const route = '/';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(MainMenuScreen.route);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.9, end: 1),
              duration: GameDurations.slow,
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Opacity(
                  opacity: scale.clamp(0.0, 1.0).toDouble(),
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      gradient: GameGradients.badge,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 5),
                      boxShadow: GameShadows.glow(GameColors.accentGold),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 70,
                    ),
                  ),
                  const SizedBox(height: GameSpacing.xl),
                  const Text(
                    'Triple Tile\nAdventure',
                    textAlign: TextAlign.center,
                    style: GameTextStyles.h1,
                  ),
                  const SizedBox(height: GameSpacing.xl),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
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
