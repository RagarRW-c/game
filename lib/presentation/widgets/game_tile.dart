import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../../domain/tile.dart';
import '../theme/game_theme.dart';

class GameTileWidget extends StatefulWidget {
  const GameTileWidget({
    super.key,
    required this.tile,
    required this.enabled,
    required this.highlighted,
    this.blocked = false,
    this.depth = 1,
    this.trayTile = false,
    this.catalog = tileCatalog,
    this.onTap,
  });

  final Tile tile;
  final bool enabled;
  final bool highlighted;
  final bool blocked;
  final double depth;
  final bool trayTile;
  final Map<String, TileArt> catalog;
  final VoidCallback? onTap;

  @override
  State<GameTileWidget> createState() => _GameTileWidgetState();
}

class _GameTileWidgetState extends State<GameTileWidget> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.catalog[widget.tile.type] ??
        const TileArt(Icons.help_rounded, GameColors.tileFallback);
    final topLift =
        widget.blocked ? 0.0 : widget.depth.clamp(0.0, 1.0).toDouble();
    final shadowOpacity = widget.blocked ? 0.16 : 0.22 + (topLift * 0.18);
    final blur = widget.blocked ? 7.0 : 10.0 + (topLift * 9.0);
    final yOffset = widget.blocked ? 4.0 : 6.0 + (topLift * 4.0);
    final radius =
        widget.trayTile ? GameRadius.mediumRadius : GameRadius.largeRadius;

    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedOpacity(
        duration: GameDurations.quick,
        curve: Curves.easeInOut,
        opacity: widget.blocked
            ? 0.58
            : widget.enabled
                ? 1
                : 0.52,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 1,
            end: _pressed ? 0.93 : 1,
          ),
          duration: GameDurations.quick,
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            foregroundDecoration: BoxDecoration(
              color: widget.blocked
                  ? GameColors.tileBlockedOverlay.withValues(alpha: 0.26)
                  : null,
              borderRadius: radius,
              gradient: widget.blocked
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.42 + (topLift * 0.10)),
                        Colors.white.withValues(alpha: 0.06),
                        Colors.black.withValues(alpha: 0.04),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
            ),
            decoration: BoxDecoration(
              color: Color.lerp(
                art.color,
                GameColors.tileBlocked,
                widget.blocked ? 0.36 : 0,
              ),
              borderRadius: radius,
              border: Border.all(
                color: widget.highlighted
                    ? GameColors.tileHighlight
                    : Colors.white.withValues(alpha: 0.94),
                width: widget.highlighted ? 4 : 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.highlighted
                      ? GameColors.tileHighlightGlow.withValues(alpha: 0.82)
                      : Colors.black.withValues(alpha: shadowOpacity),
                  blurRadius: widget.highlighted ? 26 : blur,
                  spreadRadius: widget.highlighted ? 1.5 : 0,
                  offset: Offset(0, yOffset),
                ),
                if (!widget.blocked)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.34),
                    blurRadius: 6,
                    offset: const Offset(-2, -2),
                  ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  right: 10,
                  top: 7,
                  height: widget.trayTile ? 8 : 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: GameRadius.extraLargeRadius,
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    art.icon,
                    color: Colors.white,
                    size: widget.trayTile ? 30 : 36,
                    shadows: widget.blocked
                        ? null
                        : const [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 4,
                              offset: Offset(0, 1.4),
                            ),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PoppingGameTile extends StatelessWidget {
  const PoppingGameTile({
    super.key,
    required this.tile,
    required this.enabled,
    required this.highlighted,
    this.catalog = tileCatalog,
    this.trayTile = false,
  });

  final Tile tile;
  final bool enabled;
  final bool highlighted;
  final Map<String, TileArt> catalog;
  final bool trayTile;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('pop_${tile.id}'),
      tween: Tween<double>(begin: 0.86, end: 1),
      duration: GameDurations.normal,
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: GameTileWidget(
        tile: tile,
        enabled: enabled,
        highlighted: highlighted,
        catalog: catalog,
        trayTile: trayTile,
      ),
    );
  }
}

class EmptyTraySlot extends StatelessWidget {
  const EmptyTraySlot({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: GameGradients.traySlot,
        borderRadius: GameRadius.mediumRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
    );
  }
}
