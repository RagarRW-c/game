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
    this.trayTile = false,
    this.onTap,
  });

  final Tile tile;
  final bool enabled;
  final bool highlighted;
  final bool blocked;
  final double depth;
  final bool trayTile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final art = tileCatalog[tile.type] ?? const TileArt('?', Color(0xFF90CAF9));
    final topLift = blocked ? 0.0 : depth.clamp(0.0, 1.0).toDouble();
    final shadowOpacity = blocked ? 0.10 : 0.16 + (topLift * 0.16);
    final blur = blocked ? 5.0 : 8.0 + (topLift * 8.0);
    final yOffset = blocked ? 3.0 : 5.0 + (topLift * 4.0);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        opacity: blocked
            ? 0.58
            : enabled
                ? 1
                : 0.52,
        child: Container(
          foregroundDecoration: BoxDecoration(
            color: blocked ? Colors.blueGrey.withValues(alpha: 0.24) : null,
            borderRadius: BorderRadius.circular(18),
            gradient: blocked
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.18 + (topLift * 0.10)),
                      Colors.transparent,
                    ],
                  ),
          ),
          decoration: BoxDecoration(
            color: Color.lerp(art.color, Colors.blueGrey, blocked ? 0.28 : 0),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.92),
              width: highlighted ? 4 : 3,
            ),
            boxShadow: [
              BoxShadow(
                color: highlighted
                    ? Colors.amberAccent.withValues(alpha: 0.72)
                    : Colors.black.withValues(alpha: shadowOpacity),
                blurRadius: highlighted ? 26 : blur,
                spreadRadius: highlighted ? 1.5 : 0,
                offset: Offset(0, yOffset),
              ),
              if (!blocked && !trayTile)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(-2, -2),
                ),
            ],
          ),
          child: Center(
            child: Text(
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
          ),
        ),
      ),
    );
  }
}
