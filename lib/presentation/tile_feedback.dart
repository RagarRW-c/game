import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/audio_service.dart';

/// Fire-and-forget feedback: platform failures never propagate into gameplay.
void dispatchTileFeedback(
    {required GameAudioService audio,
    required bool matched,
    required bool vibrationEnabled,
    bool terminal = false}) {
  if (audio.sfxEnabled) {
    safelyPlayFeedback(matched ? audio.playMatch : audio.playTap);
  }
  // Terminal screens already own their result feedback.
  if (vibrationEnabled && !terminal) {
    safelyPlayFeedback(
        matched ? HapticFeedback.lightImpact : HapticFeedback.selectionClick);
  }
}

void safelyPlayFeedback(Future<void> Function() effect) {
  unawaited(
      Future<void>.sync(effect).catchError((Object error, StackTrace stack) {
    if (kDebugMode) debugPrint('Interaction feedback unavailable: $error');
  }));
}
