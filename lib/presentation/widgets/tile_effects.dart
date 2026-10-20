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
  static const duration = Duration(milliseconds: 280);
  const TileFlight(
      this.serial, this.source, this.target, this.slot, this.matched);
  final int serial;
  final TileFlightSource source;
  final Rect target;
  final int slot;
  final bool matched;

  Rect rectAt(double progress) {
    if (progress <= 0) return source.rect;
    if (progress >= 1) return target;
    final t = Curves.easeInOutSine.transform(progress);
    final rect = Rect.lerp(source.rect, target, t)!;
    final lift = math.sin(math.pi * progress);
    final settling = progress > .75
        ? math.sin(math.pi * (progress - .75) / .25) * .045
        : 0.0;
    return rect
        .inflate(math.min(rect.width, rect.height) * (lift * .12 + settling))
        .shift(Offset(lift * (slot >= 3 ? -16 : 16), -lift * 18));
  }
}

class TrayBurst {
  static const duration = Duration(milliseconds: 500);
  static const particlesPerSlot = 12;
  const TrayBurst(this.serial, this.rects, this.direction);
  final int serial;
  final List<Rect> rects;
  final double direction;
}

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
        if (_bursts.length == maxBursts) _bursts.removeAt(0);
        _bursts.add(TrayBurst(
            ++_serial, rects, placement == TrayPlacement.top ? 1 : -1));
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
                                    opacity: flight.matched
                                        ? (1 -
                                            ((progress - .65) / .35)
                                                .clamp(0.0, 1.0))
                                        : 1,
                                    child: TileFlightVisual(flight: flight)),
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
                            builder: (context, progress, _) => CustomPaint(
                                painter: _BurstPainter(burst, progress)),
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
  const TileFlightVisual({super.key, required this.flight});
  final TileFlight flight;
  @override
  Widget build(BuildContext context) => FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
          width: flight.source.faceSize.width,
          height: flight.source.faceSize.height,
          child: GameTileWidget(
            tile: flight.source.tile,
            catalog: flight.source.catalog,
            depth: flight.source.depth,
            enabled: true,
            highlighted: false,
            trayTile: true,
            preserveBoardAppearance: true,
          )));
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
    if (progress <= 0 || progress >= 1) return;
    final strength = math.sin(math.pi * progress);
    for (var i = trailSamples; i >= 1; i--) {
      final previous = progress - i * .045;
      if (previous <= 0) continue;
      final rect = RRect.fromRectAndRadius(
          flight.rectAt(previous), const Radius.circular(12));
      canvas.drawRRect(
          rect,
          Paint()
            ..color =
                const Color(0xFFFFDF80).withValues(alpha: strength * .13 / i)
            ..style = PaintingStyle.fill);
      canvas.drawRRect(
          rect,
          Paint()
            ..color = Colors.white.withValues(alpha: strength * .28 / i)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    final halo = RRect.fromRectAndRadius(
        flight.rectAt(progress).inflate(1.5), const Radius.circular(13));
    // Dark edge reads on bright worlds; gold and white read on dark worlds.
    for (final stroke in [
      (7.0, const Color(0xFF17304E), .45),
      (4.0, const Color(0xFFFFD66B), .75),
      (1.6, Colors.white, .95)
    ]) {
      canvas.drawRRect(
          halo,
          Paint()
            ..color = stroke.$2.withValues(alpha: strength * stroke.$3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke.$1);
    }
    if (!flight.matched && progress > .72) {
      final landing = (progress - .72) / .28;
      final pulse = math.sin(math.pi * landing);
      final ring = RRect.fromRectAndRadius(
          flight.target.inflate(2 + landing * 5), const Radius.circular(13));
      canvas.drawRRect(
          ring,
          Paint()
            ..color = const Color(0xFFFFDF80).withValues(alpha: pulse * .8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      canvas.drawRRect(
          RRect.fromRectAndRadius(flight.target, const Radius.circular(12)),
          Paint()..color = Colors.white.withValues(alpha: pulse * .35));
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
    final fade = 1 - progress;
    for (final rect in burst.rects) {
      if (progress < .4) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(12)),
            Paint()
              ..color =
                  Colors.white.withValues(alpha: (1 - progress / .4) * .96));
      }
      final ring = RRect.fromRectAndRadius(
          rect.inflate(2 + progress * 13), const Radius.circular(14));
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
      // Fixed 12 glints per slot, calculated directly: no particle allocation,
      // randomness, simulation, blur or unbounded emitter.
      for (var i = 0; i < TrayBurst.particlesPerSlot; i++) {
        final angle = i * math.pi * 2 / TrayBurst.particlesPerSlot;
        final origin = rect.center +
            Offset(math.cos(angle) * rect.width * .3,
                math.sin(angle) * rect.height * .3);
        final point = origin +
            Offset(
                math.cos(angle) * 42 * progress,
                burst.direction * (24 * progress + 45 * progress * progress) +
                    math.sin(angle) * 22 * progress);
        final radius = (i.isEven ? 4.8 : 3.4) * fade;
        final paint = Paint()
          ..color = (i.isEven ? Colors.white : const Color(0xFFFFDF80))
              .withValues(alpha: fade)
          ..strokeWidth = 2.2;
        final outline = Paint()
          ..color = const Color(0xFF17304E).withValues(alpha: fade * .7)
          ..strokeWidth = 4.2;
        canvas.drawLine(
            point - Offset(radius, 0), point + Offset(radius, 0), outline);
        canvas.drawLine(
            point - Offset(0, radius), point + Offset(0, radius), outline);
        canvas.drawLine(
            point - Offset(radius, 0), point + Offset(radius, 0), paint);
        canvas.drawLine(
            point - Offset(0, radius), point + Offset(0, radius), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.burst != burst;
}
