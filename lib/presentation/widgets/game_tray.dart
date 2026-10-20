import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../../domain/game_engine.dart';
import '../../domain/tile.dart';
import '../theme/game_theme.dart';
import '../theme/world_theme.dart';
import 'game_surfaces.dart';
import 'game_tile.dart';

/// A disposable description of an already-accepted engine move, never a queue.
class TrayFeedback {
  TrayFeedback(
      {required this.serial,
      required this.matched,
      required List<String> before,
      required Iterable<String> collected,
      required Set<String> matchedIds})
      : slots = List.unmodifiable([
          for (final entry in [...before, ...collected].asMap().entries)
            if (entry.key < GameEngine.trayLimit &&
                (matched
                    ? matchedIds.contains(entry.value)
                    : entry.key >= before.length))
              entry.key,
        ]);

  final int serial;
  final bool matched;
  final List<int> slots;
}

/// Same geometry in both modes. Tiles reflect the engine immediately; only
/// painted light fades out, so no outgoing tile or animation can capture input.
class GameTray extends StatelessWidget {
  const GameTray(
      {super.key,
      required this.trayTiles,
      required this.catalog,
      required this.worldTheme,
      this.feedback});

  final List<Tile?> trayTiles;
  final Map<String, TileArt> catalog;
  final WorldVisualTheme worldTheme;
  final TrayFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    final count = trayTiles.whereType<Tile>().length;
    final full = count == GameEngine.trayLimit;
    final event = feedback;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: full ? 'Tray full, 7 of 7 slots' : 'Tray, $count of 7 slots',
      child: Container(
        height: 94,
        margin: const EdgeInsets.fromLTRB(
            GameSpacing.lg, GameSpacing.sm, GameSpacing.lg, GameSpacing.lg),
        padding: const EdgeInsets.all(GameSpacing.md),
        decoration: traySurfaceDecoration(worldTheme),
        child: Stack(
          children: [
            Row(children: [
              for (var index = 0; index < GameEngine.trayLimit; index++)
                Expanded(
                    child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: GameSpacing.xs),
                  child: index >= trayTiles.length || trayTiles[index] == null
                      ? const EmptyTraySlot()
                      : GameTileWidget(
                          key: ValueKey('tray_${trayTiles[index]!.id}'),
                          tile: trayTiles[index]!,
                          enabled: true,
                          highlighted: false,
                          catalog: catalog,
                          trayTile: true),
                )),
            ]),
            if (full)
              const Positioned.fill(
                  child: IgnorePointer(
                      child: ExcludeSemantics(
                child: CustomPaint(
                    painter: _TrayLightPainter(
                        progress: 0,
                        slots: [0, 1, 2, 3, 4, 5, 6],
                        color: GameColors.dangerRed,
                        matched: false,
                        full: true)),
              ))),
            if (event != null)
              Positioned.fill(
                  child: IgnorePointer(
                      child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('tray_feedback_${event.serial}'),
                    tween: Tween(begin: 0, end: 1),
                    duration: reducedMotion
                        ? Duration.zero
                        : Duration(milliseconds: event.matched ? 280 : 160),
                    builder: (context, value, _) => CustomPaint(
                      painter: _TrayLightPainter(
                        progress: value,
                        slots: event.slots,
                        color: event.matched
                            ? worldTheme.secondaryAccent
                            : Colors.white,
                        matched: event.matched,
                      ),
                    ),
                  ),
                ),
              ))),
          ],
        ),
      ),
    );
  }
}

class _TrayLightPainter extends CustomPainter {
  const _TrayLightPainter(
      {required this.progress,
      required this.slots,
      required this.color,
      required this.matched,
      this.full = false});
  final double progress;
  final List<int> slots;
  final Color color;
  final bool matched;
  final bool full;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1 && !full) return;
    final opacity = full ? .85 : (1 - progress);
    final width = size.width / GameEngine.trayLimit;
    for (final slot in slots) {
      final rect = Rect.fromLTWH(slot * width + GameSpacing.xs, 1,
          math.max(0, width - GameSpacing.xs * 2), size.height - 2);
      final border = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      canvas.drawRRect(
          border, Paint()..color = color.withValues(alpha: opacity * .22));
      canvas.drawRRect(
          border,
          Paint()
            ..color = color.withValues(alpha: opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = full ? 2.5 : 2);
      if (matched) {
        // Four tiny glints confined to each affected slot; no particles or blur.
        for (var i = 0; i < 4; i++) {
          final angle = i * math.pi / 2 + math.pi / 4;
          final center = rect.center +
              Offset(math.cos(angle) * rect.width * .32,
                  math.sin(angle) * rect.height * (.18 + progress * .18));
          final radius = 3.0 * (1 - progress);
          final pen = Paint()
            ..color = Colors.white.withValues(alpha: opacity)
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
              center - Offset(radius, 0), center + Offset(radius, 0), pen);
          canvas.drawLine(
              center - Offset(0, radius), center + Offset(0, radius), pen);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TrayLightPainter old) =>
      old.progress != progress ||
      old.slots != slots ||
      old.color != color ||
      old.full != full ||
      old.matched != matched;
}
