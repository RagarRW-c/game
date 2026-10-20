import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import 'game_over_art.dart';
import 'game_ui.dart';

/// Presentation only. Costs, recovery and navigation stay with the caller.
class GameOverDialog extends StatelessWidget {
  const GameOverDialog({
    super.key,
    required this.canUseShuffle,
    required this.onBackToMap,
    required this.onUseShuffle,
    required this.onRestart,
  });

  final bool canUseShuffle;
  final VoidCallback onBackToMap;
  final VoidCallback onUseShuffle;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    // Leave the full button width to labels at accessibility text sizes.
    final showActionIcons = MediaQuery.textScalerOf(context).scale(19) <= 24;
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: ColoredBox(
        color: GameColors.dialogOverlay.withValues(alpha: 0.62),
        child: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  key: const ValueKey('game_over_fade'),
                  opacity: value,
                  child: Transform.scale(
                    key: const ValueKey('game_over_scale'),
                    scale: 0.92 + value * 0.08,
                    child: child,
                  ),
                ),
                // The whole card can scroll on short screens or with large
                // text. No artwork or action competes for a fixed-height slot.
                child: SingleChildScrollView(
                  key: const ValueKey('game_over_scroll'),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: GameOverPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Game Over',
                                  key: const ValueKey('game_over_title'),
                                  style: GameTextStyles.h1.copyWith(
                                    fontSize: 36,
                                    height: 1.08,
                                    letterSpacing: -1.4,
                                    color: const Color(0xFF593C6B),
                                    shadows: const [
                                      Shadow(
                                          color: Color(0x33473559),
                                          blurRadius: 8,
                                          offset: Offset(0, 5)),
                                      Shadow(
                                          color: Color(0xFFC4ACC3),
                                          offset: Offset(0, 3)),
                                      Shadow(
                                          color: Color(0xFFFFFEF5),
                                          offset: Offset(-1.2, 0)),
                                      Shadow(
                                          color: Color(0xFFFFFEF5),
                                          offset: Offset(1.2, 0)),
                                      Shadow(
                                          color: Color(0xFFFFFEF5),
                                          offset: Offset(0, -1.2)),
                                      Shadow(
                                        color: Color(0xFFFFFEF5),
                                        offset: Offset(0, 1.2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Tooltip(
                              message: 'Close',
                              child: GameRoundIconButton(
                                key: const ValueKey('game_over_close'),
                                icon: Icons.close_rounded,
                                backgroundColor: const Color(0xFFB1A0B9),
                                foregroundColor: const Color(0xFF392748),
                                // Preserve the original Close -> Map behavior.
                                onPressed: onBackToMap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const FullTrayIllustration(),
                        const SizedBox(height: 8),
                        Text(
                          'Tray is full',
                          style: GameTextStyles.h2.copyWith(
                              fontSize: 24, color: const Color(0xFF493B57)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'A fresh start, a new possibility.',
                          textAlign: TextAlign.center,
                          style: GameTextStyles.body.copyWith(
                              fontSize: 14,
                              height: 1.4,
                              color: const Color(0xFF746679)),
                        ),
                        const SizedBox(height: 24),
                        GameButton(
                          key: const ValueKey('game_over_restart'),
                          label: 'Restart',
                          wrapLabel: true,
                          sculpted: true,
                          icon: showActionIcons ? Icons.refresh_rounded : null,
                          height: 68,
                          onPressed: onRestart,
                          variant: GameButtonVariant.success,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF5FC780),
                              Color(0xFF268453),
                              Color(0xFF156343)
                            ],
                            stops: [0, 0.5, 1],
                          ),
                          foregroundColor: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        GameButton(
                          key: const ValueKey('game_over_shuffle'),
                          label: 'Use Shuffle',
                          wrapLabel: true,
                          sculpted: true,
                          icon: showActionIcons ? Icons.air_rounded : null,
                          onPressed: canUseShuffle ? onUseShuffle : null,
                          variant: GameButtonVariant.gold,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFFFE6A0),
                              Color(0xFFF4BC63),
                              Color(0xFFDD8C44)
                            ],
                            stops: [0, 0.5, 1],
                          ),
                          foregroundColor: const Color(0xFF62421E),
                        ),
                        const SizedBox(height: 20),
                        GameButton(
                          key: const ValueKey('game_over_map'),
                          label: 'Back to Map',
                          wrapLabel: true,
                          height: 52,
                          icon: showActionIcons ? Icons.map_rounded : null,
                          onPressed: onBackToMap,
                          variant: GameButtonVariant.secondary,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFF0EDF4), Color(0xFFDCD6E5)],
                          ),
                          foregroundColor: const Color(0xFF665570),
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
}
