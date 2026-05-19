import 'package:flutter/material.dart';

class FinalCodeScreen extends StatelessWidget {
  const FinalCodeScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 92,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Adventure Complete!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your reward code is',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 18),
                    ],
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Back to Menu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
