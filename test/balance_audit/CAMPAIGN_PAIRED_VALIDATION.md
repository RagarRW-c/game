# Phase 4D-2 — paired Campaign difficulty validation

This is a separately versioned experiment, `campaign4d2/paired-v1`. It changes
only isolated Campaign validation tooling. Production gameplay, all 100 Campaign
levels, rules, boosters, economy, UI, assets, Classic Endless and Endless Battle
are untouched. The historical `campaign4c/v1` runner, seed function and default
decision policy remain available. Historical artifacts are never overwritten.

**Implementation status:** the author has not run Flutter tests, simulations,
Flutter analyze, Gradle, ADB, emulators or APK builds. Only Dart formatting,
source/diff checks and read-only aggregation of existing results were performed.
No new experiment outcomes are claimed here. Run the commands below locally.

## Local commands and outputs

From the repository root:

```powershell
flutter test test/balance_audit/campaign_validation_contract_test.dart test/balance_audit/campaign_paired_contract_test.dart --concurrency=1 --reporter=expanded
flutter test test/balance_audit/campaign_paired_run_test.dart --dart-define=CAMPAIGN_PAIRED_VALIDATE=true --concurrency=1 --reporter=expanded
```

The second command runs exactly **990 planned attempts**:

- Levels **3, 23, 29, 65, 71, 76, 78, 84, 92, 96, 98**.
- Screens `small_320x568`, `medium_360x800`, `tall_412x915` using the existing
  Campaign geometry helper (logical boards 300×360, 340×538, 392×620; square
  tile sides 51.2, 57.6, 65.92).
- Existing strategies `randomLegal`, `greedyMatch`, `visibleLookahead`, with
  explicit `/paired-ties-v1` versions.
- Replica indices **0–9**. No subset/expansion override, automatic retry,
  additional baseline replay or exploratory search is performed.

The new runner is skipped unless `CAMPAIGN_PAIRED_VALIDATE=true`. The historical
`CAMPAIGN_VALIDATE`, `CAMPAIGN_LEVELS` and `CAMPAIGN_SEED_COUNT` flags do not
configure this runner. A 30-minute guard between attempts can produce PARTIAL
coverage; the test timeout is 35 minutes. Deterministic per-attempt budgets are
the original tile count for successful actual taps and 84 expanded lookahead
actions per decision. Full tree ranking previews are additional work, bounded
by 21 × the initial exposed count; tracing also previews every legal candidate.

Each invocation atomically allocates a unique new directory:

```text
qa/campaign_validation_runs/paired-<UTC timestamp>-<pid>-<unique suffix>/
  manifest.json
  paired_attempts.jsonl
  paired_summary.json
  paired_report.md
```

The manifest records HEAD, scoped dirty-tree status, before/after FNV-1a input
fingerprints, actual UTF-8 scoped input snapshots (including uncommitted harness
code and the 11 level inputs), installed Flutter version-file contents, Dart
runtime version, screen geometry, policy definitions, seed/token version,
samples, budgets, scope, completion status and measurement health. The runtime
reads SDK provenance without spawning Flutter. UNAVAILABLE SDK/Git fields must
be retained with independently recorded local provenance; they are not invented.
Snapshots permit recovery of dirty source; HEAD plus a fingerprint alone would
not. Dependencies still require the recorded Flutter/Dart SDK and lockfile.
Fingerprints are accidental-change detectors, not cryptographic attestations.

Every JSONL row is flushed separately. Exceptions become UNVERIFIED,
INCONCLUSIVE rows; they never become losses. Coverage discrepancies, rejected
taps, missing legal moves, ambiguous public tokens and move-budget exhaustion
are INCONCLUSIVE. Ordinary heuristic losses do not fail the health gate.
Input changes or missing inputs on recheck require review. COMPLETE means all
990 rows exist; it does not imply every attempt resolved or the level is fair.
PARTIAL/FAILED runs must not be compared as full cohorts. A hard process kill or
test timeout may leave a RUNNING manifest and incomplete artifacts; keep that
evidence and explicitly launch a fresh run, never resume into its directory.

The two contract suites include small synthetic simulations and three old
attempt replays. These are verification fixtures, separate from the **990**
attempt experiment, and produce no validation-run artifacts. No tests have been
deleted or weakened.

## Exact seed and candidate priority policy

Let `V = "campaign4d2/paired-v1"`, `L = Campaign level`, `R = replica index`,
and `D = zero-based actual successful tap index`. JSON here means compact Dart
`jsonEncode`, encoded as UTF-8. FNV-1a starts at `0x811c9dc5`; for each byte,
XOR then multiply by `0x01000193`, masking to unsigned 32 bits.

```text
experiment seed = FNV1a32(UTF8(JSON([V,L,R])))
public token T  = JSON([visibleType, normalizedXString, normalizedYString])
actual priority = FNV1a32(UTF8(JSON([V,L,R,D,"actual",[],T])))
plan priority   = FNV1a32(UTF8(JSON([V,L,R,D,"plan",P,T])))
```

`P` is the ordered list of public tokens already hypothetically tapped in this
plan, rooted at the current real observation. Root ranking always uses actual
priority; internal ranking uses plan priority. The seed is the compact recorded
identifier of the full `[V,L,R]` experiment key. Priorities hash the full key,
not merely its 32-bit digest, avoiding accidental experiment aliasing from a
seed digest collision. The actual decision number never counts hypothetical
nodes or random draws. Neither screen nor strategy enters the key.

The x/y strings are the normalized top-left coordinates already present in
`VisibleCampaignBoard`, using Dart `double.toString()` and normalizing either
signed zero to `0.0`. They are public position values from the observation,
not authoring indices or hidden identities. They preserve exact normalized
positions without quantizing separate candidates together. The tool models a
player's observable position; it does not claim humans perceive floating-point
precision. Geometry still changes tile/board proportions and legal sets.

Lower unsigned priority wins a tie; equal 32-bit hashes use lexicographic
public-token order. No handle, tile ID, layer, list index, hidden symbol,
constructive witness or future tile identity breaks a tie. Duplicate legal
public tokens fail the attempt as INCONCLUSIVE rather than invoking a hidden
fallback. Under current positive-size overlap rules, coincident tiles cannot
both be legal; a contract guards the ordinary identity boundary.

The candidate hash does not include enumeration order, legal-set size, other
candidates or the screen. Thus the same public token at the same experiment
key and actual decision always receives the same actual priority. A different
legal set can still choose a different minimum. Greedy scores can also differ
because the exposed same-type counts differ. Identical priorities do not force
different strategies to make identical decisions.

This mode consumes **no sequential RNG**: a throwing `NoPairedRng` is supplied
to the shared decision routine. Candidate sorting, branch pruning, search work,
earlier differing decisions and extra instrumentation cannot shift later
priorities. Plan priorities are in a separate domain and additionally depend on
the public hypothetical path, so traversal order does not consume a stream.
The recorded experiment seed alone is not an SDK `Random` seed.

FNV is a small deterministic pseudorandom ranking mechanism, not cryptographic
randomness or a guarantee of exact uniformity/independence. In particular,
randomLegal now picks the minimum hashed candidate instead of historical
uniform rejection-sampled `nextInt`. This behavioral change is explicitly
versioned as `randomLegal/paired-ties-v1`; the historical policy is retained.
Informed policy scores, search depth, branch cap, terminal handling and leaf
evaluation are unchanged; only tie ordering is replaced and versioned. Compare
paired cells within the new version, not paired and historical rates as if they
were a single randomization regime.

## Policy boundary and historical compatibility

`CampaignObservation.capture` still exposes selectable tiles only, replaces
authoring IDs with local handles and strips layers. The strategies receive no
whole board, total inventory, witness or future reveals. Policies get tray
symbols and exposed type/position. Privileged actual IDs and complete blocking
edges are recorded by the tracer/report **after separation from policy input**;
they are never hashed or passed to the strategy hooks.

The only shared-file changes are optional `tieBreak` and `onRanked` hooks in
`support/campaign_validation.dart`, plus passing sanitized hypothetical paths.
With hooks absent, historical random draws, Fisher–Yates shuffle calls, greedy
ranking, traversal and first-equal-leaf selection are retained. Historical
tracing and its result schema are untouched. `fixtures/campaign_historical_v1.json`
contains three complete stored attempt rows for level 3 / small / replica 0,
one per policy, copied read-only from the completed run. New tests replay those
rows through the default historical API and compare the full returned maps.
Initial group metadata added by the old IO runner is excluded from the fixture.
This is a focused regression sample, not a claim that all 2160 old attempts have
been rerun or independently proven identical.

## Comparisons and metric definitions

There are **165 comparison cells** and **1650 paired outcomes** in a complete
summary, reusing the same 990 attempts rather than adding simulations:

- Per level and strategy: small→medium and small→tall (6 cells).
- Per level and screen: greedy→lookahead, random→greedy, random→lookahead (9 cells).
- Ten replica pairs per cell, paired on the full experiment version/level/replica.

Each cell reports W/L/I totals, all nine paired outcome combinations, missing
replicas and full per-replica outcomes. No unmatched or inconclusive row is
silently discarded. Pair summaries include the first different legal candidate
set, first different chosen move, first changed remaining/tray inventory,
every differing decision index, and unmatched trace tails. Equality checks use
the full public lists and diagnostic actual IDs, not hash equality alone.
An identical public token can refer to a different physical tile after reveal;
diagnostic IDs prevent treating those physical actions as the same path.

At a shared successful action prefix, an observed legal-set difference across
screens is structural geometry evidence. The report does not call this an
identical gameplay state: geometry already differs. After the first different
chosen move, all subsequent aligned indices are marked
`POST_DIVERGENCE_DESCRIPTIVE_ONLY`, even if visible lists later coincide.
Ending one trace is an unmatched tail, not an invented different move or legal
set. A null event means none observed in the compared prefix, not proven
agreement beyond incomplete evidence.

Static graph comparisons retain all lower/upper ID edge differences on the
initial intact board, same-layer counts, edge counts and maximum blocker-chain
length. Overlap ratios and dimensions are retained separately. This isolates
structural dependencies from strategy behavior without replaying a privileged
solution. Per-decision remaining IDs permit inspection of which of those edges
are still active. These diagnostics do not grant the agents hidden symbols.

Attempt metrics and complete decision traces include:

- Legal public tokens, actual candidate priorities and chosen public token.
- Candidate one-step tray occupancy, immediate loss and triple completion.
- Tray symbols before the tap, occupancy before/after resolution, pressure
  (occupancy / 7), per-attempt mean post-resolution pressure and transient peak.
- First **available triple**: at least three of a type among exposed+tray tiles,
  measured before a real decision. This is availability, not a completed match.
- First **immediate triple**: a selectable tile has two same-type tray tiles.
- First **resolved triple**: engine matched-count increases after the actual tap.
- First **high-risk state**: pre-decision tray occupancy >=6. A terminal loss at
  occupancy 7 has no subsequent decision; it remains visible in after metrics.
- At every root/internal ranking, public hypothetical path, ordered tokens,
  priority domain/value, greedy score fields and branch-cap membership. A
  `within_branch_cap` entry is eligible by ordering, not a claim it was expanded
  if a separately reduced node budget interrupts traversal.
- Expanded actions, pruned branch options, exhausted-budget flag, and newly
  selectable public tokens measured **after** the real tap. These reveals are
  not predictions and are never fed backward into the plan that selected it.

The Markdown report includes per-cell totals and every replica pair, first
divergences, tray peaks/mean pressure, first available triples and high-risk
indices. JSON retains full metrics and all intermediate ranking/trace details;
`focus_level_evidence` points to pruning/reveal decisions for levels 84 and 96.
All event indices are zero-based; the historical `moves_to_first_triple` is
one-based successful move count and must not be compared without conversion.

## Evidence-based limitations: levels 84 and 96

The following are **read-only historical observations**, not outcomes from the
new paired mode. Source: `qa/campaign_validation_runs/20261104T215452428949Z-25028/`
(`manifest.json`, `baseline.jsonl`, `attempts.jsonl`). That completed run contains
300/300 successful baselines, 2160 behavioral attempts, 741 wins, 1419 losses,
and zero inconclusive attempts. Both focus levels have 0 wins / 90 losses across
three screens × three strategies × ten historical seeds. Those seeds mix screen
and strategy identity, so their outcome differences are not paired effects.

| Level | Screen | Initial selectable | Initial available triples | Blocker chain | Same-/cross-layer edges |
|---|---|---:|---:|---:|---:|
| 84 | small | 3 | 0 | 26 | 133 / 838 |
| 84 | medium | 6 | 0 | 20 | 109 / 674 |
| 84 | tall | 6 | 0 | 20 | 108 / 664 |
| 96 | small | 6 | 0 | 31 | 164 / 1017 |
| 96 | medium | 6 | 0 | 31 | 164 / 852 |
| 96 | tall | 6 | 0 | 31 | 164 / 840 |

Historical **visibleLookahead** totals over ten attempts per row:

| Level | Screen | Actual decisions | Decisions without exposed+tray complete set | Pruned options | Expanded actions | Budget-exhausted decisions |
|---|---|---:|---:|---:|---:|---:|
| 84 | small | 94 | 83 | 4 | 1776 | 0 |
| 84 | medium | 244 | 158 | 766 | 12848 | 0 |
| 84 | tall | 124 | 95 | 320 | 5869 | 0 |
| 96 | small | 70 | 70 | 98 | 3242 | 0 |
| 96 | medium | 70 | 70 | 107 | 3166 | 0 |
| 96 | tall | 70 | 70 | 128 | 3313 | 0 |

Source inspection of `decideCampaignMove`, `_rankedMoves`, `_greedyCompare`,
`_PlanValue` and `CampaignObservation.capture` establishes:

1. **Depth 3 / branch 4 / expansions 84.** These are actual constants; 84 is
   4+16+64, the full expanded-action bound of the pruned tree. Ranking evaluates
   every selectable candidate in a node before keeping four. Historical focus
   attempts did not exhaust that bound. This does not mean pruning was harmless
   or that the full unpruned search was explored.
2. **Greedy ordering restricts search.** Nonlosing moves precede losses, then
   lower resulting tray occupancy, more tray matches, and more exposed same-type
   tiles. Only ties use randomization. A move with no immediate match but useful
   future information can rank outside the four branches. Level 84 medium/tall
   exhibit substantial observed pruning; level 84 small has just four omitted
   branch options across all ten runs, so pruning volume alone is an inadequate
   explanation for its ten losses. Level 96 has pruning on all three screens.
   The old traces do not identify which omitted alternative would have won;
   the paired traces now preserve ordering and candidates for review.
3. **Revealing covered tiles has no modeled information value.** Projections
   contain only the currently exposed tiles and tray; tapping them in a plan
   never introduces a covered tile. Projected `won` only ends that visible
   subset and gives no victory bonus. On level 96 all 210 historical lookahead
   decisions across all screens lack an exposed+tray complete set, and every
   attempt loses after seven taps without one resolved triple. With no complete
   type in the projection, deeper enumeration of that same projection cannot
   manufacture a match. Planning can still avoid immediate losses and rank tray
   counts, but cannot value the unknown symbols a tap may reveal. This is strong
   evidence of a blind spot on those observed paths, not proof that any specific
   reveal-aware policy would win or that humans necessarily read the hidden tile.
4. **Level 84 also frequently lacks projected matches.** The initial small
   screen exposes drop/gem/carrot; medium/tall add two suns and another carrot,
   still without a triple. Historical small lookahead resolves a triple in only
   two of ten attempts. No-complete-set states dominate all screen samples.
   Exposure scarcity and absent reveal modeling are therefore relevant, while
   medium/tall also show branch restriction. Their separate causal contributions
   cannot be estimated from these historical traces alone.
5. **No partial visibility or persistent memory.** Covered symbols are omitted
   even if artwork might expose part of them; the tool has not verified visual
   readability. There is no belief state, remembered blocked symbol, reveal
   history or learned move value. Historical RNG state is not player memory;
   the paired index and seed are experiment state, not information about tiles.
   The current traces cannot quantify how much real players benefit from those
   omitted abilities.

Greater depth cannot fix missing information, nor does blocker-chain length
directly specify a necessary planning depth. Historical successful witnesses
establish existence only; they do not establish practical human fairness. Bot
losses, even 0/90, do not justify level changes without better evidence.

## Optional follow-up design — not implemented

- **Geometry-only comparison:** compare the same intact board and static
  dependency edges, then predeclare identical physical tap prefixes that remain
  legal on both geometries; stop at the first eligibility difference. This
  separates geometry from action-selection drift. Any privileged prefix must
  be labeled a structural diagnostic, never fed into behavioral policies.
- **Controlled branch cap:** a new experiment version could vary only cap
  4 versus a predeclared alternative while retaining exposed-only information,
  actual priorities, leaf scores and depth. Explicitly budget expansions for
  each cap and report selection changes/pruned candidates. The present experiment
  neither runs nor automatically schedules that sample.
- **Player-visible blocked-symbol model:** first verify readability on the
  actual artwork and screen sizes through UI evidence/human review. Only then
  specify a visibility mask and expose symbols verified readable, with no
  underlying authoring identities or constructive witness leakage. Unreadable
  content stays unknown; memory would require a separate version and evaluation.
- **Candidate level 96 refinement:** after paired evidence and approved design,
  investigate an early readable route to a triple or an informative reveal,
  checking that it remains accessible across all three geometries. This is a
  hypothesis, not an instruction to alter symbols or layout now.
- **Candidate level 84 refinement:** investigate early exposure consistency on
  small screens and whether the initial reveal choices provide understandable
  progression. Do not infer an exact edit from the current bot win rates.
- **Before/after evaluation:** retain immutable original levels, use a separate
  approved level branch and experiment version, reuse a predeclared paired key
  mapping where public tokens remain comparable, and report changed tokens,
  geometry, baseline validity, outcome pairs, pressure and human playtest
  evidence. Repositioned/retargeted tiles invalidate exact token pairing and
  must be reported. No balancing or human fairness claim precedes that review.

## Added contracts and remaining limits

Contracts cover cross-screen priorities, enumeration/handle independence,
hidden-identity isolation, no RNG-stream drift, separate plan priorities,
unchanged depth/branch bounds and greedy safety, observer transparency,
byte-identical repeated traces, real engine/coverage agreement, high-risk/loss
metrics, budget cutoffs, real geometry-set divergence, post-move attribution,
missing pairs/tails, outcome aggregation, invalid pairing/duplicate rejection,
and stored historical attempt replay. Existing tests remain intact.

Paired randomization removes a source of noise, not all confounding. Geometry
changes eligibility and visible counts; scores and branch membership can then
change. Subsequent paths may diverge, and equal decision indices need not imply
equal remaining inventories or knowledge. Ten deterministic replicas describe
this fixed heuristic sample; no independence assumption, confidence interval,
human win rate or calibrated difficulty score is asserted. Priorities reproduce
for identical public tokens; display rounding and a human partial-visibility
model are outside this version. Compile/runtime behavior remains unverified
until the local commands are executed.
