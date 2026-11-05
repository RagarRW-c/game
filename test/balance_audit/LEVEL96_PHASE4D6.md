# Phase 4D-6 — read-only regression and failure migration diagnostic

Requires Python 3.11+ and only the standard library. Run from the Flutter project
root. No new agent, policy search, candidate, A/B cohort or gameplay edit is made.

The source is pinned, without fallback or alternate-source CLI options:

`qa/campaign_validation_runs/phase4d5-level96-20261105T114207305023Z-34520-a437c264/`

The loader verifies the exact identity, COMPLETE/OK status, four artifact SHA-256
pins, historical artifact FNV fingerprints, current behavior/tool input hashes,
source snapshots, all correctness/reproduction gates, 360 unique rows, 180 pairs,
replicas 30–59, 3 geometries, 2 strategies, two correct in-memory symbol maps and
all 14,054 recorded decisions. Source summary/group counts are recomputed.

## Run diagnostics

```powershell
python -B test/balance_audit/level96_phase4d6_diagnostic.py --verify-repeat
```

This creates a unique `qa/campaign_validation_runs/phase4d6-level96-*` directory
containing exactly `manifest.json`, `summary.json`, `report.md`,
`regression_cases.json` and `cluster_migration.json`. It never overwrites an
existing run. `--validation-json PATH` optionally embeds independently collected
validation results. Without it, validation is recorded as null, not assumed.

The four analytical payloads are byte-identical on regeneration, including after
input row enumeration is reversed. Manifest timestamp/destination metadata may
differ. Input hashes are checked before and after reporting. Source snapshots and
the unchanged trace-validation dependency are included in the manifest.

## Methodology and boundaries

- Actual Phase 4D-5 identities are validated first. The existing Phase 4D-4
  `validate_trace` is reused only for recorded arithmetic, eligibility, reveal,
  candidate and planner-ranking consistency. A shallow copied envelope supplies
  its obsolete shadow/cohort labels; original rows, seeds, replicas, public
  tokens, trajectories and symbol maps are unchanged. This explicit adapter
  does not change the experiment methodology or feed data into an agent.
- Exact physical identity uses geometry, remaining IDs and ordered tray IDs.
  Exact mechanical identity additionally includes symbols of every live tile.
  Arms may join only when the complete mechanical keys agree. Merely equal
  physical layouts may still differ in symbols and resolution effects.
- Actual terminal-state counts refer to the state after the losing tap. Pre-loss
  physical counts and public symbol/tray patterns are reported separately.
  Public patterns collapse IDs/positions, and are not physical equality.
- Unordered tray matches are a separate association, never called exact ordered
  states. Geometry is always included in physical/mechanical equality. Identical
  ID sequences on different screens are correlated paths, not identical boards.
- Immediate-loss proofs cover every recorded legal action at a reached state.
  A merely legal/safe earlier alternative proves neither eventual safety nor a
  win. Winning-continuation certificates use only actual recorded edges joined
  at exact mechanical states, with source attempt/tap provenance for every edge.
  Missing branches remain unknown; no new trajectory is simulated.
- Public observations/previews and analyst-only IDs, covered types and blocking
  dependencies have separate report fields. Privileged data never enters policy
  selection; this Python analysis invokes no policy.
- Fixed paired results support effects of the symbol intervention under these
  exact policies/keys. They cannot isolate depth, pruning, hidden information,
  heuristic scoring and tie-break contributions without another intervention.
- The original acceptance result remains REVISE. Option B means retain the
  existing in-memory two-swap candidate for targeted human review, not production
  adoption or retrospective relaxation of acceptance rules. Phase 4D-7 is not
  launched. Replicas 30–59 are now inspected and cannot be a fresh future holdout.

## Required validation

```powershell
python -B -m unittest discover -s test/balance_audit -p test_level96_phase4d6_diagnostic.py -v
python -B -m unittest discover -s test/balance_audit -p test_level96_post_opening.py -v
flutter test test/balance_audit/level96_phase4d5_contract_test.dart --no-pub --concurrency=1 --reporter=expanded
flutter test test/balance_audit/level96_shadow_contract_test.dart --no-pub --concurrency=1 --reporter=expanded
flutter analyze --no-pub
git diff --check
```

The Flutter commands run the explicitly required existing contracts (stored
witnesses, historical traces and synthetic fixtures); neither opt-in experiment
runner is invoked. Compare analyzer findings with the baseline and report
pre-existing findings separately. Verify JSON parseability, cohort and migration
totals, certificate provenance, input immutability and repeat payload hashes.
