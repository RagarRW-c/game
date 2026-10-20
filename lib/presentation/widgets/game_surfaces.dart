import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import '../theme/world_theme.dart';

// These decorations deliberately retain the original 2px board and 3px tray
// borders. Painting upgrades must not consume more of the logical canvas.
BoxDecoration boardSurfaceDecoration(WorldVisualTheme theme) => BoxDecoration(
      gradient: theme.boardGradient,
      borderRadius: GameRadius.extraLargeRadius,
      border: Border.all(
          color: theme.secondaryAccent.withValues(alpha: 0.85), width: 2),
      boxShadow: [
        BoxShadow(
            color:
                Color.lerp(theme.trayGradient.colors.last, Colors.black, 0.25)!,
            offset: const Offset(0, 7)),
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12)),
        BoxShadow(
            color: Colors.white.withValues(alpha: 0.24),
            blurRadius: 4,
            offset: const Offset(-1, -1)),
      ],
    );

BoxDecoration traySurfaceDecoration(WorldVisualTheme theme) => BoxDecoration(
      gradient: theme.trayGradient,
      borderRadius: GameRadius.extraLargeRadius,
      border: Border.all(
          color: theme.secondaryAccent.withValues(alpha: 0.85), width: 3),
      boxShadow: [
        BoxShadow(
            color: theme.trayGradient.colors.last, offset: const Offset(0, 5)),
        ...GameShadows.medium(),
        BoxShadow(
            color: Colors.white.withValues(alpha: 0.16),
            blurRadius: 3,
            offset: const Offset(-1, -1)),
      ],
    );

class GameBoardBackdrop extends StatelessWidget {
  const GameBoardBackdrop({super.key, required this.theme});
  final WorldVisualTheme theme;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
            child: Stack(children: [
          Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.20),
                  Colors.transparent,
                  theme.primaryAccent.withValues(alpha: 0.07)
                ],
                stops: const [
                  0,
                  0.4,
                  1
                ]),
          ))),
          Positioned.fill(
            left: 6,
            top: 6,
            right: 6,
            bottom: 6,
            child: DecoratedBox(
                decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
            )),
          ),
          Positioned(
            left: 28,
            right: 28,
            top: 3,
            height: 4,
            child: DecoratedBox(
                decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(colors: [
                Colors.transparent,
                Color(0xBBFFFFFF),
                Colors.transparent
              ]),
            )),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 3,
            height: 2,
            child: DecoratedBox(
                decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: theme.trayGradient.colors.last.withValues(alpha: 0.12),
            )),
          ),
          Positioned(
              left: 12,
              top: 12,
              child: Icon(theme.decorationIcons.first,
                  size: 24,
                  color: theme.primaryAccent.withValues(alpha: 0.14))),
          Positioned(
              right: 12,
              bottom: 12,
              child: Icon(theme.decorationIcons.last,
                  size: 24,
                  color: theme.primaryAccent.withValues(alpha: 0.14))),
        ])),
      );
}

/// Shared visual shell. Availability, payment and effects remain in each screen.
class GameBoosterButton extends StatelessWidget {
  const GameBoosterButton(
      {super.key,
      required this.onPressed,
      required this.icon,
      required this.label,
      required this.badge,
      required this.accent});
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final String badge;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = GameRadius.largeRadius;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label $badge',
      onTap: onPressed,
      child: ExcludeSemantics(
          child: AnimatedOpacity(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : GameDurations.quick,
        opacity: enabled ? 1 : 0.46,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            child: Ink(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: enabled
                          ? [
                              Color.lerp(accent, Colors.white, 0.12)!,
                              Color.lerp(accent, Colors.black, 0.24)!
                            ]
                          : const [
                              GameColors.disabledTop,
                              GameColors.disabledBottom
                            ]),
                  borderRadius: radius,
                  border: Border.all(color: Colors.white70, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Color.lerp(accent, Colors.black, 0.5)!,
                        offset: const Offset(0, 4)),
                    ...GameShadows.light()
                  ],
                ),
                child: Stack(children: [
                  Positioned(
                    top: 3,
                    left: 10,
                    right: 10,
                    height: 15,
                    child: IgnorePointer(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)]),
                    ))),
                  ),
                  Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child: Center(
                          child: IconTheme(
                              data: const IconThemeData(
                                  color: Colors.white, size: 25),
                              child: icon))),
                  Positioned(
                      left: 5,
                      right: 5,
                      bottom: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 3),
                        decoration: BoxDecoration(
                            color: GameColors.primaryBlueDark
                                .withValues(alpha: 0.92),
                            borderRadius: GameRadius.smallRadius,
                            border: Border.all(color: Colors.white30)),
                        child: Text('$label $badge',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1,
                                fontWeight: FontWeight.w900)),
                      )),
                ])),
          ),
        ),
      )),
    );
  }
}
