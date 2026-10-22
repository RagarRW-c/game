# Experiment 1: retain the decorated world-card body

Date: 2026-10-22. Target: physical Samsung Galaxy S21 FE, Android,
Impeller/Vulkan, Profile mode, 60 Hz.

Status: implemented as a candidate for local verification. No Flutter tests,
analysis, builds, app launches, emulator/ADB commands, baseline generation or
device measurements were run. Dart formatting and source/diff inspection only.
There is no measured FPS or Raster improvement to report.

## Scope and source justification

The complete `qa/PERFORMANCE_AUDIT.md` was read before editing. This implements
only its first proposed experiment. The audit itself remains unchanged.

Previous hierarchy, omitting layout wrappers:

```text
ListView's existing item RepaintBoundary
  GameEntrance: Opacity -> translation (420 ms, easeOutCubic)
    Semantics
      AdventurePressable: AnimatedScale (100 ms) -> Material -> InkWell
        Container: gradient, border, two shadows
          ClipRRect
            panorama (existing RepaintBoundary), lock tint, badge,
            title, subtitle, current-world label, progress and action row
```

The panorama is already isolated. The other body drawing commands share their
ancestor's paint traversal. In the inspected Flutter SDK, changing a
`RenderTransform` matrix calls `markNeedsPaint`; its paint method traverses its
child beneath the transform. The list-item boundary is above that invalidation,
so it protects siblings but cannot stop traversal into an unisolated body.
Passing the card as the entrance builder's `child` already avoids rebuilding
that subtree on each tick; widget reuse alone does not isolate painting.

The body is static during a transform-only frame: gradient, border, shadows,
rounded clip, themed panorama, lock tint, badge, text and determinate progress.
Its inputs can still change when progress refreshes or constraints/text scaling
change. Entrance opacity/translation, press scaling and Material ink feedback
are animated. There are no star widgets on destination cards; saved star displays
belong to map nodes and remain untouched.

The only production change inserts a `RepaintBoundary` as the
`AdventurePressable.child`, immediately around the existing decorated Container.
This is below both animation transforms and below Material/InkWell. A clean body
can retain its display lists/layer subtree while ancestors repaint or composite
the changing transform/opacity and ink. A changed body still lays out and paints
normally; no snapshots, custom cache, keep-alive policy or new state are added.

The new boundary follows the card's actual layout bounds and introduces no clip,
padding, fixed size or saveLayer call. Both shadows remain outside the existing
inner rounded clip. The existing panorama and list boundaries are preserved;
no boundary is added to the complete list or to each text/icon individually.
Standard Flutter retained layers are compatible with Impeller/Vulkan; no
renderer-specific API or configuration changes are involved.

All ten theme inputs, colors, decoration, sizes, spacing, semantics, callbacks,
keys and existing animation timing/curves remain the same. Reduced motion still
selects zero-duration transitions. No navigation gate, OverlayEntry or input
delay is introduced. Experiments 2 and 3, gameplay, campaign data, rewards,
persistence, stars and unrelated screens are outside this change.

## Limits and tradeoffs

- The intended saving is repeated paint recording of the static decorated body
  during transform/ink frames, with possible downstream raster-cache reuse.
  Reusing display lists does not guarantee avoiding their GPU rasterization.
  This is a technically justified experiment, not an identified root cause.
- One extra retained layer per mounted card adds bookkeeping and may increase
  raster-cache/GPU memory. Lazy-list disposal is unchanged. A boundary does not
  mandate a bitmap or offscreen pass; cache eligibility and opacity handling are
  engine decisions. Scale changes may reduce cache reuse. The already nested
  panorama boundary may limit the incremental benefit.
- First paint, progress changes, layout changes, route transitions and opacity
  blending still have costs. Steady scrolling after entrances settle may already
  be efficient due to existing list boundaries, so improvement may be small.
- Fractional transforms and compositing can affect raster sampling. Verify
  shadows, rounded corners, text and ink during entrance/press frames as well as
  at rest. Exact visual equivalence has not yet been verified on the device.
- Reject this candidate if repeated measurements show no useful improvement,
  visual differences or disproportionate memory cost. Do not extend the boundary
  pattern to other screens without attribution.

## Regression coverage and local commands

New `test/qa/adventure_world_card_repaint_test.dart` checks:

- Independent parent/body painting during intermediate entrance and press frames
  using debug repaint-boundary counters. These assertions test paint isolation,
  not real-device Raster duration or cache residency.
- All ten themes through locked/current/completed input states, changed progress,
  labels, semantics, tap behavior and reduced motion. The same body render object
  and entrance/press State objects survive parent updates.
- Input before the entrance finishes and safe disposal during entrance/press,
  with no remaining animation callbacks or framework exception.

Existing `test/qa/adventure_map_test.dart` retains its real-route navigation,
duplicate-callback guards, scroll retention, unlock/completion refresh, saved-star,
responsive layout and lifecycle assertions. Existing QA and Golden files and all
PNG baselines are unchanged. New tests have not been executed.

Run from Windows Git Bash using the same Flutter SDK/fonts as the existing
Windows baselines and already resolved dependencies:

```bash
cd '/c/Gra - telefon/game'

# Focused rendering plus existing navigation/state/lifecycle regression checks.
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/qa/adventure_world_card_repaint_test.dart test/qa/adventure_map_test.dart

# Full existing QA runner, including the new test; writes qa/results reports.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File qa/run_qa.ps1

# Verify every existing Golden with the strict comparator. Never update PNGs.
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/goldens

# Static analysis, separately.
flutter analyze --no-pub

git status --short
git diff --check
```

Do not use `--update-goldens` for this experiment. A mismatch requires investigation
of the candidate, SDK/fonts and fixture state, not accepting replacement images.
Existing Goldens cover representative settled views, not every theme or animation
frame; supplement them with device review. The pre-existing balance reports and
other uncommitted work must remain separate from this experiment.

## Repeatable physical-device A/B procedure

1. Prepare two otherwise identical source snapshots: A with the original card
   body, B with this one wrapper. Preserve the pre-existing working-tree changes
   in both. A clean HEAD build is not necessarily the correct baseline. Do not
   switch renderer, SDK, profile manifest, dependencies or DevTools configuration
   between captures. Record source diff/revision and Flutter/engine/DevTools
   versions. Use the same application ID and existing save; do not clear app data
   or modify progress to make more worlds accessible.
2. Use the physical S21 FE at 60 Hz with the same Android version, text scale,
   logical size/DPR, brightness, motion setting and power-saving setting. Start
   from similar thermal/battery conditions. Use a Profile build launched locally
   with `flutter run --profile --no-pub --enable-impeller --dart-define=FLAVOR=prod
   -d "$S21_FE_DEVICE_ID"` (one line; set the variable to the physical device ID).
   Confirm the runtime startup output actually identifies Impeller/Vulkan.
   No device launch has been performed for this implementation.
3. Use DevTools Performance to record **first entry** separately: settle the
   menu and any legitimately pending dialogs, clear the timeline, tap Adventure,
   and stop after Worlds' route/entrance animations settle. Label this as first
   Worlds entry after process launch, not guaranteed cold OS/driver cache.
4. Record **Worlds traversal** separately. Start at the top. Drag from 80% to 25%
   of the list viewport height over roughly 500 ms; pause roughly 150 ms and
   repeat until Crystal is fully visible. Reverse with matching 25% to 80% drags
   to Garden. Repeat this down/up traversal three times per capture. Use the same
   gesture count and pace established during the first baseline rehearsal; log
   them. These short pauses allow entrances and scrolling to overlap. Traverse
   all ten cards regardless of lock state; do not tap locked worlds to navigate.
   Record recreation/entrance behavior rather than assuming every card restarts.
5. Record a separate **navigation/press** capture: Worlds -> Garden -> Back to
   Worlds -> Back to menu, ten times at a consistent pace. Do not start a level
   or claim rewards. Keep this separate from the traversal statistics so map
   entry cost does not obscure the card experiment. Verify back navigation and
   restored scroll position. Separately hold/release or cancel a card press to
   inspect shadow edges and ink while the scale changes.
6. Collect at least three paired warm captures per scenario, alternating A/B
   order and allowing thermal recovery. Export each timeline with variant,
   scenario and repeat in its filename. Record frame count, UI and Raster median,
   p95 and worst duration, per-thread fraction above 16.67 ms and available
   dropped-frame indicators. Compare active windows with matching actions;
   exclude long idle gaps and keep first-entry results separate. Do not add UI
   and Raster times or compare only a whole-session average such as 12.79 ms.
7. In a separate diagnostic pass, use available paint tracking/repaint highlights
   to identify whether the decorated body repaints during transforms in A and B.
   Inspect layer/cache/offscreen diagnostics where supported; the retained body
   should paint initially and on content changes, with fewer repeated body
   recordings on transform-only frames. Debug-only diagnostics must be labeled
   as such. Turn enhanced tracing/highlights/overlays off for Profile A/B timing.
8. Compare memory after initial warm-up and after 10 and 20 identical navigation
   cycles, returning to the same settled menu and taking snapshots after GC where
   supported. Compare retained route/controller objects and Dart/external/RSS
   trends; Dart heap alone cannot establish GPU texture cost. Record a cache
   plateau separately from sustained growth. Missing GPU metrics remain unknown.
9. Review all ten card illustrations, locked/current/completed states available
   in existing saves, progress, shadows and corners at rest and during entrances
   and presses. Verify reduced motion, Back and rapid taps. Use existing QA for
   320x568, 360x800, 412x915 and text scales 1.0/1.6/2.0; these host checks are
   separate from physical-device performance. Do not change saves for coverage.
10. Keep the change only if body-paint evidence and repeated Raster p95/over-budget
    results improve beyond baseline variability, without a UI regression, visual
    change, lost input or excessive memory cost. If body recording drops but
    Raster does not improve, inspect the same slow frames for opacity/route
    compositing and first-use raster work next. Do not automatically implement
    the audit's other experiments.

## Files changed by this experiment

- `lib/presentation/widgets/adventure_world_destination_card.dart`
- `test/qa/adventure_world_card_repaint_test.dart` (new)
- `qa/WORLD_CARD_REPAINT_EXPERIMENT.md` (new)
