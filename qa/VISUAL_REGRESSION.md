# Visual regression testing

The golden suite protects production widgets with Flutter's built-in
`matchesGoldenFile` and the default, exact pixel comparator. It adds no packages.
The owner reports that the golden suite passes after the audio-fixture repair.
Manual review nevertheless found two visual defects in the 320x568 / 2.0
achievement and boss-victory candidates. The layout repairs described below
have **not been verified by running tests**; no tests, analysis, builds or
baseline generation were run while making them. Existing PNGs remain unchanged,
unapproved candidates. Passing a comparison only confirms matching pixels,
not correct composition, readable content or human design approval.
The Samsung Galaxy S21 FE review remains the design reference; host-rendered
goldens are a separate regression reference, not screenshots of that device.

## Files and responsibilities

```text
test/goldens/
  navigation_golden_test.dart     home, world selection, adventure map
  gameplay_golden_test.dart       real campaign and seeded Endless screens
  results_golden_test.dart        victory, Game Over, achievement content
  secondary_golden_test.dart      settings, pause, shop, daily, wheel, chests
  support/
    golden_harness.dart           fonts, viewport, capture, settling, cleanup
    golden_fixtures.dart          isolated progress, levels, chest/time fixtures
  baselines/windows/
    README.md                    candidate/review policy
    flutter-version.txt          record locally when generating candidates
    <scene>_<width>x<height>_text<scale>.png
    failures/                    generated diffs, ignored by Git
```

The existing `lib/presentation/screens/endless_screen.dart` test seam:
`EndlessScreen.forTesting` accepts a generator and starting round. The ordinary
constructor still starts round 1 with the ordinary random generator. No engine,
generator, progression, economy, purchase, save, flavor or animation rules were
changed. The later-round fixture starts a fresh run at round 14; score and boards
cleared start at zero. It is a presentation scenario, not a simulated run history.

## Coverage matrix

There are 29 widget test cases and 36 intended PNGs, rather than the full product
of every screen, size and text scale. All dimensions are logical Flutter pixels.
Device pixel ratio is explicitly 1, so PNG dimensions equal the viewport.
Every case uses top and bottom safe areas of 24 pixels, Android target platform,
light appearance, English locale, production flavor and explicit text scaling.

| Scene | 360x800 / 1.0 (main baselines) | Additional baselines |
| --- | --- | --- |
| Main menu | Initial home and scrolled navigation kit; 1250 coins | Initial home at 320x568 and 412x915; primary Adventure/Endless actions at 320x568 / 2.0 |
| World selection | Reached through the real Adventure button; Garden progress and locked worlds | — |
| Adventure map | Level 5 current, earlier levels completed with stars, following levels locked; separate scroll to locked level 10 boss | Current-level view at 320x568 and 412x915 |
| Campaign | Real level 7, level 10 boss, level 7 after one specified legal tile selection | Level 7 at 320x568 |
| Endless | Seed 73129, rounds 1 and 14, bottom/top seven-slot trays and booster controls | Round 1 at 320x568; round 14 at 412x915 |
| Victory | Garden boss, 3 stars, +350 coins, +300 XP, Gold Chest; additional scrolled reward view | 320x568 / 2.0 initial description and separate scrolled secondary actions, with Next Level pinned |
| Game Over | Production dialog on a themed host | 320x568 / 1.0 and 360x800 / 1.6 (Restart scrolled into view) |
| Achievement | Production Complete Garden World popup content and 300-coin reward | 320x568 / 2.0 initial heading and separate reward view, with the full trophy visible in both |
| Settings / Shop | Initial viewport of each | — |
| Pause | Actual pause button opens the production dialog | — |
| Daily Challenges | Fixed date, claimable/partial/claimed entries; second view at Daily Bonus | — |
| Lucky Wheel | Available, idle wheel with all reward sectors | — |
| Treasure Chests | Ready wood chest, silver chest with fixed countdown, empty slot; separate opened-chest reward | — |

Main-menu progress is represented on world selection and the map, where the
production UI actually displays it. Screens are captured at their real scroll
positions; these are viewport screenshots, not stitched full-page images.
At large text scales scrollable artwork may be offscreen while actions remain
visible. Existing responsive QA continues to check all supported size/scale
combinations and individual action reachability.

## Small-screen result layout repairs

The two actual candidate PNGs were inspected before editing production widgets.
The harness uses the requested viewport, DPR 1, text scale 2 and a full-screen
RepaintBoundary; it does not crop or resize these results incorrectly.

- **Achievement:** the fixed 160-pixel trophy originally lived in the same
  scroll content as the heading, achievement name and coin badge, below a
  fixed Close row. The golden deliberately scrolls to the reward. This moved
  the upper half of the trophy above the scroll clip and left a cut-off medal
  under the fixed row, exactly as a user could see by scrolling. Production now
  reserves separate header columns for decoration, the full trophy and Close.
  The trophy stays outside the scroll clip and scales uniformly to 104 pixels
  on short screens or with enlarged text (160 otherwise). Text remains scaled
  and scrollable, and the large coin badge is unchanged. This also leaves room
  for the three-line Garden World name and reward in the small-phone reward view.
- **Victory:** all three navigation buttons were pinned below an Expanded
  content scroll. At 320x568 / 2.0 their scaled heights left too little content
  height, so the initial scroll clip cut through `Garden Boss defeated`. The
  six-pixel gap also let the next button's shadow visually crowd that edge.
  Production now keeps Next Level pinned, but puts Replay and Back to Map at
  the end of the scroll when available height divided by text scale is below
  400 logical pixels. Otherwise all three remain pinned. A 20-pixel gap separates
  the scroll clip from the primary action. All callbacks, rewards, stars and
  world-completion copy are preserved.

`test/qa/support/result_layout.dart` supplies shared geometry assertions to the
existing result QA and goldens. Achievement QA checks transformed medal/glyph
bounds and a fixed, collision-free trophy before and after scrolling, including
long names and the full reward badge. Victory QA adds all three sizes, all three
text scales, boss/final variants and both motion settings, checking full
paragraph visibility after scrolling, real scroll gestures, action reachability,
button-label containment and unchanged callbacks. Existing assertions remain.

The golden harness itself is unchanged: no viewport changes, masking, looser
comparison, disabled assertions or altered scroll target. Result cases now
assert artwork geometry and the initial boss-description visibility before
capture. Two supplementary views protect the achievement header and scrolled
victory navigation; the original affected captures remain in the suite.

Local validation and deliberate candidate regeneration (Windows Git Bash):

```bash
cd '/c/Gra - telefon/game'
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/qa/achievement_popup_test.dart test/qa/victory_screen_test.dart

# Preserve the current unapproved candidates before replacing result images.
mkdir -p qa/results
candidate_backup="$(mktemp -d qa/results/golden-candidates-before-layout-fix.XXXXXX)"
cp -a test/goldens/baselines/windows/. "$candidate_backup/"
GOLDEN_REVIEW=candidate flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod --update-goldens test/goldens/results_golden_test.dart

# After human review of every regenerated result image and both new views:
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/goldens/
```

Review the two original defective images against their replacements, then check
normal-scale result composition as well. The trophy must be whole in both
achievement views. The boss description must be whole in the initial victory
view, with clear separation from Next Level, and secondary navigation must be
fully visible after scrolling. Do not approve based only on a green test run.

## Determinism and capture contract

- `GoldenLevels` follows the existing QA approach: it parses the actual campaign
  JSON synchronously into fresh objects. Level changes therefore affect goldens.
- Each Endless scenario receives a new `Random(73129)` generator; generation
  changes are visible regressions, never silently accepted.
- Each test resets `SharedPreferences` to an in-memory empty store. The progress
  fixture supplies fixed coins, stars, availability and challenges. No personal
  saves, real purchases, advertisements, network services or native audio are
  started. `GoldenAudio` explicitly implements every public audio property and
  method, without a `noSuchMethod` fallback. `musicEnabled` and `sfxEnabled`
  start as `true`, matching default preferences and keeping feedback dispatch
  exercised. Property assignments and `setMusicEnabled` change only local
  in-memory settings; all playback, lifecycle and disposal methods are silent
  no-ops. Future interface additions must be implemented at compile time.
- Daily repository methods ignore their real-time argument and return fixed
  state. The chest fixture overrides `remaining` and `isUnlocked`, so even a
  periodic screen rebuild displays exactly `1 h 23 min`. Opening the ready chest
  returns a fixed 75 coins, 1 Undo and 1 Shuffle through the production dialog.
- Result cases mount actual production widgets over `GameBackground` through
  real dialog routes, without replaying gameplay to obtain a result.
  The achievement case mounts the actual `AchievementRewardDialog` through a
  real dialog route. The three-second auto-dismiss wrapper is intentionally
  excluded; existing achievement QA covers its lifecycle.
- Reduced motion is enabled only through the harness's `MediaQuery`. Finite
  transitions settle at 50 ms fake-time intervals, with a three-second timeout.
  There are no real-time sleeps. A newly introduced infinite animation fails
  this bounded settle and must be handled explicitly in the harness; never just
  increase the timeout or capture a random frame. Tickers are not frozen at
  frame zero. Production animation behavior is unchanged.
- A keyed `RepaintBoundary` sits above the Navigator. Captures include actual
  dialog routes, scrims, backgrounds and shadows. Loading indicators, framework
  exceptions, missing boundaries and unexpected dimensions fail before capture.
- Cleanup runs in `goldenTest`'s `finally`, **before** Flutter checks invariants:
  unmount screens/routes, dispose periodic timers, restore debug flags/view size,
  reset mocked preferences and clear the image cache, even when comparison fails.
  No custom comparator or pixel-difference tolerance is installed.

## Fonts, assets and Windows rendering

The harness loads Roboto regular, light, medium, bold, black and italic, plus
MaterialIcons, explicitly using `FontLoader` before tests. It resolves the
installed Flutter SDK through `.dart_tool/package_config.json` and reads its
`bin/cache/artifacts/material_fonts` directory. A missing file is a hard failure;
there is no fallback to the widget-test Ahem font or an automatic download.
Keep the exact SDK/framework/engine revision used to review the PNGs.

Current screens use vector painters and Material icons rather than raster image
assets. Level assets are loaded through the fixture repository. If a future UI
adds raster images, explicitly `precacheImage` the exact providers from a mounted
context and await completion before capture; add loading/error assertions.
Do not use arbitrary delays as a substitute for waiting on asset decoding.

These are **Windows host** baselines using Android widget conventions. They are
not Android GPU captures. Text rasterization, synthetic/intermediate font
weights, missing glyph fallback, shadows and engine changes can differ between
Windows, Linux, macOS and physical Android devices. Do not compare or update these
PNGs from another OS. The suite fails clearly on non-Windows hosts, rather than
skipping silently. Continue device QA for system bars, gestures, physical pixel
ratios and actual device font rendering. If another OS needs goldens, introduce
an explicitly reviewed platform directory and workflow; do not loosen tolerance.

## Exact Windows Git Bash commands

Use the existing Flutter installation and resolved dependencies. Commands use
`--no-pub`; resolve dependencies separately if `.dart_tool/package_config.json`
is missing. Run from this project root, with no emulator or ADB needed.

### First-time candidate generation (manual, not approval)

```bash
cd '/c/Gra - telefon/game'
git status --short
mkdir -p test/goldens/baselines/windows
flutter --version > test/goldens/baselines/windows/flutter-version.txt
GOLDEN_REVIEW=candidate flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod --update-goldens test/goldens
git status --short -- test/goldens
```

Review **all 36 PNGs**, including scrolled states and accessible text variants.
Confirm real Roboto text and icons, expected data, all seven tray slots, controls,
map states, rewards, spacing, shadows and no loading/error screens. Compare with
the approved design. If a fixture/assertion fails, correct its cause before
accepting any candidates; a failed generation can leave partial output.

Record the Windows version alongside the Flutter version in `flutter-version.txt`.
Reviewers should also record SDK font hashes if sharing baselines across machines.
After review, stage only explicitly approved PNGs, source changes and the version
record. A green update run means candidate images were written, not approved.

### Completing a generation that previously failed

Keep the existing candidates; their presence, or even a count of 34 PNGs, does
not establish that the complete suite passed. No existing PNG was changed or
approved by the audio repair. Before rerunning generation, optionally preserve
the current set in an ignored, separate directory for comparison:

```bash
cd '/c/Gra - telefon/game'
mkdir -p qa/results
candidate_backup="$(mktemp -d qa/results/golden-candidates-before-audio-fix.XXXXXX)"
cp -a test/goldens/baselines/windows/. "$candidate_backup/"
GOLDEN_REVIEW=candidate flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod --update-goldens test/goldens/
```

Rerun the **whole suite**, without a test-name filter, to regenerate all expected
states from the repaired fixture. This manual command overwrites the candidate
PNGs in place; it does not approve them. Require all 29 tests to pass, review all
36 expected PNGs (including the campaign occupied-tray state), compare changes
with the preserved candidates and approved design, then run ordinary verification
below without `--update-goldens`. Stage only deliberately reviewed files.

### Ordinary golden verification (never writes baselines)

```bash
cd '/c/Gra - telefon/game'
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/goldens
```

Run this again after initial review, and once more in a fresh process to check
repeatability. Missing PNGs and unexpected pixel changes must fail. A CI check
must run this verification command only, without the update flag or
`GOLDEN_REVIEW`. Do not add update-and-retry behavior to CI.

### Full existing QA and static analysis (separate checks)

```bash
cd '/c/Gra - telefon/game'
# Existing runner, with its manifests and reports in qa/results:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File qa/run_qa.ps1
# Additional existing balance-audit suites, outside test/qa:
flutter test --no-pub --concurrency=1 test/balance_audit
# Static analysis, including the new golden helpers and cases:
flutter analyze --no-pub
```

The existing QA runner and all existing assertions remain unchanged. Goldens
supplement gameplay-engine, campaign/Endless solvability, navigation, purchase,
reward/economy, animation and overflow checks. They do not replace those tests.
Some existing balance audits write their own tracked report files; inspect the
working tree afterward and keep report changes separate from baseline review.
After initial baselines are approved, `flutter test --no-pub --concurrency=1`
also discovers the golden suite, so it requires the same Windows environment.

### Reviewing failures and intentional updates

1. Run ordinary verification first. Read assertion errors before inspecting PNGs.
2. On a pixel mismatch, Flutter reports the `failures/` directory beneath the
   golden key path (normally `test/goldens/baselines/windows/failures/`). Compare
   `_masterImage.png`, `_testImage.png`, `_isolatedDiff.png` and `_maskedDiff.png`.
   Missing baselines may produce an error without a full diff set.
3. Establish whether this is an unintended UI change, fixture drift, font/SDK
   change or an intentional approved design change. Fix regressions in code.
4. Only for an intentional change, regenerate the smallest relevant test set.
   For example, to update just the initial small-phone menu:

```bash
GOLDEN_REVIEW=candidate flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod --update-goldens test/goldens/navigation_golden_test.dart --plain-name 'golden home 320x568_text1.0'
git diff --stat -- test/goldens/baselines/windows
git status --short -- test/goldens/baselines/windows
flutter test --no-pub --concurrency=1 --dart-define=FLAVOR=prod test/goldens
```

5. Review every changed PNG and state why the design changed in the PR. For an
   SDK upgrade, review all affected fonts/rendering and update the version record.
   Check `git diff --cached --name-only` before committing; never stage failures,
   temporary screenshots, logs or unreviewed PNGs. `.gitignore` excludes golden
   failure directories, while baseline PNGs remain trackable. Logs and reports
   belong under the existing ignored `qa/results/` directory.

Accidental approval has two barriers: normal verification cannot update files,
and `--update-goldens` additionally requires the command-scoped
`GOLDEN_REVIEW=candidate`. This flag only permits writing candidates; human image
review and deliberate staging remain necessary. Do not export it permanently,
configure it in CI or automatically commit generated files.

## Adding a screen

1. Choose the actual production widget and a meaningful state not already covered.
2. Add deterministic repository/model fixtures in `golden_fixtures.dart`; avoid
   wall-clock or unseeded randomness and never reproduce UI in test-only widgets.
3. Call `configureGoldens()` once in the test file. Register with `goldenTest`,
   then use `pumpGolden`, explicit interactions/scrolls and `expectGolden`.
   Use a unique scene name; keep golden test files directly in `test/goldens/`
   because `matchesGoldenFile` resolves paths relative to the test file.
4. Assert that the intended state is present before taking a baseline. Use
   `goldenGlobalRect` for transformed board geometry, not unscaled local sizes.
5. Start with 360x800 / 1.0. Add a small-screen or large-text view only when it
   guards distinct behavior; update the matrix and PNG count in this document.
6. Generate candidates explicitly, review them, then run ordinary verification
   and existing relevant QA. Preserve every existing functional assertion.

## Known coverage limits

- Existing PNGs are candidates, not approved baselines. The owner reports that
  the audio repair passes, but the result-layout repairs still require local
  tests, regeneration and human review. Do not report these repairs as verified.
- Only representative campaign/world themes and Endless rounds are pictured.
  High-round difficulty and solvability remain engine QA responsibilities.
- Lucky Wheel is captured idle; random spins/reward outcomes are not exercised.
  The deterministic chest and victory scenes cover reward presentation.
- Achievement screenshots cover production content rather than auto-dismiss
  timing; result callbacks are inert. Pause and chest dialogs use real entry
  actions. Existing tests continue to verify navigation and reward semantics.
- This matrix does not cover every offscreen card, every animation frame, shop
  purchase confirmation, login-streak prompt, disabled recovery variant or the
  private Endless result dialog. Keep their functional QA and extend goldens
  when a concrete visual risk warrants another representative state.
