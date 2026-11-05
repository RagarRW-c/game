# Phase 4D-7A: automated Android validation

From Git Bash in `C:\Gra - telefon\game`:

```bash
bash scripts/run_level96_android_qa.sh
```

Flutter, Python and Git must be on PATH. The SDK comes from
`android/local.properties`. The default device is `RZCTA0TPGDD`; `--device SERIAL`
selects another explicitly authorized device. Keep the phone connected, unlocked
and authorized. No device security, density or system orientation settings change.

Each invocation creates a unique `qa/level96_android_qa_runs/<run-id>/` containing
`summary.json`, `report.md`, per-step raw logs and, when the driver returns,
`android_response.json`. The response holds scenario results, session snapshots,
native clipboard JSON, witness provenance and debug frame timings. Failures retain
their original errors. Missing devices and dependent scenarios after a critical
failure are NOT RUN. Independent host checks still execute when disconnected.
Reruns preserve previous evidence. Reports and disposable builds are Git ignored;
nothing is staged, committed or pushed.

## Installation and data isolation

Production `com.ragarrwc.game` and existing DEV `com.ragarrwc.game.dev` are never
replaced. Every invocation builds `com.ragarrwc.game.dev.l96qa<unique-run-id>`.
The runner rejects unsafe or installed IDs, inspects the built APK with `aapt`,
requires the exact ID and no shared UID, and checks absence again before install.
Production and DEV APK paths are compared before/after. No existing private
storage is read, cleared or restored. Only fresh QA-package SharedPreferences
are seeded and compared. Only that new application is stopped after testing;
it remains installed, with its ID recorded in the report.

Production dependencies are pinned by historical contracts. The nested
`integration_test/pubspec.yaml` and lockfile supply tooling dependencies for
analysis without editing production dependency files. A disposable project under
`.dart_tool/level96_android_qa/<run-id>/` first runs the ordinary suite against the
original dependencies, then adds the SDK integration_test dependency. Existing
locked dependency versions must remain unchanged. Only the copy's DEV suffix,
launcher label and debug manifest change. The copied debug manifest grants
INTERNET for Dart's loopback VM-service socket; the APK permission is checked.
No telemetry or network upload is added. No production Android configuration,
GameScreen, GameEngine or asset edits are needed for this phase.

Protected lib files, level assets, historical campaign evidence, production
dependency/build files and driver source are hashed before/after. Ordinary tests
run in the disposable copy so generated qa/results cannot replace historical
evidence. Golden baselines are not updated. No 360-attempt cohort is invoked.

## Real UI coverage

The test initializes integration_test and calls the actual
`main_level96_playtest.dart` entrypoint with explicit opt-in. Native audio,
SharedPreferences and clipboard plugins remain real on Android. Engine state is
observed for assertions; no direct tapTile, undo, shuffle or hint method drives
gameplay. WidgetTester pointer events traverse Flutter hit testing and gestures
on the physical phone. This does not certify the capacitive digitizer or Android's
physical finger-input pipeline; ADB is used for inspection, installation and logs.

Thirteen named checkpoints execute inside one integration test:

| Checkpoint | Assertions |
|---|---|
| startup_and_opt_in | Missing-flag/release protection; real entrypoint; rendered menu; no Flutter exception |
| select_original | Fresh 99-tile board; empty tray; original definitions |
| select_a | Fresh board and exact A swaps |
| select_b | Fresh board and exact B swaps |
| covered_and_selectable_touch | Covered-area pointer rejected; selectable tiles enter tray |
| restart | Old session aborted; new ID; full board; empty tray; zero taps |
| variant_switching | A after moves, then B and ORIGINAL; no prior state leakage |
| win_original | Complete certified 99-tap UI replay; WIN; 33 triples; empty board/tray |
| win_a | Same checks for A |
| win_b | Same checks for B |
| loss_original | Historical loss path; seven-slot tray; correct failure tap; result summary |
| android_clipboard_export | Actual Copy JSON action/native readback; exact schema; chronological traces; outcomes and timestamps |
| persistence_and_assistance_isolation | Disabled boosters; unchanged QA preferences, progression, coins and stock |

Stable existing keys identify controls and board tiles. Bounded scrolling reveals
lazy menu options, layout settles before taps, and every accepted tile ID/count
is checked. A failed witness reports variant, one-based tap, target and actual
geometry; the driver never searches for another move or silently changes paths.

Fixtures contain certified original historical winning paths and Phase 4D-3
losses, with source SHA-256 provenance. The wins were already replayed against A/B
by Phase 4D-5 contract gates. The nearest existing width category selects a path;
the actual phone geometry remains unchanged and is recorded. A successful real
UI replay establishes compatibility. Witnesses remain driver-only, never player
UI hints. Export validation uses an independent schema allowlist, excluding
device IDs and solver rankings/tokens; accepted analyst traces are intentional.

## Regression matrix and interpretation

The workflow runs 27 Phase 4D-7 tests; three long-history driver widget regressions;
15 Phase 4D-5, 13 Phase 4D-3, 12 Campaign paired and 14 Campaign validation
contracts; 11 Phase 4D-4 and 14 Phase 4D-6 Python diagnostics; 11 automation safety
contracts; and the full ordinary test/qa and test/goldens suites.

`flutter analyze --no-pub` is compared with the 81 recorded pre-existing info
findings. Any new finding fails. Exit 1 with that identical baseline is an
accepted baseline, not a clean analyzer. `git diff --check` also runs. Host test
counts exclude duplicated framework lines in Android/logcat; the 13 Android
checkpoints are counted separately from their single enclosing integration test.

Earlier device runs exposed test-tooling issues: the copied debug APK needed
loopback permission; the final tile selector needed actual T098; session-history
scrolling needed settled layout and bounded drags to materialize lazy options.
Corrections are isolated to tooling. The shared ui_driver.dart is covered by
small, actual-phone-size and tall host regressions starting with 25 old sessions,
switching B to ORIGINAL to A via real menu taps. Disabled boosters intentionally
lack an enabled hit-test target: their check sends a pointer to the transformed
rendered center, then verifies unchanged board/session/storage. Those pointer
checks also run in all three host regressions. Previous failed/aborted run
directories retain their errors and NOT RUN results.

Debug build/raster counts over 16.67 ms are diagnostic samples, not release
performance or perceived smoothness claims. Human review remains necessary for
fairness, frustration, enjoyment, readability, visual/audio quality, animation
perception and human difficulty. Certified wins do not estimate human win rate.
Phase 4D-5's REVISE recommendation is unchanged. Phase 4D-8 is not started.

## Verified device execution

Run `20261105T173553-19a0359c7cc7` completed on Samsung SM-G990B2, Android 16,
device `RZCTA0TPGDD`: 1,713 host tests PASS, 13 Android checkpoints PASS, zero
FAIL and zero NOT RUN. All 34 orchestration checks passed. Analyzer exit 1
contained exactly the 81 pre-existing infos and no new findings; diff check
passed. All 210 protected inputs matched their pre-run hashes.

ORIGINAL, A and B each won after 99 actual UI taps, clearing all board/tray tiles.
The historical ORIGINAL loss occurred at tap 7 with seven tray tiles. Native
clipboard JSON contained 11 sessions and passed independent schema/trace checks.
QA-package preferences stayed unchanged. The unique test package was stopped;
production and existing DEV installations were preserved.

Evidence is in
`qa/level96_android_qa_runs/20261105T173553-19a0359c7cc7/`:
`summary.json`, `report.md`, `android_response.json` and the original per-step
logs. Exact commands, exit codes and counts are in summary.json. Earlier failed
runs remain evidence of tooling defects, not passing executions.
