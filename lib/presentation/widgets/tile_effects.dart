import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../../domain/tile.dart';
import 'game_tile.dart';
import 'tile_face.dart';

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
      this.serial, this.source, this.target, this.slot, this.matched,
      {this.reversed = false, this.reverseFrom = 1, this.restoredSource});
  final int serial;
  final TileFlightSource source;
  final Rect target;
  final int slot;
  final bool matched;
  final bool reversed;
  final double reverseFrom;
  // Reselecting a mid-return tile starts its new flight away from its cell.
  // A subsequent Undo must still finish at the original canonical location.
  final TileFlightSource? restoredSource;

  Size faceSizeAt(double progress) {
    final size =
        Size.lerp(source.faceSize, target.size, appearanceAt(progress))!;
    return reversed && restoredSource != null
        ? Size.lerp(size, restoredSource!.faceSize, _smootherStep(progress))!
        : size;
  }

  double pathProgressAt(double progress) =>
      reversed ? reverseFrom * (1 - progress) : progress;

  double appearanceAt(double progress) => travelAt(pathProgressAt(progress));

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
    final rect = _forwardRectAt(pathProgressAt(progress));
    return reversed && restoredSource != null
        ? Rect.lerp(rect, restoredSource!.rect, _smootherStep(progress))!
        : rect;
  }

  Rect _forwardRectAt(double progress) {
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
  const MatchedTileSnapshot(this.tile, this.rect, {this.sourceRect});
  final Tile tile;
  final Rect rect;
  final Rect? sourceRect;
}

class TrayBurst {
  static const duration = Duration(milliseconds: 640);
  static const compressionDuration = Duration(milliseconds: 70);
  static const fadeDuration = Duration(milliseconds: 80);
  static const particlesPerSlot = 12;
  const TrayBurst(this.serial, this.rects, this.direction,
      {this.snapshots = const [],
      this.shifts = const [],
      this.catalog = tileCatalog,
      this.incomingId,
      this.boardMatch = false});
  final int serial;
  final List<Rect> rects;
  final double direction;
  final List<MatchedTileSnapshot> snapshots;

  /// Unmatched survivors move to their already-committed canonical slots while
  /// the matching pair moves beside the incoming tile. No engine reordering.
  final List<MatchedTileSnapshot> shifts;
  final Map<String, TileArt> catalog;
  final String? incomingId;
  final bool boardMatch;

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
    if (p <= reactionStart) return shiftRectAt(face, p);
    final squeeze = _smoothStep(reactionAt(p));
    final clearing = _smoothStep(((p - release) / _fade).clamp(0.0, 1.0));
    final scale = 1 - clearing * .24;
    return Rect.fromCenter(
        center: face.rect.center,
        width: face.rect.width * (1 + squeeze * .07) * scale,
        height: face.rect.height * (1 - squeeze * .13) * scale);
  }

  Rect shiftRectAt(MatchedTileSnapshot face, double p) {
    if (reactionStart == 0 || p >= reactionStart) return face.rect;
    return Rect.lerp(face.sourceRect ?? face.rect, face.rect,
        _smootherStep((p / reactionStart).clamp(0.0, 1.0)))!;
  }
}

double _smoothStep(double t) => t * t * (3 - 2 * t);
double _smootherStep(double t) => t * t * t * (10 + t * (-15 + 6 * t));

enum BoardCueKind { hint, undo, shuffle }

/// Decorative feedback for a committed action, never a second board state.
/// Shuffle permutes artwork in place, so its cue must not move tile bodies.
class BoardCue {
  const BoardCue(this.serial, this.kind, this.rects);
  static const maxRects = 12;
  final int serial;
  final BoardCueKind kind;
  final List<Rect> rects;
  Duration get duration => Duration(
          milliseconds: switch (kind) {
        BoardCueKind.hint => 240,
        BoardCueKind.undo => 260,
        BoardCueKind.shuffle => 300,
      });
  Rect get bounds => rects.reduce((a, b) => a.expandToInclude(b));
}

/// Presentation only: no engine reference, rewards, asynchronous work or timers.
/// Eviction/cancellation reveals the canonical tray immediately.
class TileEffectsController extends ChangeNotifier {
  static const maxFlights = 7;
  static const maxBursts = 3;
  final layerKey = GlobalKey();
  final boardKey = GlobalKey();
  Size boardTileSize = Size.zero;
  final slotKeys = List.generate(7, (_) => GlobalKey());
  final List<TileFlight> _flights = [];
  final List<TrayBurst> _bursts = [];
  final Map<String, Rect> _presentedRects = {};
  final Map<int, double> _flightProgress = {};
  int? _presentationBurst;
  int _serial = 0;
  int _revision = 0;
  int get revision => _revision;
  bool _disposed = false;
  BoardCue? _boardCue;
  BoardCue? get boardCue => _boardCue;
  bool reducedMotion = false;
  bool _audioActive = true;
  VoidCallback? cancelPendingAudio;
  final Map<int, _BurstAudio> _burstAudio = {};

  void setAudioActive(bool active) {
    if (_disposed || _audioActive == active) return;
    _audioActive = active;
    if (!active) clear(notify: false);
  }

  void _cancelAudio() {
    _burstAudio.clear();
    cancelPendingAudio?.call();
  }

  /// Observe the existing visual clock. Dispatch after this frame paints, once
  /// per retained burst; never notify listeners or call audio during build.
  void observeBurst(TrayBurst burst, double progress) {
    if (!_disposed && presents(burst)) {
      for (final shift in burst.shifts) {
        _presentedRects[shift.tile.id] = burst.shiftRectAt(shift, progress);
      }
    }
    final cue = _burstAudio[burst.serial];
    if (_disposed ||
        !_audioActive ||
        cue == null ||
        cue.queued ||
        progress < burst.release ||
        progress >= 1) return;
    cue.queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed ||
          !_audioActive ||
          !identical(_burstAudio[burst.serial], cue)) return;
      _burstAudio.remove(burst.serial);
      cue.play();
    });
  }

  // Refreshed by the tray with its actual world palette, including Hint moves
  // that have no tapped board source. No notification or animation is started.
  Map<String, TileArt> catalog = tileCatalog;

  List<TileFlight> get flights => List.unmodifiable(_flights);
  List<TrayBurst> get bursts => List.unmodifiable(_bursts);
  bool presents(TrayBurst burst) => burst.serial == _presentationBurst;
  bool hides(String id) =>
      _flights
          .any((f) => !f.reversed && !f.matched && f.source.tile.id == id) ||
      _bursts.any((b) => presents(b) && b.shifts.any((s) => s.tile.id == id));
  bool hidesBoard(String id) =>
      _flights.any((f) => f.reversed && f.source.tile.id == id);

  void observeFlight(TileFlight flight, double progress) {
    if (!_disposed &&
        !flight.matched &&
        _flights.any((active) => active.serial == flight.serial)) {
      _presentedRects[flight.source.tile.id] = flight.rectAt(progress);
      _flightProgress[flight.serial] = progress;
    }
  }

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
    for (final flight
        in _flights.where((f) => f.reversed && f.source.tile.id == tile.id)) {
      final progress = _flightProgress[flight.serial] ?? 0;
      return TileFlightSource(tile, flight.rectAt(progress), catalog, depth,
          flight.faceSizeAt(progress));
    }
    return rect == null
        ? null
        : TileFlightSource(tile, rect, catalog, depth,
            (context.findRenderObject()! as RenderBox).size);
  }

  /// Called after transaction validation, using the existing fitted Stack.
  /// No extra per-tile keys, retained contexts, layout or engine dependency.
  List<TileFlightSource> captureBoard(Iterable<Tile> tiles) {
    if (_disposed || reducedMotion || !_audioActive || boardTileSize.isEmpty) {
      return const [];
    }
    final board = boardKey.currentContext?.findRenderObject();
    final layer = layerKey.currentContext?.findRenderObject();
    if (board is! RenderBox ||
        layer is! RenderBox ||
        !board.attached ||
        !layer.attached ||
        !board.hasSize ||
        !layer.hasSize) {
      return const [];
    }
    final transform = board.getTransformTo(layer);
    return [
      for (final tile in tiles)
        TileFlightSource(
            tile,
            MatrixUtils.transformRect(
                transform, tile.boardRect(board.size, boardTileSize)),
            catalog,
            1,
            boardTileSize),
    ]
        .where((source) =>
            source.rect.isFinite &&
            !source.rect.isEmpty &&
            (Offset.zero & layer.size).overlaps(source.rect))
        .toList(growable: false);
  }

  void showBoardCue(BoardCueKind kind, Iterable<TileFlightSource> sources,
      {int? expectedRevision}) {
    if (_disposed ||
        reducedMotion ||
        !_audioActive ||
        (expectedRevision != null && expectedRevision != _revision)) return;
    final rects = sources.map((s) => s.rect).take(BoardCue.maxRects).toList();
    if (rects.isEmpty) return;
    _revision++;
    _boardCue = BoardCue(++_serial, kind, List.unmodifiable(rects));
    notifyListeners();
  }

  void finishBoardCue(int serial) {
    if (_disposed || _boardCue?.serial != serial) return;
    _boardCue = null;
    notifyListeners();
  }

  /// Snapshot all tray anchors inside the validated transaction, before Undo
  /// changes state. The engine's before/after IDs identify the restored tile.
  Map<String, TileFlight> captureUndo(List<Tile> tray,
      {required int maxLayer}) {
    final board = {
      for (final source in captureBoard(tray)) source.tile.id: source
    };
    return {
      for (var slot = 0; slot < tray.length && slot < slotKeys.length; slot++)
        if (board[tray[slot].id] case final source?)
          if (rectFor(slotKeys[slot].currentContext) case final target?)
            tray[slot].id: _undoTemplate(source, target, slot, maxLayer),
    };
  }

  TileFlight _undoTemplate(
      TileFlightSource source, Rect target, int slot, int maxLayer) {
    maxLayer = math.max(maxLayer, source.tile.layer);
    for (final flight in _flights) {
      if (!flight.reversed &&
          !flight.matched &&
          flight.source.tile.id == source.tile.id) {
        // Reverse from the last PAINTED position, not the slot the forward
        // flight has not yet reached. Also retain its exact artwork blend.
        return TileFlight(0, flight.source, flight.target, slot, false,
            reversed: true,
            reverseFrom: _flightProgress[flight.serial] ?? 0,
            restoredSource:
                (flight.source.rect.center - source.rect.center).distance > 1e-9
                    ? source
                    : null);
      }
    }
    return TileFlight(
        0,
        TileFlightSource(source.tile, source.rect, source.catalog,
            maxLayer == 0 ? 1 : source.tile.layer / maxLayer, source.faceSize),
        target,
        slot,
        false,
        reversed: true);
  }

  void clearForUndo() {
    final returning = _flights.where((flight) => flight.reversed).toList();
    final progress = Map<int, double>.of(_flightProgress);
    clear(notify: false);
    if (_disposed) return;
    _flights.addAll(returning);
    for (final flight in returning) {
      _flightProgress[flight.serial] = progress[flight.serial] ?? 0;
    }
    notifyListeners();
  }

  void undoAccepted(TileFlight? captured, {required int expectedRevision}) {
    if (_disposed ||
        reducedMotion ||
        !_audioActive ||
        captured == null ||
        expectedRevision != _revision) return;
    _revision++;
    if (_flights.length == maxFlights) _flights.removeAt(0);
    _flights.add(TileFlight(
        ++_serial, captured.source, captured.target, captured.slot, false,
        reversed: true,
        reverseFrom: captured.reverseFrom,
        restoredSource: captured.restoredSource));
    _flightProgress
        .removeWhere((serial, _) => !_flights.any((f) => f.serial == serial));
    notifyListeners();
  }

  bool accepted(
      {required TileFlightSource? source,
      required int slot,
      required List<String> tray,
      required Set<String> matchedIds,
      List<Tile> matchedTiles = const [],
      List<Tile> beforeTiles = const [],
      List<TileFlightSource> hintSources = const [],
      bool directBoardMatch = false,
      int? expectedRevision,
      required List<int> matchedSlots,
      required TrayPlacement placement,
      VoidCallback? onMatchBurst}) {
    if (_disposed ||
        (expectedRevision != null && expectedRevision != _revision))
      return false;
    _revision++;
    if (reducedMotion || !_audioActive) {
      clear();
      return false;
    }
    var deferred = false;
    _boardCue = null;
    final previousRects = Map<String, Rect>.of(_presentedRects);
    for (final flight in _flights) {
      previousRects.putIfAbsent(
          flight.source.tile.id, () => flight.source.rect);
    }
    // A new accepted move supersedes the old transient arrangement. Retain
    // each burst's audio clock, but never draw old faces over newly reused
    // canonical slots. Input and engine state are never queued behind VFX.
    _presentationBurst = null;
    _presentedRects.clear();
    // A match compacts tray indices. Cancel earlier flights rather than letting
    // them land in obsolete slots or replay already matched tile faces.
    if (matchedIds.isNotEmpty) {
      _flights.removeWhere(
          (f) => !f.reversed || matchedIds.contains(f.source.tile.id));
    } else {
      _flights.removeWhere((f) => f.reversed
          ? tray.contains(f.source.tile.id)
          : !tray.contains(f.source.tile.id));
      for (final flight in _flights) {
        final rect = previousRects[flight.source.tile.id];
        if (rect != null) _presentedRects[flight.source.tile.id] = rect;
      }
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
      final hasIncoming = _flights.any((f) => f.matched);
      final group = hasIncoming &&
          matchedSlots.length == 3 &&
          matchedTiles.length == 3 &&
          slot >= 2;
      // Keep the engine's append/compact order. Visually place the triple in
      // the three adjacent slots ending at the incoming tile's measured target.
      final targets = group ? [slot - 2, slot - 1, slot] : matchedSlots;
      final boardSources = {
        for (final source in hintSources)
          if (matchedIds.contains(source.tile.id)) source.tile.id: source,
      }.values.take(3).toList(growable: false);
      final rects = directBoardMatch
          ? [
              if (boardSources.length == 3)
                for (final s in boardSources) s.rect
            ]
          : [
              for (final slot in targets)
                if (slot >= 0 && slot < slotKeys.length)
                  rectFor(slotKeys[slot].currentContext)
            ].whereType<Rect>().toList();
      if (rects.isNotEmpty) {
        final snapshots = <MatchedTileSnapshot>[];
        if (directBoardMatch) {
          snapshots.addAll(
              boardSources.map((s) => MatchedTileSnapshot(s.tile, s.rect)));
        }
        for (var i = 0;
            !directBoardMatch &&
                i < matchedSlots.length &&
                i < matchedTiles.length &&
                i < 3;
            i++) {
          final index = targets[i];
          if (index < 0 || index >= slotKeys.length) continue;
          final rect = rectFor(slotKeys[index].currentContext);
          if (rect != null) {
            final oldIndex = matchedSlots[i];
            final origin = previousRects[matchedTiles[i].id] ??
                (oldIndex >= 0 && oldIndex < slotKeys.length
                    ? rectFor(slotKeys[oldIndex].currentContext)
                    : null);
            snapshots.add(MatchedTileSnapshot(matchedTiles[i], rect,
                sourceRect: group ? origin : null));
          }
        }
        final shifts = <MatchedTileSnapshot>[];
        if (group) {
          for (var i = 0; i < beforeTiles.length; i++) {
            final tile = beforeTiles[i];
            final destination = tray.indexOf(tile.id);
            if (destination < 0 ||
                destination >= slotKeys.length ||
                i >= slotKeys.length) continue;
            final target = rectFor(slotKeys[destination].currentContext);
            final origin =
                previousRects[tile.id] ?? rectFor(slotKeys[i].currentContext);
            if (target != null && origin != null) {
              shifts.add(MatchedTileSnapshot(tile, target, sourceRect: origin));
            }
          }
        }
        if (_bursts.length == maxBursts) {
          _burstAudio.remove(_bursts.removeAt(0).serial);
        }
        _bursts.add(TrayBurst(
            ++_serial, rects, placement == TrayPlacement.top ? 1 : -1,
            snapshots: List.unmodifiable(snapshots),
            shifts: List.unmodifiable(shifts),
            catalog: source?.catalog ?? catalog,
            boardMatch: directBoardMatch,
            incomingId: hasIncoming ? source?.tile.id : null));
        _presentationBurst = _bursts.last.serial;
        if (_audioActive && onMatchBurst != null) {
          _burstAudio[_bursts.last.serial] = _BurstAudio(onMatchBurst);
          deferred = true;
        }
      }
    }
    _flightProgress
        .removeWhere((serial, _) => !_flights.any((f) => f.serial == serial));
    notifyListeners();
    return deferred;
  }

  void finishFlight(int serial) {
    if (_disposed) return;
    for (final flight in _flights.where((f) => f.serial == serial)) {
      _presentedRects.remove(flight.source.tile.id);
    }
    _flights.removeWhere((f) => f.serial == serial);
    _flightProgress.remove(serial);
    notifyListeners();
  }

  void finishBurst(int serial) {
    if (_disposed) return;
    _burstAudio.remove(serial);
    _bursts.removeWhere((b) => b.serial == serial);
    if (_presentationBurst == serial) {
      _presentationBurst = null;
      _presentedRects.clear();
    }
    notifyListeners();
  }

  void clear({bool notify = true}) {
    if (_disposed) return;
    _revision++;
    _cancelAudio();
    _presentationBurst = null;
    _presentedRects.clear();
    _flightProgress.clear();
    final hadCue = _boardCue != null;
    _boardCue = null;
    if (_flights.isEmpty && _bursts.isEmpty && !hadCue) return;
    _flights.clear();
    _bursts.clear();
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _cancelAudio();
    cancelPendingAudio = null;
    _disposed = true;
    _flightProgress.clear();
    _boardCue = null;
    _presentationBurst = null;
    _presentedRects.clear();
    _flights.clear();
    _bursts.clear();
    super.dispose();
  }
}

class _BurstAudio {
  _BurstAudio(this.play);
  final VoidCallback play;
  bool queued = false;
}

/// Only paint visibility changes. Canonical layout, semantics and hit testing
/// stay engine-owned while one non-interactive copy returns from the tray.
class BoardFlightVisibility extends StatelessWidget {
  const BoardFlightVisibility(
      {super.key,
      required this.controller,
      required this.tileId,
      required this.child});
  final TileEffectsController controller;
  final String tileId;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (_, child) => Opacity(
          opacity: controller.hidesBoard(tileId) ? 0 : 1,
          alwaysIncludeSemantics: true,
          child: child));
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

class _GameTileEffectsState extends State<GameTileEffects>
    with WidgetsBindingObserver {
  Object? _geometry;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void _updateAudioActivity() {
    widget.controller.setAudioActive(_foreground &&
        TickerMode.of(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAudioActivity();
  }

  @override
  void didUpdateWidget(GameTileEffects oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.clear(notify: false);
      _geometry = null;
      _updateAudioActivity();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) {
      _updateAudioActivity();
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          _foreground,
          ModalRoute.of(context)?.isCurrent ?? true,
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
                    if (widget.controller.boardCue case final cue?)
                      Positioned.fromRect(
                        rect: cue.bounds,
                        key: ValueKey('board_cue_${cue.serial}'),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: cue.duration,
                          onEnd: () =>
                              widget.controller.finishBoardCue(cue.serial),
                          builder: (context, progress, _) => CustomPaint(
                              painter: BoardCuePainter(cue, progress)),
                        ),
                      ),
                    for (final flight in widget.controller.flights)
                      Positioned.fill(
                          key: ValueKey('flight_layer_${flight.serial}'),
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey('flight_${flight.serial}'),
                            tween: Tween(begin: 0, end: 1),
                            duration: TileFlight.duration,
                            onEnd: () =>
                                widget.controller.finishFlight(flight.serial),
                            builder: (context, progress, _) {
                              widget.controller.observeFlight(flight, progress);
                              return Stack(children: [
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
                              ]);
                            },
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
                            builder: (context, progress, _) {
                              widget.controller.observeBurst(burst, progress);
                              // Superseded bursts retain this keyed clock for
                              // exactly-once audio, but no longer own visuals.
                              // Opacity(0) skipped paint while still rebuilding
                              // and laying out every obsolete face each tick.
                              if (!widget.controller.presents(burst)) {
                                return const SizedBox.shrink();
                              }
                              return Stack(children: [
                                for (final shift in burst.shifts)
                                  Positioned.fromRect(
                                      rect: burst.shiftRectAt(shift, progress),
                                      child: TrayShiftVisual(
                                          tile: shift.tile,
                                          catalog: burst.catalog)),
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
                                        painter: MatchBurstPainter(
                                            burst, progress))),
                              ]);
                            },
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
    final size = flight.faceSizeAt(progress);
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

/// A survivor of an already-committed match, shown exactly once while its
/// canonical tray slot is hidden. Uses the same face as a settled tray tile.
class TrayShiftVisual extends StatelessWidget {
  const TrayShiftVisual({super.key, required this.tile, required this.catalog});
  final Tile tile;
  final Map<String, TileArt> catalog;

  @override
  Widget build(BuildContext context) => GameTileWidget(
      tile: tile,
      catalog: catalog,
      enabled: true,
      highlighted: false,
      trayTile: true);
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
    if (progress < 0 || progress >= 1 || flight.opacityAt(progress) == 0)
      return;
    // Accepted-move light starts on the first flight frame and uses its pickup
    // clock. Pointer-down alone cannot create it, and input is never delayed.
    final phase = flight.pathProgressAt(progress);
    if (phase < TileFlight.pickup) {
      final glow = 1 - phase / TileFlight.pickup;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              flight.rectAt(progress).inflate(1), const Radius.circular(12)),
          Paint()
            ..color = const Color(0xFFFFDF80).withValues(alpha: glow * .65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    final strength = math.sin(math.pi * phase);
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
    if (!flight.reversed && !flight.matched && progress > TileFlight.arrival) {
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

/// Local-only accents: no blur, shader allocation or paint outside tile bounds.
class BoardCuePainter extends CustomPainter {
  const BoardCuePainter(this.cue, this.progress);
  final BoardCue cue;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final strength = math.sin(math.pi * progress);
    final pen = Paint()
      ..color = const Color(0xFFFFDF80).withValues(alpha: strength * .75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final absolute in cue.rects) {
      final rect = absolute.shift(-cue.bounds.topLeft);
      final unit = rect.shortestSide;
      final body = RRect.fromRectAndRadius(
          rect.deflate(unit * .09), Radius.circular(unit * .18));
      canvas.save();
      canvas.clipRRect(body);
      canvas.drawRRect(body.deflate(1), pen);
      switch (cue.kind) {
        case BoardCueKind.undo:
          // Two left-facing chevrons retreat along the lower rim of the
          // restored face. The tile itself stays at its authoritative position.
          for (var i = 0; i < 2; i++) {
            final c = Offset(
                rect.center.dx + unit * (.12 - i * .18 - progress * .08),
                rect.top + unit * .75);
            canvas.drawPath(
                Path()
                  ..moveTo(c.dx + unit * .06, c.dy - unit * .07)
                  ..lineTo(c.dx - unit * .02, c.dy)
                  ..lineTo(c.dx + unit * .06, c.dy + unit * .07),
                pen);
          }
        case BoardCueKind.shuffle:
          // Opposed perimeter sweeps describe the in-place type permutation.
          for (var i = 0; i < 2; i++) {
            canvas.drawArc(body.outerRect.deflate(unit * .04),
                math.pi * (i + progress), math.pi * .35, false, pen);
          }
        case BoardCueKind.hint:
          for (var i = 0; i < 4; i++) {
            final angle = math.pi * (i * .5 + .25);
            final c = rect.center +
                Offset(math.cos(angle), math.sin(angle)) * unit * .34;
            final r = unit * .055 * strength;
            canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), pen);
            canvas.drawLine(c - Offset(0, r), c + Offset(0, r), pen);
          }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(BoardCuePainter old) =>
      old.cue != cue || old.progress != progress;
}

class MatchBurstPainter extends CustomPainter {
  const MatchBurstPainter(this.burst, this.progress);
  final TrayBurst burst;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress < burst.reactionStart || progress >= 1) return;
    final p = burst.particlesAt(progress);
    final reaction = burst.reactionAt(progress);
    for (final slot in burst.rects) {
      // The artwork is square even in a tall tray slot. Confine all light and
      // particles to that face; never wash over a neighboring tile or badge.
      final rect = TileFace.artworkRect(slot.size).shift(slot.topLeft);
      final unit = rect.shortestSide;
      final body = RRect.fromRectAndRadius(
          rect.deflate(unit * .06), Radius.circular(unit * .18));
      canvas.save();
      canvas.clipRRect(body);
      final light = reaction * (1 - p);
      canvas.drawRRect(
          body,
          Paint()
            ..color = const Color(0xFFFFF4DA).withValues(alpha: light * .18));
      canvas.drawRRect(
          body.deflate(1),
          Paint()
            ..color = const Color(0xFFFFDF80).withValues(alpha: light * .8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.min(1.6, unit * .05));
      if (progress >= burst.release) {
        // Fixed, deterministic particles share the original burst/audio clock.
        // Small filled glints replace the wide flash and per-particle shaders.
        for (var i = 0; i < TrayBurst.particlesPerSlot; i++) {
          final delay = (i % 3) * .035;
          if (p <= delay) continue;
          final age = ((p - delay) / (1 - delay)).clamp(0.0, 1.0);
          final scatter = Curves.easeOutCubic.transform(age);
          final angle = i * math.pi * 2 / TrayBurst.particlesPerSlot;
          final point = rect.center +
              Offset(
                  math.cos(angle) * unit * (.18 + .22 * scatter),
                  math.sin(angle) * unit * (.18 + .22 * scatter) +
                      burst.direction * unit * .04 * age);
          final radius = math.min(2.2, unit * .055) * (1 - age * .75);
          final pen = Paint()
            ..color = (i.isEven ? const Color(0xFFFFDF80) : Colors.white)
                .withValues(alpha: (1 - age) * (1 - age));
          if (i.isEven) {
            final star = Path()
              ..moveTo(point.dx, point.dy - radius)
              ..lineTo(point.dx + radius * .3, point.dy - radius * .3)
              ..lineTo(point.dx + radius, point.dy)
              ..lineTo(point.dx + radius * .3, point.dy + radius * .3)
              ..lineTo(point.dx, point.dy + radius)
              ..lineTo(point.dx - radius * .3, point.dy + radius * .3)
              ..lineTo(point.dx - radius, point.dy)
              ..lineTo(point.dx - radius * .3, point.dy - radius * .3)
              ..close();
            canvas.drawPath(star, pen);
          } else {
            canvas.drawCircle(point, radius * .6, pen);
          }
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(MatchBurstPainter old) =>
      old.progress != progress || old.burst != burst;
}
