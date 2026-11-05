# Phase 4D-4 read-only diagnostic

This Python 3.11+ standard-library tool analyzes the **existing** Phase 4D-3
360-attempt evidence. It neither calls Flutter/GameEngine nor executes an agent,
solver, alternate trajectory, new A/B cohort or proposed swap. Run from the project
root. The existing Flutter shadow contract suite is a separate required check.

```powershell
python -B -m unittest discover -s test/balance_audit -p test_level96_post_opening.py -v
flutter test test/balance_audit/level96_shadow_contract_test.dart --concurrency=1 --reporter=expanded
flutter analyze --no-pub
git diff --check
python -B test/balance_audit/level96_post_opening.py --verify-repeat
```

The default input is the latest `COMPLETE` / `OK` Phase 4D-3 manifest by
`finished_utc`. Invalid selected evidence causes an error, not fallback to an
older run. To reproduce this investigation after additional runs exist:

```powershell
python -B test/balance_audit/level96_post_opening.py --source qa/campaign_validation_runs/shadow96-20261105T102737023052Z-30288-562eae3b --verify-repeat
```

Every invocation creates a new uniquely named directory under
`qa/campaign_validation_runs/phase4d4-level96-*`. It writes exactly `report.md`,
`summary.json`, `failure_clusters.json` and `manifest.json`. It never overwrites
an evidence directory. `--validation-json PATH` embeds separately obtained test,
analyzer and integrity-check results; it does not execute those commands or infer
that they passed. Without it the manifest explicitly records null validation.

## Evidence and proof boundary

- Check all 360 complete actual traces, including public candidates, seeds,
  priorities, stored ranking nodes, eligibility, tray arithmetic, newly exposed
  tiles and outcomes. Preserve 0–9 overlap and 10–29 holdout labels.
- Reconstruct only the already-recorded 094/095 candidate in a diagnostic data
  model. No proposed future swap is applied, even to that model.
- Use exact remaining tile IDs, ordered tray IDs, symbol version and complete
  recorded geometry as physical state identity. Intern geometry by exact full
  values. SHA-256 state IDs are display references scoped to this source run.
  Seeds, strategies and move counts are not physical-state identity fields.
- A recorded winning continuation can join transitions from different attempts
  only at the same exact state. Each edge includes its original attempt and tap.
  This is reachability over stored transitions, not a newly simulated bot path.
- A forced-loss certificate requires all legal actions to be immediately fatal,
  or to have an observed successor already proved losing. Unobserved branches
  remain unknown. The certificates here prove terminal immediate traps only.
- Covered symbol/blocker identities are explicitly privileged analyst evidence.
  Agents receive no new information; this analysis does not invoke them.
- Future swap rankings measure immediate relief at a **frozen recorded state**.
  They predict neither wins nor human fairness. Earlier policy choices, witness
  viability and later challenge remain untested after a proposed swap.

`--verify-repeat` requires byte-identical regenerated summary, cluster and
Markdown payloads. The manifest deliberately varies by creation time/output
location and records input/output SHA-256 hashes plus an executable diagnostic
source snapshot. Tests also reverse input row enumeration and verify that output
is unchanged, check edge provenance and confirm historical files remain intact.

All 30 replicas were inspected during proposal discovery. A later experiment
using those seeds is exploratory regression evidence; replicas 10–29 must not be
presented as an unseen holdout for a proposal designed using this report.
