# Triple Tile Adventure — balance audit preparation

Date: 2026-10-21. **Analysis only; no balance changes authorized or made.**

## Evidence and execution boundary

This report distinguishes (1) current source inspection, (2) pre-existing local QA evidence, (3) mathematical consequences of the authoring algorithm, and (4) measurements still to collect. No tests, builds, analyzer, emulator, ADB, screenshots, gameplay simulations, solvers, benchmarks or report-generation scripts were executed for this audit. New tooling has been reviewed as source only and still needs local verification.

The current working tree initially contained changes to `pubspec.lock` and untracked `.idea/` and `qa/results/`. These were preserved. Production files, all campaign assets, economy, progression, animation and flavor configuration remain unchanged.

Existing evidence inspected:

- [Prior campaign table](results/campaign.md) lists all **100 levels as SOLVED on all three geometries**, with no listed issues. [Prior campaign JSON](results/campaign.json) identifies its creation time as `2026-10-21T08:28:59.089358Z` and contains solution tile IDs, search reasons and node counts per screen.
- [Prior run manifest](results/run.json) records exit code 0 and source SHA-256 entries. [Prior log](results/run.log) ends with `+516: All tests passed!`. These are statements made by existing files, not a run performed for this audit.
- [Prior Endless solver report](results/endless_solver.json) specifically records **SOLVED / Engine-replayed reverse paint order / 0 search nodes** for Garden round 8 seed 0 and round 12 seed 0 on `small_320x568`.
- File hashes have **not** been recomputed or compared to that prior manifest during this audit. Prior results are therefore historical evidence, not certification of the current checkout. The old [QA_REPORT.md](QA_REPORT.md) contains historical unresolved defects, including the seventh-slot condition, that current source has already changed; do not treat its old failure table as current results.

The supplied `balance_campaign.json` and `balance_endless.json` are **preparation manifests**, with historical facts clearly separated from pending current measurements. The explicit local runner replaces them with complete measurements, witnesses and provenance. `NOT MEASURED` means no execution; `UNKNOWN` means an executed search was inconclusive. Neither means impossible.

## Actual rule model

| Rule | Source-inspected behavior | Audit consequence |
|---|---|---|
| Selection | `GameEngine.tapTile` accepts only board tiles that are uncovered while playing | Solver uses tile identities and actual paint order |
| Paint order | Ascending layer, then original input index; later entries paint on top | Same-layer overlaps block too; layer count alone understates depth |
| Blocking | `Tile.overlaps` requires intersection area **>=3% of the candidate tile area** | Tiny overlaps below 3% do not block; covered tiles still block tiles underneath |
| Triple | Exactly three matching type keys are removed automatically on collection | Icons/labels are presentation; logical type key controls matching |
| Tray | Seven slots; triples resolve before result update | A seventh tile that completes a triple is legal; seven left afterward loses immediately |
| Win | `_updateResult` checks full tray first, then empty board | Objective completion is not a win gate; the engine can win with a small residual tray on malformed inventories |
| Objectives | Counts matched tiles of the objective type, capped at target | On valid complete-triple inventories, full clearance satisfies an attainable target automatically |
| Undo | Only the most recent selection can return to the board, and only if still in the tray | Cannot undo a completed match or skip its history to retrieve an older unmatched tile |
| Shuffle | Randomly permutes types of remaining board tiles only | Preserves positions and inventory, but is excluded from booster-free solvability; its RNG is not injected |
| Hint / campaign cat action | Selects exposed tiles to finish a tray triple, otherwise an exposed triple; collects a batch | Capacity is checked before batch resolution; a batch exceeding seven sets lost. This is an existing rule, not changed by this audit |
| Booster economy | Both screens have two free uses per booster per board/level, then inventory/coins; 150-coin fallback | All of these aids, including free uses, are excluded from the audit's witnesses |
| Campaign stars | Zero boosters -> 3 stars; at most two -> 2; more -> 1 | Witnesses target genuinely booster-free clearance; no star-policy change proposed |
| Time metadata | `timeBonusSeconds` is parsed; no runtime countdown/loss use was found in `lib` | Decreasing JSON values are not evidence of timed difficulty |

Sources: [engine](../lib/domain/game_engine.dart), [tile overlap](../lib/domain/tile.dart), [level parser](../lib/domain/level.dart), [Campaign integration](../lib/presentation/screens/game_screen.dart), [Endless integration](../lib/presentation/screens/endless_screen.dart), [catalogs](../lib/core/tile_catalog.dart).

### Solver correctness and limits

The existing [BoardSolver](../test/qa/support/solver.dart) sorts through the real engine, builds blocker masks with `Tile.overlaps`, tracks type counts modulo three, and applies immediate full-tray loss after triple resolution. For taps only, the remaining-board mask determines collected counts modulo three, so its memoization key is sufficient. Tray order and selection history would matter for boosters; boosters are outside this model.

It first replays reverse paint order using the **real engine**, then uses bounded DFS if needed. A successful search witness is also replayed. Zero search nodes can mean a successful candidate replay, not an unverified divisibility shortcut. Exhausting the graph without cutoff is `UNSOLVABLE`; hitting the node/time budget is `UNKNOWN`. Existing independent small-board engine-oracle tests and the two legacy Endless regressions support this modeling approach, but were not rerun here.

**Important semantic mismatch:** `BoardSolver.replay` requires every tile matched, empty tray and completed objective. `GameEngine` only requires an empty board without a full tray. Thus a bad inventory or impossible objective can be `UNSOLVABLE` under the strict audit criterion even when the engine's weaker win condition is reachable. The new report records the criterion, inventory-dependent equivalence and a separate `engine_win_status`. It never translates a strict rejection into engine impossibility when equivalence is absent. For valid complete triples and attainable objectives, the criteria coincide.

Limitations: one found witness is not an optimal strategy; DFS node count is ordering-dependent; no minimum-capacity proof, solution count, human win-rate estimate, hidden-information reasoning or exhaustive off-witness dead-end analysis is supplied. A player can still lose on a solvable board. No audit metric represents the chance an ordinary player discovers the witness.

## Geometry and screen dependence

The runner reuses [QA geometry](../test/qa/support/geometry.dart), checked against the source calculations in both screens:

- Width: clamp(screen width - 20, 0, 440).
- Campaign height: clamp(screen height - safe top - 238, 360, 620); tile side: clamp((board width + 20) * .16, 50, 70).
- Endless height: clamp(screen height - safe top - 286, 330, 600); tile side: clamp((board width + 20) * .16, 48, 68).
- Profiles: 320x568 / safe top 24; 360x800 / 24; 412x915 / 32. Board/frame `FittedBox` uniformly scales the logical canvas. This does not change overlap ratios within that canvas, but different logical aspect ratios **do** change blocking.

Concrete prior evidence: L1 had **5 initially playable tiles on 320x568 versus 10 on 360x800** in the existing campaign JSON. Its current asset contains 30 tiles, three layer labels and seven type keys (apple, moon, shell, carrot, gem, star, flower). This makes L1 a priority for onboarding review; it is not proof that players find it too hard. Touch visibility, icon readability, text scaling and actual fitted bounds are UI QA concerns not measured by this headless audit. Run the existing screen-fit suite for live widget geometry.

## Campaign curve: evidence from all ten worlds

Counts below are transcribed from the prior 100-level campaign table. Layer ranges are the **prior static QA inventory**, not newly computed. Solution construction batch size is read from the current authoring script; it is not a measurement of required player tray pressure.

| World | IDs | Prior tile range | Prior layer labels | Construction batch size | Main review focus |
|---|---|---:|---|---:|---|
| Garden | 1–10 | 30–54 | 3 | 2 | Already layered and type-rich at onboarding; compare small screen legal choice counts |
| Ocean | 11–20 | 42–66 | 4 | 3 | First increase in interleaved matching; evaluate L10→11 geometry despite fewer tiles |
| Candy | 21–30 | 54–78 | 5 | 3 | More work/depth without changing witness batching; watch repetitive planning |
| Space | 31–40 | 72–90 | 6 | 4 | Second interleaving transition at L31; boss40 has same tile count as39 |
| Desert | 41–50 | 60–78 | 4–5 | 4 | Large reset from Space; distinguish intended recovery from a sustained difficulty drop |
| Ice | 51–60 | 66–84 | 4–5 | 4 | Same type-order control; verify layouts produce different choices |
| Jungle | 61–70 | 72–90 | 5–6 | 4 | Evaluate depth and branching, not merely more tiles |
| Volcano | 71–80 | 78–96 | 5–6 | 4 | Geometry shares some earlier families; verify distinct planning demands |
| Dream | 81–90 | 84–102 | 6–7 | 4 | Separate lengthy clears from meaningful endgame decisions |
| Crystal | 91–100 | 90–108 | 6–7 | 4 | Final workload peak; require fair, discoverable booster-free paths |

Current authoring uses only **three interleaving tiers**: levels 1–10, 11–30 and 31–100. The last 70 levels do not increase this particular control. Geometry and inventory can still change difficulty; this is a plateau in a design parameter, not a measured plateau in human difficulty.

Each world has five ordinary pattern slots plus a reserved boss pattern. Stages 1–5 use the ordinary pool and stages 6–9 repeat its first four, with mirroring, vertical scale and layer offsets. Several different names share candidate geometry: grove/reef/canopy; tide/vine; orbit/crater; satellites/islands. Shared anchors do not prove identical final boards because sampling, count, layer distribution and seed differ. The runner exposes exact ordered-shape fingerprints and blocking components; similarity beyond exact matches remains a design review task.

Source: [board layouts and clearable order](../lib/domain/board_layout.dart), [offline authoring script](../tool/generate_mixed_level_layouts.dart). **Do not run the authoring script for this audit: it writes every level asset.** The original inventory authoring process is not present in the inspected `tool/` directory; current assets, rather than hypothetical formulas, must remain the source of inventory measurements.

### Candidate spikes, drops and plateaus — not difficulty verdicts

| Affected IDs | Supported observation | Required investigation |
|---|---|---|
| 1 | Current asset: 30 tiles, seven types, three layers; prior small-screen playable count five | Onboarding choice burden and whether exposed matches are legible |
| 9→10 | Prior tiles 42→54, unique boss silhouette | Measure pressure/depth and compare boss score to 7–9 |
| 10→11 | Prior tiles 54→42, construction tier 2→3, prior layers 3→4 | A tile-count drop can conceal increased planning difficulty |
| 30→31 | Prior tiles 78→72, construction tier 3→4, prior layers 5→6 | Likely review boundary for tray pressure; do not call it a proven spike |
| 39→40 | Prior tiles 90→90; boss-specific pattern | Verify challenge comes from geometry rather than a label |
| 40→41 | Prior tiles 90→60; prior six layers→Desert's 4–5 range | Large workload reset; identify intended recovery versus accidental curve collapse |
| 31–100 | Same four-type interleaving controller throughout | Look for near-flat score windows and repeated planning patterns |
| 50→51, 60→61, 70→71, 80→81, 90→91 | Each prior tile total drops by12 | Could be healthy recovery; classify only after geometry/path measurements |
| 91–100 | Prior totals rise 90→108 | Distinguish long repetition from fair advanced decisions |

### All ten bosses

All listed bosses had prior SOLVED results on all three geometries. Current-run verification and comparative difficulty scores are **NOT MEASURED**. Boss metadata adds titles, visuals and rewards; the inspected engine has no separate boss attack, damage, timer or tray-capacity rules.

| Boss | World / reserved pattern | Previous level → boss tiles (prior) | Assessment pending |
|---|---|---|---|
| 10 | Garden / gardenBloom | 42→54 | Clear workload jump; suitability for first finale unmeasured |
| 20 | Ocean / oceanGyre | 54→66 | Spiral arrangement; pressure relative to10 unmeasured |
| 30 | Candy / candyCastle | 72→78 | Distinct row silhouette; choice constraints unmeasured |
| 40 | Space / spaceNova | 90→90 | Equal count; geometry must supply distinction |
| 50 | Desert / desertTemple | 75→78 | Fewer tiles than boss40; not proof of easier play |
| 60 | Ice / iceCrown | 81→84 | Distinct rows; challenge relative to50 unmeasured |
| 70 | Jungle / jungleSanctuary | 87→90 | Lobed pattern; meaningful choice burden unmeasured |
| 80 | Volcano / volcanoCaldera | 93→96 | Squashed rings; compare with earlier orbit/crater boards |
| 90 | Dream / dreamPalace | 99→102 | Larger workload; planning improvement unmeasured |
| 100 | Crystal / crystalCrown | 105→108 | Current objective drop9; full-clear witness and score pending |

### Most difficult levels / further investigation

| Ranking request | Current defensible answer |
|---|---|
| Highest measured difficulty | **NOT MEASURED**; no human data and no new heuristic calculation |
| Highest prior workload | L100:108 tiles; L99:105; L90/97/98:102; counts are not a difficulty ranking |
| Priority onboarding cases | L1, L2 and L10 |
| Priority curve boundaries | L10–11, L30–31, L39–41 |
| Priority long-form/endgame cases | L80, L90, L91–100 |
| Remaining current solvability validation | All100 × three geometries; existing evidence is historical |
| Suspected impossible current campaign boards | None established by inspection; no new UNSOLVABLE claim |

## Endless findings

| Rounds | Tile range | Layer range | Jitter coefficient | Type-order batch |
|---|---:|---|---:|---:|
| 1–3 | 24–30 | 2–3 | .025 | 2 |
| 4–7 | 30–42 | 3 | .045 | 3 |
| 8–12 | 42–54 | 4 | .070 | 4 |
| 13+ | 54–72 | 5–6 | .095 | 4 |

These are **source-defined ranges**, not sampled averages. Counts are selected from an inclusive integer range then rounded down to a multiple of three, so endpoint probabilities are not uniform over the resulting multiples. Do not assume each legal count is equally likely. Layers and positions have additional randomness.

After round13, count/layer/jitter/interleaving profiles remain constant. The scoring multiplier continues to grow, but that is not increasing board difficulty. Round numbers affect the derived solution seed and IDs; repeated random draws produce variation without a further difficulty ramp. Treat post13 as a plateau unless a future approved design deliberately changes it.

Position offsets grow by layer and clamp origins to x=.02–.82 and y=.02–.80. Large late-layer offsets can concentrate tiles at clamped edges, increasing blocking or similarity. This is a source-supported risk, not a measured frequency. The new metrics record coincidence depth, maximum direct blockers, connected components and union compactness to investigate it.

`Random(seed)` can be injected for reproducible QA; production constructs an unseeded generator. `_solutionSeed` uses an explicit stable character fold and does not consume the main RNG, preserving subsequent seeded count/inventory/position draws. Dart's RNG implementation and catalog insertion order remain dependencies: record SDK and source fingerprints; do not promise identical boards across arbitrary future SDKs. Fresh `Random(0)` at round8 is **not** the same experiment as drawing rounds1–8 from one `Random(0)` instance. The audit reports both modes separately.

All visual themes share logical matching infrastructure; themed icons do not create extra engine rules. The runtime rotates theme every three rounds unless cosmetics select a fixed theme. The plan samples all ten themes at profile boundaries, Garden with seeds0,1,42,2147483647 at rounds1,3,4,7,8,12,13,30,100, and continuous seeded runs through round30 with the default theme cycle. The fixed-theme continuous mode, all seeds and indefinitely late rounds remain outside the sample.

### Why the previous Endless fix is structurally credible

The former generator randomized type locations after constructing complete triples. Covered tiles could force seven unmatched selections. The current generator instead assigns a safe type sequence to **reverse actual engine paint order**, preserving its original inventory and coordinates.

At every step, the last painted remaining tile has no later remaining blocker. Therefore reverse paint order is legal regardless of overlap geometry. `clearableTileOrder` emits complete batches with these patterns (A–D denote distinct types):

| Batch | Selection sequence | Maximum retained tray after resolution |
|---|---|---:|
| 1 | AAA | 2 |
| 2 | ABABAB | 4 |
| 3 | ABCABACBC | 5 |
| 4 | ABCDABACDBCD | 6 |

Each batch ends with an empty tray; concatenation preserves that invariant. If the remaining inventory forces repeated types within a batch, merging type counters modulo three cannot increase retained occupancy above the distinct-type case. This is a construction argument for a booster-free route, **not evidence that all player choices are safe or the route is easy to recognize**. Campaign authoring uses the same sequence constructor, but existing assets must be replayed to confirm they still reflect that authoring output.

Prior local evidence specifically supports the repaired Garden round8/12 seed0 small-screen cases. The new runner includes both again. Existing `endless_test.dart` additionally preserves the old generator fixtures, exhaustively checks their impossibility with actual engine transitions, and expects the repaired witnesses to peak at six retained tiles. Those regressions were not rerun here.

## Metric definitions and limitations

The local runner writes every level's world, tile count, type count/distribution, distinct layer labels, pattern, objective, per-screen geometry, solver outcome/budget/stats/path, witness trace, score components, issues and recommended action.

Objective measurements:

- Initial playable/blocked IDs and per-type available counts; same/cross-layer blocking edge counts.
- Maximum **direct blockers**, longest blocker chain in tiles, and largest coincident rectangle depth. These are different quantities; geometric coincidence includes sub-3% overlaps, while blocker edges do not.
- Blocking connected-component sizes; union area, occupied board fraction, union/bounding-box ratio and summed tile area/bounding-box ratio. The latter may exceed1 because tiles overlap.
- During a verified witness: legal choices before each move, one-choice steps, immediate losing alternatives, retained/transient tray peaks, mean tray occupancy and safe margin. A transient seventh slot that immediately matches is distinguished from seven retained slots (loss).
- Raw tile-ID witness, engine replay confirmation, DFS node count, chosen node budget and observed solver duration. Runtime is diagnostic, not a difficulty feature.

**Heuristic score v1** (0–100, per-screen; level score is the maximum screen score):

`10*min(N/108,1) + 15*min(K/15,1) + 20*(initialBlocked/N) + 15*min((longestBlockerChain-1)/12,1) + 25*(witnessRetainedPeak/6) + 15/(meanLegalChoicesOnWitness)`

N=tiles; K=distinct types. The score is withheld if a screen has no verified witness. Each term is recorded separately. This deliberately gives tile count only10% of the weight. It is an **uncalibrated triage score**, not a target difficulty, success probability or optimal-play cost. Forced play can simplify decisions or make a puzzle fragile; choice scarcity is an explicit heuristic assumption, not a universal law. Do not tune levels to this score alone. Compare multiple screen profiles and human outcomes before approving balance changes.

Flags for review: adjacent score change >=10 upward or downward; world-boundary deltas regardless of magnitude; four consecutive levels within a three-point score range; boss score against the preceding three-level mean and previous boss. These thresholds are design-review conventions, not statistical significance tests.

Unresolved measurements: optimal/minimum tray peak, branching dead ends beyond immediate loss, percentage of viable moves, unavoidable guessing under partial visual information, player completion rate, retry count, booster reliance, readability and elapsed human time. The runner explicitly leaves these unmeasured. Solver discovery work is not substituted for them.

## Prioritized recommendations — approval required before implementation

No evidence inspected establishes that a purchased booster is mathematically mandatory: prior campaign witnesses and the current Endless construction support booster-free completion. This is narrower than saying the game never creates frustration or monetization pressure. Wrong choices can still lose, Undo cannot reverse matched selections, and Hint's pre-resolution batch capacity rule can itself end a run. Human booster reliance and paid-conversion behavior are NOT MEASURED. Treat boosters as optional recovery aids and preserve an attainable route requiring no free boosters, purchases, ads, extra lives or paid advantages. No economy change is made or authorized here.

1. **P1: Refresh evidence and investigate semantic mismatches.** Run the audit and existing QA. Resolve invalid inputs, solver/engine disagreements, out-of-bounds geometry or proven full-clearance failures before tuning. Decide whether objectives are intended to gate victory; do not silently change that rule in an audit.
2. **P1: Review onboarding and small-screen exposure.** Pilot simpler L1–3 inventories and exposed choices only after approval. Current L1 already combines seven types, three labels and small-screen blocking. Preserve a visible, teachable solution rather than merely reducing count.
3. **P1: Audit boundaries10/11 and30/31.** Type interleaving rises while tile totals fall. Use measured tray margin and legal alternatives to smooth any confirmed spikes; do not erase intentional recovery levels.
4. **P2: Define the purpose of40/41 and post13 Endless.** The campaign has a large workload reset; Endless stops escalating its structural profile. Choose deliberate recovery/endurance behavior or a bounded, approved progression. Do not increase count indefinitely.
5. **P2: Give each world a varied planning rhythm.** Retain the illustrated silhouettes but vary exposed matching options, safe alternate paths, independent regions and overlap order. Distinct pattern names alone do not guarantee distinct puzzles.
6. **P2: Validate boss distinction.** Boss40 especially needs evidence beyond tile count. Compare every boss with its preceding three levels and previous boss, then playtest discoverability. Keep guaranteed booster-free completion; do not add mandatory purchases or tighter tray rules.
7. **P3: Calibrate with player evidence.** Collect consented aggregate completion/retry/booster-free outcomes later, segmented by screen and experience. Revise heuristic weights from that evidence; no telemetry is added by this work.

Proposed progression is a design hypothesis, not a report of measured results:

| Range | Proposed learning emphasis | Variation within the world |
|---|---|---|
| 1–10 | Recognize triples, understand coverage, learn safe tray use | Short exposed openings, recovery before first boss |
| 11–30 | Introduce type variety and light ordering constraints | Alternate open boards with one clear planning dependency |
| 31–50 | Plan two/three moves while reserving tray space | Hard challenge followed by recovery; make the40→41 reset intentional |
| 51–70 | Deeper dependencies with readable alternate routes | Mix independent regions and tightly connected shapes |
| 71–90 | Advanced ordering and recoverable mistakes | Avoid repetitive long clears or single obscure forced routes |
| 91–100 | Challenging, fair endgame and final mastery | Maintain booster-free witnesses and discoverable alternatives |

A possible ten-stage rhythm: recovery, standard, standard, challenge, recovery, standard, challenge, standard, short preparation, boss. Specific changes must follow measured evidence and approval; no per-level edits are proposed as proven necessary yet.

## Local execution — Git Bash, existing Flutter installation

Run from the project root. The tooling imports `dart:ui`/Flutter-backed engine types, so use the Flutter host test runner, not `dart run`. These commands run **only when you execute them**; no packages are installed and no Android build/device is requested.

```bash
cd '/c/Gra - telefon/game'

# Verify the new metric contracts first (does not generate balance reports).
flutter test --no-pub --concurrency=1 --reporter=expanded test/balance_audit/metrics_test.dart

# All 100 campaign levels and 88 representative Endless boards, three geometries.
# Default: reverse-order candidate replay; zero DFS nodes.
flutter test --no-pub --concurrency=1 --reporter=expanded test/balance_audit/balance_audit_test.dart

# Optional bounded search for UNKNOWN cases: at most 5000 nodes/board and
# 200000 nodes across the entire run. No unbounded exhaustive benchmark.
BALANCE_MAX_NODES=5000 BALANCE_TOTAL_NODES=200000 \
  flutter test --no-pub --concurrency=1 --reporter=expanded test/balance_audit/balance_audit_test.dart

# Existing independent solver and repaired/legacy Endless regressions.
flutter test --no-pub --concurrency=1 test/qa/solver_test.dart test/qa/endless_test.dart

# Existing complete QA suite and ordinary machine-readable evidence.
powershell.exe -NoProfile -File ./qa/run_qa.ps1
```

The balance runner writes `qa/balance_campaign.json`, `qa/balance_endless.json` and only the marked generated section below. Existing `qa/results/` remains separate. Inputs are fingerprinted at start/end; a change invalidates the run. FNV-1a32 fingerprints are non-cryptographic comparison aids, not security hashes. For stronger archival provenance, save a Git commit plus the existing QA SHA-256 manifest. SDK version, source inputs, seed mode and budgets are stored in each report. Wall times/timestamps naturally vary; node-limited statuses/paths should reproduce for identical inputs/SDK unless the disclosed emergency wall guard fires.

Interrupted outputs remain `RUNNING` and are incomplete. A zero test exit does **not** mean all searches were SOLVED: UNKNOWN is reported without asserting impossibility. Inspect every per-screen outcome. Proven UNSOLVABLE, invalid input, determinism mismatch and replay/geometry disagreement fail the runner **after** evidence is saved. New tests and tooling have not been compiled or executed here.

<!-- BALANCE_MEASUREMENTS_BEGIN -->
### Local generated measurements

Generated by the explicit balance audit. Scores are heuristic, not measured human difficulty.
Search nodes consumed: 0/200000. Exact paths and statistics are in the JSON files.

| World | Solved levels (all screens) | Mean score | Score range | Patterns |
|---|---:|---:|---|---:|
| garden | 10/10 | 58.61 | 46.60–69.49 | 6 |
| ocean | 10/10 | 69.93 | 59.99–77.86 | 6 |
| candy | 10/10 | 75.51 | 68.81–79.24 | 6 |
| space | 10/10 | 83.22 | 81.53–84.39 | 6 |
| desert | 10/10 | 82.61 | 81.36–83.91 | 6 |
| ice | 10/10 | 82.68 | 81.45–83.55 | 6 |
| jungle | 10/10 | 83.65 | 82.27–85.20 | 6 |
| volcano | 10/10 | 84.39 | 83.31–86.95 | 6 |
| dream | 10/10 | 84.64 | 82.79–86.97 | 6 |
| crystal | 10/10 | 85.68 | 84.53–86.57 | 6 |

| Boss | Status | Score | Delta from preceding 3 | Delta from previous boss |
|---|---|---:|---:|---:|
| 10 | SOLVED | 69.49 | 6.38 | NOT MEASURED |
| 20 | SOLVED | 77.86 | 5.13 | 8.37 |
| 30 | SOLVED | 78.39 | 0.01 | 0.53 |
| 40 | SOLVED | 83.48 | -0.15 | 5.09 |
| 50 | SOLVED | 82.51 | -0.84 | -0.97 |
| 60 | SOLVED | 83.47 | -0.07 | 0.96 |
| 70 | SOLVED | 84.27 | 0.33 | 0.80 |
| 80 | SOLVED | 86.95 | 2.36 | 2.68 |
| 90 | SOLVED | 85.84 | 0.53 | -1.11 |
| 100 | SOLVED | 85.69 | -0.44 | -0.15 |

| Highest heuristic score | World | Score |
|---|---|---:|
| 89 | dream | 86.97 |
| 80 | volcano | 86.95 |
| 98 | crystal | 86.57 |
| 96 | crystal | 86.49 |
| 84 | dream | 86.33 |
| 97 | crystal | 86.23 |
| 95 | crystal | 85.96 |
| 90 | dream | 85.84 |
| 100 | crystal | 85.69 |
| 99 | crystal | 85.58 |

| Adjacent review candidate | Delta | Classification |
|---|---:|---|
| 2 → 3 | 12.89 | SPIKE |
| 4 → 5 | -10.29 | DROP |
| 10 → 11 | -9.50 | WITHIN_HEURISTIC_BAND; world boundary |
| 20 → 21 | -5.74 | WITHIN_HEURISTIC_BAND; world boundary |
| 30 → 31 | 4.53 | WITHIN_HEURISTIC_BAND; world boundary |
| 40 → 41 | -1.74 | WITHIN_HEURISTIC_BAND; world boundary |
| 50 → 51 | -0.66 | WITHIN_HEURISTIC_BAND; world boundary |
| 60 → 61 | -1.20 | WITHIN_HEURISTIC_BAND; world boundary |
| 70 → 71 | -0.62 | WITHIN_HEURISTIC_BAND; world boundary |
| 80 → 81 | -3.56 | WITHIN_HEURISTIC_BAND; world boundary |
| 90 → 91 | -0.43 | WITHIN_HEURISTIC_BAND; world boundary |

| Additional investigation | Findings |
|---|---|

Near-flat windows (heuristic range ≤3 over four levels): `[{"from":27,"through":30,"score_range":1.6576006201615172},{"from":31,"through":34,"score_range":1.8165240079897984},{"from":32,"through":35,"score_range":1.8165240079897984},{"from":33,"through":36,"score_range":2.664666464903931},{"from":34,"through":37,"score_range":2.865231868326916},{"from":35,"through":38,"score_range":1.2424704163102405},{"from":36,"through":39,"score_range":1.2424704163102405},{"from":37,"through":40,"score_range":1.2424704163102405},{"from":38,"through":41,"score_range":1.737662844868467},{"from":39,"through":42,"score_range":1.737662844868467},{"from":40,"through":43,"score_range":1.737662844868467},{"from":41,"through":44,"score_range":0.8468975468975373},{"from":42,"through":45,"score_range":1.230384930384929},{"from":43,"through":46,"score_range":2.165500239185789},{"from":44,"through":47,"score_range":2.165500239185789},{"from":45,"through":48,"score_range":2.5515970515970565},{"from":46,"through":49,"score_range":0.9250642013353882},{"from":47,"through":50,"score_range":1.405376466352081},{"from":48,"through":51,"score_range":2.069665729459544},{"from":49,"through":52,"score_range":1.53649165574285},{"from":50,"through":53,"score_range":1.10176226902378},{"from":51,"through":54,"score_range":1.4197548684687433},{"from":52,"through":55,"score_range":1.4197548684687433},{"from":53,"through":56,"score_range":1.0607788639703557},{"from":54,"through":57,"score_range":1.7357888657888765},{"from":55,"through":58,"score_range":1.7398461810226564},{"from":56,"through":59,"score_range":1.7398461810226564},{"from":57,"through":60,"score_range":0.08045372523844208},{"from":58,"through":61,"score_range":1.2820157090412323},{"from":59,"through":62,"score_range":1.3111380378127677},{"from":60,"through":63,"score_range":1.3111380378127677},{"from":61,"through":64,"score_range":1.3111380378127677},{"from":62,"through":65,"score_range":2.0594364720916047},{"from":63,"through":66,"score_range":2.0594364720916047},{"from":64,"through":67,"score_range":2.1865713558089936},{"from":65,"through":68,"score_range":2.022042178005492},{"from":66,"through":69,"score_range":2.022042178005492},{"from":67,"through":70,"score_range":2.022042178005492},{"from":68,"through":71,"score_range":1.0881775051516769},{"from":69,"through":72,"score_range":0.8427103107640761},{"from":70,"through":73,"score_range":0.6242727441757836},{"from":71,"through":74,"score_range":0.6843367387697157},{"from":72,"through":75,"score_range":0.6843367387697157},{"from":73,"through":76,"score_range":1.2112808585316657},{"from":74,"through":77,"score_range":1.3157991730111576},{"from":75,"through":78,"score_range":0.7312804367717547},{"from":76,"through":79,"score_range":0.10807939594855043},{"from":77,"through":80,"score_range":2.4296477997954185},{"from":84,"through":87,"score_range":2.1367111885404455},{"from":85,"through":88,"score_range":1.3530308558323867},{"from":89,"through":92,"score_range":1.9774284005237632},{"from":90,"through":93,"score_range":0.8409018937580015},{"from":91,"through":94,"score_range":0.8828686868686759},{"from":92,"through":95,"score_range":1.4383017705927585},{"from":93,"through":96,"score_range":1.9640375180375145},{"from":94,"through":97,"score_range":1.9640375180375145},{"from":95,"through":98,"score_range":0.6092843923276803},{"from":96,"through":99,"score_range":0.996241608180128},{"from":97,"through":100,"score_range":0.996241608180128}]`.

Endless boards measured: 88; SOLVED on all screens: 88.
The JSON distinguishes fresh-seed cases from continuous seeded runs and records reproducibility failures.
<!-- BALANCE_MEASUREMENTS_END -->

Stop here: this audit authorizes no rebalancing, regeneration, economy changes or gameplay changes. Review measured reports before approving any implementation.
