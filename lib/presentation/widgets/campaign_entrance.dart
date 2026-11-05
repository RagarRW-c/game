import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/campaign_feedback_audio.dart';
import '../../domain/tile.dart';

/// One finite clock for the whole board. It never owns or edits engine state.
class CampaignEntranceController {
  CampaignEntranceController({required TickerProvider vsync, this.onEvent})
      : clock = AnimationController(vsync: vsync, duration: duration) {
    clock.value = 1;
    clock.addListener(_observe);
  }

  static const duration = Duration(milliseconds: 980);
  static const waveCount = 6;
  static const waveGapMs = 100;
  static const tileDurationMs = 480;
  static const landingFraction = .68;
  final AnimationController clock;
  final ValueChanged<CampaignFeedbackEvent>? onEvent;
  Map<String, int> _waves = const {};
  final Set<int> _sounded = {};
  int _generation = 0;
  bool _disposed = false;
  bool get running => clock.value < 1;
  Map<String, int> get waves => Map.unmodifiable(_waves);

  /// Layer first, then top-to-bottom spatial order. Only this presentation map
  /// is sorted: canonical Stack ordering and tile coordinates never change.
  void prepare(Iterable<Tile> tiles, {required bool reducedMotion}) {
    final generation = ++_generation;
    clock.stop();
    _sounded.clear();
    final ordered = tiles.toList()
      ..sort((a, b) {
        var order = a.layer.compareTo(b.layer);
        if (order == 0) order = a.y.compareTo(b.y);
        if (order == 0) order = a.x.compareTo(b.x);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    _waves = {
      for (var i = 0; i < ordered.length; i++)
        ordered[i].id: i * waveCount ~/ ordered.length,
    };
    clock.value = reducedMotion || ordered.isEmpty ? 1 : 0;
    if (!running) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || generation != _generation || !running) return;
      onEvent?.call(CampaignFeedbackEvent.entrance);
      clock.forward();
    });
  }

  double progressFor(String id) =>
      ((clock.value * duration.inMilliseconds - (_waves[id] ?? 0) * waveGapMs) /
              tileDurationMs)
          .clamp(0.0, 1.0);

  void _observe() {
    if (_disposed || !clock.isAnimating || clock.value >= 1) return;
    // Three shared accents, not 99 independent landing sounds. A skipped frame
    // dispatches at most the latest accent, never a backlog of stale sounds.
    int? latest;
    for (final wave in const [0, 2, 5]) {
      if (_sounded.contains(wave) || !_waves.containsValue(wave)) continue;
      final landingMs = wave * waveGapMs + tileDurationMs * landingFraction;
      if (clock.value * duration.inMilliseconds >= landingMs) {
        _sounded.add(wave);
        latest = wave;
      }
    }
    if (latest != null) onEvent?.call(CampaignFeedbackEvent.landing);
  }

  /// Interruption/reduced motion reveals the exact canonical board immediately.
  /// Resuming does not replay entrance audio or restart the gate.
  void finish() {
    if (_disposed) return;
    _generation++;
    clock.stop();
    clock.value = 1;
  }

  void dispose() {
    _disposed = true;
    _generation++;
    clock.dispose();
  }
}

class CampaignEntranceGate extends StatelessWidget {
  const CampaignEntranceGate(
      {super.key, required this.controller, required this.child});
  final CampaignEntranceController controller;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller.clock,
      child: child,
      builder: (_, child) => IgnorePointer(
          ignoring: controller.running,
          child:
              ExcludeSemantics(excluding: controller.running, child: child!)));
}

class CampaignTileEntrance extends StatelessWidget {
  const CampaignTileEntrance(
      {super.key,
      required this.controller,
      required this.tileId,
      required this.child});
  final CampaignEntranceController controller;
  final String tileId;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller.clock,
      child: RepaintBoundary(child: child),
      builder: (_, child) {
        final p = controller.progressFor(tileId);
        if (p >= 1) return child!;
        final wave = controller._waves[tileId] ?? 0;
        final drop = Curves.easeOutCubic.transform(
            (p / CampaignEntranceController.landingFraction).clamp(0.0, 1.0));
        final settle = ((p - CampaignEntranceController.landingFraction) /
                (1 - CampaignEntranceController.landingFraction))
            .clamp(0.0, 1.0);
        final bounce = math.sin(settle * math.pi * 2) * (1 - settle);
        return Transform.translate(
            offset: Offset(0, -(34 + wave * 2) * (1 - drop) + bounce * 2.2),
            transformHitTests: false,
            child: Transform.rotate(
                angle: (wave.isEven ? 1 : -1) * .028 * (1 - drop),
                transformHitTests: false,
                child: Transform.scale(
                    scaleX: 1 + bounce * .025,
                    scaleY: 1 - bounce * .04,
                    transformHitTests: false,
                    child: Opacity(
                        opacity: (p / .18).clamp(0.0, 1.0), child: child))));
      });
}
