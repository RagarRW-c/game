# Triple Tile Adventure — QA report

Audit date: 2026-10-20. Scope: current working tree, including existing uncommitted changes.

**Execution status:** static data/source inspection, Dart formatting, and `dart analyze test/qa` were performed. Analysis reported **No issues found**. PowerShell runner syntax was checked without executing it. Flutter tests, solver replay, builds, emulator, ADB, installations, and screenshot capture were **not run**. Runtime outcomes below remain UNKNOWN until the local run. No gameplay, level JSON, rendering, dependency, or animation code was changed by this QA work.

## Run locally

From the project root, using the existing Flutter SDK and already resolved dependencies:

```powershell
powershell -NoProfile -File .\qa\run_qa.ps1
```

The runner executes `flutter test --no-pub --concurrency=1 --reporter=expanded test/qa`, preserves the exit code, and saves logs, input SHA-256 hashes and generated results under `qa/results/`. It does not fetch dependencies, run the layout authoring tool, build an Android application, or start a device. Host tests compile the Dart test program. If the SDK or existing package configuration is missing, the runner stops with instructions instead of installing anything. The changed lockfile currently requires Dart >=3.11.0 and Flutter >=3.41.0; SDK compatibility has not been exercised by a test run.

**Expected current failure:** QA-001 is a deliberately active regression test. A nonzero exit is expected until the gameplay owner approves and implements a fix. Other runtime failures may be discovered on the first run; none are hidden with skips or expected-failure annotations.

Generated evidence:

| File in `qa/results/` | Content |
|---|---|
| `run.log`, `run.json` | All test names, failures, process exit, timestamps and exact input hashes |
| `campaign.md`, `campaign.json` | Every level ID, issues, tile/layer counts, overlap counts, and solver outcome/witness for each screen |
| `screen_fit.json` | 300 campaign screen cases plus three actual Endless screen cases |
| `endless_validity.json` | 240 seeded boards across all themes and difficulty boundaries, each checked at three geometries |
| `endless_solver.json` | 72 sampled solver outcomes: eight rounds × three seeds × three geometries |

The runner clears only these known generated outputs before each run. Missing output after an interrupted run means UNKNOWN, never PASS. A zero process exit alone does not certify solvability: inspect UNKNOWN rows as well. This document is the delivery audit; generated results are the evidence for subsequent runs.

## Current status

PASS below means the stated static check passed, not that unexecuted Flutter tests passed.

| Check | Status | Affected level IDs | Severity | Evidence / reproduction |
|---|---|---|---|---|
| JSON syntax and expected campaign file set | PASS (static) | 1–100 | — | All 100 current JSON files parsed during the read-only audit; `campaign_test.dart` repeats this with the production parser |
| Production `LevelDefinition` and asset-bundle loading | UNKNOWN | 1–100 | Pending | Run `campaign_test.dart`; repository loads all 100 paths including `level_100.json` |
| Unique IDs, tile catalog membership, nonnegative contiguous layers | PASS (static) | 1–100 | — | 100 level IDs; 7,332 globally unique tile IDs; valid theme type keys and layer ranges |
| Tile totals and per-type inventories divisible by three | PASS (static, necessary only) | 1–100 | — | 7,332 tiles total, 30–108 per level; NOT a solvability claim |
| Objective inventory | PASS (static) | 1, 2, 12, 16, 22, 27, 33, 38, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 | — | All 20 targets have sufficient matching inventory; runtime progress/win assertions are unrun |
| Analytical tile rectangles inside inner board | PASS (static) | 1–100, all three profiles | — | Applied current board/tile clamps and allowed for the Container's 2-pixel border on each side |
| Actual screen fitting, FittedBox transform, controls and Flutter overflow | UNKNOWN | 1–100; Endless round 1 | Pending | Run `screen_fit_test.dart`; it mounts production screens and measures transformed rectangles |
| Overlap/coverage correctness during interaction | UNKNOWN | 1–100; Endless | Pending | Layer + original index defines paint order; real overlap threshold is >=3% of candidate area; engine and widget tests cover same-layer blocking and removal |
| World pattern variety | PASS (static structural check) | 1–100 | — | Six pattern families in each ten-level world; automated checks also require distinct coordinate signatures |
| Boss definitions | PASS (static) | 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 | — | Ten private `_BossLevelInfo` definitions and dedicated world boss patterns; automated source contract and rendered title checks are unrun |
| Seventh-slot loss timing | FAIL (source finding QA-001; test unrun) | Shared engine: 1–100 and Endless | High / P1 | `game_engine_test.dart`, test name containing `QA-001` |
| Matching, Undo, Shuffle, Hint, terminal states and board-clear win | UNKNOWN | Shared engine: 1–100 and Endless | Pending | Run `game_engine_test.dart` and `tile_widget_test.dart` |
| Campaign solvability | UNKNOWN | 1–100 × three geometries | Pending | Run `campaign_test.dart`; see individual SOLVED / UNSOLVABLE / UNKNOWN results and witness IDs |
| Endless board validity / solvability samples | UNKNOWN | Endless rounds 1, 3, 4, 7, 8, 12, 13, 100; seeds 0, 1, 42 | Pending | Run `endless_test.dart`; finite seeded sample coverage, not a guarantee for every random board |
| Emulator screenshots and visual quality | UNKNOWN — not performed | 1–100; Endless | Pending | No screenshots or golden images were captured or compared |

Static world inventory:

| World | Level IDs | Tile range | Layer count | Pattern families |
|---|---|---|---|---|
| Garden | 1–10 | 30–54 | 3 | 6 |
| Ocean | 11–20 | 42–66 | 4 | 6 |
| Candy | 21–30 | 54–78 | 5 | 6 |
| Space | 31–40 | 72–90 | 6 | 6 |
| Desert | 41–50 | 60–78 | 4–5 | 6 |
| Ice | 51–60 | 66–84 | 4–5 | 6 |
| Jungle | 61–70 | 72–90 | 5–6 | 6 |
| Volcano | 71–80 | 78–96 | 5–6 | 6 |
| Dream | 81–90 | 84–102 | 6–7 | 6 |
| Crystal | 91–100 | 90–108 | 6–7 | 6 |

## Findings and reproduction

### QA-001 — Full tray waits for an additional tap before Game Over

Status: **FAIL by source inspection; regression execution pending**. Severity: **High / P1**. Affected IDs: **1–100 and all Endless rounds**, through the shared engine; reachability of a particular losing sequence in each asset is not claimed.

`lib/domain/game_engine.dart:308` checks `tray.length > trayLimit` after matching. A seventh non-matching tile leaves exactly seven IDs and therefore leaves `result` as `playing`. The pre-tap guard at line 121 rejects the following tile and only then sets `lost`.

Reproduce with the test named `QA-001 seventh non-matching tile triggers Game Over immediately` in `test/qa/game_engine_test.dart`. Its valid inventory contains three copies each of seven types on separate uncovered positions. Select one of each type: after tap six, expect playing; after tap seven, expect lost. Current code predicts playing at step seven. The separate seventh-slot-match test verifies that a triple resolves before checking loss. No engine fix was made.

Focused local reproduction:

```powershell
flutter test --no-pub test/qa/game_engine_test.dart --plain-name "QA-001 seventh non-matching tile triggers Game Over immediately"
```

### QA-002 — Hint can end a run when its batch does not fit

Status: **UNKNOWN desired product behavior; current source behavior identified**. Severity: **Medium / P2 review item**. Affected IDs: shared engine, potentially **1–100 and Endless**, when the tray/board state permits this condition.

With five unrelated tray entries and three exposed matching tiles, Hint finds a triple, but `collectHintTileIds` checks `5 + 3 > 7`, returns false, and sets `lost` before collecting anything (`lib/domain/game_engine.dart:261`). Both screens handle that as Game Over. Paid/inventory booster charging occurs before collection in both screens and is outside the current engine test scope. Whether capacity rejection should end a run is a product decision, so this is not asserted as an approved behavior change. The test `Hint respects the current batch capacity rule without tray overflow` reproduces and characterizes the present engine rule. Positive Hint tests cover tray completion, exposed-triple collection and duplicate ID handling. No gameplay change was made.

## Audit of existing changes

- Reviewed the existing diffs in `game_screen.dart`, `endless_screen.dart`, `game_tile.dart`, `generate_mixed_level_layouts.dart`, all campaign assets, and `pubspec.lock`, plus the untracked `board_layout.dart`.
- Read-only comparison of all 100 current assets against HEAD confirmed unchanged level/name/time/objective metadata, tile ID sets, tile counts and per-type inventories. Positions, type assignments to individual IDs, layer assignments and `layoutPattern` metadata changed.
- The generator now authors all 100 assets using `BoardLayouts`; it retains inventories and assigns a planned type sequence in reverse paint order. It is a writing tool and is never invoked by QA. Tests call only pure composition/order helpers and compare the results to assets.
- Both screens now cap board width at 440 logical pixels and wrap the decorated board in `FittedBox(fit: BoxFit.scaleDown)`. This requires checking unscaled engine geometry and transformed screen rectangles separately.
- Tile changes affect opacity, color, borders and shadows. Widget checks do not certify appearance, shadow clipping, rounded-corner hit behavior, readability or artistic world variety.
- The dependency lockfile updates are pre-existing. No new package or development dependency was added. Existing `.idea/` files were left untouched.

Actual schema: required `level` (int), `name` (String), `timeBonusSeconds` (int), `tiles` (list of `id`, `type`, numeric `x`/`y`, int `layer`); optional `objective` (`type`, `target`). Current assets also contain `layoutPattern`, consumed by QA/authoring and ignored by `LevelDefinition`. Boss metadata lives in the gameplay screen, not in a JSON boss object. Tile state is initialized to `board` by the parser. Coordinates are normalized tile **origins**, not centers.

## Geometry and solver contract

| Profile | Viewport, logical pixels | Safe top | Campaign board / tile side | Endless board / tile side |
|---|---|---|---|---|
| Small | 320 × 568 | 24 | 300 × 360 / 51.2 | 300 × 330 / 51.2 |
| Medium | 360 × 800 | 24 | 340 × 538 / 57.6 | 340 × 490 / 57.6 |
| Tall | 412 × 915 | 32 | 392 × 620 / 65.92 | 392 × 597 / 65.92 |

Widget tests use a 24-pixel bottom inset, normal text scale and device pixel ratio 1. They mount the production GameScreen for every level and the production EndlessScreen at round one. Preferences use an in-memory mock and audio uses an implementation that never constructs native players. They inspect real board bounds, FittedBox transforms, Positioned coordinates, tile sizes, paint order, blocked/enabled/IgnorePointer agreement, seven tray slots, booster labels and boss headers. The screen geometry helper is a QA mirror of private formulas; widget comparisons detect drift. These are layout and widget interaction tests, not screenshot tests. Larger fonts, landscape, tablets, other insets and device rendering remain outside this initial suite.

The solver uses production paint order and `Tile.overlaps`, including same-layer overlaps and the >=3% threshold. It first tries reverse paint order and accepts it only after replaying every tap through the real `GameEngine`. If that fails, bounded depth-first search uses precomputed blocker masks, tray type counts modulo three, immediate matching, a seven-slot capacity and memoization. BigInt masks support the 108-tile campaign maximum without 64-bit truncation.

- **SOLVED:** complete witness replayed through the engine, all board tiles matched, empty board/tray and objective complete. Witness tile IDs are saved in JSON.
- **UNSOLVABLE:** impossible full-triple/objective inventory, or exhaustive search with no successful path. Scope is a fresh board, specified geometry and ordinary tile taps with no boosters.
- **UNKNOWN:** invalid input, witness disagreement, or search node/time cutoff. It is never relabeled UNSOLVABLE. The limits apply to search; witness replay/preprocessing add overhead.

Campaign search limits are 50,000 states / 500 ms per geometry; sampled Endless limits are 10,000 / 200 ms. Timeout outcomes may differ by machine. Search models the current engine's inability to accept an eighth tile; the delayed loss notification at exactly seven does not add a successful tap-only path. Solver tests include a divisible but forced-unsolvable stack, node/time cutoffs, alternative-order search, a >64-tile search and an independent exhaustive engine-transition oracle on small fixtures. None of these tests has been executed in this delivery.

## Optional visual automation proposal

A separate, user-run `integration_test` harness could replay saved solver witness IDs on an emulator and capture initial boards, uncovering, a triple, Undo, Shuffle, Hint, seven-slot loss and victory at the three profiles. Save level ID, viewport, device pixel ratio, seed, input hashes and screenshots together; use fixed seeds/preferences and stable fonts for baseline comparisons. Cover every campaign initial board, each boss and representative seeded Endless difficulty boundaries. Real taps should also verify that covered tiles do not respond and exposed tiles enter the tray.

This is a proposal only: no integration dependency, emulator action, screenshot, visual baseline, flying animation or OverlayEntry was added. Screenshot evidence and human appearance review remain UNKNOWN.
