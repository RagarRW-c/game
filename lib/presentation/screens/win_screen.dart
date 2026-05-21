import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import '../widgets/game_ui.dart';

class WinScreen extends StatelessWidget {
  const WinScreen({
    super.key,
    required this.level,
    required this.isFinalLevel,
    required this.tilesCleared,
    required this.undoUsed,
    required this.hintUsed,
    required this.shuffleUsed,
    required this.onNext,
    required this.onRestart,
    required this.onMap,
  });

  final int level;
  final bool isFinalLevel;
  final int tilesCleared;
  final int undoUsed;
  final int hintUsed;
  final int shuffleUsed;
  final VoidCallback onNext;
  final VoidCallback onRestart;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return GameDialogFrame(
      title: 'Level Complete',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 12,
            top: -8,
            child: _ParticleDot(size: 10, color: GameColors.accentGold),
          ),
          const Positioned(
            right: 28,
            top: 14,
            child: _ParticleDot(size: 8, color: GameColors.primaryBlueLight),
          ),
          const Positioned(
            right: 8,
            bottom: 126,
            child: _ParticleDot(size: 12, color: GameColors.secondaryPurple),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: GameGradients.badge,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: GameShadows.glow(GameColors.accentGold),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: GameSpacing.md),
              Text(
                isFinalLevel
                    ? 'All levels are complete.'
                    : 'Level ${level + 1} is unlocked.',
                textAlign: TextAlign.center,
                style: GameTextStyles.body,
              ),
              const SizedBox(height: GameSpacing.lg),
              _StatsPanel(
                tilesCleared: tilesCleared,
                undoUsed: undoUsed,
                hintUsed: hintUsed,
                shuffleUsed: shuffleUsed,
              ),
              const SizedBox(height: GameSpacing.xl),
              GameButton(
                label: isFinalLevel ? 'Show Final Code' : 'Next Level',
                icon: isFinalLevel
                    ? Icons.pin_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: onNext,
                variant: GameButtonVariant.success,
              ),
              const SizedBox(height: GameSpacing.md),
              GameButton(
                label: 'Replay',
                icon: Icons.refresh_rounded,
                onPressed: onRestart,
                variant: GameButtonVariant.secondary,
              ),
              TextButton.icon(
                onPressed: onMap,
                icon: const Icon(Icons.map_rounded),
                label: const Text('Back to Map'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.tilesCleared,
    required this.undoUsed,
    required this.hintUsed,
    required this.shuffleUsed,
  });

  final int tilesCleared;
  final int undoUsed;
  final int hintUsed;
  final int shuffleUsed;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      padding: const EdgeInsets.all(GameSpacing.md),
      shadow: GameShadows.light(),
      borderColor: GameColors.borderBlue,
      child: Column(
        children: [
          _StatRow(
            icon: Icons.check_circle_rounded,
            label: 'Tiles cleared',
            value: '$tilesCleared',
          ),
          const SizedBox(height: GameSpacing.sm),
          _StatRow(
            icon: Icons.auto_awesome_rounded,
            label: 'Boosters used',
            value: 'Undo $undoUsed  Hint $hintUsed  Shuffle $shuffleUsed',
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: GameColors.primaryBlue, size: 22),
        const SizedBox(width: GameSpacing.sm),
        Expanded(
          child: Text(label, style: GameTextStyles.body),
        ),
        Text(
          value,
          style: GameTextStyles.body.copyWith(color: GameColors.ink),
        ),
      ],
    );
  }
}

class _ParticleDot extends StatelessWidget {
  const _ParticleDot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: GameShadows.glow(color),
      ),
      child: SizedBox(width: size, height: size),
    );
  }
}
