import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../../domain/tile.dart';

class GameTileWidget extends StatelessWidget {
  const GameTileWidget({
    super.key,
    required this.tile,
    required this.enabled,
    required this.highlighted,
    this.blocked = false,
    this.depth = 1,
    this.matching = false,
    this.pickedUp = false,
    this.trayTile = false,
    this.onTap,
  });

  final Tile tile;
  final bool enabled;
  final bool highlighted;
  final bool blocked;
  final double depth;
  final bool matching;
  final bool pickedUp;
  final bool trayTile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final art = tileCatalog[tile.type] ?? const TileArt('?', Color(0xFF90CAF9));
    final topLift = blocked ? 0.0 : depth.clamp(0.0, 1.0).toDouble();
    final effectiveHighlight = highlighted || matching;
    final shadowOpacity = blocked ? 0.10 : 0.16 + (topLift * 0.16);
    final blur = blocked ? 5.0 : 8.0 + (topLift * 8.0);
    final yOffset = blocked ? 3.0 : 5.0 + (topLift * 4.0);
    final scale = matching
        ? 1.12
        : pickedUp
            ? 1.05
            : highlighted
                ? 1.10
                : 1.0;

    return AnimatedScale(
      duration: Duration(milliseconds: pickedUp ? 120 : 210),
      curve: pickedUp ? Curves.easeOut : Curves.easeOutBack,
      scale: scale,
      child: AnimatedSlide(
        duration: Duration(milliseconds: pickedUp ? 120 : 220),
        curve: Curves.easeOut,
        offset: Offset(0, pickedUp ? -0.10 : 0),
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeInOut,
            opacity: blocked
                ? 0.58
                : enabled
                    ? 1
                    : 0.52,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              foregroundDecoration: BoxDecoration(
                color: blocked ? Colors.blueGrey.withOpacity(0.24) : null,
                borderRadius: BorderRadius.circular(18),
                gradient: blocked
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.18 + (topLift * 0.10)),
                          Colors.transparent,
                        ],
                      ),
              ),
              decoration: BoxDecoration(
                color: Color.lerp(art.color, Colors.blueGrey, blocked ? 0.28 : 0),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: effectiveHighlight ? Colors.white : Colors.white.withOpacity(0.92),
                  width: effectiveHighlight ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: effectiveHighlight
                        ? Colors.amberAccent.withOpacity(0.72)
                        : Colors.black.withOpacity(shadowOpacity),
                    blurRadius: effectiveHighlight ? 26 : blur,
                    spreadRadius: effectiveHighlight ? 1.5 : 0,
                    offset: Offset(0, yOffset),
                  ),
                  if (!blocked && !trayTile)
                    BoxShadow(
                      color: Colors.white.withOpacity(0.28),
                      blurRadius: 6,
                      offset: const Offset(-2, -2),
                    ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (matching)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.50),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  Text(
                    art.emoji,
                    style: TextStyle(
                      fontSize: trayTile ? 26 : 28,
                      shadows: blocked
                          ? null
                          : const [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                    ),
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
