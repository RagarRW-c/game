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
    this.preserveBoardAppearance = false,
    this.trayAppearanceBlend,
    this.catalog = tileCatalog,
    this.onTap,
  });

  final Tile tile;
  final bool enabled;
  final bool highlighted;
  final bool blocked;
  final double depth;
  final bool trayTile;

  /// Flight copies keep board styling while belonging to the tray presentation.
  final bool preserveBoardAppearance;

  /// Presentation-only morph used by the flight; normal tiles keep their style.
  final double? trayAppearanceBlend;
  final Map<String, TileArt> catalog;
  final VoidCallback? onTap;

  @override
  State<GameTileWidget> createState() => _GameTileWidgetState();
}

class _GameTileWidgetState extends State<GameTileWidget> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (value && (!widget.enabled || widget.blocked || widget.onTap == null)) {
      return;
    }
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(GameTileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.blocked || widget.onTap == null) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trayAppearance = widget.trayTile && !widget.preserveBoardAppearance;
    final blend = widget.trayAppearanceBlend?.clamp(0.0, 1.0) ??
        (trayAppearance ? 1.0 : 0.0);
    double mix(double board, double tray) => board + (tray - board) * blend;
    final art = widget.catalog[widget.tile.type] ??
        const TileArt(Icons.help_rounded, GameColors.tileFallback);
    final topLift =
        widget.blocked ? 0.0 : widget.depth.clamp(0.0, 1.0).toDouble();
    final shadowOpacity =
        mix(widget.blocked ? .18 : .24 + topLift * .06, .22 + topLift * .18);
    final blur = mix(widget.blocked ? 3 : 6 + topLift * 2, 10 + topLift * 9);
    final yOffset = mix(widget.blocked ? 2 : 3 + topLift, 6 + topLift * 4);
    final radius = BorderRadius.lerp(
        GameRadius.largeRadius, GameRadius.mediumRadius, blend)!;

    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedOpacity(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : GameDurations.quick,
        curve: Curves.easeInOut,
        opacity: widget.blocked
            ? 0.86
            : widget.enabled
                ? 1
                : 0.52,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 1,
            end: _pressed ? 0.93 : 1,
          ),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : GameDurations.quick,
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(
                scale: scale, transformHitTests: false, child: child);
          },
          child: Container(
            foregroundDecoration: BoxDecoration(
              color: widget.blocked
                  ? GameColors.tileBlockedOverlay.withValues(alpha: 0.20)
                  : null,
              borderRadius: radius,
              gradient: widget.blocked
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(
                          alpha: mix((_pressed ? .30 : .12) + topLift * .04,
                              .42 + topLift * .10),
                        ),
                        Colors.white.withValues(alpha: 0.02),
                        Colors.black.withValues(alpha: 0.04),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                      art.color,
                      widget.blocked ? GameColors.tileBlocked : Colors.white,
                      widget.blocked ? 0.32 : 0.18)!,
                  Color.lerp(
                      art.color,
                      widget.blocked ? GameColors.tileBlocked : art.color,
                      widget.blocked ? 0.32 : 0)!,
                ],
              ),
              borderRadius: radius,
              border: Border.all(
                color: widget.highlighted
                    ? GameColors.tileHighlight
                    : Colors.white
                        .withValues(alpha: widget.blocked ? 0.60 : 0.94),
                width: widget.highlighted ? 4 : 3,
              ),
              boxShadow: [
                if (blend < 1)
                  BoxShadow(
                    color: Color.lerp(art.color, Colors.black, 0.42)!
                        .withValues(alpha: 1 - blend),
                    blurRadius: 0,
                    offset: Offset(0, widget.blocked ? 2 : 4),
                  ),
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
                    color: Colors.white.withValues(alpha: mix(.18, .34)),
                    blurRadius: mix(2, 6),
                    offset: Offset(mix(-1, -2), mix(-1, -2)),
                  ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  right: 10,
                  top: 7,
                  height: mix(5, 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: widget.blocked ? 0.10 : 0.32),
                      borderRadius: GameRadius.extraLargeRadius,
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    art.icon,
                    color: Colors.white,
                    size: mix(36, 30),
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
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : GameDurations.normal,
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
          color: Colors.white.withValues(alpha: 0.24),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 3,
            offset: const Offset(0, -2),
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
