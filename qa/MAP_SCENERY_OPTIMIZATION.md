# Adventure Map scenery: experiment 3 assessment

Date: 2026-10-22. Source baseline: `ac007d7`, plus the existing working tree.
Target: Samsung Galaxy S21 FE, Flutter Profile, Impeller/Vulkan, 60 Hz.

## Decision

**No production rendering change is justified by the available evidence yet.**
Use the request's fallback rather than split the scenery speculatively. The
existing scenery boundary already separates static artwork from the route and
every animated level node. Splitting it cannot add that missing isolation because
it is already present. Smaller regions might improve GPU caching or culling, but
source inspection cannot establish that benefit or rule it out.

`PERFORMANCE_AUDIT.md:46,144` explicitly makes segmentation conditional on map
traces confirming a large-layer/cache problem. The supplied UI/Raster timings and
`UI_JANK_AUDIT.md` do not provide that attribution. The separate sporadic idle UI
stall is outside this experiment. Experiments 1 and 2 remain unchanged.

This change adds characterization tests and this report only. There is no
candidate B production implementation and no measured speedup. No Flutter test,
analyze, build, run, emulator, ADB or baseline generation was executed.

## Rendering evidence

Locations below refer to the unchanged production source at this assessment.

| Location | Observed behavior | Consequence |
| --- | --- | --- |
| `lib/presentation/screens/map_screen.dart:183,252` | A `CustomScrollView` contains a whole `AdventureMapPath` in a `SliverToBoxAdapter`, between header and footer. | The map body is eager; scrolling changes its position in the viewport. There is no scroll listener calling `setState` to repaint scenery. |
| `lib/presentation/widgets/adventure_map_path.dart:13-26,48-55` | Shared geometry determines node coordinates and scene height. Height is `10 * stride + 100`. | At linear text scales 1.0, 1.6 and 2.0 the scene is respectively 2000, 2468 and 2780 logical pixels high. Width and text scale legitimately change layout. |
| `lib/presentation/widgets/adventure_map_path.dart:55-98` | Stack order is scenery, route, then ten nodes. The route and every node have their own repaint boundary. | Completion changes can repaint the route and affected nodes independently of scenery. |
| `lib/presentation/widgets/adventure_world_scenery.dart:21-29` | `IgnorePointer -> ExcludeSemantics -> RepaintBoundary -> CustomPaint`. | The scenery is already an isolated retained paint region; it contributes neither interactive targets nor accessibility labels. |
| `lib/presentation/widgets/adventure_world_scenery.dart:38-84` | One full-scene clip and gradient, overlapping terrain, globally indexed edge motifs, then foreground ovals. No `saveLayer`. | Static, deterministic artwork. Its gradient coordinates and translucent overlap must remain global if ever divided. |
| `lib/presentation/widgets/adventure_world_scenery.dart:300-302` | `shouldRepaint` compares theme and panorama mode only. | Ordinary rebuilds and progress changes do not request new scenery recording. Size changes still repaint through render-object layout, independently of this predicate. |
| `lib/presentation/widgets/adventure_map_path.dart:110-148` | Nine route curves, three strokes each; invalidation checks width, stride, completed segments and accent. | Route progress is deliberately separate from static artwork. |
| `lib/presentation/widgets/adventure_level_node.dart:46-70` | Accessible level state and taps wrap a finite 1200 ms current-node pulse; reduced motion uses zero duration. | The pulse changes a node's transform, not the scenery painter's inputs. Press feedback is also local. |
| `lib/presentation/screens/map_screen.dart:56-58,78,176-182` | Scroll controller disposal, `ensureVisible` and guarded initial positioning. | Entry/Find Current scrolling must be profiled separately from steady scrolling; its lifecycle needs no scenery change. |

The screen background also uses static `WorldAtmosphere` artwork behind the map.
It already has a separate boundary. A possible occluded-background cost is a
hypothesis, not evidence that the GPU performs all obscured drawing. Removing or
clipping it speculatively would risk header, footer, overscroll and transition
appearance.

There are ten levels per world map. Worlds are separate navigation destinations;
there is no continuous vertical scroll across all ten worlds. Test a world
transition by returning to world selection and opening another available world.

## Before and after

Production behavior is unchanged. On initial paint, the scenery records a full
scene. During scrolling, its retained layer moves within the scroll viewport.
Node animation or route progress should not require re-recording that scenery.
Theme, panorama mode and actual size changes still invalidate it appropriately.
New tests make these expectations explicit; their results await local execution.

A retained display list is not proof of a cached GPU texture or inexpensive
rasterization. The engine may still replay drawing commands, process translucent
overlap, or create/evict caches. Consequently, even passing the recording-retention
tests cannot establish the cause of a slow Raster frame.

No additional work is avoided by this test/documentation change, and it introduces
no runtime layers, allocations or memory overhead. The existing boundaries are
the mechanism intended to avoid repeating Dart paint recording when nearby
content changes.

## Why segmentation is deferred

The map currently has one explicit scenery boundary, one route boundary and ten
node boundaries, plus the screen atmosphere and framework layers. This is not a
count of physical GPU textures: a repaint boundary does not guarantee a texture
allocation or a `saveLayer`.

Replacing the scenery boundary with several eagerly created sections would:

- Leave node/route invalidation isolation essentially unchanged.
- Potentially allow finer cache/culling granularity, depending on engine behavior.
- Add layer bookkeeping and potentially multiple cache entries. Total cached pixel
  area is not automatically smaller; padding and cache churn can increase cost.
- Duplicate drawing if each section simply clips and replays the whole painter.
- Require preserving the full-height gradient, global motif indices, terrain
  overlap, foreground positions and alpha drawing order. Fractional scroll
  offsets, device pixel ratio and clip edges could reveal seams.

For scale only, a hypothetical full RGBA texture for a 360 x 2000 logical-pixel
scene at DPR 3 would contain 25,920,000 bytes (about 24.7 MiB), before padding or
other resources. This is **not** a measured allocation, the device's asserted DPR,
or evidence that Impeller actually caches that full texture. Record actual device
metrics and engine diagnostics before choosing section dimensions.

No backend-specific code or new dependency is introduced. Impeller/Vulkan
compatibility and the current visuals are unchanged.

## Narrow alternative, conditional on measurement

If a CPU trace identifies `_SceneryPainter.paint` path construction as material
on initial entry or genuine invalidation, a smaller candidate is to skip only
terrain bands whose entire conservative control-point bounds lie outside the
existing scene clip, before allocating their `Path`. Keep the single boundary
and all intersecting artwork unchanged, with an antialiasing safety margin.

For example, for map height 2000, the final `y = 1800` bands in layers 1 and 2
have their minimum control-point y coordinates at 2028 and 2082 respectively;
their closing edges are also below the clip. They currently construct paths
that cannot contribute visible pixels. Their conservative bounds follow directly
from the cubic control points and closing polygon, not just the curve endpoints.

This is a bounded reduction in Dart path construction on actual repaints, likely
small. It is not a proposed cure for warm-scroll Raster cost or >100 ms UI stalls.
It is not implemented here without attribution. Do not add a global geometry or
image cache. If the trace instead shows retained recording with high Raster cost,
investigate layer/cache behavior before returning to the segmentation hypothesis.

## Regression coverage

Added `test/qa/map_scenery_rendering_test.dart`:

- All ten world themes: retain the same recorded scenery picture during current
  node animation, fractional scroll offsets, parent rebuilds and progress changes.
  Route invalidation, completed stars and a real node tap are checked separately.
- Full scene clip and shader extent, global motif placement and no scenery
  `saveLayer`, using recorded canvas calls. This checks structural continuity;
  it does not replace pixel comparison or prove that every artwork pixel is right.
- All nine viewport/text-scale combinations: 320x568, 360x800 and 412x915 at 1.0,
  1.6 and 2.0, each with reduced motion both enabled and disabled. Check all node
  positions and route curve endpoints against shared geometry, then scroll.
- Theme, text scale, width and panorama invalidation; preserved scroll position
  during input changes; disposal while the node pulse is active.

The picture-identity assertions test framework paint recording, not raster-cache
residency. They intentionally depend on the current scene's retained picture
structure. If Flutter changes that structure, investigate rather than treating
these tests as device performance measurements.

Existing `test/qa/adventure_map_test.dart` remains unchanged and covers actual
world navigation, scroll restoration, locked/current/completed states, taps,
preview/game routes, progress refresh, disposal and reduced motion. The new small
harness does not substitute for those repository-backed navigation checks.

Existing Golden assertions and PNGs remain unchanged. No new section edges exist
in production, so no new seam is introduced. Existing deterministic map Goldens
remain the visual check at their supported viewports/states; they do not provide
pixel coverage for all ten themes and every scroll offset. Any future segmentation
needs that additional comparison, especially at fractional offsets and edges.

## Local verification (Git Bash on Windows)

Run from the repository with dependencies already available and the same Flutter
SDK/fonts used for existing baselines. Commands below are for the user; they were
not executed during this investigation.

```bash
cd '/c/Gra - telefon/game'

# Focused scenery, real navigation, and preserved card optimization
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/qa/map_scenery_rendering_test.dart test/qa/adventure_map_test.dart test/qa/adventure_world_card_repaint_test.dart

# Full QA
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/qa

# Existing Golden comparisons; never regenerate baselines for this work
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/goldens
```

## Repeatable physical-device investigation

1. Use the S21 FE at fixed 60 Hz in Profile with Impeller/Vulkan confirmed in the
   run output. Record Flutter/engine revision, Android version, physical/logical
   size, DPR, text scale, reduced-motion and audio settings, battery/charging and
   thermal state. Keep these conditions and the saved progression identical.
2. Start with the same available world and saved current level. Record initial
   entry separately, including automatic positioning. Wait for the finite entry
   pulse to finish before measuring steady scrolling. Do not attribute entry
   navigation, loading or initial positioning to scenery without their timelines.
3. Move to the top before starting the warm-scroll recording. Swipe vertically
   through the middle of the map viewport, from 80% to 25% of its height over
   approximately 500 ms, with a 150 ms pause between swipes, until the boss/footer
   is visible. Record the swipe count. Reverse with the same count and duration.
   Use exactly that path in subsequent runs; retain the first pass separately from
   repeated warm passes. Avoid taps on level nodes.
4. Capture at least three repetitions with DevTools Performance. Export timelines;
   record UI and Raster median/p90/p99, worst frames, sample/frame counts and each
   thread's frames above the 16.67 ms budget. Keep entry and warm-scroll samples
   separate. An isolated spike is not a recurring scenery diagnosis.
5. In a separate diagnostic capture, enable paint tracking where the installed
   DevTools/engine supports it. Inspect whether the scenery's paint recording
   actually repeats during scrolling or node animation. Correlate CPU samples
   with `_SceneryPainter.paint`, build/layout work and the relevant frame. Use
   available layer/raster-cache diagnostics to investigate cache behavior; if
   the tool cannot expose misses or allocations, record that limitation rather
   than inferring them from frame time. Turn extra instrumentation off for timing.
6. If scenery recording is retained while Raster spikes, repeated Dart painting
   is not established as that spike's cause. Investigate raster replay/cache,
   clipping and overlap using frame evidence. If UI alone is slow, inspect its
   call tree separately. Do not label it GC, shader work or OS scheduling without
   supporting events.
7. Separately exercise Find Current, level preview/back and world selection/back.
   Open another available world, repeat the scroll path and record its name and
   state. Cover all ten themes with existing QA fixtures; do not unlock worlds or
   alter saves merely to benchmark. Use already available worlds on the device.

For a future justified candidate B, compare it against production baseline A with
identical unrelated working-tree changes. Alternate A/B order for at least three
pairs, matching warm-up, data and device conditions. Do not benchmark this
tests-only revision as an optimization: A and B production code are identical.

| Measurement | Baseline A | Future candidate B |
| --- | --- | --- |
| Initial-entry UI/Raster distribution | Not captured | No candidate |
| Warm-scroll UI/Raster distribution and >16.67 ms frames | Not captured | No candidate |
| Scenery recording frequency | Source predicts retention; test/device verification pending | No candidate |
| Layer/cache/memory behavior | Not measured | No candidate |
| Deterministic Golden comparison | Local execution pending | No candidate |

## Acceptance and rollback criteria

For this tests/report change, run the listed commands locally. Investigate every
failure; do not weaken existing assertions or update PNG baselines to accept it.
No production change needs rollback. The only files added by this work are this
report and the new test; preserve all pre-existing working-tree files.

For a future rendering candidate, require unchanged deterministic pixels, all
focused/QA/Golden checks, stable scroll/gesture/navigation/semantics behavior and
correct invalidation. Keep it only if paired device captures demonstrate a useful
repeatable benefit without entry, UI, Raster or memory regressions. Reject on
seams, clipped artwork, stale themes/progress, increased layer/cache churn or no
repeatable benefit. Revert only that candidate's changes, not unrelated work.

**Next action:** capture one attributed warm Adventure Map scroll session on the
physical S21 FE, establishing whether slow Raster frames occur while the existing
scenery recording is retained. This decides whether segmentation addresses the
actual map cost before taking on its visual and GPU tradeoffs.
