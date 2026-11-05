import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/game_engine.dart';
import '../domain/game_result.dart';
import '../domain/level.dart';
import '../domain/tile.dart';

const playtestSchema = 'level96-human-playtest/v1';
const level96Asset = 'assets/levels/level_96.json';
const level96Fingerprint = '2b2b8578';

void requirePlaytestOptIn({
  bool enabled = const bool.fromEnvironment('LEVEL96_PLAYTEST'),
  bool release = kReleaseMode,
}) {
  if (!enabled || release) {
    throw StateError('Level 96 playtesting requires LEVEL96_PLAYTEST=true '
        'and a non-release build.');
  }
}

enum PlaytestVariant { original, candidateA, candidateB }

extension PlaytestVariantLabel on PlaytestVariant {
  String get label => switch (this) {
        PlaytestVariant.original => 'ORIGINAL',
        PlaytestVariant.candidateA => 'CANDIDATE A',
        PlaytestVariant.candidateB => 'CANDIDATE B',
      };
}

String fingerprint(String raw) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(raw)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Retains only immutable original text. Every request parses it independently.
class PlaytestLevels {
  PlaytestLevels(this.originalText) {
    if (fingerprint(originalText) != level96Fingerprint) {
      throw StateError('Original Level 96 integrity check failed.');
    }
  }

  final String originalText;

  static Future<PlaytestLevels> load() async =>
      PlaytestLevels(await rootBundle.loadString(level96Asset));

  LevelDefinition create(PlaytestVariant variant) {
    final raw = jsonDecode(originalText) as Map<String, dynamic>;
    final swaps = <String, String>{
      if (variant != PlaytestVariant.original) ...{
        'L96_T094': 'star',
        'L96_T095': 'heart',
      },
      if (variant == PlaytestVariant.candidateB) ...{
        'L96_T071': 'heart',
        'L96_T069': 'banana',
      },
    };
    for (final tile in raw['tiles'] as List<dynamic>) {
      if (swaps.containsKey(tile['id'])) tile['type'] = swaps[tile['id']];
    }
    return LevelDefinition.fromJson(raw);
  }
}

/// No persistent storage, device identifiers, simulation policies or networking.
/// Terminal metrics stop changing; departure records the later navigation.
/// In-progress exports are explicitly RUNNING.
class PlaytestSession {
  PlaytestSession({
    required this.variant,
    required LevelDefinition level,
    String? id,
    DateTime? startedUtc,
    int Function()? elapsedMilliseconds,
  })  : id = id ?? _newId(),
        startedUtc = (startedUtc ?? DateTime.now()).toUtc() {
    _watch.start();
    _elapsed = elapsedMilliseconds ?? () => _watch.elapsedMilliseconds;
    engine = RecordedGameEngine(level, this);
  }

  static String _newId() {
    final random = Random.secure();
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}-'
        '${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  }

  final String id;
  final PlaytestVariant variant;
  final DateTime startedUtc;
  final Stopwatch _watch = Stopwatch();
  late final int Function() _elapsed;
  late final RecordedGameEngine engine;
  final List<Map<String, Object?>> _trace = [];
  final List<Map<String, Object?>> _geometry = [];
  final Map<int, (int, int, Offset)> _pointers = {};
  Size screen = Size.zero;
  Size board = Size.zero;
  Size tile = Size.zero;
  int rejectedTaps = 0;
  int maxTrayOccupancy = 0;
  int maxTrayBeforeResolution = 0;
  int? firstTripleTap;
  List<String>? firstTripleIds;
  String? outcome;
  String? endReason;
  String? departure;
  int? durationMs;
  int get acceptedTaps => _trace.length;
  bool get ended => outcome != null;

  void geometry(Size boardSize, Size tileSize) {
    if (ended) return;
    if (_geometry.isEmpty ||
        board != boardSize ||
        tile != tileSize ||
        _geometry.last['screen'] != '${screen.width}x${screen.height}') {
      board = boardSize;
      tile = tileSize;
      _geometry.add({
        'before_tap': acceptedTaps + 1,
        'elapsed_ms': _elapsed(),
        'screen': '${screen.width}x${screen.height}',
        'screen_width': screen.width,
        'screen_height': screen.height,
        'board_width': board.width,
        'board_height': board.height,
        'tile_width': tile.width,
        'tile_height': tile.height,
      });
    }
  }

  void pointerDown(PointerDownEvent event) {
    if (!ended) {
      _pointers[event.pointer] = (acceptedTaps, rejectedTaps, event.position);
    }
  }

  void pointerUp(PointerUpEvent event) {
    final before = _pointers.remove(event.pointer);
    if (before == null) return;
    // Run after Flutter's gesture arena dispatch. A board tap that did not
    // collect anything counts as rejected (covered tile, margin or blank area).
    scheduleMicrotask(() {
      if (!ended &&
          (event.position - before.$3).distance <= kTouchSlop &&
          acceptedTaps == before.$1 &&
          rejectedTaps == before.$2) {
        rejectedTaps++;
      }
    });
  }

  void abort(String reason) {
    if (!ended) _finish('ABORTED', reason);
  }

  void depart(String reason) {
    departure ??= reason;
    abort(reason);
  }

  void _finish(String value, String reason) {
    if (ended) return;
    outcome = value;
    endReason = reason;
    durationMs = _elapsed();
    _watch.stop();
    _pointers.clear();
  }

  Map<String, Object?> toJson() => {
        'schema': playtestSchema,
        'session_id': id,
        'variant': variant.label,
        'original_asset_fnv1a32': level96Fingerprint,
        'started_utc': startedUtc.toIso8601String(),
        'duration_ms': durationMs,
        'screen_width': screen.width,
        'screen_height': screen.height,
        'board_width': board.width,
        'board_height': board.height,
        'tile_width': tile.width,
        'tile_height': tile.height,
        'geometry_history': _geometry.map((g) => Map.of(g)).toList(),
        'accepted_taps': acceptedTaps,
        'rejected_taps': rejectedTaps,
        'first_triple_tap': firstTripleTap,
        'first_triple_ids':
            firstTripleIds == null ? null : List.of(firstTripleIds!),
        'max_tray_occupancy': maxTrayOccupancy,
        'max_tray_before_resolution': maxTrayBeforeResolution,
        'final_tray_occupancy': engine.tray.length,
        'outcome': outcome ?? 'RUNNING',
        'failure_tap': outcome == 'LOSS' ? acceptedTaps : null,
        'remaining_board_tiles': engine.boardTiles.length,
        'assisted': false,
        'booster_usage': {'hint': 0, 'shuffle': 0, 'undo': 0},
        'end_reason': endReason,
        'departure': departure,
        'restart': departure == 'restart',
        'abandoned': outcome == 'ABORTED',
        'analyst_only_accepted_trace': jsonDecode(jsonEncode(_trace)),
      };
}

/// Calls the unchanged authoritative tap and geometry methods. No substitute
/// match, coverage or outcome implementation exists in this recorder.
class RecordedGameEngine extends GameEngine {
  RecordedGameEngine(LevelDefinition level, this.session)
      : super(level.tiles, objective: level.objective);

  final PlaytestSession session;

  @override
  void updateBoardGeometry(Size boardSize, Size tileSize) {
    super.updateBoardGeometry(boardSize, tileSize);
    session.geometry(boardSize, tileSize);
  }

  @override
  bool tapTile(String id, Size boardSize, Size tileSize) {
    if (session.ended) return false;
    final before = List<String>.of(tray);
    final accepted = super.tapTile(id, boardSize, tileSize);
    if (!accepted) {
      session.rejectedTaps++;
      return false;
    }
    final matched = [...before, id]
        .where((item) => tileById(item)?.state == TileState.matched)
        .toList();
    final number = session.acceptedTaps + 1;
    session.maxTrayOccupancy = max(session.maxTrayOccupancy, tray.length);
    session.maxTrayBeforeResolution =
        max(session.maxTrayBeforeResolution, before.length + 1);
    if (matched.isNotEmpty && session.firstTripleTap == null) {
      session.firstTripleTap = number;
      session.firstTripleIds = List.of(matched);
    }
    session._trace.add({
      'tap': number,
      'elapsed_ms': session._elapsed(),
      'tile_id': id,
      'visible_symbol': tileById(id)!.type,
      'tray_before': before,
      'tray_after': List<String>.of(tray),
      'matched_ids': matched,
      'remaining_board_tiles': boardTiles.length,
      'geometry_index': session._geometry.length - 1,
    });
    if (result != GameResult.playing) {
      session._finish(result == GameResult.won ? 'WIN' : 'LOSS', 'terminal');
    }
    return true;
  }

  // Defense in depth; the real screen also disables all three controls.
  @override
  bool get canUndo => false;
  @override
  bool undo() => false;
  @override
  bool shuffleBoard() => false;
  @override
  List<String> findBestHintTileIds() => [];
  @override
  bool canCollectHintTileIds(List<String> ids) => false;
  @override
  bool collectHintTileIds(List<String> ids) => false;
}

String exportSessions(Iterable<PlaytestSession> sessions) =>
    const JsonEncoder.withIndent('  ').convert({
      'schema': playtestSchema,
      'audience': 'analyst-only; do not inspect traces during play',
      'sessions': sessions.map((session) => session.toJson()).toList(),
    });
