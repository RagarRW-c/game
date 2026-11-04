import 'package:flutter/material.dart';

import '../../core/audio_service.dart';
import '../tile_feedback.dart';

/// Owns the fallback boss reward only while its result dialog is visible.
/// This adds no layout, animation, timer or second achievement notification.
class WorldRewardAudio extends StatefulWidget {
  const WorldRewardAudio(
      {super.key,
      required this.audio,
      required this.enabled,
      required this.child});

  final GameAudioService audio;
  final bool enabled;
  final Widget child;

  @override
  State<WorldRewardAudio> createState() => _WorldRewardAudioState();
}

class _WorldRewardAudioState extends State<WorldRewardAudio>
    with WidgetsBindingObserver {
  final _owner = Object();
  bool _started = false;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (!mounted ||
          !widget.enabled ||
          _ended ||
          (lifecycle != null && lifecycle != AppLifecycleState.resumed) ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      _started = true;
      widget.audio.beginAchievementFeedback(_owner);
      safelyPlayFeedback(widget.audio.playWorldUnlocked);
    });
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    if (_started) widget.audio.cancelAchievementFeedback(owner: _owner);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) _end();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _end();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _end();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
