# Phase 4D-5 — Level 96 second shadow A/B

Implementation only until the opt-in command below is manually invoked. Ordinary
test discovery skips the runner before allocating output or executing its gates.

## Fixed experiment

- Control A: independently copy untouched production Level 96; change T094
  heart to star and T095 star to heart.
- Candidate B: independently copy the same production input; apply the A swaps
  plus T071 banana to heart and T069 heart to banana. Never derive B from A.
- Three existing Campaign geometries: 320x568, 360x800, 412x915.
- Unmodified GreedyMatch and VisibleLookahead through `simulatePairedCampaign`.
- Replicas **30–59 inclusive** in every cell; 2 arms × 3 screens × 2 strategies
  × 30 replicas = **360 attempts**, with 180 A/B pairs. All are `unseen_30_59`.
- Paired-v1 seed/priority namespace is unchanged. Variant, strategy and screen
  are not added to seed/priority keys. No hidden tile data enters policy inputs.
- No retries, automatic sample expansion, parameter tuning, booster use or
  witness search. A 30-minute guard between attempts preserves partial evidence;
  test timeout is 35 minutes. Unverified attempts stop the schedule.

## Mandatory gates before new-cohort attempts

1. Pin the reviewed COMPLETE/OK Phase 4D-3 and Phase 4D-4 artifacts. Check current
   behavior fingerprints against historical inputs, including production Level
   96 (`2b2b8578`). Missing or changed inputs fail closed.
2. Check exact symbol changes, inventory, order, metadata, non-type fields,
   independent object ownership, blocking graphs and bounds against production.
3. Replay all three original stored witnesses in both arms using the real engine.
   All six must fully clear; record exact first-failure diagnostics otherwise.
4. Check repeatable single opening decisions at replicas 30, 44 and 59 for both
   strategies and every geometry. B's additional changed symbols are hidden:
   public observations and decisions must equal A. This plays no full trajectory.
5. Reproduce six historical **replica-24** Phase 4D-3 candidate rows using A,
   comparing the entire paired-v1 row including every trace field. These checks
   are separate preflight regressions, not part of the new 360-attempt cohort.
6. Verify all model inputs remain unchanged after preflight and every attempt;
   recheck input, tool and historical artifact fingerprints at completion.

Fingerprints use the existing explicitly non-cryptographic FNV-1a32 methodology.
The manifest records current tools/behavior source snapshots, pinned evidence,
SDK/Git provenance, exact acceptance rules, seeds, schedule, gates and errors.

## Predeclared acceptance (phase4d5-acceptance-v1)

Order matters; the code stores these rules in every report and initial manifest.

1. A measured correctness gate failure: **REJECT**; zero new attempts.
2. Missing gates, incomplete coverage, drift or unverified results: **REVISE**
   measurement, with no balance conclusion.
3. B must retain first triple at tap 3 in all 180 attempts and have no losses at
   or before tap 7. Otherwise **REJECT** the opening regression.
4. If neither total wins increase nor tap-31 losses decrease: **REJECT**.
5. **ACCEPT FOR HUMAN REVIEW** requires all of: more B wins overall and on each
   screen; fewer tap-31 losses overall and no screen increase; zero A-win/B-loss
   regressions; zero earlier B losses in pairs where both lose; no B cell at
   30/30 wins. All other mixed outcomes: **REVISE**.

These conservative descriptive rules are not significance thresholds or a human
difficulty calibration. The 30/30 condition flags challenge for review; it does
not prove the level is too easy. Inspect full loss distributions and late traps,
not just the targeted tap count. Identical loss taps do not prove identical
physical states. Witness failure does not prove unsolvability. No recommendation
authorizes production edits.

Replicas 0–29 were inspected during Phase 4D-4 discovery. They are excluded from
the confirmation cohort; the historical replay checks cannot be pooled into its
win rates. New seeds are paired across screens and strategies, so observations
are correlated. Bot completion is never reported as human win probability.

## Validation (does not run the new cohort)

```powershell
flutter test test/balance_audit/level96_phase4d5_contract_test.dart --no-pub --concurrency=1 --reporter=expanded
flutter test test/balance_audit/level96_shadow_contract_test.dart --no-pub --concurrency=1 --reporter=expanded
python -B -m unittest discover -s test/balance_audit -p test_level96_post_opening.py -v
flutter analyze --no-pub
git diff --check
```

New contracts use stored witnesses, historical replica 24, isolated single-step
decisions and synthetic reporting fixtures. They do not execute the new 360
attempts or inspect full 30–59 trajectories.

## Manual execution only

```powershell
flutter test test/balance_audit/level96_phase4d5_run_test.dart --no-pub --dart-define=CAMPAIGN_LEVEL96_PHASE4D5=true --concurrency=1 --reporter=expanded
```

Every enabled invocation allocates a fresh directory
`qa/campaign_validation_runs/phase4d5-level96-<timestamp>-<pid>-<unique>/`.
It contains `manifest.json`, `attempts.jsonl`, `summary.json` and `report.md`.
Complete actual decision traces are streamed and flushed after each attempt.
The summary includes all cells, screens, strategies, pressure statistics, loss
clusters, paired regressions, physical/public divergence and strategy comparisons.
Gate failures, partial runs and reporting failures retain diagnostic artifacts;
historical files are never overwritten.
