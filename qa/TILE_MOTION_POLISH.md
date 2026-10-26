# Tile motion and visual redesign — reference follow-up

This section supersedes the 280 ms timing and unchanged-art conclusions in the
initial polish record retained below.

## Reference inspection and design decision

Inspected the supplied `WhatsApp Video 2026-10-20 at 21.53.35.mp4` locally with
FFprobe/FFmpeg: 576x1296, 60 fps, 13.589 seconds (not the earlier 73-second wheel
reference). Examined the full clip as a contact sheet, the 1.6–2.8 second range
at 30 fps, and a full-resolution frame at 1.7 seconds. The sampled basketball
selection at roughly 1.6–1.9 seconds shows enlargement before tray insertion,
a clean ivory/grey dimensional tile, saturated outlined illustration and very
little trailing decoration. This clip uses a top tray; its styling is applied
to the existing top and bottom placements without changing their selection rule.

The visible reference flight is roughly a quarter second; the exact tap time is
not visible. **440 ms is a deliberate slower adaptation requested by the owner,
not a claim that the reference was measured at 440 ms.** The prior 280 ms flight
arrived after only 218.4 ms and had almost no visible pickup interval.

## Implemented behavior

- Press remains immediate (tint and 70 ms contraction / 110 ms release).
- Flight: 440 ms, up from 280 ms. Pickup occupies 0–61.6 ms with no destination
  travel, enlarging the face up to 22% and lifting it 12 logical pixels.
- Transport: 61.6–343.2 ms. Quintic smootherstep starts and ends with zero
  velocity and acceleration. Lift recedes as travel progresses; a bounded
  lateral arc reads clearly in either tray position.
- Settle: 343.2–440 ms. Exact destination is preserved, with gentler 5% width /
  7.5% height compression followed by a small rebound. Canonical tray ownership
  resumes at the original animation completion mechanism, with no extra delay.
- Match snapshots use the same arrival clock. Compression remains 70 ms and
  face fading remains 80 ms. The burst clock is extended from 500 to 640 ms so
  those phases and its particle tail fit after the later arrival. Hint matches
  still react immediately when no incoming flight exists.
- Trails and halo are softer, and the landing ring is thinner. No extra
  particles, timers, callbacks, controllers, overlays or layers were added.
- All tile faces now share `TileFace`: ivory ceramic cap, a proportional grey
  lower bevel, tight contact shadow, fine outline, and a bright inset edge.
  `TileSymbol` renders existing theme glyphs with a dark outline, coloured
  gradient and embossed shadow. It uses normal text painting, no ShaderMask or
  saveLayer. It retains all theme/type identities and uses no copied assets.
- Artwork fits the measured tile including narrow tray slots. Symbol sizing
  is proportional to the visible face. Only the icon-font glyph ignores text
  scaling (as Icon did); player-facing labels are not capped. Named tile
  semantics expose one action for enabled tiles and no action for covered ones.

## Scope, correctness and limitations

Engine selection, scoring, tray ordering, persistence, rewards, boosters and
progression are untouched. Concurrent animation ownership, reduced-motion
fallback, route/disposal cleanup and resize cancellation remain in place.
Unrelated working-tree changes are preserved.

Audio remains the existing immediate acceptance/match cue, once per accepted
move. It is **not retimed to the now-later burst**. No delayed sound can survive
navigation, but the audible/visual gap still needs device review. Rapid matches
and layout changes retain the existing cancellation policy rather than new
mid-flight retargeting. Immediate victory/game-over navigation remains immediate.

The faces are a reference-inspired recreation, not a copy of its sports artwork.
Symbols retain this project's theme silhouettes; gradient/outline treatment is
closer to the reference but is not equivalent to bespoke painted illustrations.
No visual parity or measured performance improvement is claimed. A longer flight
means more animated frames; glyphs now paint twice for outline/fill, while tile
faces no longer require the former multiple blurred box shadows. Measure on S21 FE.

## Regression coverage and intentional golden changes

Updated explicit flight/burst timing assertions and deterministic samples for
pickup, travel, arrival ownership, compression and independent completion clocks.
Kept exact endpoint, canonical-face equivalence, state, rapid-tap, booster,
reduced-motion, navigation and stale-callback assertions. Added all-theme symbol
containment at 24x60, 48x48 and 72x72, covered/highlighted states, large text and
accessible action checks.

Expect intentional Golden changes in all eight gameplay images (Campaign,
occupied tray, Endless and their viewport variants), plus the `pause` image in
`secondary_golden_test.dart` where the board remains visible behind the dialog.
Reason: the tile fill, border, bevel and symbols have been redesigned. Baseline
PNGs and Golden assertions were NOT edited. Inspect generated failure diffs;
accept only tile artwork changes before selectively updating those baselines.
Lucky Wheel and unrelated screen baselines should remain unchanged.

## Local verification (repository root, Windows Git Bash)

```bash
flutter test --no-pub --concurrency=1 --flavor prod --dart-define=FLAVOR=prod test/qa/tile_motion_test.dart test/qa/tile_feedback_test.dart test/qa/tile_widget_test.dart
flutter test --no-pub --concurrency=1 --flavor prod --dart-define=FLAVOR=prod test/qa/
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/goldens/
flutter analyze
git diff --check
```

No Flutter, Gradle, tests, builds, emulator or ADB were run for this change.
Dart formatting and source/diff inspection only; Flutter compilation, rendering,
QA and analyzer results remain unverified.

On S21 FE verify slow single selections, fast alternating taps, triples during
other flights, both tray positions, near-full tray and all ten themes. Inspect
symbol readability, disabled tiles and hint highlights. Test reduced motion,
TalkBack selection, navigation/Undo/Shuffle during pickup and arrival. Compare
Profile UI/raster traces using identical sequences and confirm no residual
animation after settling. Review match sound versus the later burst explicitly.

---

## Initial polish record (superseded timing/artwork)


## Inspected architecture

- `lib/presentation/widgets/game_tile.dart`: gesture-down press tint and 0.93
  scale, cancellation on release/invalid state, unchanged hit-test geometry.
- `lib/presentation/screens/game_screen.dart` (`_onTileTap`, `_showMoveFeedback`)
  and `endless_screen.dart`: canonical engine selection occurs before feedback
  and persistence awaits. Repeated selection is rejected by engine state.
- `lib/presentation/widgets/tile_effects.dart`: measured source/slot render-box
  transforms include SafeArea and FittedBox. Seven bounded flights and three
  bounded bursts use independent, serial-keyed TweenAnimationBuilders. Normal
  tray faces are hidden while their presentation copy flies. Appearance morphs
  into the canonical tray face before handoff. Matches cancel obsolete flights
  when the tray compacts, retaining immutable matched snapshots.
- Flights last 280 ms; arrival is at 78% (218.4 ms), followed by compression and
  rebound. Matches share that arrival boundary, compress for 70 ms, then fade
  their snapshots over 80 ms within a 500 ms burst. Hint matches without flight
  start their reaction immediately. Twelve particles per slot, three trail
  samples, a shared flash and bounded rings already exist.
- The effects Stack is input-transparent, excluded from semantics and isolated
  by a RepaintBoundary. Its stable board child is not rebuilt on animation ticks.
  Geometry, round, TickerMode and reduced-motion changes cancel presentation;
  framework-owned tweens are disposed when removed. Disposal clears snapshots.
- `lib/presentation/tile_feedback.dart` dispatches tap OR match audio once on an
  accepted move, respecting SFX and vibration settings and isolating failures.
  `lib/core/audio_service.dart` reuses its existing player pool/generated cues.
  There are no separate launch, landing or burst-completion cues. No new sounds,
  delayed audio callbacks, timers or controllers are introduced here.

## Confirmed weaknesses and changes

1. The old fractional-power brake matched velocity at progress 0.5 but not
   acceleration. Its exponent 1.344 also made acceleration unbounded as arrival
   approached. A quintic brake now matches position, speed and acceleration at
   the same midpoint and ends with zero speed and acceleration. The initial
   travel phase and endpoints remain unchanged. The lift envelope uses sine
   cubed instead of sine squared to ease its acceleration to zero at both ends.
2. Press feedback took 150 ms and used an overshooting curve. It now contracts
   over 70 ms and releases over 110 ms with easeOutCubic, retaining the same 0.93
   scale, immediate tint, hit area and synchronous tap callback. No selection
   waits for this feedback.
3. Match compression previously started at nonzero speed; disappearance used
   linear scale/fade. Smoothstep now eases compression, shrinking and opacity
   into/out of their existing phases. Snapshot ownership, arrival, release and
   cleanup deadlines remain unchanged. Existing landing bounce is preserved.

These are source-confirmed curve properties; their perceived improvement has
not been validated on a device. The complete rectangle motion still transitions
into the existing landing response; only the travel component is C2 continuous.

## Tests and limits

Extended `test/qa/tile_motion_test.dart` with acceleration continuity, monotonic
bounded travel, and smooth match-onset/fade assertions. Extended
`test/qa/tile_feedback_test.dart` to verify press/release durations while keeping
its cancellation, single selection, hit geometry and ticker cleanup checks.
All existing assertions remain. Existing suites cover simultaneous flights,
rapid matches, duplicate callbacks, tray ordering, boosters, geometry changes,
navigation/disposal, reduced motion, both tray placements and Campaign/Endless.
`test/goldens/gameplay_golden_test.dart` covers settled board/tray appearance;
it does not validate intermediate motion. No baseline updates are expected for
settled appearance and none were made.

Audio is still an acceptance cue: for a tapped triple it precedes snapshot
reaction by 218.4 ms and particle release by 288.4 ms. This pass does not claim
sample-accurate burst synchronization. Device listening should determine whether
that separation warrants a distinct presentation cue without duplicating the
existing match sound. No new landing sound is added to rapid-tap sequences.

No additional layers, particles, animation objects or timers are allocated.
Polynomial evaluation replaces a fractional power in braking; particle shader
allocation and existing frame rebuild costs remain. No FPS improvement is claimed.
Resizing/compaction still cancels stale flights and reveals canonical state rather
than retargeting mid-flight; this established behavior is preserved.

## Owner verification

No Flutter, Gradle, tests, builds, emulator or ADB were run during this pass.

```bash
flutter test --no-pub --concurrency=1 --flavor prod --dart-define=FLAVOR=prod test/qa/tile_motion_test.dart test/qa/tile_feedback_test.dart test/qa/tile_widget_test.dart
flutter test --no-pub --concurrency=1 --flavor prod --dart-define=FLAVOR=prod test/qa/
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/goldens/
```

On Samsung S21 FE, compare the previous commit and this patch in Profile mode
at 60 Hz, using the same level and tap sequence:

1. Hold, cancel and quickly tap uncovered tiles. Check prompt press feedback,
   no duplicate selection and continuous handoff into flight.
2. Send several tiles together to top and bottom trays. Check the brake, exact
   landing and quiet settled state; repeat with a nearly full tray.
3. Match rapidly, including overlapping triples. Check synchronized face
   compression/disappearance, readable tray contents and no extra sound spam.
4. Use Undo, Hint and Shuffle during movement; resize or navigate away mid-flight.
   Verify canonical tray state and absence of stale effects on return.
5. Repeat at 320x568, 360x800 and 412x915, large text and reduced motion. Compare
   SFX on/off and listen to the acceptance cue versus later burst separately.
6. Capture equivalent cold/warm DevTools traces. Compare UI/raster frame times
   during concurrent flights and triple bursts, then confirm no active tickers
   after settling or leaving the screen. Keep visual judgment separate from FPS.
