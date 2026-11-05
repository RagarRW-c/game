# Phase 4D-3 — Level 96 shadow balance experiment

This adds an isolated, opt-in A/B runner for **Campaign level 96 only**. It does
not edit production Dart, level JSON, rules, overlap threshold, the seven-slot
tray, boosters, economy, UI, animations, sounds, Golden baselines, historical
results, Classic Endless or Endless Battle. Existing validation implementations
and tests are unchanged. No commits or pushes are part of this experiment.

**Execution status:** this implementation has not been compiled, tested or
simulated by its author. Only source inspection, read-only inspection of the
existing runs, Dart formatting and scoped change checks were performed. New
candidate outcomes, witness success and a balance recommendation remain
**UNVERIFIED until local execution**. No new run artifacts are supplied as if
they were measured results.

## Local execution

Run from the repository root with the installed project Flutter SDK:

```powershell
flutter test test/balance_audit/level96_shadow_contract_test.dart --concurrency=1 --reporter=expanded
flutter test test/balance_audit/level96_shadow_run_test.dart --dart-define=CAMPAIGN_LEVEL96_SHADOW=true --concurrency=1 --reporter=expanded
```

Existing suites can also be run without changing their tests or sample sizes:

```powershell
flutter test test/balance_audit/campaign_validation_contract_test.dart test/balance_audit/campaign_paired_contract_test.dart --concurrency=1 --reporter=expanded
```

The shadow runner is skipped without `CAMPAIGN_LEVEL96_SHADOW=true`. No level,
replica, strategy, candidate or reference override is accepted. The old paired
runner remains 990 attempts with ten replicas; it is not extended or invoked by
this experiment. The two historical directories below must be present; no
automatic discovery of a newer run, fallback baseline or replacement witness
is allowed.

## Control, candidate and fixed sources

Control is the original `assets/levels/level_96.json`. Its expected byte-level
FNV-1a32 fingerprint is **`2b2b8578`**, also recorded before and after both
historical runs. The current file has 99 tiles and no objective. Runtime code
nevertheless preserves and checks an objective if present in a valid input.
The immutable input version must not drift under this experiment identifier.

Candidate creation accepts only level 96 with the expected two original types:

| Tile ID | Control | In-memory candidate |
|---|---|---|
| L96_T094 | heart | star |
| L96_T095 | star | heart |

`makeLevel96Candidate` creates a new `LevelDefinition`, a new unmodifiable tile
list and a new `Tile` for every entry. IDs, x/y, layer, state, tile order, level
number/name/time bonus and objective values remain equal. No list is shared
with the control; independent immutable tile objects are used as well. The
full type inventory, tile count and exact two changed IDs are checked. Level
metadata ignored by the production `LevelDefinition` parser, such as the JSON
layout label, stays untouched in the source file and its original snapshot;
neither arm rewrites or reinterprets that JSON metadata.

There is **no modified production asset**, candidate file export or alternate
GameEngine. The manifest stores the original input and declarative swap, not a
replacement asset. Report traces naturally contain observed candidate symbols.

The fixed paired reference is:

```text
qa/campaign_validation_runs/paired-20261105T085938901757Z-32484-15d06b81/
  manifest.json
  paired_attempts.jsonl
```

Read-only inspection established that its manifest is COMPLETE / OK with 990
attempts. For level 96, each of the six screen/strategy cells below has **0 wins,
10 losses, zero inconclusive, and ten losses after exactly seven taps**. Thus
all **60** selected historical informed-agent attempts lost at seven taps. These
are historical observations, not candidate or holdout results.

Historical witnesses come from:

```text
qa/campaign_validation_runs/20261104T215452428949Z-25028/
  manifest.json
  baseline.jsonl
```

The loader reads the actual recorded level 96 `witness.path_ids` for each screen,
requiring REPLAYED and full-clearance source evidence. Each stored path contains
99 IDs, beginning L96_T098, L96_T097, L96_T096, L96_T095, L96_T094, L96_T093. The
runner does not regenerate a witness from the candidate, search for a new one,
or supply the witness to behavioral agents.

## Gates before A/B comparison

1. **Reference/input gate.** Require the completed healthy paired-v1 manifest,
   60 unique in-scope reference rows with traces, three recorded witnesses and
   the original level fingerprint. Compare current engine, tile, level, geometry,
   paired policy, shared policy, supporting helpers and dependency files with
   the paired run's before/after fingerprints. If anything differs, stop and
   record the mismatch; do not silently bless a new baseline. SDK versions are
   recorded independently, with exact trace reproduction providing the runtime
   behavioral gate rather than asserting SDK equivalence.
2. **Invariant and solvability gate.** Check independent copies, exactly the
   two specified type changes, metadata/order equality and equal type counts.
   On all three existing Campaign geometries, compare the entire blocking
   graph including overlap ratios, dimensions, depths and same-layer counts;
   compare all tile rectangles and require no out-of-bounds tile. Replay the
   stored witness on both arms using real `GameEngine.tapTile`, checking cached
   coverage against the engine before every move. Success requires engine win,
   empty board, empty tray, every tile matched and any objective complete.
3. **Historical control gate.** Run all 180 controls first. Within those runs,
   compare all **60 overlap attempts** (replicas 0–9) with historical rows. Strip
   only the new wrapper's variant/cohort/shadow-version fields and compare the
   entire paired-v1 result, including every decision, priority, candidate set,
   ranking and trace. JSON object-key ordering is irrelevant, arrays and values
   are exact. Outcomes matching while traces differ is a failed gate. No
   candidate attempt starts unless all 60 required cells reproduced exactly.

Six witness replay results, successful/winning paths, tile count, pre-resolution
and post-resolution tray peaks, full per-move witness traces, inventories,
graphs, rectangles and bounds are retained in the manifest/summary. All three
screens are checked even if one witness fails. The first failure records its
requested tile, legal IDs, tray IDs/types, remaining board count and engine
state; the failing move's post-state is in the trace when a tap succeeded.

On candidate witness failure, inspect that failure against the control at the
same recorded path index. No behavioral attempt is permitted, the run is
GATE_FAILED and the candidate is rejected for this comparison pending
investigation. **Failed witness does not prove unsolvability**. There is no
automatic alternate witness, solver search, booster use or rule relaxation.

## Fixed behavioral experiment

| Axis | Values |
|---|---|
| Version/arm | control, candidate |
| Screen | small_320x568, medium_360x800, tall_412x915 |
| Strategy | greedyMatch, visibleLookahead |
| Replica | 0–29 |
| Total planned attempts | **2 × 3 × 2 × 30 = 360** |
| Historical overlap | 0–9, 120 A/B attempts / 60 pairs |
| Additional holdout | 10–29, 240 A/B attempts / 120 pairs |

These are the existing geometry helper's Campaign boards: 300×360, 340×538 and
392×620, with tile sides 51.2, 57.6 and 65.92 respectively. Geometry remains
fixed for each attempt and identical between arms on the same screen.

The implementation delegates directly to unchanged `simulatePairedCampaign`.
The experiment wrapper version is `campaign4d3/level96-shadow-v1`; the decision
policy and randomization namespace remain **`campaign4d2/paired-v1`**. Neither
the variant identifier nor the shadow experiment version enters priorities.

The exact existing scheme is:

```text
V = "campaign4d2/paired-v1"; L = 96; R = replica; D = zero-based actual decision
seed = FNV1a32(UTF8(compactJSON([V,L,R])))
actual priority = FNV1a32(UTF8(compactJSON([V,L,R,D,"actual",[],token])))
plan priority = FNV1a32(UTF8(compactJSON([V,L,R,D,"plan",publicPlannedPath,token])))
token = compactJSON([visibleType, normalizedXString, normalizedYString])
```

Normalized coordinates use the existing `double.toString` representation with
signed zero normalized. Lower unsigned priority wins, then token lexicographic
order for hash ties. No screen, strategy, authoring ID, hidden identity, witness
or RNG stream is part of that key. The seed is the digest of the full experiment
key; priorities hash the full key rather than just its digest. Replicas 10–29
use the same function, not a new namespace.

Unchanged visible tokens retain their priorities across arms. A changed truly
visible heart/star token can legitimately receive a different priority. The
agents still receive only selectable tiles and tray symbols; hidden tile 94's
future type cannot influence their preceding decisions. Diagnostic IDs and
graphs are held outside the policy boundary.

Greedy scoring remains nonloss, lower post-tap tray occupancy, more same-type
tray symbols, then more exposed same-type symbols. Lookahead retains depth 3,
branch cap 4, maximum 84 expanded actions and its existing leaf score / first
equal leaf behavior. No future reveals, partial-visibility model, persistent
memory or planning improvement is introduced.

The deterministic move budget is the original tile count. A 30-minute wall
guard checks between attempts; the test timeout is 35 minutes. Reference reads
and gates consume wall time too. No automatic retry, sample expansion or
additional behavioral baseline is run. The control reproduction checks reuse
the controls within the 360; they are not 60 extra experiment attempts.
Contract tests are separate verification fixtures and may replay those controls
and selected candidate traces; they do not write experiment results or expand
the runner's cohort.

## Comparison semantics and metrics

The report contains 180 control/candidate replica pairs, six screen/strategy
cells with overlap, holdout and combined summaries (18 rows), per-screen totals
and holdout win changes, and 180 greedy/lookahead comparisons across both arms.
These reuse the same 360 attempts. Missing pairs and inconclusive attempts are
explicit and never counted as wins or losses. Completion rates use all attempts
in the cell; incomplete cohorts cannot support acceptance.

Physical IDs and public tokens are deliberately separate:

- **Physical legal-set difference:** different selectable actual tile IDs.
- **Public legal-set difference:** different visible symbol/position tokens,
  which can occur immediately from this swap without an eligibility change.
- **Chosen physical move difference:** different tapped actual tile IDs.
- **Chosen public-token difference:** possibly the same physical tile with a
  changed type; this alone does not break the shared physical tap prefix.
- **Reveal difference:** different public tokens becoming selectable after the
  actual taps. The report distinguishes the same tap from a shared physical
  prefix from reveals following different chosen taps/histories. It does not
  feed post-tap information back into the plan that selected that tap.

Equal physical prefixes do not assert identical symbol/tray states. Once
different physical tiles are selected (or remaining/tray IDs differ), all later
aligned decisions are marked `POST_DIVERGENCE_DESCRIPTIVE_ONLY`, even if they
later converge. An ended trace is a missing tail, not an invented divergent
move. Blocking graphs must be exactly equal initially; later legal-set
differences can result from different removals and must not be attributed to
changed geometry. Identical remaining tiles and the identical graph imply
identical structural reveal opportunities, while revealed types may differ.

Per-attempt and paired output records:

- Wins, losses, inconclusive reasons, all replica outcome pairs and the 3×3
  outcome matrix per combined screen/strategy cell.
- First physical/public legal-set divergence, first physical/public chosen-move
  divergence, first reveal-token difference, every differing decision and its
  attribution boundary.
- First completed triple (one-based tap, derived from the zero-based trace
  event), first available triple and first high-risk state (zero-based
  pre-decision tray occupancy >=6).
- Pre-resolution/transient and post-resolution tray peaks, mean pressure
  (post-resolution occupancy / 7), per-cell decision-weighted pressure.
- Loss after **exactly seven** successful taps, loss after the opening, loss
  after any completed triple, remaining board count and terminal loss context.
- After the first seven taps: later decision count, tray peak and mean pressure,
  all high-risk indices and indices with immediate losing options.
- Candidate cases worse on recorded measures: control win→candidate loss,
  earlier loss when both lose, loss of an early triple, newly observed seven-tap
  loss, earlier high risk, later first triple, higher peak and mean pressure.
  Pressure and survival comparisons are path-dependent, not scalar design scores.

The operational **opening-trap-removed** condition is deliberately strict:
complete, healthy evidence and every one of 180 candidate attempts completes
a triple by tap 7, with zero seven-tap losses. Otherwise the condition is false
(or null/UNVERIFIED for incomplete evidence). Merely surviving seven taps or
winning more often is not enough. It is a statement about this fixed agent
sample, not proof that all possible human opening choices are safe.

Candidate failures later in the level are reported as remaining problematic
attempts, with terminal context and post-opening decision indices. If control
already failed at the opening, a candidate's newly reached later loss is not
evidence that the swap introduced a new trap there. Comparing those paths does
not establish causality or prove the absence of unsampled traps. Full ranking
and branch data remain in attempts.jsonl for inspection.

## Predeclared recommendation policy

The report emits exactly one requested recommendation with its reason:

1. **REJECT** when a measured invariant/witness gate fails. This rejects the
   candidate for the proposed experiment, without an unsolvability claim.
2. **REVISE** when evidence is incomplete, inputs drift, or exact historical
   reproduction fails. This means repair measurement, not change production.
3. **REVISE** if any paired control win becomes a candidate loss.
4. **REJECT** when complete evidence does not show both a reduction in
   seven-tap losses and an increase in triples completed by tap 7.
   Both improvements are required by this opening-focused candidate hypothesis.
5. Otherwise **ACCEPT FOR HUMAN REVIEW** only if the opening condition above
   holds, holdout wins improve on every screen (pooling the two strategies per
   screen), and no screen/strategy cell wins all 30 candidate attempts.
6. All other complete cases receive **REVISE**, with the unmet screening
   conditions exposed in the report and summary.

A fully winning cell is a conservative flag to inspect possible over-easing,
not proof of trivial human difficulty. There is no calibrated human win-rate
target or arbitrary claim that a specific bot rate is ideal. Remaining losses
and metric regressions are still listed even on acceptance. More wins alone
do not imply better design; level 96 should remain challenging. Recommendations
**never authorize writing a production level**.

## Artifacts and provenance

Each invocation atomically allocates a new unique directory:

```text
qa/campaign_validation_runs/shadow96-<UTC timestamp>-<pid>-<unique suffix>/
  manifest.json
  attempts.jsonl
  summary.json
  report.md
```

The output API cannot reopen an existing run and accepts only the expected
artifact names. Every attempt is flushed separately. Only files inside this
newly allocated directory are written; old balance reports and historical run
files are read-only. No candidate is serialized as a production asset.

The manifest contains definitions, explicit scope, Git HEAD and scoped dirty
status, Flutter version-file contents, Dart runtime version, screen geometry,
unchanged policy/seed specification, cohort/budgets, full original scoped input
snapshots, before/after fingerprints, six replay gates, 60 full-row reproduction
comparisons, reference rows/witnesses/provenance, completion and health status.
Historical JSONL is read and fingerprinted incrementally to avoid retaining its
entire hundreds-of-MB file in memory. FNV fingerprints detect accidental drift;
they are not cryptographic attestations. Preserve the recorded SDK and lockfile
as well as the retained source snapshots for reproduction.

COMPLETE describes all 360 recorded attempts, not human fairness. INCONCLUSIVE
attempts cause REVIEW_REQUIRED. A failed gate yields GATE_FAILED and stops
dependent work; exceptions yield FAILED, and time-limited coverage is PARTIAL.
Ordinary heuristic losses do not fail the execution health assertion. Reports
are still written for caught gate/input/attempt failures, with unmeasured fields
identified. A hard process kill or test timeout can leave RUNNING/incomplete
artifacts; do not treat them as complete and do not resume into that directory.

## Contract coverage and files

- `support/level96_shadow.dart`: isolated copy/invariants, real-engine stored
  witness replay, gate, unchanged-policy wrapper, exact historical comparison.
- `support/level96_shadow_io.dart`: fixed reference loading/provenance checks,
  bounded-memory file hashing, exclusive new-directory output interface.
- `support/level96_shadow_report.dart`: physical/public divergence distinctions,
  cohorts, later difficulty, regressions and conservative recommendation.
- `level96_shadow_run_test.dart`: opt-in gated experiment, 360 fixed attempts.
- `level96_shadow_contract_test.dart`: original byte fingerprint and immutability,
  independent copies/exact swap, inventory/geometry/bounds equality, six safe
  witness replays, explicit bad-witness diagnostics, all 60 historical control
  traces, reference drift detection, paired holdout priorities, hidden-identity
  isolation, deterministic candidate traces and unchanged delegation, report
  boundaries/cohort accounting/recommendation rules, and non-overwriting output.

The output contract writes only a fresh temporary test directory, with a mock
historical sentinel; it never writes actual historical runs. Existing tests and
the paired-v1 implementation remain untouched. Runtime/test results remain
unverified until the local commands are executed.
