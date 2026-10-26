import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../../domain/tile.dart';
import 'game_tile.dart';

enum TrayPlacement { top, bottom }

TrayPlacement trayPlacementForRound(int round) =>
    round.isEven ? TrayPlacement.top : TrayPlacement.bottom;

/// Measured before the engine removes the board tile, in the effects Stack's
/// coordinate system. Includes FittedBox scaling and SafeArea offsets.
class TileFlightSource {
  const TileFlightSource(
      this.tile, this.rect, this.catalog, this.depth, this.faceSize);
  final Tile tile;
  final Rect rect;
  final Map<String, TileArt> catalog;
  final double depth;
  final Size faceSize;
}

class TileFlight {
  static const duration = Duration(milliseconds: 440);
  static const pickup = .14;
  static const arrival = .78;
  const TileFlight(
      this.serial, this.source, this.target, this.slot, this.matched);
  final int serial;
  final TileFlightSource source;
  final Rect target;
  final int slot;
  final bool matched;

  double appearanceAt(double progress) => travelAt(progress);

  double opacityAt(double progress) => matched && progress >= arrival ? 0 : 1;

  /// A visible pickup precedes transport. Both phase boundaries have zero
  /// velocity and acceleration; gameplay has already accepted the selection.
  double travelAt(double progress) {
    if (progress <= pickup) return 0;
    if (progress >= arrival) return 1;
    return _smootherStep((progress - pickup) / (arrival - pickup));
  }

  double liftAt(double progress) => progress <= pickup
      ? _smootherStep((progress / pickup).clamp(0.0, 1.0))
      : 1 - travelAt(progress);

  Rect rectAt(double progress) {
    if (progress <= 0) return source.rect;
    if (progress >= 1 || progress == arrival) return target;
    final t = travelAt(progress);
    final rect = Rect.lerp(source.rect, target, t)!;
    if (progress < arrival) {
      final lift = liftAt(progress);
      final arc = math.pow(math.sin(math.pi * t), 3).toDouble();
      return rect
          .inflate(math.min(rect.width, rect.height) * lift * .11)
          .shift(Offset(arc * (slot >= 3 ? -8 : 8), -lift * 12));
    }
    final landing = (progress - arrival) / (1 - arrival);
    final compression = landing < .45
        ? math.pow(math.sin(math.pi * landing / .45), 2).toDouble()
        : -math.pow(math.sin(math.pi * (landing - .45) / .55), 2).toDouble() *
            .4;
    return Rect.fromCenter(
        center: target.center,
        width: target.width * (1 + compression * .05),
        height: target.height * (1 - compression * .075));
  }
}

/// Immutable, bounded copies of faces already removed by the engine.
class MatchedTileSnapshot {
  const MatchedTileSnapshot(this.tile, this.rect);
  final Tile tile;
  final Rect rect;
}

class TrayBurst {
  static const duration = Duration(milliseconds: 640);
  static const compressionDuration = Duration(milliseconds: 70);
  static const fadeDuration = Duration(milliseconds: 80);
  static const particlesPerSlot = 12;
  const TrayBurst(this.serial, this.rects, this.direction,
      {this.snapshots = const [], this.catalog = tileCatalog, this.incomingId});
  final int serial;
  final List<Rect> rects;
  final double direction;
  final List<MatchedTileSnapshot> snapshots;
  final Map<String, TileArt> catalog;
  final String? incomingId;

  // Both tweens are inserted in the same frame. This is the exact flight
  // arrival expressed on the burst clock, not a timer or a completion callback.
  double get reactionStart => incomingId == null
      ? 0
      : TileFlight.duration.inMicroseconds *
          TileFlight.arrival /
          duration.inMicroseconds;
  double get _compression =>
      compressionDuration.inMicroseconds / duration.inMicroseconds;
  double get _fade => fadeDuration.inMicroseconds / duration.inMicroseconds;
  double get release => reactionStart + _compression;
  double reactionAt(double p) =>
      ((p - reactionStart) / _compression).clamp(0.0, 1.0);
  double particlesAt(double p) =>
      ((p - release) / (1 - release)).clamp(0.0, 1.0);
  double opacityAt(MatchedTileSnapshot face, double p) {
    if (face.tile.id == incomingId && p < reactionStart) return 0;
    return 1 - _smoothStep(((p - release) / _fade).clamp(0.0, 1.0));
  }

  Rect rectAt(MatchedTileSnapshot face, double p) {
    if (p <= reactionStart) return face.rect;
    final squeeze = _smoothStep(reactionAt(p));
    final clearing = _smoothStep(((p - release) / _fade).clamp(0.0, 1.0));
    final scale = 1 - clearing * .24;
    return Rect.fromCenter(
        center: face.rect.center,
        width: face.rect.width * (1 + squeeze * .07) * scale,
        height: face.rect.height * (1 - squeeze * .13) * scale);
  }
}

double _smoothStep(double t) => t * t * (3 - 2 * t);
double _smootherStep(double t) => t * t * t * (10 + t * (-15 + 6 * t));

/// Presentation only: no engine reference, rewards, asynchronous work or timers.
/// Eviction/cancellation reveals the canonical tray immediately.
class TileEffectsController extends ChangeNotifier {
  static const maxFlights = 7;
  static const maxBursts = 3;
  final layerKey = GlobalKey();
  final slotKeys = List.generate(7, (_) => GlobalKey());
  final List<TileFlight> _flights = [];
  final List<TrayBurst> _bursts = [];
  int _serial = 0;
  bool _disposed = false;
  bool reducedMotion = false;
  // Refreshed by the tray with its actual world palette, including Hint moves
  // that have no tapped board source. No notification or animation is started.
  Map<String, TileArt> catalog = tileCatalog;

  List<TileFlight> get flights => List.unmodifiable(_flights);
  List<TrayBurst> get bursts => List.unmodifiable(_bursts);
  bool hides(String id) =>
      _flights.any((f) => !f.matched && f.source.tile.id == id);

  Rect? rectFor(BuildContext? context) {
    if (_disposed || context == null || !context.mounted) return null;
    final box = context.findRenderObject();
    final layer = layerKey.currentContext?.findRenderObject();
    if (box is! RenderBox ||
        layer is! RenderBox ||
        !box.attached ||
        !layer.attached ||
        !box.hasSize ||
        !layer.hasSize) return null;
    final rect = MatrixUtils.transformRect(
        box.getTransformTo(layer), Offset.zero & box.size);
    if (!rect.isFinite ||
        rect.isEmpty ||
        !(Offset.zero & layer.size).overlaps(rect)) return null;
    return rect;
  }

  TileFlightSource? capture(BuildContext context, Tile tile,
      Map<String, TileArt> catalog, double depth) {
    if (reducedMotion) return null;
    final rect = rectFor(context);
    return rect == null
        ? null
        : TileFlightSource(tile, rect, catalog, depth,
            (context.findRenderObject()! as RenderBox).size);
  }

  void accepted(
      {required TileFlightSource? source,
      required int slot,
      required List<String> tray,
      required Set<String> matchedIds,
      List<Tile> matchedTiles = const [],
      required List<int> matchedSlots,
      required TrayPlacement placement}) {
    if (_disposed) return;
    if (reducedMotion) {
      clear();
      return;
    }
    // A match compacts tray indices. Cancel earlier flights rather than letting
    // them land in obsolete slots or replay already matched tile faces.
    if (matchedIds.isNotEmpty) {
      _flights.clear();
    } else {
      _flights.removeWhere((f) => !tray.contains(f.source.tile.id));
    }
    if (source != null && slot >= 0 && slot < slotKeys.length) {
      final target = rectFor(slotKeys[slot].currentContext);
      if (target != null) {
        if (_flights.length == maxFlights) _flights.removeAt(0);
        _flights.add(TileFlight(++_serial, source, target, slot,
            matchedIds.contains(source.tile.id)));
      }
    }
    if (matchedIds.isNotEmpty) {
      final rects = [
        for (final slot in matchedSlots)
          if (slot >= 0 && slot < slotKeys.length)
            rectFor(slotKeys[slot].currentContext)
      ].whereType<Rect>().toList();
      if (rects.isNotEmpty) {
        final snapshots = <MatchedTileSnapshot>[];
        for (var i = 0;
            i < matchedSlots.length && i < matchedTiles.length && i < 3;
            i++) {
          final index = matchedSlots[i];
          if (index < 0 || index >= slotKeys.length) continue;
          final rect = rectFor(slotKeys[index].currentContext);
          if (rect != null)
            snapshots.add(MatchedTileSnapshot(matchedTiles[i], rect));
        }
        if (_bursts.length == maxBursts) _bursts.removeAt(0);
        _bursts.add(TrayBurst(
            ++_serial, rects, placement == TrayPlacement.top ? 1 : -1,
            snapshots: List.unmodifiable(snapshots),
            catalog: source?.catalog ?? catalog,
            incomingId:
                _flights.any((f) => f.matched) ? source?.tile.id : null));
      }
    }
    notifyListeners();
  }

  void finishFlight(int serial) {
    if (_disposed) return;
    _flights.removeWhere((f) => f.serial == serial);
    notifyListeners();
  }

  void finishBurst(int serial) {
    if (_disposed) return;
    _bursts.removeWhere((b) => b.serial == serial);
    notifyListeners();
  }

  void clear({bool notify = true}) {
    if (_disposed || (_flights.isEmpty && _bursts.isEmpty)) return;
    _flights.clear();
    _bursts.clear();
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _flights.clear();
    _bursts.clear();
    super.dispose();
  }
}

/// Finite, framework-owned implicit animations; bounded to this screen. The
/// stable child keeps animation frames from rebuilding the board or its rules.
class GameTileEffects extends StatefulWidget {
  const GameTileEffects(
      {super.key,
      required this.controller,
      required this.round,
      required this.child});
  final TileEffectsController controller;
  final Object round;
  final Widget child;
  @override
  State<GameTileEffects> createState() => _GameTileEffectsState();
}

class _GameTileEffectsState extends State<GameTileEffects> {
  Object? _geometry;

  @override
  void dispose() {
    widget.controller.clear(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final signature = (
          constraints.biggest,
          media.padding,
          media.viewInsets,
          media.textScaler.scale(16),
          media.disableAnimations,
          TickerMode.of(context),
          widget.round
        );
        if (_geometry != signature) {
          // Before descendants build, both the flight layer and tray observe the
          // same cleared snapshot. No notification or setState during layout.
          widget.controller.clear(notify: false);
          _geometry = signature;
        }
        widget.controller.reducedMotion = media.disableAnimations;
        return AnimatedBuilder(
          animation: widget.controller,
          // Remount presentation on geometry/lifecycle changes so hidden tray
          // faces cannot retain an old Opacity after silent cancellation.
          child: KeyedSubtree(key: ValueKey(signature), child: widget.child),
          builder: (context, child) => Stack(
            key: widget.controller.layerKey,
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              child!,
              Positioned.fill(
                  child: IgnorePointer(
                child: ExcludeSemantics(
                    child: RepaintBoundary(
                        child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    for (final flight in widget.controller.flights)
                      Positioned.fill(
                          key: ValueKey('flight_layer_${flight.serial}'),
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey('flight_${flight.serial}'),
                            tween: Tween(begin: 0, end: 1),
                            duration: TileFlight.duration,
                            onEnd: () =>
                                widget.controller.finishFlight(flight.serial),
                            builder: (context, progress, _) => Stack(children: [
                              Positioned.fill(
                                  child: CustomPaint(
                                      painter: FlightAccentPainter(
                                          flight, progress))),
                              Positioned.fromRect(
                                rect: flight.rectAt(progress),
                                child: Opacity(
                                    opacity: flight.opacityAt(progress),
                                    child: TileFlightVisual(
                                        flight: flight, progress: progress)),
                              ),
                            ]),
                          )),
                    for (final burst in widget.controller.bursts)
                      Positioned.fill(
                          key: ValueKey('burst_layer_${burst.serial}'),
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey('burst_${burst.serial}'),
                            tween: Tween(begin: 0, end: 1),
                            duration: TrayBurst.duration,
                            onEnd: () =>
                                widget.controller.finishBurst(burst.serial),
                            builder: (context, progress, _) => Stack(children: [
                              for (final face in burst.snapshots)
                                Positioned.fromRect(
                                    rect: burst.rectAt(face, progress),
                                    child: MatchedTileVisual(
                                        key: ValueKey(
                                            'match_${burst.serial}_${face.tile.id}'),
                                        burst: burst,
                                        face: face,
                                        progress: progress)),
                              Positioned.fill(
                                  child: CustomPaint(
                                      painter: _BurstPainter(burst, progress))),
                            ]),
                          )),
                  ],
                ))),
              ))
            ],
          ),
        );
      });
}

class TileFlightVisual extends StatelessWidget {
  const TileFlightVisual({super.key, required this.flight, this.progress = 0});
  final TileFlight flight;
  final double progress;
  @override
  Widget build(BuildContext context) {
    final blend = flight.appearanceAt(progress);
    final size = Size.lerp(flight.source.faceSize, flight.target.size, blend)!;
    return FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
            width: size.width,
            height: size.height,
            child: GameTileWidget(
              tile: flight.source.tile,
              catalog: flight.source.catalog,
              depth: flight.source.depth + (1 - flight.source.depth) * blend,
              enabled: true,
              highlighted: false,
              trayTile: true,
              preserveBoardAppearance: true,
              trayAppearanceBlend: blend,
            )));
  }
}

class MatchedTileVisual extends StatelessWidget {
  const MatchedTileVisual(
      {super.key,
      required this.burst,
      required this.face,
      required this.progress});
  final TrayBurst burst;
  final MatchedTileSnapshot face;
  final double progress;

  @override
  Widget build(BuildContext context) => Opacity(
      opacity: burst.opacityAt(face, progress),
      child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
              width: face.rect.width,
              height: face.rect.height,
              child: GameTileWidget(
                  tile: face.tile,
                  catalog: burst.catalog,
                  enabled: true,
                  highlighted: false,
                  trayTile: true))));
}

/// Shares the flight's existing clock. Three outline samples form a short
/// trail without duplicate tile faces, retained history, timers or blur layers.
class FlightAccentPainter extends CustomPainter {
  const FlightAccentPainter(this.flight, this.progress);
  static const trailSamples = 3;
  final TileFlight flight;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || flight.opacityAt(progress) == 0)
      return;
    final strength = math.sin(math.pi * progress);
    final body = flight.rectAt(progress);
    final shadow = body.shift(Offset(0, 9 * strength)).inflate(6 * strength);
    canvas.drawOval(
        shadow,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFF102034).withValues(alpha: .34 * strength),
            const Color(0x00102034),
          ]).createShader(shadow));
    for (var i = trailSamples; i >= 1; i--) {
      final previous = progress - i * .045;
      if (previous <= 0) continue;
      final rect = RRect.fromRectAndRadius(
          flight.rectAt(previous), const Radius.circular(12));
      canvas.drawRRect(
          rect,
          Paint()
            ..color =
                const Color(0xFFFFF4DA).withValues(alpha: strength * .06 / i)
            ..style = PaintingStyle.fill);
      canvas.drawRRect(
          rect,
          Paint()
            ..color = Colors.white.withValues(alpha: strength * .12 / i)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    final halo = RRect.fromRectAndRadius(
        flight.rectAt(progress).inflate(1.5), const Radius.circular(13));
    // Let the ivory face and its shadow read first, rather than a neon frame.
    for (final stroke in [
      (3.0, const Color(0xFF17304E), .16),
      (1.2, Colors.white, .50)
    ]) {
      canvas.drawRRect(
          halo,
          Paint()
            ..color = stroke.$2.withValues(alpha: strength * stroke.$3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke.$1);
    }
    if (!flight.matched && progress > TileFlight.arrival) {
      final landing =
          (progress - TileFlight.arrival) / (1 - TileFlight.arrival);
      final pulse = math.sin(math.pi * landing);
      final ring = RRect.fromRectAndRadius(
          flight.target.inflate(2 + landing * 5), const Radius.circular(13));
      canvas.drawRRect(
          ring,
          Paint()
            ..color = const Color(0xFFFFF4DA).withValues(alpha: pulse * .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8);
      canvas.drawRRect(
          RRect.fromRectAndRadius(flight.target, const Radius.circular(12)),
          Paint()..color = Colors.white.withValues(alpha: pulse * .18));
    }
  }

  @override
  bool shouldRepaint(FlightAccentPainter old) =>
      old.flight != flight || old.progress != progress;
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.burst, this.progress);
  final TrayBurst burst;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress < burst.reactionStart) return;
    final p = burst.particlesAt(progress);
    final fade = 1 - p;
    // The faces compress together before any particles are released.
    final reaction = burst.reactionAt(progress);
    for (final rect in burst.rects) {
      if (p < .3) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(12)),
            Paint()
              ..color = Colors.white
                  .withValues(alpha: reaction * (1 - p / .3) * .82));
      }
    }
    if (progress < burst.release || progress >= 1 || burst.rects.isEmpty)
      return;
    // One shared central flash ties all three slot reactions together.
    final center = burst.rects.map((r) => r.center).reduce((a, b) => a + b) /
        burst.rects.length.toDouble();
    final flashRect = Rect.fromCenter(
        center: center, width: 48 + 100 * p, height: 38 + 38 * p);
    canvas.drawOval(
        flashRect,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: fade * .9),
            const Color(0xFFFFDC78).withValues(alpha: fade * .5),
            const Color(0x00FFDC78),
          ], stops: const [
            0,
            .35,
            1
          ]).createShader(flashRect));
    for (final rect in burst.rects) {
      final ring = RRect.fromRectAndRadius(
          rect.inflate(2 + Curves.easeOut.transform(p) * 13),
          const Radius.circular(14));
      canvas.drawRRect(
          ring,
          Paint()
            ..color = const Color(0xFF17304E).withValues(alpha: fade * .45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 * fade);
      canvas.drawRRect(
          ring,
          Paint()
            ..color = const Color(0xFFFFDF80).withValues(alpha: fade * .9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * fade);
      // Fixed 12 particles per slot. Small deterministic stagger, varied star
      // and round shapes, decelerating scatter and gentle inward gravity.
      for (var i = 0; i < TrayBurst.particlesPerSlot; i++) {
        final delay = (i % 3) * .035;
        if (p <= delay) continue;
        final age = ((p - delay) / (1 - delay)).clamp(0.0, 1.0);
        final scatter = Curves.easeOutCubic.transform(age);
        final alpha = (1 - age) * (1 - age);
        final angle = i * math.pi * 2 / TrayBurst.particlesPerSlot;
        final origin = rect.center +
            Offset(math.cos(angle) * rect.width * .3,
                math.sin(angle) * rect.height * .3);
        final point = origin +
            Offset(
                math.cos(angle) * (22 + (i % 4) * 5) * scatter,
                burst.direction * (12 * scatter + 34 * age * age) +
                    math.sin(angle) * 21 * scatter);
        final radius = (3.3 + (i % 3) * 1.1) * (1 - age * .8);
        final glow = Rect.fromCircle(center: point, radius: radius * 2);
        canvas.drawCircle(
            point,
            radius * 2,
            Paint()
              ..shader = RadialGradient(colors: [
                const Color(0xFFFFDF80).withValues(alpha: alpha * .65),
                const Color(0x00FFDF80)
              ]).createShader(glow));
        final pen = Paint()
          ..color = const Color(0xFFFFDF80).withValues(alpha: alpha);
        if (i.isEven) {
          final star = Path();
          for (var tip = 0; tip < 8; tip++) {
            final theta = angle + age * .65 + tip * math.pi / 4;
            final r = tip.isEven ? radius : radius * .32;
            final x = point.dx + math.cos(theta) * r;
            final y = point.dy + math.sin(theta) * r;
            if (tip == 0) {
              star.moveTo(x, y);
            } else {
              star.lineTo(x, y);
            }
          }
          star.close();
          canvas.drawPath(
              star,
              Paint()
                ..color = const Color(0xFF17304E).withValues(alpha: alpha * .6)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5);
          canvas.drawPath(star, pen);
        } else {
          canvas.drawCircle(point, radius * .65, pen);
        }
        canvas.drawCircle(point, radius * .3,
            Paint()..color = Colors.white.withValues(alpha: alpha));
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.burst != burst;
}
