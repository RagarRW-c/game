# Phase 5A — Campaign gameplay feel

Scope: Campaign board entrance, accepted tile interactions, triple resolution
presentation and corresponding SFX. Default `GAME_FEEL_V2=false` preserves the
existing presentation. No menu, button, dialog, balance or other-mode redesign.

## Reference inspection

Both supplied MP4s were decoded and inspected before implementation. No reference
audio was extracted, and no reference artwork or samples were copied into assets.
Frame sheets and numerical audio metadata are temporary analysis files under
`.dart_tool/phase5a_reference/`, outside the shipped assets.

| Reference | Inspected evidence | Application to this phase |
|---|---|---|
| WhatsApp Video 2026-11-05 at 19.04.59.mp4 | 18.537 s, 480x1070, reported 120 fps. Whole clip at 2 fps; entrance and match windows at 12 fps. The board assembles in successive layers over about 1.8–2 s. Around 7.9–8.2 s a selected tile travels toward the upper tray; a bright fragmentation burst follows around 8.2–8.5 s. | Shorter grouped entrance, immediate selection response, visible travel, then a shared triple/burst clock. Retain this game's artwork and restrained gold/ivory accents. |
| WhatsApp Video 2026-11-05 at 19.05.01.mp4 | 7.387 s, 480x1070, reported 60 fps. Whole clip at 4 fps. Wheel overlay around 1.0–2.0 s, shop transition around 2.8–3.6 s, coin dialog around 4.0–5.2 s. | Timing reference only. These menus/dialogs are outside Phase 5A and remain unchanged. |

Audio timing was inspected numerically using decoded RMS metadata only. The first
clip has repeated transients through approximately 0.2–2.2 s and a stronger group
around 8.3–8.8 s, consistent with the visible assembly and match. The second has
transients near its UI transitions. Those are temporal associations, not isolated
instrument identifications. Local soundtrack timbre, pitch, perceived latency and
subjective quality could not be reliably auditioned in this environment; no claim
of an auditory match is made. Numerical timing and visual frames informed the
implementation, while new sounds use original procedural synthesis.

## Existing behavior and changes

The existing implementation already provided a 0.96 press scale, 440 ms curved
tile flights, tray settlement, simultaneous triple snapshots, a local flash and
bounded particles. Match audio already followed the burst release clock. Covered
tiles, rapid selection, Undo/Hint/Shuffle presentation, reduced motion and
cancellation were already handled. Those systems were extended, not duplicated.

Flag ON adds a 980 ms entrance with six deterministic layer/spatial waves, 100 ms
apart, each lasting 480 ms. Tiles translate down 34–44 logical board pixels, fade
in briefly, rotate at most 0.028 radians and settle with a small damped bounce.
One AnimationController drives the entire board; tile artwork is retained as
stable repaint-boundary children. The entrance never rebuilds coverage logic on
every tick. Canonical Positioned coordinates and Stack layering are unchanged.

Board pointers and board semantics are gated until the entrance finishes. A
defensive accepted-tap guard also rejects stale callbacks during entrance.
Reduced motion, backgrounding, navigation interruption and disabled ticker mode
immediately reveal the canonical board. Ordinary rebuilds do not replay the
sequence. A real level restart starts one new entrance.

Accepted selection retains the existing press response and uses a 360 ms version
of the existing flight: 43.2 ms pickup, arrival at 288 ms, then a small settling
compression. Lift and enlargement are reduced. A non-matching tile's collection
sound is dispatched once from that same arrival clock. Canceled/evicted flights
cannot emit stale collection sounds. No timers or second flight system are added.

The engine still removes triples immediately. Three presentation snapshots share
the incoming flight clock, compress together for 70 ms, release their match cue
at approximately 358 ms, fade over 80 ms and resolve by 640 ms. Flag ON uses eight
glints per slot (24 per visible triple), clipped to the face area. There is no blur
or screen-wide flash. Existing caps remain seven flights and three burst clocks;
only the current burst owns the transient face arrangement. Terminal reward
presentation retains ownership of its own audio.

## Audio

All event mapping is centralized in `lib/core/campaign_feedback_audio.dart`.

| Event | Asset | Gain | Voice |
|---|---|---:|---:|
| Entrance | Original `campaign_entrance_v2.wav`, 240 ms ascending glass/air tone | .42 | 0 |
| Group landing | Original `campaign_landing_v2.wav`, 95 ms soft tonal/contact accent | .32 | 1 |
| Accepted selection | Existing approved `triotrek/sfx/tile_tap_b.mp3` | .26 | 0 |
| Non-match collection | Original `campaign_collect_v2.wav`, 85 ms bright settling note | .32 | 1 |
| Triple release | Existing approved `triotrek/sfx/triple_match_c.mp3` | .52 | 2 |

Landing accents occur only for waves 0, 2 and 5, at approximately 326, 526 and
826 ms. Delayed frames coalesce stale accents instead of producing a backlog.
Three replaceable voices bound simultaneous Campaign SFX; matches cannot stack
multiple loud tails. Existing other-mode allocation is unchanged. With approved
sources conservatively bounded at full scale and generated WAV peaks bounded at
.35, the simultaneous new SFX peak bound is .892. This leaves headroom in the SFX
mix; it is not a measurement of the device speaker or its combined music mixer.

`tool/generate_campaign_feel_sfx.py` deterministically generates the three original
mono 22,050 Hz PCM WAVs using oscillators, seeded noise, attack and decay envelopes.
No third-party audio inputs or runtime synthesis dependencies are used. Tests
verify headers, duration, amplitude, RMS and silent edges. Assets are cached on
Campaign entry. Existing mute, lifecycle suspension, request ownership and pending
cue cancellation remain authoritative.

## Validation workflow and safe launch

From Git Bash in `C:\Gra - telefon\game`:

```bash
PYTHONUTF8=1 python -B scripts/run_phase5a_qa.py
```

This executes both configurations against fresh isolated application IDs. It
never replaces `com.ragarrwc.game` or `com.ragarrwc.game.dev`, reads their private
data, or clears their storage. Installed QA apps are stopped and retained. The
copy's APK identity, absence and non-shared UID are verified before installation.
Root Android configuration, production pubspec/lockfile and existing dependency
versions are preserved. No historical A/B cohort is run.

The tested Flutter configuration arguments are:

```text
OFF: --profile --flavor dev --dart-define=FLAVOR=dev --dart-define=LEVEL96_QA_INSTALL=true --dart-define=GAME_FEEL_V2=false
ON:  --profile --flavor dev --dart-define=FLAVOR=dev --dart-define=LEVEL96_QA_INSTALL=true --dart-define=GAME_FEEL_V2=true
```

The runner uses `flutter build apk` followed by `flutter drive --no-pub` with
`integration_test/phase5a_campaign_test.dart`, `integration_test/phase5a_driver.dart`
and the verified `--use-application-binary`. Exact executable paths, working
directories, complete commands and exit codes are recorded in each unique run's
`summary.json`. Use that isolated workflow rather than installing a workspace
DEV build over an existing account.

Host coverage includes 35 dedicated Phase 5A contracts, existing tile/audio
regressions, Level 96 playtest contracts with the flag OFF and ON, historical
Campaign contracts and the full ordinary/golden suite in a disposable copy.
Historical golden baselines are not updated. Analyzer comparison preserves the
82 verified pre-existing info identities while allowing line-number shifts after edits.

Android validation uses actual GameScreen pointer taps on production Level 96,
seven certified historical witness moves yielding a triple, enabled and muted
native audio, exact tile definitions and fresh test storage. It observes normal
Campaign state through rendered widgets; it never drives GameEngine methods.
Only the test account's first-match achievement is pre-seeded to keep that
unrelated dialog out of the effects measurement.

Profile build/raster frame samples are collected before screenshot conversion.
Screenshots then capture entrance, settled board, collection and triple phases.
These samples do not establish sustained 60 FPS, perceptual smoothness, audio
latency at the speaker, or enjoyment. Human listening and visual judgment remain
necessary. This is Phase 5A only; no Phase 5B/5C work is included.

The Phase 4D-7 baseline recorded 81 infos; the initial Phase 5A analyzer also
reported prefer_const_declarations in unchanged lib/core/app_flavor.dart. Its
content was verified against Git HEAD. qa/phase5a_analyzer_baseline.json records
all 82 pre-existing identities without changing the historical baseline.

An additional regression verifies that Undo during an active V2 flight preserves
the same painted curve and rectangle when reversing. Only the presentation
preset is carried through the existing Undo snapshot; booster rules are unchanged.

## Files delivered

All paths below are relative to `C:\Gra - telefon\game`.

| Status | File | Purpose |
|---|---|---|
| Modified | `.gitignore` | Ignore unique QA outputs; allow only the three original WAVs |
| Modified | `lib/core/audio_service.dart` | Cached, bounded Campaign event playback through existing mute/lifecycle guards |
| Modified | `lib/presentation/screens/game_screen.dart` | Feature flag, shared entrance, event dispatch and cleanup |
| Modified | `lib/presentation/tile_feedback.dart` | Central guarded Campaign dispatch; legacy defaults retained |
| Modified | `lib/presentation/widgets/tile_effects.dart` | Optional faster flight, arrival cue, shared match timing and reverse continuity |
| Modified | `test/goldens/support/golden_fixtures.dart` | Explicit no-op implementations for the extended audio interface |
| Created | `lib/core/campaign_feedback_audio.dart` | Event-to-asset/gain/voice map |
| Created | `lib/presentation/widgets/campaign_entrance.dart` | One finite entrance clock and paint/input wrappers |
| Created | `assets/audio/campaign_entrance_v2.wav` | Original entrance SFX |
| Created | `assets/audio/campaign_landing_v2.wav` | Original grouped landing SFX |
| Created | `assets/audio/campaign_collect_v2.wav` | Original collection SFX |
| Created | `tool/generate_campaign_feel_sfx.py` | Deterministic original WAV generator |
| Created | `test/qa/phase5a_game_feel_test.dart` | Geometry, waves, reset, UI taps, lifecycle and playtest compatibility |
| Created | `test/qa/phase5a_audio_test.dart` | Event mapping, headroom, mute, cancellation and WAV contracts |
| Created | `test/qa/phase5a_reverse_test.dart` | Mid-flight Undo continuity regression |
| Created | `integration_test/phase5a_campaign_test.dart` | Real Campaign Android ON/OFF, enabled/muted, snapshots and frame sampling |
| Created | `integration_test/phase5a_driver.dart` | Unique JSON and screenshot evidence export |
| Created | `scripts/run_phase5a_qa.py` | Repeatable host/Android validation with safe package isolation |
| Created | `qa/phase5a_analyzer_baseline.json` | Verified current pre-existing analyzer identities |
| Created | `qa/PHASE5A.md` | This technical report |

Unrelated pre-existing working-tree changes are preserved. No production level
asset, GameEngine, progression/economy/reward implementation, other mode, player
save or historical experiment result is edited by Phase 5A.


## Final validation results — 2026-11-05

Final evidence directory: `qa/phase5a_runs/20261105T193753-9fa0b9de/`.
Its `summary.json` is COMPLETE, with 36 passing orchestration steps, 12/12 Android
checkpoints, and no failed or unrun host tests. `report.md` indexes commands/logs;
`off/android_response.json` and `on/android_response.json` contain native results,
audio dispatches, screenshots and frame samples. `visual_review.json` records the
screenshot inspection; `original_input_integrity.json` verifies all 145 protected
original files; `audio_integrity.json` records byte-exact SFX regeneration.

| Validation command (all tests also use `--concurrency=1 --reporter=expanded`) | Result |
|---|---:|
| `flutter test --no-pub test/qa/phase5a_game_feel_test.dart test/qa/phase5a_audio_test.dart test/qa/phase5a_reverse_test.dart` | 35 PASS |
| `flutter test --no-pub test/qa/tile_motion_test.dart test/qa/tile_feedback_test.dart test/qa/tile_audio_service_test.dart` | 211 PASS |
| `flutter test --no-pub --dart-define=GAME_FEEL_V2=false test/balance_audit/level96_phase4d7_contract_test.dart test/balance_audit/level96_phase4d7_session_test.dart test/balance_audit/level96_phase4d7_widget_test.dart` | 27 PASS |
| Same three Level 96 tests with `--dart-define=GAME_FEEL_V2=true` | 27 PASS |
| `flutter test --no-pub test/balance_audit/level96_phase4d5_contract_test.dart test/balance_audit/level96_shadow_contract_test.dart test/balance_audit/campaign_paired_contract_test.dart test/balance_audit/campaign_validation_contract_test.dart` | 54 PASS |
| `flutter test --no-pub test/qa test/goldens` in a disposable copy | 1,628 PASS |
| `flutter analyze --no-pub` | 81 pre-existing infos, 0 new findings; exit 1 |
| `git diff --check` | PASS |

The ordinary suite includes the dedicated and affected tests: 1,982 reported
host executions include intentional repeated checks, not 1,982 unique tests.
The complete host tests ran in `20261105T191817-32359474`. That run failed its
initial overly strict analyzer-count gate (81 current versus 82 known infos),
not a test. The corrected gate rejects new identities and allows known findings
to disappear. Successful subsequent runs preserve explicit host provenance and
verify unchanged runtime and test hashes before reuse. The final run freshly
executed analysis, diff checking, builds and all Android checks. Only the two
device-only test/driver files may differ for host reuse; they are freshly rebuilt
and executed on Android. A legacy reason label in the recorded host-integrity
step says runtime/driver; `visual_review.json` clarifies this exception.

To repeat everything, use the default command above. To repeat device validation
with strict verification of this saved host evidence:

```bash
PYTHONUTF8=1 python -B scripts/run_phase5a_qa.py --host-evidence qa/phase5a_runs/20261105T193753-9fa0b9de
```

Samsung SM-G990B2, Android 16, serial RZCTA0TPGDD passed six checkpoints per flag:
fresh isolated storage/native audio, unmuted entry, unmuted seven-pointer-tap
triple, muted entry, muted seven-pointer-tap triple and screenshot capture.
These are Flutter pointer events on the physical device, not a claim of testing
hardware touch delivery. The original production and existing DEV APK paths
remain unchanged; their private storage was neither read nor cleared.

The actual ON screenshots show partial assembly at entrance progress 0.4425,
collection at flight progress 0.4633 and synchronized matched-face highlighting
at burst progress 0.6255. Capture waits for measured progress rather than a fixed
sleep. `on/contact_sheet.jpg` provides a four-frame overview. OFF and ON settled
1080x2340 images are pixel-identical. Still frames establish rendering states,
not motion smoothness; automated settling separately verifies no ghost effects.

| Profile sample (screenshot conversion excluded) | OFF | ON |
|---|---:|---:|
| Frames sampled | 215 | 247 |
| Build p50 / p90 / p99, ms | 2.686 / 5.030 / 23.161 | 2.889 / 8.801 / 25.598 |
| Raster p50 / p90 / p99, ms | 17.360 / 18.367 / 19.424 | 18.128 / 19.596 / 29.394 |
| Build samples above 16.667 ms | 7 | 11 |
| Raster samples above 16.667 ms | 131 | 166 |

Sustained 60 FPS is **not verified**. Both configurations already exceed the
raster budget in this single-device, ordered scripted sample; it is not a
controlled benchmark establishing causation. Native logs also contain 4x4
AHardwareBuffer/allocator warnings during capture. Both configurations completed
without a Flutter test exception; the native warning cause remains undiagnosed.
Speaker timbre, perceived latency, combined music/SFX output and subjective
polish need human listening and visual review. Keep GAME_FEEL_V2 default OFF
until that review; no automatic rollout is recommended from these samples.

All 145 originally protected inputs remain unchanged, including production level
assets, domain/engine code, Level 96 instrumentation, historical evidence and
root dependencies. No new balance cohort ran. No commits or pushes were made,
and Phase 5B/5C was not started.
