import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/audio_service.dart';
import '../main.dart' show AppScope, appRouteObserver;
import '../presentation/screens/game_screen.dart';
import '../presentation/theme/game_theme.dart';
import 'isolation.dart';
import 'session.dart';

class PlaytestLog {
  final List<PlaytestSession> sessions = [];
  PlaytestSession start(PlaytestLevels levels, PlaytestVariant variant) {
    final session =
        PlaytestSession(variant: variant, level: levels.create(variant));
    sessions.add(session);
    return session;
  }

  String exportJson() => exportSessions(sessions);
}

class Level96PlaytestApp extends StatefulWidget {
  Level96PlaytestApp(
      {super.key,
      required this.levels,
      this.audio,
      this.log,
      bool enabled = const bool.fromEnvironment('LEVEL96_PLAYTEST')}) {
    requirePlaytestOptIn(enabled: enabled);
  }
  final PlaytestLevels levels;
  final GameAudioService? audio;
  final PlaytestLog? log;
  @override
  State<Level96PlaytestApp> createState() => _PlaytestAppState();
}

class _PlaytestAppState extends State<Level96PlaytestApp>
    with WidgetsBindingObserver {
  late final GameAudioService audio = widget.audio ?? GameAudioService();
  late final PlaytestLog log = widget.log ?? PlaytestLog();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(audio.resumeMusicFromBackground());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(audio.pauseMusicForBackground());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final session in log.sessions) {
      session.abort('app_disposed');
    }
    if (widget.audio == null) unawaited(audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Level 96 Human Playtest',
        debugShowCheckedModeBanner: false,
        theme: GameTheme.theme(),
        navigatorObservers: [appRouteObserver],
        home: _VariantMenu(levels: widget.levels, log: log, audio: audio),
      );
}

Future<void> _copyResults(BuildContext context, PlaytestLog log) async {
  try {
    await Clipboard.setData(ClipboardData(text: log.exportJson()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('JSON copied. Paste into a local file; '
              'nothing was saved to your computer.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Copy failed. Keep this app open and retry.')));
    }
  }
}

class _VariantMenu extends StatefulWidget {
  const _VariantMenu(
      {required this.levels, required this.log, required this.audio});
  final PlaytestLevels levels;
  final PlaytestLog log;
  final GameAudioService audio;
  @override
  State<_VariantMenu> createState() => _VariantMenuState();
}

class _VariantMenuState extends State<_VariantMenu> {
  PlaytestVariant variant = PlaytestVariant.original;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Level 96 playtest')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Human review only • Unassisted • No production rewards'),
          const SizedBox(height: 12),
          for (final value in PlaytestVariant.values)
            ListTile(
              key: ValueKey(value.name),
              title: Text(value.label),
              selected: value == variant,
              leading: Icon(value == variant
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              onTap: () => setState(() => variant = value),
            ),
          FilledButton(
              key: const ValueKey('start_session'),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => _SessionPage(
                        levels: widget.levels,
                        log: widget.log,
                        variant: variant,
                        audio: widget.audio)));
                if (mounted) setState(() {});
              },
              child: const Text('Start a fresh session')),
          const Text('During play, Pause opens summary, restart and export. '
              'Back returns here. Export before closing: records live only in memory. '
              'Do not read analyst traces while playing.'),
          const SizedBox(height: 12),
          Text('${widget.log.sessions.length} sessions recorded locally'),
          for (final session in widget.log.sessions.reversed)
            ListTile(
                title: Text(
                    '${session.variant.label}: ${session.outcome ?? 'RUNNING'}'),
                subtitle: Text('${session.acceptedTaps} taps • '
                    '${session.engine.tray.length}/7 tray'),
                onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                            title: const Text('Session summary'),
                            content: _Summary(session),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'))
                            ]))),
          OutlinedButton(
              key: const ValueKey('export_sessions'),
              onPressed: () => _copyResults(context, widget.log),
              child: const Text('Copy all sessions as JSON')),
        ])),
      );
}

class _SessionPage extends StatefulWidget {
  const _SessionPage(
      {required this.levels,
      required this.log,
      required this.variant,
      required this.audio});
  final PlaytestLevels levels;
  final PlaytestLog log;
  final PlaytestVariant variant;
  final GameAudioService audio;
  @override
  State<_SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<_SessionPage> {
  late PlaytestSession session;
  late PlaytestLevelRepository levels;
  final progress = PlaytestProgress();
  bool summaryOpen = false;
  @override
  void initState() {
    super.initState();
    _fresh();
  }

  void _fresh() {
    session = widget.log.start(widget.levels, widget.variant);
    levels = PlaytestLevelRepository(widget.levels, widget.variant);
  }

  @override
  void dispose() {
    session.depart('selection');
    super.dispose();
  }

  Future<void> _summary() async {
    if (!mounted || summaryOpen) return;
    summaryOpen = true;
    final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(
                  '${session.variant.label} • ${session.outcome ?? 'RUNNING'}'),
              content: SingleChildScrollView(child: _Summary(session)),
              actions: [
                TextButton(
                    onPressed: () => _copyResults(dialogContext, widget.log),
                    child: const Text('Copy JSON')),
                TextButton(
                    key: const ValueKey('restart_session'),
                    onPressed: () => Navigator.pop(dialogContext, 'restart'),
                    child: const Text('Restart')),
                TextButton(
                    key: const ValueKey('variant_selection'),
                    onPressed: () => Navigator.pop(dialogContext, 'selection'),
                    child: const Text('Variant selection')),
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(session.ended ? 'Close' : 'Resume')),
              ],
            ));
    summaryOpen = false;
    if (!mounted) return;
    if (action == 'restart') {
      session.depart('restart');
      setState(_fresh);
    } else if (action == 'selection') {
      session.depart('selection');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!session.ended) session.screen = MediaQuery.sizeOf(context);
    return AppScope(
      progressRepository: progress,
      levelRepository: levels,
      audioService: widget.audio,
      child: GameScreen(
          key: ValueKey(session.id),
          level: 96,
          sessionHooks: GameScreenSessionHooks(
            title: '96 • ${session.variant.label}',
            createEngine: (_) => session.engine,
            onResult: (_) => _summary(),
            onPause: () => unawaited(_summary()),
            onBoardPointerDown: session.pointerDown,
            onBoardPointerUp: session.pointerUp,
          )),
    );
  }
}

/// Public summary deliberately contains no tile identities, symbols or replay.
class _Summary extends StatelessWidget {
  const _Summary(this.session);
  final PlaytestSession session;
  @override
  Widget build(BuildContext context) => Text(
        '${session.variant.label}\n'
        'Outcome: ${session.outcome ?? 'RUNNING'}\n'
        'Accepted taps: ${session.acceptedTaps}\nRejected taps: ${session.rejectedTaps}\n'
        'First triple: ${session.firstTripleTap ?? 'none'}\n'
        'Tray: ${session.engine.tray.length}/7; max after resolution: ${session.maxTrayOccupancy}\n'
        'Remaining: ${session.engine.boardTiles.length}\n'
        'Duration: ${session.durationMs == null ? 'in progress' : '${session.durationMs} ms'}\n'
        'Unassisted: hints 0, shuffles 0, undo 0\n'
        'Screen: ${session.screen.width} × ${session.screen.height}\n'
        'Board: ${session.board.width} × ${session.board.height}\n'
        'Tile: ${session.tile.width} × ${session.tile.height}',
      );
}
