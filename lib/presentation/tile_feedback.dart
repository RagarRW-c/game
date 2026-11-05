import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/audio_service.dart';
import '../core/campaign_feedback_audio.dart';

/// Fire-and-forget feedback: platform failures never propagate into gameplay.
void dispatchTileFeedback(
    {required GameAudioService audio,
    required bool matched,
    required bool vibrationEnabled,
    bool deferMatch = false,
    bool tapped = true,
    bool terminal = false,
    bool campaignFeel = false}) {
  if (audio.sfxEnabled) {
    if (matched && !deferMatch) {
      if (campaignFeel) {
        dispatchCampaignFeedback(audio, CampaignFeedbackEvent.match);
      } else {
        safelyPlayFeedback(audio.playMatch);
      }
    } else if (tapped) {
      if (campaignFeel) {
        dispatchCampaignFeedback(audio, CampaignFeedbackEvent.selection);
      } else {
        safelyPlayFeedback(audio.playTap);
      }
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

void dispatchCampaignFeedback(
    GameAudioService audio, CampaignFeedbackEvent event) {
  if (audio.sfxEnabled) {
    safelyPlayFeedback(() => audio.playCampaignFeedback(event));
  }
}
