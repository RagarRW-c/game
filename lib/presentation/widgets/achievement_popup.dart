import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import 'achievement_reward_dialog.dart';

Future<void> showPendingAchievementPopups(
  BuildContext context,
  ProgressRepository repository, {
  Future<void> Function()? onPopup,
}) async {
  final popups = await repository.consumePendingAchievementPopups();
  if (!context.mounted || popups.isEmpty) return;

  for (final popup in popups) {
    if (!context.mounted) return;
    if (onPopup != null) unawaited(onPopup());
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AchievementUnlockedDialog(popup: popup),
    );
  }
}

class _AchievementUnlockedDialog extends StatefulWidget {
  const _AchievementUnlockedDialog({required this.popup});

  final PendingAchievementPopup popup;

  @override
  State<_AchievementUnlockedDialog> createState() =>
      _AchievementUnlockedDialogState();
}

class _AchievementUnlockedDialogState
    extends State<_AchievementUnlockedDialog> {
  Timer? _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
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
