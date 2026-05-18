import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../../domain/tile.dart';

class GameTileWidget extends StatelessWidget {
  const GameTileWidget({
    super.key,
    required this.tile,
    required this.enabled,
    required this.highlighted,
    this.onTap,
  });

  final Tile tile;
  final bool enabled;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final art = tileCatalog[tile.type] ?? const TileArt('?', Color(0xFF90CAF9));
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: highlighted ? 1.12 : 1,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.52,
          child: Container(
            decoration: BoxDecoration(
              color: art.color,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: highlighted
                      ? Colors.yellowAccent.withOpacity(0.9)
                      : Colors.black.withOpacity(0.22),
                  blurRadius: highlighted ? 24 : 8,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                art.emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
