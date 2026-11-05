/// Campaign-only presentation events. Existing modes retain their audio path.
enum CampaignFeedbackEvent { entrance, landing, selection, collection, match }

class CampaignFeedbackSound {
  const CampaignFeedbackSound(this.asset, this.volume, this.voice);
  final String asset;
  final double volume;
  final int voice;
}

/// Original new WAVs complement the already approved tap and match assets.
const campaignFeedbackSounds = {
  CampaignFeedbackEvent.entrance:
      CampaignFeedbackSound('audio/campaign_entrance_v2.wav', .42, 0),
  CampaignFeedbackEvent.landing:
      CampaignFeedbackSound('audio/campaign_landing_v2.wav', .32, 1),
  CampaignFeedbackEvent.selection:
      CampaignFeedbackSound('audio/triotrek/sfx/tile_tap_b.mp3', .26, 0),
  CampaignFeedbackEvent.collection:
      CampaignFeedbackSound('audio/campaign_collect_v2.wav', .32, 1),
  CampaignFeedbackEvent.match:
      CampaignFeedbackSound('audio/triotrek/sfx/triple_match_c.mp3', .52, 2),
};

CampaignFeedbackSound? campaignSoundForCue(String cue) {
  for (final event in CampaignFeedbackEvent.values) {
    if (cue == 'campaign_${event.name}') return campaignFeedbackSounds[event];
  }
  return null;
}
