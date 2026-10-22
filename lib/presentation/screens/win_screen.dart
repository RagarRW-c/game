import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import '../theme/world_theme.dart';
import '../widgets/game_ui.dart';
import '../widgets/game_decoration.dart';

/// Presentation only. Rewards are granted by GameScreen before this is shown;
/// rebuilding or animating this screen never writes progress or grants rewards.
class WinScreen extends StatelessWidget {
  const WinScreen(
      {super.key,
      required this.level,
      required this.isFinalLevel,
      required this.tilesCleared,
      required this.undoUsed,
      required this.hintUsed,
      required this.shuffleUsed,
      required this.starsEarned,
      required this.coinsEarned,
      required this.xpEarned,
      required this.onNext,
      required this.onRestart,
      required this.onMap,
      this.chestLabel,
      this.isBossLevel = false,
      this.bossTitle,
      this.emblemIcon,
      this.milestoneTitle,
      this.milestoneMessage});

  final int level;
  final bool isFinalLevel;
  final bool isBossLevel;
  final int tilesCleared;
  final int undoUsed;
  final int hintUsed;
  final int shuffleUsed;
  final int starsEarned;
  final int coinsEarned;
  final int xpEarned;
  final String? chestLabel;
  final String? bossTitle;
  final IconData? emblemIcon;
  final String? milestoneTitle;
  final String? milestoneMessage;
  final VoidCallback onNext;
  final VoidCallback onRestart;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final world = WorldThemes.forLevel(level);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final primaryAction = GameButton(
        key: const ValueKey('victory_next'),
        label: isFinalLevel ? 'Final Reward' : 'Next Level',
        icon: isFinalLevel
            ? Icons.workspace_premium_rounded
            : Icons.arrow_forward_rounded,
        onPressed: onNext,
        height: 60,
        gradient: world.actionGradient);
    final secondaryActions = Column(
        key: const ValueKey('victory_secondary_actions'),
        mainAxisSize: MainAxisSize.min,
        children: [
          GameButton(
              key: const ValueKey('victory_replay'),
              label: 'Replay',
              icon: Icons.replay_rounded,
              onPressed: onRestart,
              height: 48,
              foregroundColor: world.hudGradient.colors.last,
              variant: GameButtonVariant.secondary),
          const SizedBox(height: 8),
          GameButton(
              key: const ValueKey('victory_map'),
              label: 'Back to Map',
              icon: Icons.map_rounded,
              onPressed: onMap,
              height: 48,
              gradient: world.hudGradient),
        ]);
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: GameBackground(
        worldTheme: world,
        child: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(builder: (context, constraints) {
              // Three scaled actions must not starve the description viewport.
              // Keep the primary route pinned; secondary routes join the scroll
              // only when available height per unit of text scale is limited.
              final scrollSecondaryActions = constraints.maxHeight /
                      MediaQuery.textScalerOf(context).scale(1) <
                  400;
              return Column(children: [
                Expanded(
                    child: SingleChildScrollView(
                  key: const ValueKey('victory_scroll'),
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 20),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: reducedMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                            offset: Offset(0, (1 - value) * 10), child: child)),
                    child: Column(children: [
                      Text('${world.worldName.toUpperCase()}  ·  LEVEL $level',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(
                          isFinalLevel
                              ? 'Adventure Complete!'
                              : 'Level Complete!',
                          key: const ValueKey('victory_title'),
                          textAlign: TextAlign.center,
                          style: GameTextStyles.h1.copyWith(
                              fontSize: MediaQuery.sizeOf(context).width < 360
                                  ? 30
                                  : 34,
                              height: 1.08)),
                      const SizedBox(height: 8),
                      Text(
                          isFinalLevel
                              ? 'An extraordinary journey. A brilliant finish.'
                              : isBossLevel
                                  ? '${bossTitle ?? world.worldName} defeated'
                                  : 'Beautifully matched. On to the next adventure!',
                          key: const ValueKey('victory_description'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14, height: 1.4)),
                      const SizedBox(height: 16),
                      _VictoryEmblem(
                          world: world,
                          special: isBossLevel || isFinalLevel,
                          icon: isFinalLevel
                              ? Icons.workspace_premium_rounded
                              : emblemIcon ?? Icons.emoji_events_rounded),
                      const SizedBox(height: 4),
                      VictoryStars(stars: starsEarned),
                      if (isBossLevel || isFinalLevel) ...[
                        const SizedBox(height: 8),
                        Container(
                          key: const ValueKey('victory_milestone'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              gradient: world.hudGradient,
                              borderRadius: GameRadius.largeRadius,
                              border: Border.all(
                                  color: world.secondaryAccent
                                      .withValues(alpha: 0.7))),
                          child: Column(children: [
                            Text(
                                milestoneTitle ??
                                    (isFinalLevel
                                        ? 'All worlds complete!'
                                        : 'World Complete!'),
                                key: const ValueKey('victory_milestone_title'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text(
                                isFinalLevel
                                    ? 'All 10 worlds conquered. Your final reward awaits.'
                                    : '${WorldThemes.forLevel(level + 1).worldName} · ${milestoneMessage ?? 'New world unlocked!'}',
                                key: const ValueKey(
                                    'victory_milestone_description'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.4)),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _VictoryRewards(
                          world: world,
                          coins: coinsEarned,
                          xp: xpEarned,
                          chest: chestLabel),
                      const SizedBox(height: 14),
                      Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _VictoryStat('$tilesCleared tiles cleared'),
                            _VictoryStat('Undo $undoUsed'),
                            _VictoryStat('Hint $hintUsed'),
                            _VictoryStat('Shuffle $shuffleUsed'),
                          ]),
                      if (scrollSecondaryActions) ...[
                        const SizedBox(height: 24),
                        secondaryActions,
                      ],
                    ]),
                  ),
                )),
                // A real gap separates clipped scroll content from button
                // shadows. The primary route remains reachable at every offset.
                Padding(
                  key: const ValueKey('victory_actions'),
                  padding: const EdgeInsets.only(bottom: 12, top: 20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    primaryAction,
                    if (!scrollSecondaryActions) ...[
                      const SizedBox(height: 10),
                      secondaryActions,
                    ],
                  ]),
                ),
              ]);
            }),
          ),
        ))),
      ),
    );
  }
}

class VictoryStars extends StatelessWidget {
  const VictoryStars({super.key, required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$stars of 3 stars',
        liveRegion: true,
        child: ExcludeSemantics(
            child: SizedBox(
          width: 264,
          height: 84,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 1100),
            builder: (context, value, _) => Row(children: [
              for (var i = 0; i < 3; i++)
                Expanded(child: Builder(builder: (context) {
                  final earned = i < stars;
                  final reveal =
                      ((value - i * 0.18) / 0.55).clamp(0.0, 1.0).toDouble();
                  final scale = earned
                      ? 0.72 + Curves.easeOutBack.transform(reveal) * 0.28
                      : 0.86;
                  return Transform.translate(
                    offset: Offset(0, i == 1 ? -5 : 3),
                    child: Opacity(
                      opacity: earned ? reveal : 0.45,
                      child: Transform.scale(
                          scale: scale,
                          child: Icon(
                            earned
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            key: ValueKey('victory_star_${i + 1}'),
                            size: i == 1 ? 74 : 64,
                            color:
                                earned ? const Color(0xFFFFDA6A) : Colors.white,
                            shadows: earned
                                ? const [
                                    Shadow(
                                        color: Color(0x994F2C15),
                                        offset: Offset(0, 4),
                                        blurRadius: 2)
                                  ]
                                : null,
                          )),
                    ),
                  );
                })),
            ]),
          ),
        )),
      );
}

class _VictoryEmblem extends StatelessWidget {
  const _VictoryEmblem(
      {required this.world, required this.special, required this.icon});
  final WorldVisualTheme world;
  final bool special;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: GameCelebrationHalo(
          color: world.secondaryAccent,
          child: Container(
            width: special ? 116 : 100,
            height: special ? 116 : 100,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: world.secondaryAccent.withValues(alpha: 0.55)),
                gradient: RadialGradient(colors: [
                  world.secondaryAccent.withValues(alpha: 0.32),
                  Colors.transparent
                ]),
                boxShadow: GameShadows.glow(world.primaryAccent)),
            child: Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFF0B4),
                          Color(0xFFFFCD57),
                          Color(0xFFD68B2B)
                        ]),
                    border:
                        Border.all(color: const Color(0xFFFFF5CF), width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x775A3618), offset: Offset(0, 5))
                    ]),
                child: Icon(icon,
                    size: special ? 54 : 46, color: const Color(0xFF70471C))),
          )));
}

class _VictoryRewards extends StatelessWidget {
  const _VictoryRewards(
      {required this.world,
      required this.coins,
      required this.xp,
      required this.chest});
  final WorldVisualTheme world;
  final int coins;
  final int xp;
  final String? chest;

  @override
  Widget build(BuildContext context) => GameCard(
        key: const ValueKey('victory_rewards'),
        padding: const EdgeInsets.all(16),
        borderColor: world.secondaryAccent.withValues(alpha: 0.85),
        child: Column(children: [
          Text('YOUR REWARDS',
              style: GameTextStyles.caption
                  .copyWith(letterSpacing: 2, color: GameColors.mutedInk)),
          const SizedBox(height: 14),
          Builder(builder: (context) {
            final coinAmount = _RewardAmount(
                icon: Icons.monetization_on_rounded,
                label: 'Coins',
                value: '+$coins',
                color: const Color(0xFFB4771C));
            final xpAmount = _RewardAmount(
                icon: Icons.bolt_rounded,
                label: 'XP',
                value: '+$xp',
                color: const Color(0xFF5D57AB));
            if (MediaQuery.textScalerOf(context).scale(26) > 32 ||
                coins.toString().length > 5 ||
                xp.toString().length > 5) {
              return Column(
                  children: [coinAmount, const SizedBox(height: 14), xpAmount]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: coinAmount),
              const SizedBox(width: 12),
              Expanded(child: xpAmount),
            ]);
          }),
          if (chest != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: world.primaryAccent.withValues(alpha: 0.10),
                  borderRadius: GameRadius.mediumRadius),
              child: Row(children: [
                Icon(Icons.inventory_2_rounded,
                    color: world.hudGradient.colors.first, size: 30),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Chest', style: GameTextStyles.caption),
                      Text(chest!,
                          key: const ValueKey('victory_chest'),
                          style: GameTextStyles.body
                              .copyWith(color: GameColors.ink)),
                    ])),
              ]),
            ),
          ],
        ]),
      );
}

class _RewardAmount extends StatelessWidget {
  const _RewardAmount(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(color, Colors.white, 0.82)!,
                      Color.lerp(color, Colors.white, 0.64)!
                    ]),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.22),
                      offset: const Offset(0, 3))
                ],
                borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 28)),
        const SizedBox(height: 8),
        Text(value,
            key: ValueKey('victory_reward_$label'),
            textAlign: TextAlign.center,
            style: GameTextStyles.h2
                .copyWith(fontSize: value.length > 6 ? 20 : 26)),
        Text(label, style: GameTextStyles.body.copyWith(fontSize: 13)),
      ]);
}

class _VictoryStat extends StatelessWidget {
  const _VictoryStat(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: const Color(0x33102337),
            borderRadius: GameRadius.smallRadius,
            border: Border.all(color: Colors.white24)),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
}
