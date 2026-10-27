import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../../domain/tile.dart';
import '../theme/game_theme.dart';
import 'tile_face.dart';

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
    final art = widget.catalog[widget.tile.type] ??
        const TileArt(Icons.help_rounded, GameColors.tileFallback);

    return Semantics(
      container: true,
      label: art.label ?? widget.tile.type,
      button: !widget.trayTile && widget.onTap != null,
      enabled: widget.enabled && !widget.blocked,
      hint: widget.blocked ? 'Covered tile' : null,
      onTap: widget.enabled && !widget.blocked ? widget.onTap : null,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: widget.enabled && !widget.blocked ? widget.onTap : null,
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
                : Duration(milliseconds: _pressed ? 70 : 110),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return Transform.scale(
                  scale: scale, transformHitTests: false, child: child);
            },
            child: TileFace(
              art: art,
              blocked: widget.blocked,
              highlighted: widget.highlighted,
              pressed: _pressed,
              depth: widget.depth,
              trayBlend: blend,
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
