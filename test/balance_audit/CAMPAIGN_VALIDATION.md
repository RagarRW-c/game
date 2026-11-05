# Phase 4C — Campaign difficulty validation

This tooling measures existing Campaign data without modifying gameplay, levels,
generators, assets, economy, boosters or either Endless mode. Existing
`qa/balance_campaign.json` and `qa/balance_endless.json` are never opened by this
runner. No simulation results are included with this implementation. Formatting
and source review are not evidence that the tests or simulation have passed.

## Local execution

Run from the repository root, using the project's installed Flutter SDK:

```powershell
flutter test test/balance_audit/campaign_validation_run_test.dart --dart-define=CAMPAIGN_VALIDATE=true --concurrency=1 --reporter=expanded
```

The default experiment records **300 baseline cases** (100 levels × 3 geometries)
and **2160 behavioral attempts** (24 levels × 3 geometries × 3 strategies × 10
seeds). Baselines precede the bounded priority behavioral batch; no other levels
are added to behavioral testing automatically. Witnesses are separate from the
2160 attempts. Each baseline replays its candidate twice: existing `BoardSolver`
verification and an instrumented engine replay. This is verification, not two
independent solutions.

Lightweight deterministic contracts, without loading Campaign assets or creating
reports:

```powershell
flutter test test/balance_audit/campaign_validation_contract_test.dart --reporter=expanded
```

An optional smaller behavioral experiment still retains all 300 baselines:

```powershell
flutter test test/balance_audit/campaign_validation_run_test.dart --dart-define=CAMPAIGN_VALIDATE=true --dart-define=CAMPAIGN_LEVELS=2,3,7,8 --dart-define=CAMPAIGN_SEED_COUNT=2 --concurrency=1 --reporter=expanded
```

That example requests **72 attempts** (4 × 3 × 3 × 2). Level overrides must be a
subset of the 24 priority levels; seed count must be 1–10. Unsupported expansion
fails before writing outputs. The expensive test is outside `test/qa/` and skips
its body unless explicitly enabled. Ordinary full test discovery only adds the
small contract tests and a skipped experiment.

## Authoritative rules and architecture

1. `lib/data/level_repository.dart` defines 100 Campaign assets named
   `assets/levels/level_01.json` … `level_100.json`. The runner reads these exact
   files and parses `LevelDefinition.fromJson`; it never calls a generator.
2. `lib/domain/game_engine.dart` supplies every actual and projected state
   transition. Its seven-slot tray removes identical triples before checking
   loss. A post-resolution tray of seven loses; otherwise an empty board wins.
   Engine victory does not additionally require an empty tray or a completed
   objective. Behavioral outcomes preserve this distinction.
3. `lib/domain/tile.dart` supplies `boardRect` and `overlaps`. Blocking requires
   at least 3% of the candidate's logical rectangle, evaluated against later
   tiles in `GameEngine.renderedBoardTiles`, including later entries on the same
   layer. `CampaignGraph` caches only these immutable dependencies. It does not
   implement matching, tray transitions or win/loss logic.
4. `lib/presentation/screens/game_screen.dart` was inspected for layout inputs;
   existing `test/qa/support/geometry.dart` supplies its Campaign geometry.
   Graph availability is compared with `GameEngine.isTileCovered` initially and
   at every instrumented witness step. Every behavioral tap is also checked by
   the real engine. Geometry is fixed during an attempt; the graph is not valid
   for boosters, moved tiles or resizing, none of which this experiment uses.
5. `lib/domain/board_layout.dart` and `test/qa/support/solver.dart` establish the
   existing reverse paint-order constructive candidate. Only the existing
   `BoardSolver.replay` is invoked, never `solve` or DFS. A successful witness
   must satisfy engine victory, full clearance and the objective. Failure is
   UNVERIFIED, never proof of impossibility; no replacement witness is invented.
6. The existing `rectangleCoverage` helper from
   `test/balance_audit/support/balance_metrics.dart` reports exact rectangle union
   and coincidence measures. Its positive-area geometry statistics are distinct
   from the 3% logical blocking graph. No existing audit runner or difficulty
   score is invoked.
7. `support/campaign_validation.dart` contains the coverage cache, sanitized
   observation, deterministic policies, trace collector and baseline validator.
   `support/campaign_validation_report.dart` aggregates traces and comparisons.
   `campaign_validation_run_test.dart` owns IO and bounded experiment execution.
   `campaign_validation_contract_test.dart` covers determinism, coverage,
   hidden-information isolation, real tray/win/loss rules, replay, search bounds
   and honest aggregation. All five files (including this guide) are additions;
   no existing file needs modification.

## Coverage

| Screen | Safe top | Logical board | Square tile side |
|---|---:|---|---:|
| 320×568 | 24 | 300×360 | 51.2 |
| 360×800 | 24 | 340×538 | 57.6 |
| 412×915 | 32 | 392×620 | 65.92 |

Behavioral levels: **1–10, 23, 24, 29, 46, 65, 71, 76, 78, 80, 84, 89, 92, 96,
98**. Baseline coverage is always levels 1–100. World indices follow ten-level
Campaign groups, with Bosses at multiples of ten. Boss comparisons use each
Boss's three preceding regular levels in the same world. They do not pool
unrelated worlds into a difficulty ranking.

## Information boundary and exact policies

Policies accept only `VisibleCampaignBoard`: currently selectable tiles,
current tray symbols and geometry. Exposed tiles are ordered by `(y, x)` and
renamed `visible_0`, …; tray tiles become `tray_0`, …. Original IDs, level
number, authoring index, layers, concealed identities, whole-level inventories,
witnesses and future reveals are absent. Exposed tiles are mutually nonblocking
under the current rule and can therefore be safely projected onto one layer.
Actual IDs remain in a separate runner mapping, never in the policy argument.
Partially readable but blocked symbols are conservatively excluded. Policies
have no cross-decision memory except RNG state.

- **randomLegal**: choose uniformly among exposed tiles using rejection-sampled
  seeded integers. It deliberately does not avoid an immediate loss.
- **greedyMatch**: use real-engine one-step projections of currently exposed
  moves; prefer nonlosing moves, then fewer post-resolution tray tiles, then more
  same-type symbols already in the tray, then more same-type exposed symbols.
  Shuffle ties deterministically, then preserve explicit tie indices.
- **visibleLookahead**: rank children with the same greedy rule, examine at most
  four children per state to depth three, and expand at most 84 actions per
  decision (4 + 16 + 64). Score leaves lexicographically: survival, more matched
  tiles, lower maximum post-resolution tray occupancy along the projected path,
  then lower final occupancy. Keep the first equal-scoring leaf. Seeded greedy
  ordering controls those ties. No newly uncovered identity is added to a
  projection; projected victory simply ends the currently exposed subset and
  earns no victory bonus. Ranking itself previews all exposed candidates through
  the engine, at most 21 × initial exposed count per full decision, in addition
  to the 84 expanded actions and the tracer's one-step measurements.

The witness is explicitly marked `omniscient: true` and
`constructive_witness_NOT_A_PLAYER`. Behavioral aggregation rejects such rows.
No boosters, undo, shuffle, hidden-state search or hint APIs are used.

## Reproducibility and budgets

For each seed index 0–9, derive a 32-bit seed with FNV-1a over UTF-8 text:

```text
campaign4c/v1|<level>|<screen.name>|<policy.name>|<seedIndex>
```

FNV starts at `0x811c9dc5`; each byte is XORed and multiplied by `0x01000193`,
masked to 32 bits. The PRNG is xorshift32 (left 13, right 17, left 5), with zero
replaced by `0x6d2b79f5`. Bounded integers use rejection sampling; Fisher-Yates
produces tie orders. Neither SDK `Random` nor `String.hashCode` defines results.
GameEngine's unused random member does not influence forward taps. Identical
inputs, tool version, geometry, strategy and seed reproduce paths; no timings
enter decisions. Changing heuristic rules requires a new seed/tool version.

Each attempt permits at most its original tile count in successful forward
moves. No available move while the engine is playing, rejected taps, or exhausted
move/search budgets produce an explicit inconclusive reason. A selected move
from a bounded lookahead is still a valid heuristic choice; branch pruning alone
does not make the full attempt inconclusive. The default search cap can reach a
leaf; contract tests also check smaller artificial caps.

A 30-minute wall guard stops between cases/attempts, retains evidence and marks
the run PARTIAL. The test timeout is 35 minutes. A single in-progress case may
overshoot the wall guard. Partial coverage is machine-dependent and unsuitable
for comparing complete cohorts; rerun explicitly with a smaller behavioral
sample if necessary. A process kill or hard test timeout may leave a RUNNING
manifest and only partial JSONL; that is not a complete report. No automatic
retry, expansion or rule weakening occurs.

The manifest records runtime/SDK information when available, Git HEAD, scoped
working-tree status, actual budgets, timestamps and before/after fingerprints
of all 100 inputs, inspected authoritative sources and harness files. FNV-1a
fingerprints are non-cryptographic. Modified source must be retained alongside
the run; a Git commit and fingerprints alone cannot reconstruct uncommitted
source. Input changes during execution require review.

## Output and evidence

Every invocation creates a new directory (existing run paths are refused):

```text
qa/campaign_validation_runs/<UTC timestamp>-<process id>/
  manifest.json    # plan, actual coverage, provenance, health and runtime status
  baseline.jsonl   # 300 per-level/per-screen rows when complete
  attempts.jsonl   # 2160 per-strategy/per-screen/per-seed rows by default
  summary.json     # grouped metrics, comparisons and review cues
  report.md        # human-readable baseline/behavior/transition tables
```

Only the new run directory is written. `manifest.json` is finalized in that same
new directory; preexisting reports are never replaced. JSONL is flushed after
each strategy or ten baseline levels, retaining partial evidence on failures.

| Evidence | Meaning |
|---|---|
| CONFIRMED | Direct data/geometry properties computed from the recorded inputs |
| REPLAYED | Engine path execution; successful existence proof additionally requires `witness_status: REPLAYED` |
| SIMULATED | Outcomes and traces from deterministic exposed-only heuristic agents |
| UNVERIFIED | Human fairness, failed witness existence claims, or failed/unexecuted measurement |

`manifest.status` describes execution (RUNNING, COMPLETE, PARTIAL, FAILED).
`measurement_health` separately flags invalid inputs, failed witness checks,
inconclusive attempts or changing files. A COMPLETE run can require review and
return a failing test exit code after saving its report. Ordinary heuristic
losses do **not** fail that gate. Input/strategy exceptions are recorded as
inconclusive with the error, never silently dropped or converted to losses.

Baseline records include initial exposed IDs/types/count, visible triple count
(sum of floor(count / 3) by exposed type), blocking depth (tiles in longest
dependency chain), same/cross-layer edges, a logical graph fingerprint, minimum
blocking overlap, near-threshold examples, bounds, rectangle union/coincidence,
and the complete witness trace. Invalid input, out-of-bounds geometry, rejected
moves and unexpected deadlocks are explicit diagnostics.

Attempts retain actual paths, derived seeds, decision counts, choices over time,
post-resolution tray occupancy over time, immediate losing options at each
decision, first triple, forced single-choice decisions, states with one nonlosing
choice, and states without a complete type set among exposed-plus-tray tiles.
Pressure is occupancy / 7. Post-resolution and transient pre-resolution maxima
are separate, so a resolving seventh tap is not confused with a loss.

Grouped metrics contain attempts, wins, losses, inconclusives, completion rate,
initial choices/triples, decision totals, peak occupancy, decision-weighted mean
pressure, observed first-triple distributions (null attempts counted separately),
choice distributions, invalid-move/deadlock counts, relief counts, search budgets
and per-seed outcomes. Groups retain a separate unverified-attempt count; an
entirely unverified group is not labeled SIMULATED.
Completion uses **all attempts**, including inconclusives, as its denominator;
a separate resolved-only rate is provided. Fixed-sample min/mean/max/standard
deviation describe tie sensitivity, not uncertainty about a human population.

High-pressure relief counts currently visible triple-completing moves while the
tray contains at least five tiles. It is only an immediate opportunity proxy;
it does not identify mistakes or prove long-term recoverability. A forced-looking
decision means exactly one selectable tile; one nonlosing choice is separate.

Comparisons include levels 1–10 individually; 2→3, 7→8 and 10→11; all 297
neighbor transitions; each world start/boundary; 90 Boss-to-regular comparisons;
200 small-to-medium/tall pairs; and witness versus heuristic results. Behavioral
comparisons are only computed where both groups were sampled; 10→11 and most
world boundaries remain UNMEASURED. No hidden sample expansion fills them in.
Screen comparisons also indicate whether logical blocking dependencies changed
(a separate fingerprint excludes overlap magnitudes) and report same/cross-layer
edge deltas. Each comparison retains evidence labels and sample counts. Deltas are destination
minus source; they are descriptive, not an invented scalar difficulty score.

Review cues flag an exposed-choice fall of at least three **and** at least 50%
(between neighboring initial states or within an attempt), and post-resolution
tray occupancy of at least six. These are explicit screening thresholds, not
claims that a level is unfair. Full traces and all flags remain in JSON.

## Interpretation and limitations

A replayed constructive solution establishes existence, not practical fairness.
A heuristic loss does not establish unsolvability. No human win rate, difficulty
calibration, solve-time estimate or playtesting conclusion can be inferred from
ten deterministic seeds. Geometry-specific seeds also vary tie decisions across
screens; behavioral differences therefore combine geometry and seed variation.
The baseline dependency graph comparison provides direct geometry evidence.
Strategies omit partially visible symbols, memory and learning; their success
ordering need not match real players or be monotonic with search depth.

No production changes are required by this design. Execution/compilation and
empirical results remain unverified until the commands above are run locally.
Review the generated evidence before proposing individually approved level
changes. Classic Endless, Endless Battle, existing QA/Golden tests and old
balance reports remain untouched.
