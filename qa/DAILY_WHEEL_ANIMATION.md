# Daily wheel motion and claim isolation

## Scope and reference

Preserves the existing nine segments, equal `Random.nextInt(9)` odds, coin amounts
(30/50/75/100/150/200), one Hint/Shuffle/Undo booster, Polish daily reset,
achievement rewards. The wheel artwork is now original, programmatic vector art.
No campaign, Endless, gift-code,
Android configuration, dependency or Golden PNG changes.

The supplied WhatsApp file is 13.589 seconds of tile gameplay, not the described
73-second video with a wheel at 61–69 seconds. A contact sheet was inspected;
the wheel implementation follows the written timing/interaction brief. No audio
or graphical assets were extracted into the game.

## Before / after

Previously the wheel used a 300 ms `easeOutBack`, started the controller twice,
and rotated toward `+index / 9` even though clockwise segment placement requires
`-index / 9` to place the selected segment at twelve o'clock. Granting waited for
animation completion and a mounted screen. Leaving early could skip the reward;
separate route instances could both pass the initial eligibility check.

Now `LuckyWheelScreen.spinDuration` defaults to 4600 ms. Five full turns plus
the exact landing fraction follow the integral of a continuous positive velocity
profile. The first 8% accelerates; the rest brakes to zero without reversal or
angle correction. There is no overshoot/settling reversal. A stationary pointer
pulses when actual segment boundaries pass, with sound limited to one cue per
frame and at least 80 ms between tick starts. Dropped frames do not generate a
catch-up sound queue.

The controller transforms a retained RepaintBoundary containing one nine-wedge
wheel illustration. A one-second CustomPainter reveal highlights the landed segment,
draws twelve sparkles and, for coins, seven staggered flights to a live-layout
currency badge. Counter increment/collection sound accompanies arrival. The
badge appears on spin and stays afterward; the ready-state art now includes an
orange ribbon, gold rim, toy pointer, coin illustrations and a grassy pedestal.
The effect layer ignores input and uses no OverlayEntry, timers or saveLayer.

The winning outline uses the exact annular sector path painted for the selected
reward, transformed through the live wheel render box. This includes rotation,
FittedBox scaling and scrolling; the coin flight originates at that wedge's
illustration and still targets the live currency badge. The seven flying
coins follow the existing staggered arc timing from the winning sector
and start at a 23-logical-pixel diameter,
with a clearer rim and glint. Reduced motion still omits the visual effect.
Widget checks compare the outline to the rendered winning wedge and pointer for
every reward, and check the coin bounds and size during the reveal.

The deliberate redesign substantially changes the `lucky_wheel_ready` Golden.
Its PNG must be inspected and approved manually before a baseline update. This
change does not regenerate or edit any Golden PNG or loosen its comparator.
Nine stable reward keys remain mounted throughout the route; the reveal uses
the shared wedge geometry and the artwork's actual render transform.

The screen chooses the reward before spinning and starts the repository claim
immediately. `claimDailySpin` serializes requests across repository instances,
rechecks the original Polish-day marker, applies existing reward/accounting
methods and records the spin. Completed claims survive route recreation and
cannot be granted again for that day. `markDailySpinClaimed` shares that queue.
Status and coin-balance reads wait for in-flight claims, so returning to the
menu while persistence completes cannot capture a stale balance. The widget
never cancels the grant.

Backgrounding finishes presentation without firing a delayed modal or audio;
the final inline result remains on resume. Disposal cancels ticker waits only.
Reduced-motion/accessibility navigation skips travel/particles and presents the
committed result. Storage lookup failures no longer default to an eligible spin.
Optional audio failures cannot fail the reward operation.

The existing SharedPreferences storage is **not a durable multi-key transaction**.
This patch guarantees serialization for live-isolate wheel requests and removes
animation/navigation cancellation from the grant path. It does not claim
crash-atomic exactly-once accounting during forced process termination, disk
failure or an OS kill between preference writes. That existing persistence risk
requires a separate transaction/recovery design; do not represent the tests as
proving power-loss safety. No timers, delayed claims or UI lifecycle callbacks
are used as accounting authority.

## Audio

`playWheelTick`, `playWheelStop`, `playWheelReveal`, `playWheelCollection` use the
existing synthesized-WAV/SFX player infrastructure and saved SFX setting. They
are original short tones and may be replaced by appropriately licensed studio
cues later. Tick volume is intentionally low. No reference-game audio is used.
First-use synthesis and four-player voice mixing still need listening/profiling
on a physical device.

## Verification (owner runs locally)

### Mount timeout regression

The first local run reported repeated `pumpAndSettle` timeouts in `_mount`.
Source inspection identifies a scheduling-lifetime defect in the repository:
the static `_dailySpinQueue` retained its completed Future indefinitely. Dart's
`_Future._addListener` schedules late listeners through that Future's original
zone. The suite interleaves ordinary repository tests and widget tests with
separate fake clocks; a later `dailySpinStatus`/`coins` read could therefore wait
on work scheduled outside the clock being pumped. `_loadAvailability` stayed
pending, leaving the indeterminate `CircularProgressIndicator` scheduling frames.
Neither wheel controller starts before tapping Spin, and the atmosphere is static.
This is a retained async-queue lifetime defect exposed by the test environment,
not evidence of a perpetual wheel animation or a device persistence deadlock.

The queue now contains only pending work and clears its tail on success or error.
An identity check prevents an older completion from clearing a newer request.
Readers still await active claims, and concurrent requests still recheck daily
eligibility inside the same serialized operation. No test-only queue reset,
reward changes, timer workaround or animation suppression was added.

Regression checks retire a claim's scheduling zone and verify that subsequent
status/balance reads finish without scheduling into it, for both successful and
failed writes. Existing concurrent, reward and lifecycle assertions remain.
Mounting still uses `pumpAndSettle`, now with a two-second diagnostic timeout and
explicit assertions for the loaded wheel, absent spinner and zero active ticker
callbacks. Every segment must still be spinning at 4599 ms and land at 4600 ms.
The installed Flutter interpolation simulation uses `elapsed > duration` for
completion. The tests check the rendered angle at exactly 4600 ms, advance to
4601 ms to complete the future, then pump the reveal's scheduled rebuild. A
zero-duration pump at 4600 ms cannot complete that future. They also check that
the angle does not change on completion and both inline and modal reward labels
match the selected segment. Production spin timing is unchanged.

At 320x568 and text scale 2, the counter previously consumed most of the header
row, forcing the remaining title into many short lines. That oversized header
overflowed the screen's outer Column despite its already scrollable body and
dialog. The wheel now places the counter beneath the header when text scale is
above 1.3, retaining the existing typography and the normal-size header layout.
The nine viewport/scale cases check header and counter bounds, full large-text
title layout, positive body viewport height, scroll reachability of the reward
and disabled claimed action, and an accessible dialog dismissal action.

Disposal checks also assert no restarted ticker or new audio after storage finishes.
The corrected suite has not been executed by the agent; local verification is
required before claiming these regressions pass.

No Flutter, Gradle, tests, builds, emulator or ADB were run during implementation.
Only Dart source formatting and static diff inspection were performed.

Git Bash from the repository root:

```bash
flutter test --no-pub --concurrency=1 --flavor prod --dart-define=FLAVOR=prod test/qa/lucky_wheel_test.dart test/qa/secondary_surfaces_test.dart test/qa/main_menu_refresh_test.dart
flutter test --no-pub --concurrency=1 --flavor prod --dart-define=FLAVOR=prod test/qa
flutter test --no-pub --concurrency=1 --flavor prod --dart-define=FLAVOR=prod test/goldens

# DEV is the only flavor with the existing reset-wheel QA control.
flutter run --profile --flavor dev --dart-define=FLAVOR=dev -d RZCTA0TPGDD
```

The focused suite checks all nine landing angles and visible results, every
reward/inventory amount, persistent reload, repeat/concurrent claims, legacy
claimed dates, Polish midnight, seventh-spin achievement accounting, rapid taps,
disposal while storage is pending, lifecycle interruption, bounded tick feedback,
coin count, failed availability lookup, and reduced motion at all nine combinations
of 320x568 / 360x800 / 412x915 and text scales 1 / 1.6 / 2.
The Golden audio fake implements the added sound hooks; no assertions or PNGs
are removed or weakened.

## Samsung S21 FE review

1. Reset only the wheel through existing DEV QA. Open the wheel. Tap rapidly:
   one spin should start immediately and the back action must remain usable.
2. Check the 4.6-second spin at 60 Hz: smooth launch, multiple turns, gradual
   braking, no reverse motion or last-frame correction. The selected reward must
   match the segment centered at the pointer, including booster segments.
3. Listen for restrained ticks which spread apart during braking, one stop/reveal
   and one collection cue. Mute SFX and repeat. Check cold first-use separately.
4. Observe the brief highlight, sparkles and curved coin flight. Coins are already
   saved; the badge changes only as presentation. Close the reward dialog and
   return to the menu: balance, boosters, challenge use and achievements agree.
5. Back out immediately after tap; reopen. Background at launch, midway and during
   coin flight; resume. There must be no second grant, hanging spinner, late modal
   or burst of queued ticks. A completed claim must remain unavailable on restart.
6. Enable reduced motion, increase font size, and test small layouts, rotation/
   resizing and scrolling: reward text/actions stay reachable, effects never
   intercept input, and no long spin is required.
7. Capture separate cold/warm Profile traces in DevTools. Inspect UI and raster
   frame times during launch, peak rotation and reveal. Check that the static
   wheel is retained and effects stop repainting when finished. No FPS improvement
   is claimed without these measurements. Repaint boundaries trade layer/raster
   cache memory for less repeated illustration painting.
