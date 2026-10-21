# Endless progression — focused balance refinement

Refinement implemented; local verification pending. Codex did not run Flutter
tests, builds, analysis, emulator or ADB. The locally measured first-pass
`endless_progression_results.json` and `.md` remain unchanged.

## Evidence and scope

The completed `BALANCE_AUDIT.md` and `balance_endless.json` show that rounds
13, 30 and 100 have identical structural metrics for the same fresh seed.
For Garden seed 0 all three contain 57 tiles, 11 types and six layers:

| Screen | Available initially | Longest blocking chain | Same-layer blocking edges | Maximum rectangle depth | Retained tray peak |
|---|---:|---:|---:|---:|---:|
| 320x568 | 6 | 15 | 38 | 9 | 6 |
| 360x800 | 10 | 10 | 30 | 8 | 6 |
| 412x915 | 10 | 9 | 29 | 8 | 6 |

The old positional jitter and translation grow with layer index and then clamp
at the edges. These piles create long dependencies, including within a layer.
The first progression pass removed those piles but exposed too many independent
choices. Measured fresh Garden seed 0 on 320x568:

| Round | First-pass tiles | Types | Initially playable | Chain | Retained tray peak | Heuristic score |
|---|---:|---:|---:|---:|---:|---:|
| 13 | 57 | 11 | 6 | 15 | 6 | 76.45 |
| 14 | 54 | 6 | 16 | 4 | 6 | 54.97 |
| 20 | 60 | 8 | 16 | 5 | 6 | 59.31 |
| 21 recovery | 42 | 6 | 16 | 4 | 4 | 43.93 |
| 30 | 66 | 10 | 12 | 5 | 6 | 63.73 |
| 50 | 72 | 12 | 16 | 5 | 6 | 65.27 |
| 75 / 100 | 72 | 14 | 10 | 6 | 6 | 70.47 |

These numbers are observations of the first pass, not targets for a score
optimizer. The abrupt type drop, 16 exposed choices, and short dependencies
explain the round-14 change in decisions. Recovery rounds also removed too much
workload and tray planning at once. The refined generator restores neighboring
**cross-layer** dependencies and narrows these jumps while retaining readable
same-layer spacing.

## Difficulty rhythm

Rounds 1–13 keep the exact previous algorithm, random consumption, inventory,
coordinates and type assignment. This includes repaired Garden rounds 8 and 12.

The following are **standard-round** contracts:

| Rounds | Tiles | Layers | Distinct types | Top-layer tiles | Four-type batches per 12 batches |
|---|---|---|---:|---:|---:|
| 14–24 | 54–60 | 5 | 9 | 10 | 4 |
| 25–49 | 60–66 | 5 | 10 | 9 | 6 |
| 50–74 | 66–72 | 5–6 | 11 | 8 | 9 |
| 75 onward | 66–72 | 6 | 12 | 8 | 12 |

- Every fifth round after 13 is a challenge (15, 20, 25, 30, ...): the stage's
  maximum tile/layer counts, two extra types, six top tiles, four-type batches.
- Rounds ending in 1 after 13 (21, 31, 41, ...) are recovery. Their stage caps
  are 48–54, 54–60, 60–66 and 60–66 tiles; they have 4, 4, 5 and 5 layers,
  8, 9, 10 and 11 types, twelve top tiles and three-type batches. They remain
  easier than the corresponding standard/challenge rounds without resetting
  every late run to the same 42-tile, four-slot-tray profile.
- Other standard batches use three types. Four-type batches become more frequent
  across stages instead of raising the safe tray peak above six.
- Every selected type occurs at least once as a complete triple. Remaining
  triples vary their multiplicities using the seeded RNG.
- Terraces, vertical weave and cross-offset layouts rotate, including across
  consecutive challenges. Seeded slot order, holes, mirroring and paint order
  provide additional variation. Standard offsets grow from .018 to .028;
  recovery uses .016. Each entire layer shares its offset. No accumulating
  jitter or edge clamping.
- Beyond round 75, difficulty stays capped. The rhythm and layout variations
  continue rather than making boards indefinitely larger or less readable.

Round 14 now uses nine types and five layers. Its shorter chains remain a
readability improvement over round 13's 15-tile small-screen chain, while the
cross-layer links and narrower type transition ask for more planning than the
first-pass round 14. Human difficulty remains a playtest hypothesis; the audit
score is not a required monotonically rising curve.

## Screen and blocking guarantees

Each layer occupies unique cells of a 4x4 grid. Adjacent columns are .190 apart;
rows are .180 apart. Every tile in one layer has the same offset, so neither
adjacent row nor column tiles intersect. On the 320x568 logical board, tile width
is 51.2/300 ≈ .1707 and height is 51.2/330 ≈ .1552, both smaller than those
spacings. Opposite layer offsets differ by .032–.056; adjacent cells can then
block each other across layers. This creates more ordering decisions without
same-layer piles. The regression suite checks actual cross-cell blocking on the
small screen and exact overlap/coverage agreement on all three geometries.

Origins stay inside x=.047–.718 and y=.072–.668. Including tile dimensions,
the maximum small-screen right/bottom extents are approximately .889 and .823
of the logical board. Medium and tall screens also fit. The existing uniform
FittedBox scale preserves relative rectangles and coverage.

Consequently, a blocking chain and coincident rectangle depth cannot exceed the
number of layers (at most six). Every top-layer tile is selectable, guaranteeing
at least six opening choices on challenges, eight or more on standards, and
twelve on recovery rounds. Cross-cell links can now cover some lower cells that
previously supplied an automatic extra choice. Lower exposed tiles can still
provide useful alternatives.
These bounds apply to the later generator, not the deliberately unchanged early
boards. Actual engine replay and rectangle assertions are included in QA.

## Booster-free solvability proof

1. Use `GameEngine.renderedBoardTiles` and reverse its exact paint order,
   including the original-index tie break within a layer.
2. At every step the last remaining painted tile is uncovered. The engine only
   treats later painted tiles as blockers, including same-layer blockers.
3. Assign complete batches along this removal order using the existing
   `clearableTileOrder` construction:
   - Two types: ABABAB; retained tray peak at most 4 (short final batch only).
   - Three types: ABCABACBC; peak at most 5.
   - Four types: ABCDABACDBCD; peak at most 6.
4. Each batch ends with an empty tray. Repeated type labels can only reduce
   pressure. At a transient seventh slot the arriving tile completes a triple;
   matching resolves before the existing immediate-loss check.
5. Every generated tile belongs to one complete batch, so the witness clears
   both board and tray. There are no boosters, purchases, delays or engine changes.

This proves a legal initial-board solution for every seed, independently of
geometry. It does not promise recovery after arbitrary mistakes. The tests also
replay the witness through the actual engine on all three geometries; zero search
nodes are allowed in the new proof checks. UNKNOWN and UNSOLVABLE both fail.

## Before/after comparison

The following compare the **original measured baseline**, the **measured first
pass**, and the **refined construction contract**. Refined measurements remain
pending your local run. Fresh Garden seed 0, 320x568:

| Case | Original measured | First pass measured | Refined contract |
|---|---|---|---|
| Round 13 | 57 tiles, 11 types, 6 layers | Same | Exactly unchanged |
| Round 14 | 57 tiles, 11 types, 6 layers | 54 tiles, 6 types, 4 layers | 54–60 tiles, 9 types, 5 layers |
| Round 30 challenge | 57 tiles, 11 types, 6 layers | 66 tiles, 10 types, 5 layers | 66 tiles, 12 types, 5 layers |
| Round 100 challenge | 57 tiles, 11 types, 6 layers | 72 tiles, 14 types, 6 layers | 72 tiles, 14 types, 6 layers |
| Small-screen chain, round 14 | 15 | 4 | At most 5; actual depth pending |
| Same-layer blocking edges, round 14 | 38 | 0 | 0; cross-layer neighbor links added |
| Retained tray peak, recovery | No recovery | 4 | 5 |
| Recovery workload | 54–72 tiles | 42–48 tiles | 48–66 tiles by stage |

`endless_comparison_test.dart` measures the original and refined versions with the existing
`auditBoard` implementation: opening choices, chains, edges, rectangle depth,
tile/type distributions, actual tray peak/mean, safe margins, legal choices,
fatal choices, heuristic score and solver replay. It reads the existing
`qa/endless_progression_results.json` first-pass measurements and writes only
`qa/endless_refinement_results.json` and `.md`. Each row contains original,
first-pass and refined metrics, retaining all deltas and failure statuses.
It checks repeated fresh and continuous seeded runs and exact early-board
identity. Baseline code is frozen in `pre_progression_endless_generator.dart`.
It includes the previous solvability fix; the older impossible generator remains
separate and its historical UNSOLVABLE tests remain intact.

**Measured refined values and player difficulty are pending local verification.**

## Compatibility and regression coverage

- `EndlessScreen`, GameEngine, UI/animation code, rewards, save schemas, cosmetics,
  DEV/PROD configuration and all campaign assets remain unchanged.
- The screen still chooses its cosmetic override or rotates world every three
  rounds. The generator uses only the supplied theme's existing catalog.
- Same seed plus same call sequence remains reproducible. Late-round content
  intentionally differs from the prior release and consumes different RNG values.
- Existing saves store best score, aggregate runs and boards cleared; they do
  not store the active round, board or RNG state. No migration or new save key.
- Try Again still starts at round 1 with the existing generator instance; it does
  not reset its RNG or promise the identical board from the beginning of the run.
- New tests cover explicit stage values; fresh seeds 0, 1, 42, 2147483647; all ten
  themes; all three screens; rounds 20/30/50/75/100 and adjacent boundaries;
  recovery; round 1000; cross-cell links on the small screen, same-layer spacing,
  engine coverage agreement and rejected covered taps;
  bounds; per-type triples; exact early compatibility; full-clearance witnesses;
  continuous theme-rotated runs through 105; round-one restart sequences; saved
  scores, totals and preservation of stored stars, coins, XP and cosmetics.
- The old late-round layout-identity expectation is versioned against the frozen
  baseline, because keeping that layout would prevent this approved redesign.
  Early exact identity and every safety assertion remain; new late-stage tests
  enforce stronger readability contracts and explicit profile expectations.

## Local verification commands

From Git Bash at the project root, using the installed Flutter SDK/dependencies:

```bash
cd '/c/Gra - telefon/game'

flutter test --no-pub --concurrency=1 --reporter=expanded test/qa/endless_progression_test.dart test/qa/endless_test.dart test/qa/solver_test.dart test/qa/game_engine_test.dart

# Three-way metrics; preserves the measured first-pass and original audit reports.
flutter test --no-pub --concurrency=1 --reporter=expanded test/balance_audit/endless_comparison_test.dart

# Full QA, including the new progression tests.
powershell.exe -NoProfile -File ./qa/run_qa.ps1
```
