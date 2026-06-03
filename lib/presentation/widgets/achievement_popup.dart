import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../theme/game_theme.dart';
import 'game_ui.dart';

Future<void> showPendingAchievementPopups(
  BuildContext context,
  ProgressRepository repository,
) async {
  final popups = await repository.consumePendingAchievementPopups();
  if (!context.mounted || popups.isEmpty) return;

  for (final popup in popups) {
    if (!context.mounted) return;
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
    final definition = widget.popup.definition;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.86, end: 1),
      duration: GameDurations.normal,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Opacity(
          opacity: scale.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: GameDialogFrame(
        title: 'Achievement Unlocked!',
        onClose: _close,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                gradient: GameGradients.badge,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: GameShadows.glow(GameColors.accentGold),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 46,
              ),
            ),
            const SizedBox(height: GameSpacing.lg),
            Text(
              definition.name,
              textAlign: TextAlign.center,
              style: GameTextStyles.h2,
            ),
            const SizedBox(height: GameSpacing.md),
            GameBadge(
              icon: Icons.monetization_on_rounded,
              gradient: GameGradients.badge,
              child: Text(
                '+${definition.reward} coins',
                style: GameTextStyles.button.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
