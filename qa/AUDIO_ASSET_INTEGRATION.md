# Approved TrioTrek audio integration

## Scope and verification

All 16 user-selected MP3s in `assets/audio/triotrek/` exist, have nonzero
sizes, report an MP3 audio stream, and decoded completely using FFmpeg with
`-xerror`. All are 44.1 kHz stereo. SHA-256 checks match the supplied
`file_inventory.txt`. No asset was rewritten, normalized, trimmed or regenerated.
The inventory's generation-task IDs and hashes are retained unchanged; approval
and original-asset provenance are supplied by the user, not independently
certified licensing conclusions. No reference recording was used as an asset.

| File under `assets/audio/triotrek/` | Duration s | Bytes | Container kb/s |
| --- | ---: | ---: | ---: |
| `music/menu_a.mp3` | 116.428 | 2,801,983 | 192.5 |
| `music/menu_b.mp3` | 144.300 | 3,470,926 | 192.4 |
| `music/world_01.mp3` | 96.993 | 2,335,540 | 192.6 |
| `music/world_02.mp3` | 153.182 | 3,684,086 | 192.4 |
| `music/world_03.mp3` | 170.553 | 4,101,000 | 192.4 |
| `music/world_04.mp3` | 154.436 | 3,714,179 | 192.4 |
| `music/world_05.mp3` | 149.133 | 3,586,910 | 192.4 |
| `music/world_06.mp3` | 157.884 | 3,796,935 | 192.4 |
| `music/world_07.mp3` | 150.126 | 3,610,734 | 192.4 |
| `music/world_08.mp3` | 144.562 | 3,477,196 | 192.4 |
| `music/world_09.mp3` | 143.909 | 3,461,522 | 192.4 |
| `music/world_10.mp3` | 148.637 | 3,574,998 | 192.4 |
| `sfx/tile_tap_b.mp3` | 0.520 | 9,238 | 142.1 |
| `sfx/triple_match_c.mp3` | 1.200 | 20,105 | 134.0 |
| `sfx/wheel_tick_a.mp3` | 0.480 | 8,820 | 147.0 |
| `sfx/wheel_prize_coins.mp3` | 1.760 | 29,300 | 133.2 |

Music totals **41,616,009 bytes**; all approved audio totals **41,683,472 bytes**
(about 39.75 MiB). MP3s are already compressed: expect roughly this order of
additional packaged asset data, not a measured APK/AAB download-size delta.
No quality reduction was performed. The old `background.mp3` remains present
but is no longer selected by the service. Native asset caching can also consume
disk space beyond the package size; it is not all decoded/resident PCM at once.

`silencedetect=n=-50dB:d=0.15` found no such sustained silence in either menu
file. It did find passages inside the approved world tracks:

- `world_01`: 25.195–26.481 seconds.
- `world_06`: 148.314–153.117 seconds.

These are source-file observations, not a listening verdict or a transport
bug. They remain unchanged. No claim of sample-perfect MP3 looping is made.

## Playback implementation

Previously one music player reloaded the same background file for menu and
gameplay. SFX were generated WAV tones. The existing service remains the public
interface; `lib/core/game_music.dart` now owns music scheduling and transitions.

### Menu and navigation

- Menu A → B → A alternates continuously. Menu sources use `ReleaseMode.stop`,
  never individual looping.
- Two reusable streaming decks allow a **600 ms linear crossfade**, in twelve
  50 ms steps. Their steady-transition gain sum is .35. The second deck is
  created lazily on first audible music selection, not per song or route.
- The next menu song is prepared silently while the current song plays. A
  one-shot deadline uses native duration/current position to begin the fade
  before the end. Measured durations are fallbacks for missing native duration;
  completion events also provide a fallback. Generation checks suppress duplicate
  completion/deadline work.
- Repeated menu requests return the existing queue and never restart the song.
  Menu-related screens inherit it. Returning from Campaign selects the most
  recently selected menu song; this can restart that song after its deck has been
  reused, but menu-to-menu navigation preserves playback position.
- Both music decks use mixing audio contexts so independent Android focus
  requests do not pause each other during a fade. They can therefore coexist with
  other apps' audio. Foreground/background suspension is owned by the app. Check
  calls, notification overlays, external audio and headphone changes on Android;
  this does not claim a new system audio-focus coordinator.

### Campaign and Endless

`GameMusic.campaignAsset(level)` maps `(level - 1) ~/ 10 + 1` to
`world_01`…`world_10`, validating levels 1–100. Thus 1–10 use world 01, 11–20
world 02, through 91–100 world 10. World tracks use `ReleaseMode.loop`.

`GameScreen` passes the actual level and a route-owner identity. Same-world
selection updates ownership without reloading/restarting. Different-world
selection crossfades. Outgoing routes cannot reclaim music during dependency
changes, and an old route's disposal cannot stop a replacement route's track.
Leaving the owning Campaign route returns to menu music. The existing win
dialog keeps its underlying world's music.

Endless retains its existing inherited music behavior: when entered from the
menu it continues the approved **menu A/B sequence**, including current position.
No new Endless soundtrack or gameplay changes were introduced.

### SFX and synchronization

| Existing event | Approved source | Existing dispatch preserved |
| --- | --- | --- |
| Accepted tap | `tile_tap_b.mp3` | Immediate, with no gameplay wait |
| Triple match | `triple_match_c.mp3` | Visual burst at ~413.2 ms; Hint ~70 ms; existing reduced-motion/terminal fallback |
| Wheel segment tick | `wheel_tick_a.mp3` | Actual angular crossings, at most once per frame / 80 ms |
| Wheel coin collection | `wheel_prize_coins.mp3` | Once at celebration progress .76, only for coin rewards |

The 440 ms tile flight, match visuals, 4.6-second wheel spin, reward grant and
state mutation timings are untouched. Trigger code in `tile_feedback.dart`,
`tile_effects.dart` and `lucky_wheel_screen.dart` is unchanged.

Four low-latency SFX players remain: tap voice 0 and match voices 1–3. The tick
also uses replaceable voice 0; a 480 ms tick cannot build up across all voices
at the 80 ms crossing limit. Other existing events keep their prior allocation.
There is no unlimited polyphony: more than three overlapping matches can replace
the oldest match voice, as before. Existing non-tile result cues can also replace
voices under the previous policy.

Tap and match native sources are prepared once during shared SFX setup. Bundled
sources use the plugin cache; repeated taps do not synthesize/write WAV files.
Source preparation and resume are separate so request/board/mute/lifecycle checks
also run after the asset-loading await. Music and SFX have no unused per-frame
position updater. Wheel first-use asset preparation still needs a device latency
check; only tap/match sources are proactively preloaded into the four voices.

Existing gains are retained: music .35, tap .58, match .78, wheel tick .25 and
wheel collection .65. They are implementation gains, not measured perceived
loudness equivalence between old and new assets. Audition the new mix on device.

No new start/stop/reveal audio was invented. Existing generated wheel start,
stop and reveal cues, boosters, achievements, chest, victory/failure and unlock
cues remain as they were. Approved replacements for those events are still
missing, not silently substituted from the reference.

## Lifecycle and resource limits

- Music generations invalidate deadlines/fades on route selection, mute,
  background and disposal. A cancelled fade wait is released immediately;
  asynchronous native setup is checked before subsequent playback operations.
- Pausing preserves the selected deck/position. Repeated inactive/paused calls
  do not erase resume intent. Unmuting while backgrounded stays silent.
- SFX mute now stops the longer approved tails and invalidates pending requests,
  including a quick mute/unmute cycle. Existing board and background cancellation
  remain. Muting does not alter rewards or progression.
- Music disposal cancels timers, waits for its serialized in-flight operation,
  cancels completion subscriptions and disposes each deck once. No queue callback
  may restart a disposed service. A native operation that never completes can
  still delay cleanup; this needs platform-level investigation if encountered.
- Maximum service allocation is **two music + four SFX players**, one more than
  before. At most two music sources and bounded SFX voices play concurrently.
  Music is streamed by the player; there are no twelve decoded music buffers.
- Crossfades are best-effort Dart/native scheduling, not sample-accurate mixing.
  MP3 encoder delay, padding, native loop boundaries and dispatch-to-speaker latency
  require physical-device checks. No source samples were trimmed to hide them.

## Tests and files

New `test/qa/game_music_test.dart` covers all 100 level mappings/boundaries,
bundled asset presence/headers, A/B alternation/preloading, fade overlap/gain,
same-world continuation, different-world changes, stale route ownership,
mute/background, rapid queued requests, completion fallback and disposal during
pending native setup. Controlled pumps advance each fade step; tests do not use
wall-clock sleeps or generic settling to replace timing assertions.

`test/qa/tile_audio_service_test.dart` retains timing-independent concurrency and
cancellation assertions, checks exact approved source paths and native preload,
tests tick allocation/coin mapping and cancellation during native source loading.
Existing tile feedback/motion and wheel timing tests remain unchanged.

Files changed/added for this integration:

1. `lib/core/audio_service.dart`
2. `lib/core/game_music.dart` (new)
3. `lib/presentation/screens/game_screen.dart`
4. `pubspec.yaml` (explicit music/SFX subdirectory registration)
5. `test/qa/game_music_test.dart` (new)
6. `test/qa/tile_audio_service_test.dart`
7. `test/qa/screen_fit_test.dart` (fake method signatures only)
8. `test/goldens/support/golden_fixtures.dart` (fake method signatures only)
9. `qa/AUDIO_ASSET_INTEGRATION.md` (new)

The 16 approved asset files and their inventory were already supplied/untracked
before this task; they are integrated without byte changes. Existing unrelated
working-tree reports/configuration and the reference exclusion are preserved.
No reference asset registration, Golden PNG modification, commit or push.

## Local verification, from repository root

Flutter, tests, analysis, builds, Gradle and ADB were **not run** during this task.
Only local media inspection, source review, standalone Dart formatting and
whitespace checks were performed. These tests have not been reported as passing.

```bash
flutter test --no-pub --concurrency=1 --flavor prod --dart-define=FLAVOR=prod test/qa/game_music_test.dart test/qa/tile_audio_service_test.dart test/qa/tile_feedback_test.dart test/qa/tile_motion_test.dart test/qa/tile_widget_test.dart test/qa/lucky_wheel_test.dart
flutter test --no-pub --concurrency=1 --flavor prod --dart-define=FLAVOR=prod test/qa/
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/goldens/
flutter analyze
git diff --check
git check-ignore -v reference/TrioTrek_reference_73s.mp4
git ls-files -- reference
```

The final command must print nothing. No Golden regeneration is expected.

## Samsung S21 FE listening checklist

1. Let menu A → B → A play fully (over four minutes). Check gaps, abrupt gain
   changes, overlap loudness and whether B genuinely plays. Navigate through
   settings, map, shop and wheel without restarting menu tracks.
2. Enter levels 1, 10, 11, 20, 21 and each later boundary through 90/91/100.
   Check correct world selection; replay/next level within a world must continue
   the track. Rapidly replace levels and return to menu during a crossfade.
3. Enter Endless from the menu: current menu music continues. No world track
   should be invented for Endless. Verify return navigation does not duplicate it.
4. Test a cold first tap, rapid taps, three overlapping triples, Hint, reduced
   motion and final moves. Compare visual release with audible attack; MP3 leading
   content/plugin latency is separate from unchanged 413.2 ms/70 ms dispatch.
5. Spin the wheel through fast rotation and deceleration. Check clicks remain
   bounded and get sparser, coin sound occurs once at collection, booster rewards
   do not emit coins, and unapproved start/stop hooks retain their old sound.
6. Mute/unmute music and SFX separately, including during a fade and a long match
   tail. Background/lock/unlock repeatedly; return after a song would have ended.
   No stale queue should replay. Exit screens during first asset preparation.
7. Test calls/notifications/headphones/other apps' audio with the music mixing
   context. Use phone speaker and wired headphones for baseline latency; assess
   Bluetooth separately. Retest the quiet passages noted above and world loops.
8. Inspect Profile memory/native player counts and UI frame work during long
   sessions and rapid navigation. Confirm two music/four SFX limit and no ongoing
   timers/subscriptions after app disposal. Compare first-use versus warmed audio.

Release acceptance still requires these real-device listening and lifecycle
checks. Successful decoding and deterministic source tests do not prove an
audibly gapless or perfectly balanced Android mix.
