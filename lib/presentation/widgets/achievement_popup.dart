import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../../core/audio_service.dart';
import 'achievement_reward_dialog.dart';

Future<void> showPendingAchievementPopups(
  BuildContext context,
  ProgressRepository repository, {
  Future<void> Function()? onPopup,
  VoidCallback? onPopupEnded,
  GameAudioService? audio,
}) async {
  final popups = await repository.consumePendingAchievementPopups();
  if (!context.mounted || popups.isEmpty) return;

  for (final popup in popups) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AchievementUnlockedDialog(
          popup: popup,
          onPopup: onPopup,
          onPopupEnded: onPopupEnded,
          audio: audio),
    );
  }
}

class _AchievementUnlockedDialog extends StatefulWidget {
  const _AchievementUnlockedDialog(
      {required this.popup, this.onPopup, this.onPopupEnded, this.audio});

  final PendingAchievementPopup popup;
  final Future<void> Function()? onPopup;
  final VoidCallback? onPopupEnded;
  final GameAudioService? audio;

  @override
  State<_AchievementUnlockedDialog> createState() =>
      _AchievementUnlockedDialogState();
}

class _AchievementUnlockedDialogState
    extends State<_AchievementUnlockedDialog> {
  Timer? _timer;
  bool _closed = false;
  bool _soundStarted = false;
  bool _soundEnded = false;
  final _soundOwner = Object();

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), _close);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _closed ||
          _soundEnded ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      _soundStarted = true;
      final play = widget.onPopup;
      if (play != null) {
        widget.audio?.beginAchievementFeedback(_soundOwner);
        unawaited(Future<void>.sync(play).catchError((Object _) {}));
      }
    });
  }

  void _endSound() {
    if (_soundEnded) return;
    _soundEnded = true;
    if (_soundStarted && widget.onPopup != null) {
      widget.audio?.cancelAchievementFeedback(owner: _soundOwner);
      widget.onPopupEnded?.call();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) _endSound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _endSound();
    super.dispose();
  }

  void _close() {
    if (_closed || !mounted || !(ModalRoute.of(context)?.isCurrent ?? false))
      return;
    _closed = true;
    _endSound();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return AchievementRewardDialog(
      definition: widget.popup.definition,
      onClose: _close,
    );
  }
}
