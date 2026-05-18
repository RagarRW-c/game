import 'package:flutter/material.dart';

class WinScreen extends StatelessWidget {
  const WinScreen({
    super.key,
    required this.level,
    required this.isFinalLevel,
    required this.onNext,
    required this.onMap,
  });

  final int level;
  final bool isFinalLevel;
  final VoidCallback onNext;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.48)),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(34)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 72)),
                Text('Level $level Clear!', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onNext,
                  icon: Icon(isFinalLevel ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded),
                  label: Text(isFinalLevel ? 'Reveal Code' : 'Next Level'),
                ),
                TextButton(onPressed: onMap, child: const Text('Map')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
