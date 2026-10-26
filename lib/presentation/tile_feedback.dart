import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/audio_service.dart';

/// Fire-and-forget feedback: platform failures never propagate into gameplay.
void dispatchTileFeedback(
    {required GameAudioService audio,
    required bool matched,
    required bool vibrationEnabled,
    bool deferMatch = false,
    bool tapped = true,
    bool terminal = false}) {
  if (audio.sfxEnabled) {
    if (matched && !deferMatch) {
      safelyPlayFeedback(audio.playMatch);
    } else if (tapped) {
      safelyPlayFeedback(audio.playTap);
    }
  }
  // Terminal screens already own their result feedback.
  if (vibrationEnabled && !terminal) {
    safelyPlayFeedback(
        matched ? HapticFeedback.lightImpact : HapticFeedback.selectionClick);
  }
}

void dispatchTileMatch(GameAudioService audio) {
  if (audio.sfxEnabled) safelyPlayFeedback(audio.playMatch);
}

void safelyPlayFeedback(Future<void> Function() effect) {
  unawaited(
      Future<void>.sync(effect).catchError((Object error, StackTrace stack) {
    if (kDebugMode) debugPrint('Interaction feedback unavailable: $error');
  }));
}
