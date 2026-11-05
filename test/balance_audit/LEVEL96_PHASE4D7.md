# Phase 4D-7 — Level 96 human playtesting

This is preparation for human review, not approval of a production level change.
Phase 4D-5 remains **REVISE** (A 6/180, B 16/180, four earlier-loss regressions).
Phase 4D-6 recommends B for targeted human review only. Neither historical run
is modified, extended or replaced by this harness. No new A/B cohort is run.

## Launch on Android

From `C:\Gra - telefon\game`, with an Android device connected and USB debugging
authorized, run:

```powershell
flutter devices
flutter run --debug --flavor dev -t lib/main_level96_playtest.dart --dart-define=FLAVOR=dev --dart-define=LEVEL96_PLAYTEST=true -d <ANDROID_DEVICE_ID>
```

Replace `<ANDROID_DEVICE_ID>` with the Android ID printed by `flutter devices`.
The existing DEV flavor uses the separate `com.ragarrwc.game.dev` application ID.
Do not change the default run target for normal gameplay. Missing opt-in throws
before binding, assets or plugin initialization. Release activation throws even
with the opt-in. This is a runtime release gate, not a promise that a release APK
cannot be compiled. `lib/main.dart` does not import any playtest implementation.

## Architecture and files

- `lib/main_level96_playtest.dart`: explicit gated entrypoint, original asset
  loading, existing portrait/edge-to-edge configuration.
- `lib/level96_playtest/session.dart`: immutable original-text pin, independent
  variant construction, real-engine recorder, session schema and serialization.
- `lib/level96_playtest/isolation.dart`: Level-96-only loader and fail-closed
  `ProgressRepository` implementation with no disk-backed parent behavior.
- `lib/level96_playtest/app.dart`: selection, fresh-session lifecycle, summary,
  clipboard export, app-local audio lifecycle and memory-only session log.
- `lib/presentation/screens/game_screen.dart` (the only modified existing source):
  optional generic `GameScreenSessionHooks`; null retains the normal Campaign
  behavior. The hooks supply an engine, title, pause/result host, assistance flag
  and raw board pointer observations. Covered-tile semantics are excluded only
  in hosted sessions. No playtest imports are added to production widgets.
- `test/balance_audit/level96_phase4d7_contract_test.dart`
- `test/balance_audit/level96_phase4d7_session_test.dart`
- `test/balance_audit/level96_phase4d7_widget_test.dart`
- `test/balance_audit/support/level96_phase4d7_test_support.dart`
- This document and `test/balance_audit/phase4d7_validation.json` record validation.

The actual `GameScreen`, `GameTileWidget`, `GameTray`, `GameTileEffects`, hit
regions, FittedBox layout and tile flights are used. `RecordedGameEngine` calls
the unchanged `GameEngine.tapTile` and `updateBoardGeometry`; it does not
reimplement matching, coverage, tray capacity or terminal rules. A 22-path
historical winning-witness test compares every move with a plain GameEngine.
These are replays of stored paths, not new policy-generated experiments.

The host replaces pause and result navigation with a playtest summary. The normal
victory reward screen, achievements, map progression and settings route are not
entered. In-game art, input and effects use the production implementation; the
playtest result dialog is deliberately different from the production reward UI.
Audio uses an app-local instance of the unchanged production audio service,
without reading or writing global player preferences. Native audio is stubbed
only in host widget tests.

## Safety boundaries and variant construction

`assets/levels/level_96.json` is pinned to FNV-1a32 `2b2b8578`; its SHA-256 is
`3d66a0895011cf1bb3e3086999e9397307eab432ea314c97ac488cea3ae2062c`.
The loader rejects changed text, then parses the original independently for every
new board. Original metadata, tile IDs, coordinates, layers, objective and all
99 tiles are retained. Only these in-memory symbol replacements are allowed:

| Variant | Replacements relative to ORIGINAL |
|---|---|
| ORIGINAL | None |
| CANDIDATE A | T094 heart → star; T095 star → heart |
| CANDIDATE B | A's two replacements; T071 banana → heart; T069 heart → banana |

All IDs above have the `L96_` prefix. B is parsed from original text, not from a
mutated A. Whole-level symbol inventory is conserved. No assets are written.

The progress adapter **implements**, rather than extends, the real repository.
Allowed balance/inventory reads return zero, match accounting is inert, and the
pending achievement list is empty. Every unrecognized repository operation
throws. No real preferences are initialized or reset by the harness. Tests seed
mock player saves and verify exact before/after equality through a real UI win
and loss. Production audio, GameEngine, tray/overlap rules, repository, Campaign
progression, Endless and Endless Battle implementations are untouched.

All three assistance controls display `Off`; callbacks are null. The recorded
engine additionally refuses hints, shuffle and undo. `assisted` is always false
and per-type usage is zero. Assisted play is not implemented; it must not be
mixed into these observations or added without a separate protocol.

## Session schema and export

`Copy all sessions as JSON` in selection, or `Copy JSON` in the session summary,
writes structured JSON to the **device clipboard**. Paste it into a local text
editor/file on the device, save as UTF-8 `.json`, then transfer explicitly by USB
or an approved manual workflow. Clipboard failure displays an error and leaves
records available for retry. Nothing is automatically saved to the host project.

Export before closing/restarting the app or hot-restarting Flutter: the log is
memory-only. The app has no upload, analytics or personal-identifier collection.
The normal app does not read these results. Do not paste analyst traces into a
viewer in front of an active tester; no traces, tile IDs or future solutions are
displayed by the playtest UI. Covered-tile accessibility labels are suppressed.

The JSON envelope contains `schema: level96-human-playtest/v1`, `audience` and
`sessions`. Each session contains:

| Fields | Meaning |
|---|---|
| `session_id`, `variant`, `original_asset_fnv1a32` | Anonymous random session identity and fixed input provenance |
| `started_utc`, `duration_ms` | UTC creation time and monotonic milliseconds from creation to terminal/abort |
| `screen_width`, `screen_height` | Logical Flutter screen size, not physical pixel resolution |
| `board_width`, `board_height`, `tile_width`, `tile_height` | Authoritative logical geometry, before FittedBox scaling |
| `geometry_history` | Geometry changes, screen size, elapsed time and next accepted tap index |
| `accepted_taps`, `rejected_taps` | Successful engine collections and unsuccessful board taps |
| `first_triple_tap`, `first_triple_ids` | First resolved triple index and analyst-only member IDs, or null |
| `max_tray_occupancy`, `max_tray_before_resolution` | Maximum after resolution and transient pre-resolution occupancy |
| `final_tray_occupancy`, `remaining_board_tiles` | Terminal/current engine state |
| `outcome`, `failure_tap` | WIN, LOSS, ABORTED; LOSS's accepted tap index; non-loss failure index is null |
| `assisted`, `booster_usage` | False and zero hint/shuffle/undo counts |
| `end_reason`, `departure`, `restart`, `abandoned` | Terminal/abort cause and later navigation action |
| `analyst_only_accepted_trace` | Ordered one-based taps: elapsed time, selected ID/visible symbol, before/after tray IDs, matched IDs, remaining count, geometry index |

An export taken during play explicitly uses `RUNNING` and a null completion
duration; exclude these snapshots from completed-outcome analysis. Terminal
metrics freeze at the engine event. Later `departure` may record restart or
selection without changing WIN/LOSS. Restarting a running session records
ABORTED with `restart=true`, then creates a new ID and fresh engine. Menu/back
abandonment also records ABORTED. Repeated exports include previous sessions;
deduplicate by session ID, using the final departure snapshot.

Rejected taps are completed, non-drag board pointer attempts that collect no
tile, including blank canvas and covered/nonselectable areas. Control buttons,
tray taps and drags are excluded. Direct engine rejections are also counted,
without double-counting their pointer event. These observations do not infer a
tester's intended tile. Concurrent multitouch is outside the primary protocol;
use single-finger taps. Duration includes pauses, background time and initial
screen loading. OS process termination cannot emit an abort or preserve records;
do not classify missing records as losses. The geometry history supports size
changes, but fixed-size sessions are required for comparisons.

## Controlled human protocol

1. Start with a new test log; select the assigned variant and start fresh.
   Confirm the active label and that all boosters say `Off`.
2. Play without hints, undo, shuffle, analyst coaching or reading replay data.
   Keep the same device, logical viewport, safe areas, text scaling and input
   method across the three variants in one comparison block.
3. Pause shows the current summary. Resume continues the same session. Restart
   records abandonment if unfinished and creates a fresh board and session ID.
4. Complete WIN/LOSS, or deliberately return to selection to record ABORTED.
   Review/export immediately. Verify accepted taps and outcome before closing.
5. Paste/export JSON, confirm it parses, and retain one final record per ID.
   Keep observer notes (confusion, frustration, perceived available moves)
   outside the game; use anonymous tester codes only in the review dataset.
6. Repeat the smoke procedure at logical 320×568, 360×800 and 412×915. Emulator
   density/size must produce these Flutter logical sizes; hardware resolution
   alone is insufficient. Record actual exported geometry. Reference top safe
   insets are 24, 24 and 32 logical pixels; bottom inset is 24 in widget checks.
   Real device insets may differ and must be reported, not silently normalized.

Counterbalance across testers using all six orders: O–A–B, O–B–A, A–O–B,
A–B–O, B–O–A, B–A–O. Allocate orders evenly within each screen group, record
order and prior Level-96 exposure, and keep instructions/rest periods consistent.
Separate first exposure from repeat sessions; do not pool them as independent
randomized boards. The board is fixed and learning can dominate later outcomes.
Do not show the specific swap map or historical winning paths during testing.

Human behavior, visual search, memory, risk preference and learning differ from
GreedyMatch/VisibleLookahead. Human outcomes are not estimates of the earlier bot
win rates, and the bot counts are not human win-rate predictions. Analyze
within-tester comparisons, order and screen effects; report sample sizes,
abandonments, uncertainty and individual critical choices. A legal alternative
does not prove a win was possible, and a loss does not prove unsolvability.

## Human acceptance criteria and limits

Before recruiting a comparison cohort, require an on-device smoke pass for every
variant and screen configuration: selectable taps and triple effects work,
covered taps do not collect, tray rules are intact, controls remain disabled,
restart/selection reset the board, WIN/LOSS/ABORTED export correctly, and real
player balances/unlocks/settings are unchanged. Check native sound, touch,
Android back behavior and clipboard paste on the device. Host widget passes
alone do not certify those device behaviors.

Balance review requires interpretable counterbalanced human evidence and explicit
review of frustrating early choices and the four historical earlier-loss cases.
No human win-rate threshold or production acceptance is inferred from the bot
uplift. Retain ORIGINAL as a comparison. A decision to change production assets
needs separate authorization after human review; Phase 4D-8 is not begun here.

## Validation

Run from the workspace:

```powershell
flutter test --no-pub test/balance_audit/level96_phase4d7_contract_test.dart test/balance_audit/level96_phase4d7_session_test.dart test/balance_audit/level96_phase4d7_widget_test.dart --concurrency=1 --reporter=expanded
flutter test --no-pub test/balance_audit/level96_phase4d5_contract_test.dart test/balance_audit/level96_shadow_contract_test.dart test/balance_audit/campaign_paired_contract_test.dart test/balance_audit/campaign_validation_contract_test.dart --concurrency=1 --reporter=expanded
python -B -m unittest discover -s test/balance_audit -p test_level96_phase4d6_diagnostic.py -v
python -B -m unittest discover -s test/balance_audit -p test_level96_post_opening.py -v
flutter analyze --no-pub
git diff --check
```

The ordinary suite command is `flutter test --no-pub test/qa test/goldens
--concurrency=1 --reporter=expanded`. Run it in a disposable project copy containing
the current `lib`, `assets`, `test/qa`, `test/goldens`, `pubspec.yaml`,
`pubspec.lock`, `.dart_tool/package_config.json`, `.dart_tool/package_graph.json`
and `.flutter-plugins-dependencies`. Its existing audit tests write `qa/results`;
isolating those writes preserves historical reports in the main workspace.
Never pass `--update-goldens`. No `balance_audit/*run_test.dart` is invoked.

Validation results and the complete per-test matrix are recorded in
`phase4d7_validation.json`. Device validation is **NOT RUN**: device inventory
listed Windows, Chrome and Edge, with no connected Android device. Human
playtesting itself has not been performed. The baseline analyzer contains 81
pre-existing informational findings; compare final findings against that baseline.

Final validation on 2026-11-05:

| Suite/check | Result |
|---|---|
| New contract / session / widget suites | 10 / 10 / 7 passed |
| Phase 4D-5 / Phase 4D-3 contracts | 15 / 13 passed |
| Campaign paired / validation contracts | 12 / 14 passed |
| Phase 4D-6 / Phase 4D-4 Python diagnostics | 14 / 11 passed |
| Full ordinary `test/qa` and `test/goldens` | 1,593 passed; no golden updates |
| Targeted analyzer: all added Dart code and GameScreen | No issues |
| Full `flutter analyze --no-pub` | 81 pre-existing infos, zero new findings; exit 1 because of existing infos |
| `git diff --check` | Passed |
| SHA-256 before/after comparison | 397 pre-existing files checked; only the intended GameScreen changed |
| Android device smoke / human comparison | NOT RUN; no connected Android device |

The initial disposable-copy launch lacked `package_graph.json`; copying that
existing local metadata resolved the setup error. The completed suite above ran
successfully afterward. An initial contract-test method-name typo was corrected
before the final passing run. No product failure remains from either issue.
