# Garden balancing pass 1

Implementation complete; local verification pending. No Flutter tests, builds,
analyzer, emulator, ADB or balance audit scripts were run for this continuation.
The existing measured campaign and Endless reports remain untouched. Their old
results certify their recorded inputs, not these edited assets.

## Scope and rationale

Only levels **1, 3, 4, 6 and 9** changed: eleven coordinate fields on nine tiles.
No tiles were added, removed, retyped, reordered or moved between layers. Level
IDs, names, objective, time metadata, pattern names and exact inventories remain
unchanged. Levels 2, 5, 7, 8, all bosses (including 10), levels 11–100 and Endless
are untouched. There are no production Dart changes.

The measured early spikes correlate with same-layer blocking and long chains,
especially at the small-screen aspect ratio. They are not evidence of human win
rates. This first pass opens useful matches without flattening the whole world,
removing the layering puzzle or chasing a target score.

| Level / shape | Exact coordinate edits | Intended benefit |
|---|---|---|
| 1 / petals | T026 y: .5008 → .4800 | Separates this apple from T029; apples T024/T026/T028 form a visible opening triple that also teaches the existing apple objective. |
| 3 / leaf | T032 x: .2567 → .2300; T034 x: .4496 → .4800 | Separates two clovers from the later suns. Adds a second visible matching option alongside the existing sun triple and breaks the T034→T035 blocking link. |
| 4 / arch | T030 x: .1692 → .1250; T031 x: .2533 → .2800 | Separates a flower from T035 and a carrot from T034. Exposes both opening triples on the small screen. |
| 6 / petals | T029 x: .4429 → .4000; T035 (x,y): (.3955,.6185) → (.4000,.6500) | Releases the moon from the right-hand tiles and separates the lower star from T026/T034. Shortens the small-screen dependency chain and exposes a leaf triple as well as the existing stars. |
| 9 / arch | T036 (x,y): (.2533,.5164) → (.2800,.5500); T037 x: .7020 → .7300 | Separates the left carrot from its blockers, releases the flower above it, and exposes the right apple. Gives a visible apple triple instead of three initial tiles with no triple. |

IDs above have the corresponding `L<level>_` prefix. No move changes a board's
outer bounding rectangle. The leaf, arch and petal arrangements retain their
existing lower layers and silhouettes. These are local spacing adjustments, not
a new layout or a bulk regeneration.

## Before / after evidence

The baseline is the supplied campaign audit measured at
**2026-10-21T09:58:57.122501Z**. A frozen copy of the five original assets and their
per-screen metrics is in `test/qa/fixtures/garden_balance_before.json`; rerunning
the main audit cannot overwrite that baseline.

Screen order below is small 320x568 / medium 360x800 / tall 412x915. The logical
board and tile sizes remain respectively 300x360 / 51.2, 340x538 / 57.6 and
392x620 / 65.92. Uniform FittedBox scaling preserves these overlap ratios.

| Level | Measured initial playable, before | Designed opening availability, after (not yet executed) | Measured chain depth, before | Measured worst-screen score, before |
|---|---|---|---|---|
| 1 | 5 / 10 / 10 | At least 6 / 10 / 10; visible apple triple | 5 / 3 / 3 | 50.13 |
| 3 | 4 / 4 / 7 | At least 6 / 6 / 7; visible clover and sun triples | 10 / 9 / 7 | 61.92 |
| 4 | 4 / 7 / 7 | At least 6 / 8 / 8; visible flower and carrot triples | 10 / 8 / 8 | 62.30 |
| 6 | 6 / 10 / 10 | At least 8 / 10 / 10; visible leaf and star triples | 11 / 5 / 5 | 62.27 |
| 9 | 3 / 6 / 6 | At least 6 / 6 / 6; visible apple triple | 16 / 12 / 12 | 67.73 |

After-chain depths and after-scores are **NOT MEASURED** here. Regression gates
require no depth increase on any geometry and a strict small-screen reduction
for levels 3 and 6. The comparison runner writes the actual before/after
availability, depth, tray pressure, scores and full witnesses to:

- `qa/garden_balance_pass_1_results.md`
- `qa/garden_balance_pass_1.json`

It uses the existing `auditBoard` implementation and records negative and
positive score deltas equally. Scores remain diagnostic; a scalar decrease is
not proof of a better player experience. UNKNOWN and UNSOLVABLE are retained in
the output and fail the focused comparison. They are never replaced with PASS.

For the broader curve, the unchanged baseline scores for levels 2/5/7/8/10 are
46.60/50.84/60.24/63.04/69.49. The original 2→3 spike was +15.31 and 5→6 was
+11.43. Re-run the full audit to obtain the revised adjacent deltas. Residual
spikes and the untouched level 8 opening should be reviewed after local results
and playtesting; this pass does not claim a calibrated human difficulty curve.

## Why booster-free solvability is preserved

The supplied reports contain successful actual-engine replays of reverse paint
order for every selected level on all three geometries. Paint order is determined
by layer, then original array index; both are unchanged. At each step in reverse
paint order the selected tile is topmost among all remaining tiles, so no later
remaining tile can cover it, regardless of the adjusted coordinates.

The type sequence is also unchanged. Each original six-tile block interleaves
two complete triples and clears before the next block. Its retained tray peak
is four (transiently five before match resolution), below the seven-slot loss
condition. Consequently the same path still clears all tiles and the tray,
without boosters, and satisfies the unchanged objective. This is a constructive
argument using paint order and the actual type sequence, not divisibility alone.
Actual engine replays of the edited boards are included in the new tests and
remain pending local execution.

Tests additionally select the advertised visible opening triples first and then
replay the remaining reverse-order path. These check that the new discoverable
matches themselves have safe continuations. Level 1 explicitly remains playing
after its apple objective is met: all remaining tiles must still be cleared.
Immediate seven-unmatched loss and all booster rules remain in the unchanged
GameEngine and existing regression suite.

## Tests and authoring compatibility

`test/qa/garden_balance_test.dart` adds 21 focused tests:

- Exact approved level scope and coordinate edits; preservation of all other
  asset fields, inventory, order, layers and objectives.
- Fifteen level/geometry cases checking actual engine availability, unchanged
  silhouette bounds, canvas containment, complete triples and blocking depth.
- Booster-free full-clearance replay of the original solution and every listed
  opening triple, with tray pressure capped at the existing peak of four.
- No early victory, no loss during the witnesses, all tiles matched, empty tray,
  and objective completion without treating it as an early win.

The existing campaign test compared assets exactly with the bulk generator.
`test/qa/support/garden_balance_expectations.dart` records the nine exact curated
tile positions, and `test/qa/campaign_test.dart` incorporates those expectations
into that same exact comparison. No levels, checks or tolerances are skipped or
relaxed. All other coordinates and all types/layers still match the original
recipe. The separate frozen baseline test also rejects unrelated asset edits.

The bulk authoring script is deliberately unchanged. **Do not run
`tool/generate_mixed_level_layouts.dart`**: it writes all 100 assets and would
overwrite this manual curation. A future generator update must explicitly adopt
the reviewed curation; it is outside this controlled data-only pass.

## Local commands

Run from the project root using the existing Flutter SDK and dependencies:

```powershell
# Focused regressions plus the existing exact campaign authoring/solver checks
flutter test --no-pub --concurrency=1 test/qa/garden_balance_test.dart test/qa/campaign_test.dart

# Frozen-before / current-after measurements for the five edited levels
flutter test --no-pub --concurrency=1 test/balance_audit/garden_comparison_test.dart

# Full balance audit; refreshes the campaign/Endless reports and audit table
flutter test --no-pub --concurrency=1 test/balance_audit/balance_audit_test.dart

# Full QA, including the new focused regression file
powershell.exe -NoProfile -File .\qa\run_qa.ps1
```

## Files changed in this pass

- `assets/levels/level_01.json`
- `assets/levels/level_03.json`
- `assets/levels/level_04.json`
- `assets/levels/level_06.json`
- `assets/levels/level_09.json`
- `test/qa/campaign_test.dart`
- `test/qa/garden_balance_test.dart` (new)
- `test/qa/support/garden_balance_expectations.dart` (new)
- `test/qa/fixtures/garden_balance_before.json` (new)
- `test/balance_audit/garden_comparison_test.dart` (new)
- `qa/GARDEN_BALANCE_PASS_1.md` (new)

Pre-existing lockfile, IDE, audit tooling and measured report changes are
preserved. No other production assets or source files were changed in this pass.
