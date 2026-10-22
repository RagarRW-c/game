import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../theme/game_theme.dart';
import 'game_decoration.dart';
import 'game_ui.dart';

/// Displays an already-earned achievement. Persistence and dismissal timing
/// belong to the caller; rebuilding this widget cannot grant a reward.
class AchievementRewardDialog extends StatelessWidget {
  const AchievementRewardDialog({
    super.key,
    required this.definition,
    required this.onClose,
  });

  final AchievementDefinition definition;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: ColoredBox(
          color: GameColors.dialogOverlay.withValues(alpha: 0.62),
          child: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      key: const ValueKey('achievement_fade'),
                      opacity: value,
                      child: Transform.scale(
                        key: const ValueKey('achievement_scale'),
                        scale: 0.92 + value * 0.08,
                        child: child,
                      ),
                    ),
                    child: GameCard(
                      key: const ValueKey('achievement_panel'),
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                      borderColor: const Color(0xFFFFE8B7),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF2E9FA),
                          Color(0xFFFFF9EC),
                          Color(0xFFF3E3CE)
                        ],
                        stops: [0, 0.52, 1],
                      ),
                      shadow: const [
                        BoxShadow(
                            color: Color(0xFF92798C), offset: Offset(0, 6)),
                        BoxShadow(
                            color: Color(0x66151E3F),
                            blurRadius: 26,
                            offset: Offset(0, 14)),
                      ],
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Art and Close have separate columns outside the
                          // scroll clip. Reading a long title or its reward must
                          // never leave half a medal at the viewport edge.
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  width: 48,
                                  child: ExcludeSemantics(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Icon(Icons.auto_awesome_rounded,
                                          color: Color(0xFFB18447), size: 28),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Center(
                                    child: _AchievementTrophy(
                                      size: MediaQuery.sizeOf(context).height <
                                                  650 ||
                                              MediaQuery.textScalerOf(context)
                                                      .scale(1) >
                                                  1.3
                                          ? 104
                                          : 160,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Close',
                                  child: GameRoundIconButton(
                                    key: const ValueKey('achievement_close'),
                                    icon: Icons.close_rounded,
                                    backgroundColor: const Color(0xFFE3D8EB),
                                    foregroundColor: const Color(0xFF5F496F),
                                    onPressed: onClose,
                                  ),
                                ),
                              ]),
                          Flexible(
                            child: SingleChildScrollView(
                              key: const ValueKey('achievement_scroll'),
                              padding: const EdgeInsets.only(top: 4, bottom: 8),
                              child: Column(children: [
                                Text.rich(
                                  TextSpan(children: [
                                    TextSpan(
                                        text: 'Achievement\n',
                                        style: GameTextStyles.body.copyWith(
                                            fontSize: 20,
                                            color: const Color(0xFF715C83))),
                                    const TextSpan(text: 'Unlocked!'),
                                  ]),
                                  key: const ValueKey('achievement_heading'),
                                  semanticsLabel: 'Achievement Unlocked!',
                                  textAlign: TextAlign.center,
                                  style: GameTextStyles.h2.copyWith(
                                    fontSize:
                                        MediaQuery.sizeOf(context).width < 360
                                            ? 24
                                            : 28,
                                    height: 1.15,
                                    color: const Color(0xFF583E70),
                                    shadows: const [
                                      Shadow(
                                          color: Colors.white,
                                          offset: Offset(0, 2)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  definition.name,
                                  key: const ValueKey('achievement_name'),
                                  textAlign: TextAlign.center,
                                  style: GameTextStyles.h2.copyWith(
                                      fontSize: 22,
                                      height: 1.25,
                                      color: const Color(0xFF493B57)),
                                ),
                                const SizedBox(height: 20),
                                _CoinReward(reward: definition.reward),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _AchievementTrophy extends StatelessWidget {
  const _AchievementTrophy({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: IgnorePointer(
          child: SizedBox(
            key: const ValueKey('achievement_trophy'),
            width: size,
            height: size,
            child: FittedBox(
              child: SizedBox(
                width: 160,
                height: 160,
                child: GameCelebrationHalo(
                  color: const Color(0xFFDBAC54),
                  child: Center(
                    child: Container(
                      key: const ValueKey('achievement_medal'),
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFFBDA),
                            Color(0xFFF4CB79),
                            Color(0xFFD59A47)
                          ],
                        ),
                        border: Border.all(
                            color: const Color(0xFFFFFADE), width: 3),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0xFFAE7B43), offset: Offset(0, 5)),
                          BoxShadow(
                              color: Color(0x33B47A40),
                              blurRadius: 18,
                              offset: Offset(0, 10)),
                        ],
                      ),
                      child: const Icon(Icons.emoji_events_rounded,
                          size: 86,
                          color: Color(0xFFFFF5CD),
                          shadows: [
                            Shadow(
                                color: Color(0xFFAF793A), offset: Offset(0, 3)),
                            Shadow(
                                color: Color(0x4492542E),
                                blurRadius: 6,
                                offset: Offset(0, 5)),
                          ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _CoinReward extends StatelessWidget {
  const _CoinReward({required this.reward});
  final int reward;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('achievement_reward_badge'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEDB7), Color(0xFFF3C46D)],
          ),
          border: Border.all(color: const Color(0xFFFFFADE), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0xFFC99C54), offset: Offset(0, 4)),
            BoxShadow(
                color: Color(0x22956432), blurRadius: 10, offset: Offset(0, 7)),
          ],
        ),
        child: Column(children: [
          const ExcludeSemantics(
              child: Icon(Icons.monetization_on_rounded,
                  color: Color(0xFFAB7429), size: 30)),
          const SizedBox(height: 6),
          Text('+$reward coins',
              key: const ValueKey('achievement_reward'),
              textAlign: TextAlign.center,
              style: GameTextStyles.button.copyWith(
                  fontSize: 20, height: 1.25, color: const Color(0xFF67441E))),
        ]),
      );
}
