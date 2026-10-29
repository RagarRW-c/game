import 'package:flutter/material.dart';

import '../theme/game_theme.dart';
import '../theme/world_theme.dart';
import 'booster_art.dart';

export 'booster_art.dart'
    show BoosterAction, BoosterActionArtwork, BoosterMedallionPainter;

/// Shared gameplay spacing: reserve space for artwork once, rather than
/// stacking large tray, board and booster gutters at the expense of tile scale.
abstract final class GameplaySpacing {
  static const boardMargin = EdgeInsets.symmetric(horizontal: 10, vertical: 4);
  static const trayMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
  // The booster already includes top clearance and space below its badge.
  static const boosterPadding = EdgeInsets.symmetric(horizontal: 16);
}

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
      required this.action,
      required this.label,
      required this.badge});
  final VoidCallback? onPressed;
  final BoosterAction action;
  final String label;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // +3 is inventory; only unsigned decimal digits represent a coin price.
    final paid = RegExp(r'^[0-9]+$').hasMatch(badge);
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
                opacity: enabled ? 1 : .46,
                child: LayoutBuilder(builder: (context, constraints) {
                  final width = constraints.hasBoundedWidth
                      ? constraints.maxWidth
                      : 100.0;
                  final diameter = (width * .8).clamp(0.0, 80.0).toDouble();
                  final coinSize = diameter * .24;
                  final style = Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(
                          fontSize: diameter * .25,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: Colors.white);
                  final measure = TextPainter(
                      text: TextSpan(text: badge, style: style),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                      locale: Localizations.maybeLocaleOf(context))
                    ..layout();
                  final textWidth = measure.width;
                  measure.dispose();
                  final requiredWidth =
                      textWidth + 10.1 + (paid ? coinSize + 3 : 0);
                  final badgeWidth =
                      requiredWidth.clamp(diameter * .78, width).toDouble();
                  // At large text sizes, move the coin below the number before
                  // sacrificing readable text. Normal-size prices remain inline.
                  final stackCoin = paid && requiredWidth > width;
                  final amount = Text(badge,
                      key: const ValueKey('booster_badge_value'),
                      textAlign: TextAlign.center,
                      style: style);
                  final coin = CustomPaint(
                      key: const ValueKey('booster_price_coin'),
                      size: Size.square(coinSize),
                      painter: const BoosterCoinPainter());
                  return SizedBox(
                      width: width,
                      child: Stack(fit: StackFit.passthrough, children: [
                        // Keep the allocated width through to the inner stack.
                        // A loose child shrinks to the badge and clips the wider
                        // positioned circle; the badge itself stays content-sized.
                        Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  Positioned(
                                      top: 4,
                                      child: CustomPaint(
                                          key: const ValueKey(
                                              'booster_icon_medallion'),
                                          painter:
                                              const BoosterMedallionPainter(),
                                          child: SizedBox.square(
                                              dimension: diameter,
                                              child: Padding(
                                                  padding: EdgeInsets.fromLTRB(
                                                      diameter * .15,
                                                      diameter * .1,
                                                      diameter * .15,
                                                      diameter * .22),
                                                  child: BoosterActionArtwork(
                                                      action))))),
                                  Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(height: 4 + diameter * .73),
                                        Container(
                                            key: const ValueKey(
                                                'booster_funding_badge'),
                                            width: badgeWidth,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 3),
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        diameter * .12),
                                                gradient: const LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Color(0xFF234E72),
                                                      Color(0xFF122F50)
                                                    ]),
                                                border: Border.all(color: const Color(0xFF315D80)),
                                                boxShadow: const [
                                                  BoxShadow(
                                                      color: Color(0x660A1727),
                                                      blurRadius: 3,
                                                      offset: Offset(0, 2))
                                                ]),
                                            child: stackCoin
                                                ? Column(mainAxisSize: MainAxisSize.min, children: [
                                                    amount,
                                                    const SizedBox(height: 2),
                                                    coin
                                                  ])
                                                : Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                        Flexible(child: amount),
                                                        if (paid) ...[
                                                          const SizedBox(
                                                              width: 3),
                                                          coin
                                                        ]
                                                      ])),
                                      ]),
                                ])),
                        // Paint the ripple above the opaque illustrated layers.
                        Positioned.fill(
                            child: Material(
                                type: MaterialType.transparency,
                                child: InkWell(
                                    onTap: onPressed,
                                    borderRadius: BorderRadius.circular(24)))),
                      ]));
                }))));
  }
}
