import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/adventure_progress.dart';
import '../theme/world_theme.dart';
import 'adventure_level_node.dart';
import 'adventure_world_scenery.dart';

/// The painter and nodes use the same authored coordinates at every width.
class AdventureMapGeometry {
  AdventureMapGeometry(double width, TextScaler scaler)
      : nodeWidth =
            math.min(width - 40, 164 + 48 * (scaler.scale(16) / 16 - 1)),
        stride = 190 + 78 * (scaler.scale(16) / 16 - 1),
        width = width;

  final double width;
  final double nodeWidth;
  final double stride;
  static const bends = [-.65, .45, .9, -.2, -.9, .25, .9, -.45, -.8, .3];
  double get height => stride * 10 + 100;

  Offset center(int index) => Offset(
        width / 2 + bends[index] * math.max(0, (width - nodeWidth - 48) / 2),
        90 + index * stride,
      );
}

class AdventureMapPath extends StatelessWidget {
  const AdventureMapPath({
    super.key,
    required this.startLevel,
    required this.theme,
    required this.progress,
    required this.nodeKeys,
    required this.onLevelTap,
  });

  final int startLevel;
  final WorldVisualTheme theme;
  final AdventureProgress progress;
  final List<GlobalKey> nodeKeys;
  final ValueChanged<int> onLevelTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final geometry = AdventureMapGeometry(
              constraints.maxWidth, MediaQuery.textScalerOf(context));
          return SizedBox(
            height: geometry.height,
            child: Stack(
              children: [
                Positioned.fill(
                    child: AdventureWorldScenery(
                        key: const ValueKey('map_scenery'), theme: theme)),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _RoutePainter(
                            geometry,
                            (progress.highestUnlockedLevel - startLevel)
                                .clamp(0, 9),
                            theme.secondaryAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                for (var index = 0; index < 10; index++)
                  Positioned(
                    left: geometry.center(index).dx - geometry.nodeWidth / 2,
                    top: geometry.center(index).dy - 46,
                    width: geometry.nodeWidth,
                    child: KeyedSubtree(
                      key: nodeKeys[index],
                      child: RepaintBoundary(
                        child: AdventureLevelNode(
                          key: ValueKey('level_${startLevel + index}'),
                          level: startLevel + index,
                          unlocked: progress.isUnlocked(startLevel + index),
                          completed: progress.isCompleted(startLevel + index),
                          current: progress.isCurrent(startLevel + index),
                          stars: progress.starsByLevel[startLevel + index] ?? 0,
                          boss: (startLevel + index) % 10 == 0,
                          theme: theme,
                          onTap: () => onLevelTap(startLevel + index),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.geometry, this.completedSegments, this.accent);
  final AdventureMapGeometry geometry;
  final int completedSegments;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 9; i++) {
      final a = geometry.center(i);
      final b = geometry.center(i + 1);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, a.dy + geometry.stride * .55, b.dx,
            b.dy - geometry.stride * .55, b.dx, b.dy);
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
          path.shift(const Offset(0, 5)),
          pen
            ..strokeWidth = 22
            ..color = const Color(0x440D2735));
      canvas.drawPath(
          path,
          pen
            ..strokeWidth = 20
            ..color = i < completedSegments
                ? const Color(0xFFFFE6A2)
                : const Color(0x608FA3A6));
      canvas.drawPath(
          path,
          pen
            ..strokeWidth = 9
            ..color = i < completedSegments
                ? accent.withValues(alpha: .8)
                : Colors.white.withValues(alpha: .15));
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.geometry.width != geometry.width ||
      old.geometry.stride != geometry.stride ||
      old.completedSegments != completedSegments ||
      old.accent != accent;
}
