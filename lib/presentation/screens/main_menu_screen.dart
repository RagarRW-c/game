import 'package:flutter/material.dart';

import '../widgets/primary_button.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  static const route = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🌈', style: TextStyle(fontSize: 76)),
                  const Text(
                    'Triple Tile\nAdventure',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 44,
                      height: 0.95,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.deepPurple, blurRadius: 10)],
                    ),
                  ),
                  const SizedBox(height: 48),
                  PrimaryButton(
                    label: 'Play',
                    icon: Icons.map_rounded,
                    onPressed: () => Navigator.pushNamed(context, MapScreen.route),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Settings',
                    icon: Icons.settings_rounded,
                    onPressed: () => Navigator.pushNamed(context, SettingsScreen.route),
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
