import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import '../theme/world_theme.dart';

/// One tappable island. State is supplied by the repository-backed screen.
class AdventureLevelNode extends StatelessWidget {
  const AdventureLevelNode({
    super.key,
    required this.level,
    required this.unlocked,
    required this.completed,
    required this.current,
    required this.stars,
    required this.boss,
    required this.theme,
    required this.onTap,
  });

  final int level;
  final bool unlocked;
  final bool completed;
  final bool current;
  final int stars;
  final bool boss;
  final WorldVisualTheme theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = !unlocked
        ? 'Locked'
        : completed
            ? 'Cleared'
            : current
                ? 'Play now'
                : 'Ready';
    final colors = !unlocked
        ? const [Color(0xFF81919D), Color(0xFF465B6A)]
        : completed || boss
            ? const [Color(0xFFFFEAA0), Color(0xFFE8A84A)]
            : [Colors.white, theme.secondaryAccent];
    final ink = unlocked ? const Color(0xFF283C49) : Colors.white;
    return Semantics(
      container: true,
      button: true,
      enabled: unlocked,
      onTap: unlocked ? onTap : null,
      label:
          'Level $level, ${boss ? 'world finale, ' : ''}$status, $stars of 3 stars',
      excludeSemantics: true,
      child: AdventurePressable(
        onTap: unlocked ? onTap : null,
        borderRadius: BorderRadius.circular(boss ? 38 : 52),
        child: TweenAnimationBuilder<double>(
          // One restrained pulse on arrival, then a static ambient glow.
          // No repeating ticker or whole-map animation.
          tween: Tween(begin: 0, end: 1),
          duration: current && !MediaQuery.disableAnimationsOf(context)
              ? const Duration(milliseconds: 1200)
              : Duration.zero,
          builder: (context, value, child) => Transform.scale(
            scale: current ? 1 + .025 * math.sin(value * math.pi) : 1,
            child: child,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(boss ? 38 : 52),
              border: Border.all(
                color:
                    current || boss ? const Color(0xFFFFE7A1) : Colors.white70,
                width: boss ? 4 : 3,
              ),
              boxShadow: [
                if (current || boss)
                  BoxShadow(
                      color: theme.secondaryAccent
                          .withValues(alpha: current ? .65 : .3),
                      blurRadius: 26,
                      spreadRadius: 5),
                const BoxShadow(color: Color(0x660D2630), offset: Offset(0, 8)),
                const BoxShadow(
                    color: Color(0x330D2630),
                    blurRadius: 14,
                    offset: Offset(0, 12)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (boss)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(theme.decorationIcons.first, size: 24, color: ink),
                        const SizedBox(width: 6),
                        Icon(Icons.workspace_premium_rounded,
                            size: 30, color: ink),
                      ],
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          !unlocked
                              ? Icons.lock_rounded
                              : completed
                                  ? Icons.check_circle_rounded
                                  : Icons.play_arrow_rounded,
                          color: ink,
                          size: 22),
                      const SizedBox(width: 6),
                      Text('$level',
                          style: GameTextStyles.h2.copyWith(
                              fontSize: 26, height: 1.15, color: ink)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 3; i++)
                        Icon(
                          i <= stars
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          key: ValueKey('level_${level}_star_$i'),
                          size: 22,
                          color: i <= stars
                              ? const Color(0xFF9D5D09)
                              : ink.withValues(alpha: .5),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(boss ? 'World finale\n$status' : status,
                      textAlign: TextAlign.center,
                      style: GameTextStyles.caption
                          .copyWith(color: ink, fontSize: 13, height: 1.2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared tactile response for destinations and nodes; does not own navigation.
class AdventurePressable extends StatefulWidget {
  const AdventurePressable({
    super.key,
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  @override
  State<AdventurePressable> createState() => _AdventurePressableState();
}

class _AdventurePressableState extends State<AdventurePressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: _pressed ? .97 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 100),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: widget.borderRadius,
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: widget.child,
          ),
        ),
      );
}
