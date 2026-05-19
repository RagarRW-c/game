import 'package:flutter/material.dart';

class WinScreen extends StatelessWidget {
  const WinScreen({
    super.key,
    required this.level,
    required this.isFinalLevel,
    required this.onNext,
    required this.onRestart,
    required this.onMap,
  });

  final int level;
  final bool isFinalLevel;
  final VoidCallback onNext;
  final VoidCallback onRestart;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.94 + (value * 0.06),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.48),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 24),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFFFB300),
                    size: 76,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Level $level Clear!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFinalLevel
                        ? 'All levels are complete.'
                        : 'Level ${level + 1} is unlocked.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onNext,
                      icon: Icon(
                        isFinalLevel
                            ? Icons.pin_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        isFinalLevel ? 'Show Final Code' : 'Next Level',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Restart Level'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onMap,
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Back to Map'),
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
