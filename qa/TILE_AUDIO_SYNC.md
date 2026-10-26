# Tile audio synchronization

## Cause and chosen visual event

`dispatchTileFeedback` previously selected either tap or match audio at accepted
move time in both `GameScreen._showMoveFeedback` and
`EndlessScreen._showMoveFeedback`. Engine mutations were already complete.
There was no connection between that cue and the retained visual snapshot clock.

The current effect is **640 ms**, not 500 ms. Its shared central flash and
particle release begin at `TrayBurst.release`: **413.2 ms** for a tapped triple.
The preceding 70 ms is compression, not the main burst. The new match trigger
uses that release boundary directly; it does not wait for animation completion.

## Event timeline

| Event | Time after accepted tap | Previous audio | New audio |
| --- | ---: | --- | --- |
| Accepted ordinary tile | 0 ms | Tap | Tap |
| Accepted tile completing a nonterminal triple | 0 ms | Match | Tap |
| Pickup ends | 61.6 ms | None | None |
| Tray arrival / triple compression starts | 343.2 ms | None | None |
| Shared flash, particles and disappearance start | 413.2 ms | None | Match |
| Nonmatching flight settles | 440 ms | None | None |
| Matched faces finish fading | 493.2 ms | None | None |
| Burst finishes | 640 ms | None | None |

Dispatch occurs after the first rendered frame reaching the release milestone
and before effect completion, so frame cadence adds up to a frame of scheduling
quantization under normal load. Device/plugin latency is additional.

Hint matches with no incoming flight release at 70 ms and play one match cue
there, with no artificial tap cue. Reduced motion and missing visual anchors
use immediate match feedback. Terminal Campaign/Endless moves retain their
immediate match/result cues because navigation or round replacement interrupts
their visual effects. Gameplay, rewards and navigation never wait for audio.

No separate landing cue was added: the acceptance sound plus match cue leave
rapid sequences readable without a second sound for every nonmatching tile.
Existing synthesized tap variants, match notes, volumes and other cue assets
are unchanged. Haptics remain at acceptance, respecting their existing settings.

## Ownership and lifecycle

- Each retained burst owns one callback, keyed by its existing serial. The
  animation builder observes the clock; a single guarded post-frame callback
  dispatches audio after painting. Rebuilds cannot retrigger it.
- At most three burst callbacks exist, matching the existing visual bound.
  Eviction, clear, disposal and completion discard their pending callbacks.
- Route-current status, TickerMode and app lifecycle suppress/cancel pending
  audio. Resume does not recreate cancelled cues. Geometry changes keep the
  existing visual cancellation behavior and also invalidate audio.
- A callback already registered with Flutter cannot be removed, but becomes
  inert after cancellation and is released when that frame callback runs.
- `GameAudioService` reuses four players: one replaceable tap voice and three
  match voices. Taps cannot steal match voices. Other existing cues retain their
  round-robin allocation and may supersede tile feedback (e.g. terminal cues).
- Setup futures and generated cue files are shared. Gameplay entry prepares
  tap/match data once. Request generations and a board epoch are rechecked
  after each asynchronous preparation step. Stale, muted, backgrounded or
  disposed requests cannot subsequently issue a play command.
- Backgrounding invalidates requests and stops SFX. Music pause/resume remains
  serialized; repeated inactive/paused notifications preserve resume intent.
- Fire-and-forget sound failures never delay or mutate gameplay. No new timers,
  animation controllers, subscriptions or per-frame audio objects are added.

## Regression coverage

`tile_feedback_test.dart` checks immediate accepted/rejected taps, the 413/414 ms
release boundary, separate overlapping match clocks, silent rebuilds, muted
release, Hint timing, navigation, background/resume, disposal and cancellation
of an already queued callback. Existing state, haptic, settings and terminal
assertions remain; immediate-match expectations change only for deferred cues.

`tile_motion_test.dart` retains geometry, visual duration, ownership and state
checks, with audio expectations updated to the new milestones. Its round
transition scenario now lets each burst reach release before selecting the next
triple; rapid-overlap behavior remains covered separately.

`tile_audio_service_test.dart` uses injected fake players to check shared setup,
three concurrent match voices, tap replacement, volumes, and cancellation while
async setup is blocked. It does not require native audio or a device. The Golden
and screen-fit silent fixtures implement the new lifecycle hooks explicitly.

## Local verification (repository root)

```bash
flutter test --no-pub --concurrency=1 --flavor prod --dart-define=FLAVOR=prod test/qa/tile_audio_service_test.dart test/qa/tile_feedback_test.dart test/qa/tile_motion_test.dart test/qa/tile_widget_test.dart
flutter test --no-pub --concurrency=1 --flavor prod --dart-define=FLAVOR=prod test/qa/
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/goldens/
flutter analyze
git diff --check
```

No Flutter, Gradle, tests, builds, emulator or ADB were run for this change.
No Golden baseline change is expected or made. Dart formatting and source/diff
inspection do not confirm runtime test success or audible synchronization.

## Samsung S21 FE listening checklist and limits

1. Compare cold entry and warm play at 60 Hz using the same board/tap sequence.
   Listen for immediate restrained taps and the stronger match at the shared
   flash, not during pickup or at the end of the particle tail.
2. Compare single selections, three rapid taps, overlapping triples, Hint and
   both tray positions. Taps should not cut off the match chime.
3. Mute before release, unmute afterward, background during flight, resume,
   pause/navigate away, and use Undo/Shuffle. No cancelled cue should replay.
4. Test reduced motion, Campaign victory and Endless round replacement. They
   retain immediate feedback without waiting for a nonexistent later burst.
5. Check loudness with music enabled, then disabled. Compare phone speaker and
   wired/Bluetooth output separately; Bluetooth may add substantial latency.
6. Compare Profile UI/raster traces during fast matches and first-use audio.
   No FPS improvement is claimed.

This synchronizes the playback request with Flutter's painted effect, not the
speaker sample clock. Generated WAVs/configuration are warmed, but the platform
still loads/starts the source and its short envelope affects perceived onset.
A play command already handed to the platform cannot be recalled; short cues
already sounding may finish when navigating. Backgrounding stops SFX.
If a stalled frame skips the entire visible burst or a burst is evicted before
release, its cue is intentionally discarded rather than played stale. More
than three concurrent matches may replace the oldest audio voice.
