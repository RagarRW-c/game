# Navigation rendering performance audit

Date: 2026-10-22. Source revision: `dd89a3f`, plus the existing working tree.

## Scope and limits

Read-only source inspection of Adventure Map, world selection, main menu, their level-preview/login dialogs, navigation wiring, and shared rendering components. The only file created by this audit is this report. Existing working-tree changes, production code, saved data, configuration and Golden PNG candidates were left untouched. No tests, baseline generation, `flutter analyze`, builds, emulator, ADB or Git commit were run.

Target supplied by the user: Samsung Galaxy S21 FE, Android, Flutter Profile mode, Impeller/Vulkan, 60 Hz. Local SDK metadata reports Flutter 3.41.9 / DevTools 2.54.2; this does **not** establish which SDK produced the supplied recordings.

| Supplied recording | Frames | Mean frame time | p95 | Frames over 16.67 ms | Average Raster |
| --- | ---: | ---: | ---: | ---: | ---: |
| A | 2,079 | 15.49 ms | 20.59 ms | 14.9% | 12.79 ms |
| B | 2,299 | 9.24 ms | 18.91 ms | 5.4% | 5.89 ms |

These aggregates and the reported low UI averages justify investigating rendering first. They do not identify a screen, establish a regression between A and B, or prove GPU saturation. Raster timing includes raster-thread work; it is not a direct GPU utilization measurement. Individual UI spikes remain possible. UI and Raster durations must not simply be added to classify pipelined frames. The supplied definition of “frame time” and the raw timelines were not available.

**HIGH / MEDIUM / LOW below rank investigation priority, not a measured performance impact.** “Confirmed” means a code structure or duplicate execution path is established by inspection. All claims that a structure causes missed frames remain hypotheses until measured on the device.

## Ranked findings

### 1. HIGH — World-card entrance transforms animate decorated content while the list scrolls

**Source:** [world_selection_screen.dart:223](<C:/Gra - telefon/game/lib/presentation/screens/world_selection_screen.dart:223>), [adventure_world_destination_card.dart:26](<C:/Gra - telefon/game/lib/presentation/widgets/adventure_world_destination_card.dart:26>), [game_decoration.dart:13](<C:/Gra - telefon/game/lib/presentation/widgets/game_decoration.dart:13>), [adventure_level_node.dart:179](<C:/Gra - telefon/game/lib/presentation/widgets/adventure_level_node.dart:179>).

**Confirmed:** Every destination card is wrapped in `GameEntrance`: a 420 ms opacity/translation animation. The card contains a gradient, border, two shadows (one blurred with radius 16), a rounded clip, panorama, badge and text. `AdventurePressable` adds a 100 ms scale animation on highlight. The panorama has its own repaint boundary, but the remaining static card decoration/content has no explicit boundary below these changing transforms. The animation uses its `child` parameter, so it does not reconstruct the full card widget subtree on every tick.

World selection uses lazy `ListView.separated`, with default child repaint boundaries. Those outer boundaries isolate cards from siblings; they do not by themselves isolate static card contents from a transform inside the card. Cards created in or near the viewport start their entrance animation. A card disposed outside the retained/cache region can animate again when recreated; a stable key alone does not keep its state alive. This is not a claim that every scroll movement restarts all cards.

**Hypothesis:** Concurrent entrance animations, card translation, rounded clipping and shadow rendering increase Raster pressure during first traversal and rapid reverse scrolling. Fractional opacity can add compositing/offscreen cost, but engine opacity optimizations may avoid it. An `Opacity` widget is not proof of a costly offscreen pass on every frame.

**Minimal experiment:** On destination cards only, place a tightly bounded repaint boundary around the stable decorated card body, below the entrance/press transforms. Preserve animation duration, curve, opacity, shadows, layout and interaction. Compare with the existing arrangement before extending the change anywhere else. Do not add another boundary around the entire list item: one already exists.

**Risk / proof needed:** Extra layers and possible raster-cache memory; transform cache reuse is not guaranteed. Confirm that card-body paint events decrease and that Raster p95 improves during identical scrolling. Inspect shadow edges and rounded corners at intermediate animation frames. If the content is already retained efficiently, reject the extra boundary. Disabling entrances is useful only as a temporary diagnostic control, not an appearance-preserving fix.

### 2. HIGH — The map is one tall, eager scene with two full-height retained paint regions

**Source:** [map_screen.dart:252](<C:/Gra - telefon/game/lib/presentation/screens/map_screen.dart:252>), [adventure_map_path.dart:11](<C:/Gra - telefon/game/lib/presentation/widgets/adventure_map_path.dart:11>) (geometry), [adventure_map_path.dart:51](<C:/Gra - telefon/game/lib/presentation/widgets/adventure_map_path.dart:51>) (scene and boundaries), [adventure_world_scenery.dart:23](<C:/Gra - telefon/game/lib/presentation/widgets/adventure_world_scenery.dart:23>) and [adventure_world_scenery.dart:38](<C:/Gra - telefon/game/lib/presentation/widgets/adventure_world_scenery.dart:38>) (paint work).

**Confirmed:** A single `SliverToBoxAdapter` hosts the complete map `Stack`, including all ten nodes. Its height is `10 * stride + 100`: 2,000 logical pixels at linear text scale 1.0, 2,468 at 1.6 and 2,780 at 2.0. Actual Android nonlinear scaling follows `scaler.scale(16)`, rather than necessarily these linear examples. Scenery and route each span this full height in separate repaint boundaries. Each node also already has a boundary.

On a scenery paint, the painter records a full gradient, three terrain-band loops, and `ceil(height / 160)` motifs (13 at height 2,000; 18 at 2,780). The route records nine segments with three strokes each. Its clip covers the entire scene, not a deliberately segmented viewport region. This establishes recording scope and eager layout, **not** that every offscreen primitive reaches the GPU every frame: viewport clipping, engine culling and cache behavior can avoid work.

**Hypothesis:** Large layer bounds, first-use recording/rasterization, and cache creation/reuse during long scrolling contribute to entry spikes or memory pressure. Existing boundaries can already make steady scrolling efficient. A repaint boundary does not guarantee a cached bitmap, nor does `shouldRepaint == false` guarantee zero raster work.

**Smallest useful experiment after attribution:** Segment only the static scenery into bounded vertical paint regions, preserving global drawing coordinates, gradient bounds, motif indices, terrain overlap and clipping. Keep the existing node structure and route unchanged initially. This is more invasive than finding 1; do not start by rewriting the entire map into lazy nodes or adding another giant outer boundary.

**Risk / proof needed:** Seams, changed gradients, missing shapes crossing segment edges, more layers and worse caching are possible. Cache allocation scales with physical area: approximately `logicalWidth * logicalHeight * DPR^2 * 4` bytes for one full RGBA surface if one is allocated; this is a sizing model, not measured resident memory. Measure cold/warm scrolling, cache/raster behavior and memory before investing in segmentation. Lazy nodes would also require redesigning the `GlobalKey`-based current-level lookup and therefore are not a minimal first fix.

### 3. MEDIUM — Menu return paths request the same refresh twice

**Source:** [main.dart:102](<C:/Gra - telefon/game/lib/main.dart:102>), [main_menu_screen.dart:45](<C:/Gra - telefon/game/lib/presentation/screens/main_menu_screen.dart:45>), [main_menu_screen.dart:68](<C:/Gra - telefon/game/lib/presentation/screens/main_menu_screen.dart:68>), [main_menu_screen.dart:80](<C:/Gra - telefon/game/lib/presentation/screens/main_menu_screen.dart:80>); return callbacks at [228](<C:/Gra - telefon/game/lib/presentation/screens/main_menu_screen.dart:228>), [251](<C:/Gra - telefon/game/lib/presentation/screens/main_menu_screen.dart:251>), [279](<C:/Gra - telefon/game/lib/presentation/screens/main_menu_screen.dart:279>), [319](<C:/Gra - telefon/game/lib/presentation/screens/main_menu_screen.dart:319>) and [343](<C:/Gra - telefon/game/lib/presentation/screens/main_menu_screen.dart:343>).

**Confirmed issue:** The registered `RouteObserver` invokes menu `didPopNext`, which starts `_loadRewards()`. Awaited navigation callbacks for Endless, Lucky Wheel, Shop, Daily Challenges and Achievements also call `_loadRewards()` on return. Settings/QA can do so when returning `true`. There is no in-flight guard for this refresh. `didChangeDependencies` is an additional refresh source.

Each refresh reads five pieces of repository state, unconditionally calls menu-level `setState`, checks the login prompt and invokes `showPendingAchievementPopups`. Two calls do not necessarily produce two separately rendered frames because updates can coalesce; duplicate refresh requests are nevertheless real. The finite menu uses an eager `SingleChildScrollView`/`Column`, so a menu-level update revisits its build. This is predominantly redundant UI/data work, not proof of the reported Raster bottleneck.

**Minimal improvement to test:** Give return refreshes one owner (the route callback), and coalesce overlapping refresh requests while ensuring a final refresh after any intervening state change. Only update display state when values differ. Do not change repository persistence or reward calculations.

**Risk / proof needed:** Login and achievement presentation are side effects of this function, not merely reads. Preserve popup ordering, fresh balances and refreshes after claims; avoid accidentally dropping an update while a previous refresh or dialog is in flight. Measure callback counts and menu builds in a separate diagnostic run, then compare uninstrumented return transitions. Do not treat shared-preferences getters as repeated disk I/O without evidence.

### 4. MEDIUM — Layered backgrounds and shadows are plausible raster costs, but broad removal would change the design

**Source:** [game_ui.dart:14](<C:/Gra - telefon/game/lib/presentation/widgets/game_ui.dart:14>), [world_atmosphere.dart:30](<C:/Gra - telefon/game/lib/presentation/widgets/world_atmosphere.dart:30>), [world_atmosphere.dart:173](<C:/Gra - telefon/game/lib/presentation/widgets/world_atmosphere.dart:173>), [adventure_world_scenery.dart:41](<C:/Gra - telefon/game/lib/presentation/widgets/adventure_world_scenery.dart:41>), [adventure_level_node.dart:81](<C:/Gra - telefon/game/lib/presentation/widgets/adventure_level_node.dart:81>), [game_ui.dart:247](<C:/Gra - telefon/game/lib/presentation/widgets/game_ui.dart:247>), [game_theme.dart:71](<C:/Gra - telefon/game/lib/presentation/theme/game_theme.dart:71>).

**Confirmed:** `GameBackground` paints a base gradient plus a static `WorldAtmosphere`. The latter draws two full-bounds radial glows and a final full-bounds edge gradient, with additional translucent decorations. Map scenery draws its own opaque background gradient over the portion of the viewport occupied by the map. Thus part of the underlying atmosphere is visually occluded. Nodes use a blur-26/spread-5 glow for current/boss states plus a blur-14 shadow; buttons use blur 12 and foreground gradients. World cards use blur 16. These are real drawing operations, not evidence that each is expensive enough to miss the deadline.

**Hypothesis:** Blending, shadows and covered background work add cost, especially while layers move. The engine may cull covered content or reuse cached output; source inspection cannot quantify the wasted pixels.

**Minimal improvement to consider only if measured:** Restrict background decoration painting to regions that are actually exposed on the map, with exact preservation of visible output. First perform a diagnostic comparison to determine whether background work is material. Retain shadow/glow values; prefer static-content reuse from finding 1 over global blur reductions.

**Risk / proof needed:** Viewport/header/footer boundaries, overscroll and route transitions can reveal previously covered areas. Removing the map's gradient changes the art because its gradient coordinates span the long scene. Adding scroll-driven clipping can cost more than drawing the existing background. This is lower priority than bounded reuse or duplicate-refresh removal.

### 5. MEDIUM — Dialog entrances stack multiple transitions

**Source:** [main_menu_screen.dart:425](<C:/Gra - telefon/game/lib/presentation/screens/main_menu_screen.dart:425>), [game_ui.dart:508](<C:/Gra - telefon/game/lib/presentation/widgets/game_ui.dart:508>), [map_screen.dart:105](<C:/Gra - telefon/game/lib/presentation/screens/map_screen.dart:105>), [map_screen.dart:314](<C:/Gra - telefon/game/lib/presentation/screens/map_screen.dart:314>), [main.dart:95](<C:/Gra - telefon/game/lib/main.dart:95>), [game_theme.dart:248](<C:/Gra - telefon/game/lib/presentation/theme/game_theme.dart:248>).

**Confirmed:** Daily Login has an outer opacity/scale tween and an inner `GameDialogFrame` opacity/scale tween, in addition to the normal `showDialog` route transition. Level Preview has `GameEntrance` inside a `Dialog`. Application routing uses Material routes; no custom page-transition theme is configured here. Heavy painted content can be involved in overlapping entrance phases. The exact Android route snapshot/compositing behavior depends on the runtime; do not assume both complete routes repaint on every transition frame.

**Hypothesis:** Short spikes attributed to “menus” may actually be dialog/route entrance cost rather than idle menu or scrolling cost.

**Minimal experiment:** Isolate stable dialog content below transforms, if paint tracing shows repeated recording. An alternative would be consolidating nested animation drivers while preserving the combined scale/opacity trajectory exactly; simply deleting an animation is a visual change and is not recommended as an approved optimization.

**Risk / proof needed:** Opacity grouping with overlapping pixels can change blending. Dialog size changes after asynchronous content loads, barriers, dismissal and reduced motion must remain correct. Compare a menu visit with no pending prompts against a separate dialog-opening capture.

### 6. LOW — Initial map positioning can add entry work; it is not a perpetual scroll rebuild

**Source:** [map_screen.dart:71](<C:/Gra - telefon/game/lib/presentation/screens/map_screen.dart:71>), [map_screen.dart:176](<C:/Gra - telefon/game/lib/presentation/screens/map_screen.dart:176>), [adventure_level_node.dart:57](<C:/Gra - telefon/game/lib/presentation/widgets/adventure_level_node.dart:57>).

**Confirmed:** After progress arrives, a post-frame callback calls `Scrollable.ensureVisible` with zero duration once. This may change the offset after the initial layout, particularly for later levels. User-triggered Find Current scrolls for 420 ms unless reduced motion is enabled. The current node has one 1,200 ms scale pulse; it is not a looping animation. No screen-level scroll listener calls `setState` in either Map or World Selection.

**Hypothesis / minimal experiment:** If entry spikes correlate with the initial jump, resolve an initial offset from already available progress and the real layout constraints to avoid displaying an unnecessary initial position. This is only worthwhile after measuring it; content header height is responsive, so a hard-coded offset is unsafe.

**Risks:** Current-level centering, restored scroll position, large text and accessibility. Keep the existing behavior unless an equivalent initial-position calculation is demonstrated. Do not blame ongoing scrolling on repeated whole-screen builds without build traces.

### 7. LOW — Small eager trees and allocations are secondary candidates

**Source:** [main_menu_screen.dart:177](<C:/Gra - telefon/game/lib/presentation/screens/main_menu_screen.dart:177>), [adventure_progress.dart:14](<C:/Gra - telefon/game/lib/presentation/models/adventure_progress.dart:14>), [adventure_progress.dart:31](<C:/Gra - telefon/game/lib/presentation/models/adventure_progress.dart:31>), [progress_repository.dart:1043](<C:/Gra - telefon/game/lib/data/progress_repository.dart:1043>), [level_repository.dart:10](<C:/Gra - telefon/game/lib/data/level_repository.dart:10>), [game_screen.dart:82](<C:/Gra - telefon/game/lib/presentation/screens/game_screen.dart:82>).

**Confirmed:** Menu children and the ten map nodes are eager. Progress loads 100 star entries into an immutable presentation snapshot; `completedIn` allocates a small range list. Level Preview loads/decodes level JSON, and Game Screen loads it again when opened. No parsed-level cache is present in `LevelRepository`; this does not establish repeated physical asset I/O because the bundle can cache strings.

**Assessment:** These bounded operations are unlikely first explanations for Raster-dominated recordings. There is no justification yet for isolates, a state-management rewrite, keeping every destination alive, or converting the menu to a complex lazy layout.

**Minimal improvements if UI/allocation traces justify them:** Replace the short completion-range allocation with a loop; avoid unchanged display updates as in finding 3. Parsed-level caching has ownership/invalidation implications and is outside the recommended first experiments. A lazy menu also risks changes to scrolling and state restoration; defer it unless first layout is demonstrably expensive.

## Checks that did not reveal a defect

- **Painter invalidation:** `_RoutePainter.shouldRepaint` compares width, stride, completed segments and accent ([adventure_map_path.dart:144](<C:/Gra - telefon/game/lib/presentation/widgets/adventure_map_path.dart:144>)). Node width also affects coordinates, but under the current geometry formula it is derived from the same width/scaler represented by width and stride. `_SceneryPainter` compares theme and panorama ([adventure_world_scenery.dart:300](<C:/Gra - telefon/game/lib/presentation/widgets/adventure_world_scenery.dart:300>)); `_AtmospherePainter` compares theme ([world_atmosphere.dart:199](<C:/Gra - telefon/game/lib/presentation/widgets/world_atmosphere.dart:199>)); `_HaloPainter` compares color ([game_decoration.dart:82](<C:/Gra - telefon/game/lib/presentation/widgets/game_decoration.dart:82>)). World definitions use stable constant themes. No always-true or evidently incomplete predicate was found for current inputs. Size changes can cause painting independently of these predicates.
- **Existing isolation matters:** Map route, scenery, all ten nodes and atmosphere already have explicit boundaries. `ListView.separated` adds item boundaries by default. The installed Flutter SDK also makes the menu's `SingleChildScrollView` viewport a repaint boundary, and `GameButton`'s `AnimatedOpacity` uses a boundary when its alpha is positive. Thus “add a boundary to every button” or “every press repaints the whole menu” is not supported. These SDK details were checked in [scroll_view.dart:1484](<C:/flutter/packages/flutter/lib/src/widgets/scroll_view.dart:1484>), [single_child_scroll_view.dart:429](<C:/flutter/packages/flutter/lib/src/widgets/single_child_scroll_view.dart:429>) and [proxy_box.dart:1052](<C:/flutter/packages/flutter/lib/src/rendering/proxy_box.dart:1052>).
- **No explicit offscreen/filter calls in the inspected decoration code:** No application `Canvas.saveLayer`, `BackdropFilter`, `ImageFilter.blur` or `Clip.antiAliasWithSaveLayer` was found there. Scenery uses `save`/`clipRect`/`restore`; `save` is not `saveLayer`. The destination card's rounded clips use the default antialiased clip, not the save-layer clip mode. Framework opacity, shadows, ink and route effects still need runtime inspection. Ordinary gradients/clips are not automatically performance defects.
- **No continuous decorative ticker:** Scenery and atmosphere are deterministic and static; entrance, node pulse and press animations finish. Reduced-motion checks already exist in those animations, Find Current and dialog tweens. Retain them in any future experiment.
- **Lifecycle:** Map and World Selection dispose their scroll controllers ([map_screen.dart:56](<C:/Gra - telefon/game/lib/presentation/screens/map_screen.dart:56>), [world_selection_screen.dart:161](<C:/Gra - telefon/game/lib/presentation/screens/world_selection_screen.dart:161>)); Main Menu unsubscribes from the route observer ([main_menu_screen.dart:74](<C:/Gra - telefon/game/lib/presentation/screens/main_menu_screen.dart:74>)). Async display updates generally check `mounted`. The nearby achievement-popup timer is canceled on disposal ([achievement_popup.dart:49](<C:/Gra - telefon/game/lib/presentation/widgets/achievement_popup.dart:49>)). No definite leak was found. Overlapping menu refresh futures are a bounded lifecycle concern, not proof of a leak.
- **Navigation retention:** Main Menu -> Worlds -> Map retains underlying route state as expected. Explore Worlds on the map calls `maybePop`, rather than stacking another worlds route ([map_screen.dart:264](<C:/Gra - telefon/game/lib/presentation/screens/map_screen.dart:264>)). Normal route retention and rendering-cache growth must be distinguished from leaked routes by repeated-cycle measurements.

## Physical-device DevTools verification plan

This is a future local verification plan; none of these runtime steps were performed for the audit. No additional instrumentation or build configuration was added. Internal implementations of every destination linked from the menu were not audited; investigate them separately if screen-attributed traces point there.

1. **Record the environment and state.** Use the same physical S21 FE in Profile mode with confirmed Impeller/Vulkan and 60 Hz. Record app revision, Flutter/engine version, build flavor, Android version, actual DPR/logical size, text scaling, motion settings, battery/thermal conditions and power-saving state. Keep brightness and recording method fixed. Use existing representative progress states without altering save data. Record unlocked world/current level, daily availability and any automatic dialogs; separate runs with different states.
2. **Attribute the screen before optimizing.** Capture short, labeled Performance timelines for the scenarios below. Record the start/end actions and exported timeline filename. Do not combine all navigation into one average. Keep first entry/cold work separate from warm repeated traversal. Review individual slow frames' UI and Raster bars and neighboring events; distinguish layout/build/paint recording from raster/compositing pressure.
3. **Measure repeatably.** Perform at least three warm captures per scenario with the same drag sequence and approximate duration, plus a separately labeled first-entry run. For transitions, repeat the same push/pop cycle at least ten times in each capture. Alternate baseline and one-change candidate runs and allow thermal recovery. Record frame count, UI/Raster median and p95, frames exceeding the per-thread 16.67 ms budget, worst frames and dropped-frame indicators available in the trace. Keep the supplied combined-frame metric only if its definition is known and identical. Do not inflate statistics with long idle gaps.

| Capture | Action | Main question |
| --- | --- | --- |
| Menu idle | Wait for entrance and prompts to finish, observe separately | Do frames stop when the screen is static? |
| Menu scroll | Top to bottom and back at fixed speed | Is the finite menu itself raster-heavy while moving? |
| Menu -> Worlds | Record the entry separately from later scrolling | Are entry spikes correlated with card fades or route transition? |
| Worlds scroll | Traverse all ten worlds, reverse after distant cards leave view | Are new/recreated card entrances correlated with Raster spikes? |
| Worlds -> Map | Capture Garden and later available worlds; record current-level position | Does the initial jump or first scenery use dominate? |
| Map scroll | Slow drag, repeated fling, reverse, Find Current after pulse settles | Is cost persistent, cold-only, or tied to the 420 ms scroll? |
| Map preview | Open/dismiss the same level preview, without starting gameplay | Does dialog entrance/content arrival cause the spike? |
| Return to menu | Open Shop and return without a purchase; compare with a route having only observer refresh | Do duplicate refreshes coincide with extra builds/paint? |
| Login/reward prompt | Capture separately when legitimately available | Does stacked dialog animation explain a navigation spike? |

4. **Use instrumentation separately from benchmark runs.** Where supported by the installed DevTools/runtime, enable widget-build, layout and paint tracing for one short diagnostic capture at a time. Use repaint highlighting to check the actual extent of invalidation. Inspect raster-cache/layer and offscreen-layer diagnostics where available. Some diagnostics require debug support; label such captures and never compare their timings with Profile benchmarks. Turn enhanced tracing and visual overlays off for A/B frame-time measurements. Check whether the scenery painter actually reruns, whether static card bodies repaint under transforms, and whether clipped/opacity content requires offscreen work. Absence of an exposed GPU/cache metric is an evidence limit, not a zero-cost result.
5. **Check memory independently.** Use DevTools Memory snapshots/allocation profiles before and after 10-20 complete Menu -> Worlds -> Map -> Worlds -> Menu cycles, returning to the same settled route and comparing after GC where available. Inspect retained screen/controller objects and Dart/external/RSS trends. Dart heap alone cannot establish GPU texture usage. A cache plateau is expected; sustained retained-object growth after equivalent cycles warrants leak investigation. Record first-use spikes and warm steady-state separately.
6. **Keep the visual contract.** For any subsequently authorized candidate, compare steady and intermediate states: all available world themes, locked/current/completed nodes, stars, shadow extents, route continuity, card corners, header/footer exposure, overscroll and dialog transitions. Exercise text scales 1.0/1.6/2.0 and reduced motion; use 320x568, 360x800 and 412x915 in a separate responsive verification workflow, clearly distinguished from native-device performance measurements. Confirm navigation, Back, dismissal and Find Current. Do not approve or overwrite existing Golden candidates as part of this audit.
7. **Accept only an evidenced improvement.** Require a repeatable reduction in the affected scenario's Raster p95/over-budget fraction beyond baseline run-to-run variation, without worse UI timing, visual changes, lost actions or disproportionate memory growth. For refresh coalescing, first require one effective refresh and correct balances/prompts; it may be worthwhile without solving Raster pressure. If a scenario does not reproduce the issue, retain the hypothesis and gather attribution rather than applying a speculative optimization.

## Three highest-priority changes worth testing first

1. **Isolate the stable world-card body below its animated transforms** (finding 1). This is the smallest rendering-focused experiment, preserves the existing appearance and targets work occurring during navigation and scrolling. Keep it only if tracing and Profile timings show a benefit.
2. **Coalesce duplicate main-menu return refreshes** (finding 3). This removes a confirmed source of redundant work with limited scope. Preserve all balance updates and popup sequencing; do not present it as a proven fix for Raster pressure.
3. **Segment the static map scenery into bounded paint regions if map traces confirm a large-layer/cache problem** (finding 2). Preserve global artwork coordinates and the existing nodes/path. This has greater implementation and visual risk, so perform it after the first two experiments and only with screen-specific evidence.

These are proposals only. No optimization, gameplay change, reward change or Golden-baseline change has been implemented.
