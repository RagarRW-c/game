# Boss balance pass 1

Implementation complete; **local verification pending**. Only bosses **70 and 80**
were edited. No Flutter tests, builds, analyzer, balance audit scripts, emulator,
ADB or screenshots were run. Source inspection and the supplied measured audit
guided the changes; file fingerprints were captured to freeze the scope.

## Evidence and execution boundary

The original campaign measurements are dated **2026-10-21T10:57:10.004562Z**.
All ten original bosses are reported SOLVED on all three geometries, using
engine-replayed reverse paint order. Those are historical results for the
original inputs, not new verification of the edited assets.

The working tree initially contained a modified pubspec.lock and untracked IDE,
campaign/Endless/Garden report and QA-result files. These were preserved. The
verified Garden pass was already committed; no part of it was restarted.
The supplied qa/BALANCE_AUDIT.md and measured JSON remain unchanged.

The frozen fixture `test/qa/fixtures/boss_balance_before.json` contains:
- All ten complete original boss assets.
- Existing measured geometry, witness metrics, score components and solver
  status/reason for each boss and its preceding three normal levels (40 levels,
  120 geometry rows).
- FNV-1a UTF-8 fingerprints of all 90 normal assets, normalizing CRLF to LF to
  avoid checkout-only failures. These guard content, not cryptographic security.

## Review of all ten bosses

Screen order throughout: **320x568 / 360x800 / 412x915**. Comparison deltas use
the existing worst-screen score per level, matching the original audit.

| Boss | Identity | Screen scores S / M / T | Previous-three mean | Delta vs previous-three mean | Delta vs previous boss |
|---|---|---|---|---|---|
| 10 | gardenBloom | 69.49 / 63.37 / 63.37 | 63.11 | 6.38 | N/A |
| 20 | oceanGyre | 77.86 / 77.21 / 77.21 | 72.73 | 5.13 | 8.37 |
| 30 | candyCastle | 78.39 / 71.98 / 68.69 | 78.38 | 0.01 | 0.53 |
| 40 | spaceNova | 83.48 / 82.82 / 82.82 | 83.64 | -0.15 | 5.09 |
| 50 | desertTemple | 82.51 / 82.43 / 82.43 | 83.34 | -0.84 | -0.97 |
| 60 | iceCrown | 83.47 / 83.42 / 83.39 | 83.54 | -0.07 | 0.96 |
| 70 | jungleSanctuary | 84.27 / 83.49 / 83.46 | 83.94 | 0.33 | 0.80 |
| 80 | volcanoCaldera | 86.95 / 85.90 / 85.90 | 84.59 | 2.36 | 2.68 |
| 90 | dreamPalace | 85.84 / 84.78 / 84.78 | 85.30 | 0.53 | -1.11 |
| 100 | crystalCrown | 85.69 / 85.53 / 85.53 | 86.13 | -0.44 | -0.15 |

The type-diversity component is already capped at 15 from boss 20 onward.
The chain component caps at a chain of 13 tiles: all small-screen bosses reach
that cap, despite actual chains ranging from 13 to 30. Witness tray pressure
caps at 25 points from boss 40 onward (six retained unmatched tiles).
Thus similar scores cannot establish similar puzzles, and longer chains or more
tiles would often worsen readability without adding meaningful strategy.
The fixture retains every per-screen component, including unsaturated medium
and tall measurements. No score formula was changed.

| Boss | Decision and rationale |
|---|---|
| 10 | **Unchanged.** Garden bloom is already a clear step above levels 7–9. Eight small-screen legal selections and a four-tile witness peak provide room to plan even though no initial triple is exposed there. Do not undo verified Garden onboarding by changing its finale speculatively. |
| 20 | **Unchanged.** Ocean gyre already has an exposed sun triple, a five-tile witness peak and a positive distinction from its preceding three levels. |
| 30 | **Unchanged.** Candy castle's near-zero score delta hides strong screen dependence: chain 19 / 9 / 7 and availability 7 / 9 / 12. An initial sun triple exists. Making the castle denser to raise the score would amplify the small-screen chain. Retain this identity; review player routes before further edits. |
| 40 | **Unchanged.** Space nova has ten legal opening moves on every geometry, including carrot and star triples, with the existing four-type tray challenge. Its chain and tray components already saturate the proxy. A near-flat score is insufficient justification to obstruct those choices. |
| 50 | **Unchanged.** Desert temple's lower score includes lower workload (78 tiles versus boss 40's 90), nine initial moves on every screen and both candy and moon triples. Retain this readable recovery/finale rhythm and the gem objective rather than removing safe routes to force a higher number. |
| 60 | **Unchanged.** Ice crown has stable eight-move openings and chain 19 across all screens, an exposed berry triple, and the carrot objective. There is no measured short-screen opening penalty to repair. |
| 70 | **Changed.** Jungle sanctuary loses its exposed candy triple specifically on the small screen: seven initial selections, no complete triple, versus eight with a candy triple on taller screens. One central tile shifts sideways to restore a readable route through the sanctuary. |
| 80 | **Changed.** Volcano caldera has the most constrained boss opening: four initial small-screen selections, no triple and chain 27, versus six selections and an exposed clover triple on taller screens. A small lift of one upper-rim tile exposes that triple while retaining the caldera's deeper dependencies. |
| 90 | **Unchanged.** Dream palace already has two opening triples (apple/candy), eight selections across screens and the largest small-screen chain (30). Its small score delta is not grounds to lengthen an already deep puzzle. |
| 100 | **Unchanged intentionally.** Crystal crown retains 108 tiles, fifteen types, seven layers, the drop target of nine, a six-tile witness peak and nine initial selections with a berry triple on all screens. Its 23 / 22 / 22 chain is shorter than some preceding normals, giving the finale a readable entrance into a long mastery puzzle. A satisfying finale need not maximize the heuristic or require boosters. |

## Exact changes and intended experience

Only **two coordinate fields on two tiles** changed:

| Asset | Tile | Before | After | Purpose |
|---|---|---|---|---|
| assets/levels/level_70.json | L70_T084, candy | x = .4184 | x = .3300 | Move the central candy clear of later clover T086 and carrot T089 on the short board. |
| assets/levels/level_80.json | L80_T086, clover | y = .2613 | y = .2400 | Lift the upper-rim clover clear of later clover T094 on the short board. |

Both keep y/x respectively, types, IDs, layer and array position unchanged.
The Jungle shift is 26.52 logical pixels on the small board; the Volcano shift
is 7.668 logical pixels. Neither changes the outer board bounding rectangle.
Lower-layer scenery and both sanctuary/caldera silhouettes remain intact.

At the 300x360 logical board with 51.2-square tiles, the old Jungle tile overlaps
T086 and T089 above the engine's 3% blocking threshold. Its new horizontal
separation from both is .1748 * 300 = 52.44, greater than tile width. The old
Volcano clover is vertically .1260 * 360 = 45.36 from T094; afterward the
separation is .1473 * 360 = 53.028, greater than tile height. Other later top
tiles also leave these intended opening triples uncovered by source geometry.
The medium/tall boards have smaller normalized tile dimensions, preserving
these separations. Uniform FittedBox scaling does not alter overlap ratios.

These edits reveal purposeful opening matches rather than increase tile count:
- Jungle: candy T080/T084/T088.
- Volcano: clover T086/T090/T094.

Other visible types remain alternatives, and the four-type batching challenge
continues after the opening. This is a small fairness adjustment, not a claim
that arbitrary choices are safe or that every route can win.

## Before / after comparison

**After metrics have not been executed.** Do not label the edited boards as
engine-verified SOLVED until the local replay passes. The construction proof
below explains why the original paths survive; new regression tests and the
comparison runner independently require actual replay.

| Metric | Boss 70 before | Boss 70 after, design expectation | Boss 80 before | Boss 80 after, design expectation |
|---|---|---|---|---|
| Initial moves S / M / T | 7 / 8 / 8 | At least 8 / 8 / 8 | 4 / 6 / 6 | At least 5 / 6 / 6 |
| Small-screen exposed triple | None | Candy | None | Clover |
| Maximum chain S / M / T | 25 / 17 / 17 | NOT MEASURED; no increase required | 27 / 24 / 24 | NOT MEASURED; no increase required |
| Original witness peak S / M / T | 6 / 6 / 6 | Same type sequence; replay pending | 6 / 6 / 6 | Same type sequence; replay pending |
| Worst-screen proxy | 84.27 | NOT MEASURED | 86.95 | NOT MEASURED |
| Solver on edited inputs | N/A | NOT RUN | N/A | NOT RUN |

The local comparison runner remeasures the **same 40 levels on all three
geometries** with the existing `auditBoard` implementation. It writes:
- `qa/boss_balance_pass_1_results.json`: original baseline, exact after assets,
  all metrics/components/witnesses, all ten boss comparisons and failure issues.
- `qa/boss_balance_pass_1_results.md`: before/after boss scores, deltas against
  the preceding three and previous boss, plus all 120 geometry comparisons.

It does not overwrite the original audit or frozen fixture. Positive score
deltas are retained just like negative ones; scores are not pass/fail human
difficulty targets. SOLVED, UNSOLVABLE and UNKNOWN are preserved verbatim.
Non-SOLVED results, failed witness replay, reduced boss opening availability,
increased maximum boss chains or changed original witness peaks fail the check.
Failures are written before assertions so an inconclusive result is not hidden.

## Full measured context before editing

The following table is copied/formatted from the supplied measurements.
The frozen JSON additionally keeps initial type counts, occupied area, blocking
edges, direct blockers, all difficulty terms, choice scarcity, forced steps and
immediate-losing-choice fractions along each witness. None estimates human win
rate or minimum necessary tray pressure.

| Level | Role | Tiles | Worst score | Initial moves S / M / T | Chain S / M / T | Witness retained peak S / M / T |
|---|---|---|---|---|---|---|
| 7 | Normal | 42 | 60.24 | 9 / 9 / 9 | 10 / 6 / 6 | 4 / 4 / 4 |
| 8 | Normal | 42 | 63.04 | 4 / 7 / 7 | 10 / 8 / 8 | 4 / 4 / 4 |
| 9 | Normal | 42 | 66.05 | 6 / 6 / 6 | 14 / 12 / 12 | 4 / 4 / 4 |
| 10 | Boss | 54 | 69.49 | 8 / 10 / 10 | 13 / 9 / 9 | 4 / 4 / 4 |
| 17 | Normal | 54 | 71.24 | 7 / 7 / 7 | 11 / 11 / 11 | 5 / 5 / 5 |
| 18 | Normal | 54 | 74.80 | 5 / 8 / 8 | 16 / 14 / 14 | 5 / 5 / 5 |
| 19 | Normal | 54 | 72.15 | 7 / 10 / 10 | 12 / 9 / 9 | 5 / 5 / 5 |
| 20 | Boss | 66 | 77.86 | 7 / 8 / 8 | 14 / 13 / 13 | 5 / 5 / 5 |
| 27 | Normal | 66 | 77.58 | 7 / 9 / 9 | 17 / 6 / 6 | 5 / 5 / 5 |
| 28 | Normal | 72 | 78.33 | 6 / 11 / 11 | 16 / 9 / 9 | 5 / 5 / 5 |
| 29 | Normal | 72 | 79.24 | 4 / 8 / 8 | 19 / 17 / 17 | 5 / 5 / 5 |
| 30 | Boss | 78 | 78.39 | 7 / 9 / 12 | 19 / 9 / 7 | 5 / 5 / 5 |
| 37 | Normal | 84 | 84.39 | 7 / 7 / 7 | 22 / 20 / 20 | 6 / 6 / 6 |
| 38 | Normal | 84 | 83.15 | 9 / 9 / 9 | 21 / 18 / 18 | 6 / 6 / 6 |
| 39 | Normal | 90 | 83.36 | 9 / 10 / 10 | 15 / 14 / 14 | 6 / 6 / 6 |
| 40 | Boss | 90 | 83.48 | 10 / 10 / 10 | 21 / 15 / 15 | 6 / 6 / 6 |
| 47 | Normal | 72 | 83.13 | 6 / 8 / 8 | 22 / 13 / 12 | 6 / 6 / 6 |
| 48 | Normal | 72 | 83.91 | 5 / 5 / 5 | 19 / 18 / 18 | 6 / 6 / 6 |
| 49 | Normal | 75 | 82.99 | 8 / 8 / 8 | 20 / 15 / 15 | 6 / 6 / 6 |
| 50 | Boss | 78 | 82.51 | 9 / 9 / 9 | 17 / 17 / 17 | 6 / 6 / 6 |
| 57 | Normal | 78 | 83.55 | 7 / 7 / 7 | 25 / 24 / 24 | 6 / 6 / 6 |
| 58 | Normal | 78 | 83.55 | 6 / 7 / 7 | 19 / 15 / 15 | 6 / 6 / 6 |
| 59 | Normal | 81 | 83.53 | 7 / 12 / 12 | 19 / 8 / 8 | 6 / 6 / 6 |
| 60 | Boss | 84 | 83.47 | 8 / 8 / 8 | 19 / 19 / 19 | 6 / 6 / 6 |
| 67 | Normal | 84 | 85.20 | 6 / 8 / 8 | 24 / 22 / 22 | 6 / 6 / 6 |
| 68 | Normal | 84 | 83.18 | 9 / 9 / 9 | 20 / 13 / 13 | 6 / 6 / 6 |
| 69 | Normal | 87 | 83.43 | 9 / 9 / 9 | 20 / 19 / 19 | 6 / 6 / 6 |
| 70 | Boss | 90 | 84.27 | 7 / 8 / 8 | 25 / 17 / 17 | 6 / 6 / 6 |
| 77 | Normal | 90 | 84.63 | 7 / 8 / 8 | 25 / 22 / 22 | 6 / 6 / 6 |
| 78 | Normal | 90 | 84.62 | 8 / 8 / 8 | 23 / 20 / 20 | 6 / 6 / 6 |
| 79 | Normal | 93 | 84.52 | 8 / 8 / 8 | 25 / 25 / 25 | 6 / 6 / 6 |
| 80 | Boss | 96 | 86.95 | 4 / 6 / 6 | 27 / 24 / 24 | 6 / 6 / 6 |
| 87 | Normal | 96 | 85.15 | 7 / 10 / 10 | 22 / 15 / 15 | 6 / 6 / 6 |
| 88 | Normal | 96 | 83.79 | 10 / 11 / 11 | 15 / 11 / 11 | 6 / 6 / 6 |
| 89 | Normal | 99 | 86.97 | 4 / 7 / 7 | 27 / 23 / 23 | 6 / 6 / 6 |
| 90 | Boss | 102 | 85.84 | 8 / 8 / 8 | 30 / 22 / 22 | 6 / 6 / 6 |
| 97 | Normal | 102 | 86.23 | 6 / 10 / 10 | 29 / 14 / 14 | 6 / 6 / 6 |
| 98 | Normal | 102 | 86.57 | 5 / 10 / 10 | 27 / 16 / 16 | 6 / 6 / 6 |
| 99 | Normal | 105 | 85.58 | 8 / 9 / 9 | 29 / 29 / 29 | 6 / 6 / 6 |
| 100 | Boss | 108 | 85.69 | 9 / 9 / 9 | 23 / 22 / 22 | 6 / 6 / 6 |

## Booster-free solvability and real rules

GameEngine orders by layer then original array index. Later tiles, including
same-layer tiles, cover earlier ones when rectangular overlap is at least 3%.
Selection resolves triples first and loses immediately if seven unmatched tiles
remain. Full board clearance is preserved; the QA criterion additionally
requires an empty tray, every tile matched and the original objective met.

Only coordinates changed. In the existing successful reverse-paint-order path,
each selected tile is the latest remaining painted tile and therefore cannot
be covered, on any geometry. Its type sequence and tray evolution are unchanged.
The original witnesses retain peaks 4 (boss 10), 5 (bosses 20/30) or 6 (40–100);
a seventh collected tile on a peak-six witness completes a triple immediately.
Inventories and objective targets are unchanged. This is a constructive
preservation argument, not a divisibility-only assertion.

For each changed boss, the newly exposed triple belongs to its final four-type,
twelve-tile batch. Taking that triple first leaves only three types in that
batch; at most two of each can remain unmatched (six slots) before a triple
resolves. Clearing the rest of the batch leaves an empty tray before resuming
the original lower-board witness. Actual-engine tests replay both advertised
opening paths and require every move to be accepted, no early loss/victory,
empty final tray, all tiles matched and completed objectives.

No boosters, ads, purchases, Hint, Shuffle or Undo are used in these proofs or
replays. No GameEngine, tray, matching, progression or reward implementation was
modified.

## Regression coverage and integration

`test/qa/boss_balance_test.dart` covers:
- Exactly ten boss identities and unchanged content for the eight unedited bosses.
- All 90 normal assets unchanged, including the verified Garden pass.
- Exact approved coordinate edits; unchanged IDs, ordering, layers, names, time
  metadata, objective targets and per-type inventories.
- World-specific boss patterns, valid theme tile types and complete triples.
- Thirty solver/engine cases, one per boss/screen: legal initial moves, bounds,
  unchanged outer envelopes, SOLVED required, witness replay, full clearance and
  peak tray pressure no greater than the recorded baseline.
- Six exposed-triple continuation cases for the two changed bosses.
- All ten progression milestones using mocked preferences and the real
  repository: next-level unlock capped at 100, best stars preserved, gold chest,
  XP/coin grant amounts and final reward unlock only at 100.
- The screen's existing reward constants and ten themed boss metadata entries.

Reward coverage is a repository/source contract, not a claim that new UI
interaction tests or screenshots ran. Existing map, victory, engine and screen
QA tests remain intact and continue to cover those integrations.

The existing campaign assertion still compares every tile with exact authoring
expectations. It now applies the two precise curated coordinates from
`boss_balance_expectations.dart` after the existing Garden curation. No level
is skipped, no tolerance widened and no assertion removed.

The bulk generator remains unchanged. Do not run
`tool/generate_mixed_level_layouts.dart`: it overwrites all 100 levels and would
erase manual curation. Any future regeneration must explicitly adopt both
reviewed curation manifests.

## Exact local Git Bash commands

Run with the existing Flutter SDK and dependencies:

```bash
cd '/c/Gra - telefon/game'

# Focused boss regressions and all existing campaign checks
flutter test --no-pub --concurrency=1 test/qa/boss_balance_test.dart test/qa/campaign_test.dart

# Reproducible 40-level / three-geometry before-and-after comparison
flutter test --no-pub --concurrency=1 test/balance_audit/boss_comparison_test.dart

# Refresh the full campaign and Endless audit without changing their data
flutter test --no-pub --concurrency=1 test/balance_audit/balance_audit_test.dart

# Existing full QA runner, including Garden and the new boss tests
powershell.exe -NoProfile -File ./qa/run_qa.ps1
```

## Files modified or added

Modified:
- `assets/levels/level_70.json`
- `assets/levels/level_80.json`
- `test/qa/campaign_test.dart`

Added:
- `test/qa/support/boss_balance_expectations.dart`
- `test/qa/fixtures/boss_balance_before.json`
- `test/qa/boss_balance_test.dart`
- `test/balance_audit/boss_comparison_test.dart`
- `qa/BOSS_BALANCE_PASS_1.md`

No normal level assets, production Dart, Endless, UI, animations, economy,
saved progress or flavor configuration changed. Existing tests remain present.
No visual results or post-edit test passes are claimed. Player experience,
after-metrics and all automated checks remain subject to local verification.
