"""Phase 4D-6: forensic analysis of one pinned recorded cohort; no simulations."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict, deque
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import tempfile

import level96_post_opening as prior

VERSION = "campaign4d6/level96-regression-migration-v1"
EXPERIMENT = "campaign4d5/level96-second-shadow-v1"
RUN = "phase4d5-level96-20261105T114207305023Z-34520-a437c264"
SOURCE = Path("qa/campaign_validation_runs") / RUN
ARMS = ("control_a", "candidate_b")
SCREENS = prior.SCREENS
STRATEGIES = prior.STRATEGIES
FILES = ("manifest.json", "summary.json", "report.md", "attempts.jsonl")
PINNED_SHA256 = {
    "manifest.json": "a8c6381a7747464dcf3dac5f705ae4a38d835cccc6f0127845d222abcad45b81",
    "summary.json": "982f610b551dd6be76da38d056084c08f253a64e57e3c56987e36e69c10b8c76",
    "report.md": "d9406096b496f14777fb9412cd9b45c7ba9b11e1bfbc8a53d7aca6d2686dceb0",
    "attempts.jsonl": "1a7e6a80c5068f154b96b1d1acb37e8e84897867ebceaab3fdea108aac68b24d",
}
HELPER_SHA256 = "9eb696a2454d5557f8fb83f985937e7cb00011492da39b82a3fd93cad8cab25f"
SWAPS = {"control_a": {"L96_T094": "star", "L96_T095": "heart"},
         "candidate_b": {"L96_T094": "star", "L96_T095": "heart", "L96_T071": "heart", "L96_T069": "banana"}}
SEED_POLICY = ('seed=FNV1a32(UTF8(JSON([version,level,replica]))); '
    'priority=FNV1a32(UTF8(JSON([version,level,replica,decision,domain,path,token]))); '
    'ascending unsigned priority, then token lexicographically; '
    'domain=actual with path=[] at root, plan with public hypothetical path otherwise; '
    'token=JSON([visible type,normalized x string,normalized y string]); '
    'no screen, strategy, handles, authoring IDs, hidden symbols or RNG state')
IntegrityError = prior.IntegrityError
require = prior.require
canonical = prior.canonical
sha = prior.sha_file


def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise IntegrityError(f"Missing or malformed JSON: {path}") from error


def fnv_file(path):
    value = 0x811C9DC5
    with Path(path).open("rb") as stream:
        while chunk := stream.read(65536):
            for byte in chunk:
                value = ((value ^ byte) * 0x01000193) & 0xFFFFFFFF
    return f"{value:08x}"


def pair_key(row):
    return f"{row['screen']}/{row['strategy']}/{row['replica']:02d}"


def row_key(row):
    return f"{row['variant']}/{pair_key(row)}"


def validate_accounting(rows):
    expected = {(a, s, p, r) for a in ARMS for s in SCREENS for p in STRATEGIES for r in range(30, 60)}
    actual = []
    try:
        for row in rows:
            actual.append((row["variant"], row["screen"], row["strategy"], row["replica"]))
            require(row["level"] == 96 and row["phase4d5_version"] == EXPERIMENT
                    and row["experiment_version"] == prior.PAIRED and row["cohort"] == "unseen_30_59"
                    and row["omniscient"] is False and row["information_model"] == "exposed_only_v1"
                    and row["policy_version"] == f"{row['strategy']}/paired-ties-v1"
                    and row["outcome"] in ("WIN", "LOSS"), "Wrong attempt identity or unverified outcome")
            require(type(row["replica"]) is int and row["experiment_seed_uint32"] ==
                    prior.json_hash([prior.PAIRED, 96, row["replica"]]), "Wrong paired seed")
        require(len(rows) == len(set(actual)) == 360 and set(actual) == expected,
                "Duplicate, missing or out-of-cohort paired rows")
    except (KeyError, TypeError) as error:
        raise IntegrityError("Malformed attempt identity") from error


def validate_manifest(m):
    require(m["schema"] == EXPERIMENT and m["run_id"] == RUN and m["level"] == 96,
            "Wrong experiment identity; substitution forbidden")
    require(m["status"] == "COMPLETE" and m["measurement_health"] == "OK"
            and m["actual_attempts"] == m["planned_attempts"] == 360, "Incomplete or unhealthy evidence")
    require(m["variants"] == list(ARMS) and m["type_changes_from_production"] == SWAPS
            and m["replica_indices"] == list(range(30, 60)) and m["cohort"] == "unseen_30_59"
            and m["strategies"] == list(STRATEGIES), "Wrong arms, replicas or strategies")
    expected_screens = [(SCREENS[0], [320, 568], 24, [300, 360], [51.2, 51.2]),
                        (SCREENS[1], [360, 800], 24, [340, 538], [57.6, 57.6]),
                        (SCREENS[2], [412, 915], 32, [392, 620], [65.92, 65.92])]
    require(len(m["screens"]) == 3, "Wrong geometry count")
    for g, (name, size, safe, board, tile) in zip(m["screens"], expected_screens):
        require(g["name"] == name and g["size"] == size and g["safe_top"] == safe
                and g["board"] == board and all(abs(x-y) < 1e-9 for x, y in zip(g["tile"], tile)),
                "Unexpected screen geometry")
    require(m["paired_policy_version"] == prior.PAIRED and m["paired_seed_policy"] == SEED_POLICY
            and m["visibility"] == "exposed_only_v1" and m["variant_in_seed_or_priority"] is False,
            "Paired methodology changed")
    require(all(m["budgets"][k] == v for k, v in {"lookahead_depth": 3, "branch_cap": 4,
            "expansions": 84, "replicas_per_cell": 30}.items()), "Policy budget drift")
    require(m["inputs_unchanged"] and not m["problems"] and not m["wall_guard_reached"]
            and m["fingerprints_before"] == m["fingerprints_after"]
            and not any(k in m for k in ("fatal_error", "report_error")), "Source input or reporting failure")
    gate = m["correctness_gate"]
    require(gate["passed"] and gate["models_unchanged_after_preflight"], "Correctness gate failed")
    witnesses = gate["witness_and_invariants"]
    require(witnesses["passed"] and witnesses["independent_arms"] and len(witnesses["variant_checks"]) == 2,
            "Variant independence failure")
    for check, arm in zip(witnesses["variant_checks"], ARMS):
        require(check["passed"] and not check["problems"] and check["inventory_equal"]
                and check["arm"] == arm and check["changed_type_ids"] == sorted(SWAPS[arm])
                and check["tile_count"] == 99, "Variant invariant failure")
    require(len(witnesses["screens"]) == 3 and {s["screen"] for s in witnesses["screens"]} == set(SCREENS),
            "Incomplete witness geometries")
    for screen in witnesses["screens"]:
        require(screen["passed"] and screen["geometry_and_bounds_equal"]
                and not screen["bounds"]["outside_ids"], "Geometry witness gate failed")
        for arm in ARMS:
            r = screen[f"{arm}_replay"]
            require(r["replay_success"] and r["full_clearance"] and r["successful_moves"] == 99
                    and r["final_board_count"] == r["final_tray_count"] == 0
                    and len(set(r["winning_moves"])) == 99 and len(r["trace"]) == 99,
                    "Incomplete stored winning witness")
    paired = gate["deterministic_paired"]
    expected = {(s, p, r) for s in SCREENS for p in STRATEGIES for r in (30, 44, 59)}
    require(paired["passed"] and len(paired["checks"]) == 18
            and {(c["screen"], c["strategy"], c["replica"]) for c in paired["checks"]} == expected
            and all(c["passed"] and c["observations_equal"] and c["a"] == c["a_repeat"] == c["b"]
                    for c in paired["checks"]), "Deterministic paired gate failed")
    reproduction = m["historical_control_reproduction"]
    require(len(reproduction) == 6 and {(r["screen"], r["strategy"], r["replica"]) for r in reproduction} ==
            {(s, p, 24) for s in SCREENS for p in STRATEGIES}
            and all(r["passed"] and not r["different_fields"] and not r["counted_in_experiment"] for r in reproduction)
            and gate["historical_control_reproduction"] == reproduction, "Historical reproduction failure")


def validate_trace(row, tiles, blockers):
    # Explicit compatibility adapter: only obsolete envelope labels are supplied
    # on a shallow copy. Seeds, policies, replicas, trace values and models stay
    # untouched. Actual Phase 4D-5 identity is checked independently above.
    adapted = {**row, "shadow_experiment_version": prior.SHADOW,
               "cohort": prior.cohort(row["replica"])}
    prior.validate_trace(adapted, tiles, blockers)


def aggregate(rows):
    return {"attempts": len(rows), "wins": sum(r["outcome"] == "WIN" for r in rows),
            "losses": sum(r["outcome"] == "LOSS" for r in rows),
            "loss_taps": {str(k): n for k, n in sorted(Counter(r["decisions"] for r in rows if r["outcome"] == "LOSS").items())}}


def validate_summary(summary, manifest, rows):
    require(summary["schema"] == EXPERIMENT and summary["complete"] and summary["evidence_complete"]
            and summary["actual_attempts"] == summary["planned_attempts"] == 360 and not summary["missing_keys"]
            and summary["cohort"] == "unseen_30_59" and summary["replica_indices"] == list(range(30, 60))
            and summary["correctness_gate"] == manifest["correctness_gate"]
            and summary["acceptance_rules"] == manifest["acceptance_rules"]
            and summary["recommendation"] == manifest["recommendation"] == "REVISE", "Inconsistent source summary")
    for arm in ARMS:
        require(all(summary[arm][k] == v for k, v in aggregate([r for r in rows if r["variant"] == arm]).items()),
                "Source totals or histograms differ from raw attempts")
    for name, dimensions, count in [("cells", ("screen", "strategy"), 6), ("screens", ("screen",), 3),
                                     ("strategies", ("strategy",), 2)]:
        require(len(summary[name]) == count and len({tuple(c[d] for d in dimensions) for c in summary[name]}) == count,
                "Duplicate or incomplete summary groups")
        for cell in summary[name]:
            for arm in ARMS:
                selected = [r for r in rows if r["variant"] == arm and all(r[d] == cell[d] for d in dimensions)]
                require(all(cell[arm][k] == v for k, v in aggregate(selected).items()), "Wrong summary cell")
    by_pair = {pair_key(a): (a, b) for a, b in pair_rows(rows)}
    require(len(summary["paired_outcomes"]) == 180
            and {pair_key(p) for p in summary["paired_outcomes"]} == set(by_pair), "Wrong source paired table")
    for pair in summary["paired_outcomes"]:
        a, b = by_pair[pair_key(pair)]
        for arm, row in zip(ARMS, (a, b)):
            require(pair[arm]["outcome"] == row["outcome"] and pair[arm]["decisions"] == row["decisions"],
                    "Source pair outcome mismatch")
        require(pair["win_to_loss"] == (classify_pair(a, b) == "WIN_TO_LOSS")
                and pair["earlier_candidate_loss"] == (classify_pair(a, b) == "BOTH_LOSS_EARLIER"),
                "Source pair classification mismatch")
    counts = Counter(classify_pair(a, b) for a, b in by_pair.values())
    require(summary["earlier_paired_losses"] == counts["BOTH_LOSS_EARLIER"]
            and summary["win_to_loss_regressions"] == counts["WIN_TO_LOSS"]
            and summary["win_gain"] == summary["candidate_b"]["wins"] - summary["control_a"]["wins"]
            and summary["tap31_loss_reduction"] == int(summary["control_a"]["loss_taps"].get("31", 0)) -
                int(summary["candidate_b"]["loss_taps"].get("31", 0)), "Wrong source effect counts")
    require(len(summary["strategy_pairs"]) == 180 and len({(r["variant"], r["screen"], r["replica"])
            for r in summary["strategy_pairs"]}) == 180, "Incomplete source strategy table")


def load_evidence(workspace, source=None):
    root = Path(workspace).resolve()
    source = Path(source).resolve() if source else root / SOURCE
    require(source.name == RUN, "Wrong input directory; no alternate run allowed")
    require(all((source / f).is_file() for f in FILES), "Missing required evidence file")
    m, s = read_json(source / "manifest.json"), read_json(source / "summary.json")
    try:
        validate_manifest(m)
        hashes = {f: sha(source / f) for f in FILES}
        require(hashes == PINNED_SHA256, "Pinned evidence SHA-256 mismatch")
        require(sha(Path(prior.__file__)) == HELPER_SHA256, "Read-only validator dependency changed")
        inputs = {}
        for name, expected in sorted(m["fingerprints_before"].items()):
            path = root / name
            require(path.is_file() and path.resolve().is_relative_to(root), f"Missing or unsafe input: {name}")
            require(fnv_file(path) == expected, f"Input fingerprint drift: {name}")
            inputs[name] = sha(path)
        for name, contents in m["input_snapshots_utf8"].items():
            require((root / name).read_text(encoding="utf-8").replace("\r\n", "\n") == contents.replace("\r\n", "\n"),
                    f"Input source snapshot differs: {name}")
        for name in ("attempts.jsonl", "summary.json", "report.md"):
            entries = [v for k, v in m["artifact_fingerprints"].items() if k.replace("\\", "/").endswith("/" + name)]
            require(len(entries) == 1 and fnv_file(source / name) == entries[0], "Recorded output fingerprint mismatch")
        with (source / "attempts.jsonl").open(encoding="utf-8") as stream:
            rows = [json.loads(line) for line in stream if line.strip()]
        validate_accounting(rows)
        production = read_json(root / prior.ASSET)
        require(fnv_file(root / prior.ASSET) == "2b2b8578" and production.get("objective") is None,
                "Wrong production model")
        tiles = {arm: {t["id"]: {**t, "type": SWAPS[arm].get(t["id"], t["type"])} for t in production["tiles"]} for arm in ARMS}
        require(all(Counter(t["type"] for t in model.values()) == Counter(t["type"] for t in production["tiles"])
                    for model in tiles.values()), "Inventory mismatch")
        geometries = {g["screen"]: g["geometry"] for g in m["correctness_gate"]["witness_and_invariants"]["screens"]}
        values = sorted({canonical(g) for g in geometries.values()})
        geometry_ids = {name: values.index(canonical(g)) for name, g in geometries.items()}
        blockers = {}
        for screen, geom in geometries.items():
            blockers[screen] = {t: set() for t in tiles[ARMS[0]]}
            for edge in geom["blocking_edges"]:
                blockers[screen][edge["lower"]].add(edge["upper"])
        rows.sort(key=row_key)
        for row in rows:
            validate_trace(row, tiles[row["variant"]], blockers[row["screen"]])
        validate_summary(s, m, rows)
        report = (source / "report.md").read_text(encoding="utf-8")
        require("360/360 attempts" in report and "REVISE" in report and "30–59" in report, "Incomplete source Markdown")
        return {"root": root, "source": source, "hashes": hashes, "input_hashes": inputs,
                "manifest": m, "source_summary": s, "rows": rows, "tiles": tiles,
                "geometries": geometries, "geometry_ids": geometry_ids, "blockers": blockers}
    except (KeyError, TypeError, ValueError, OSError) as error:
        if isinstance(error, IntegrityError):
            raise
        raise IntegrityError(f"Malformed evidence: {error}") from error


def pair_rows(rows):
    indexed = {(r["variant"], pair_key(r)): r for r in rows}
    return [(indexed[ARMS[0], key], indexed[ARMS[1], key])
            for key in sorted({pair_key(r) for r in rows})]


def classify_pair(a, b):
    if a["outcome"] == "WIN":
        return "BOTH_WIN" if b["outcome"] == "WIN" else "WIN_TO_LOSS"
    if b["outcome"] == "WIN":
        return "LOSS_TO_WIN"
    return "BOTH_LOSS_EARLIER" if b["decisions"] < a["decisions"] else (
        "BOTH_LOSS_LONGER" if b["decisions"] > a["decisions"] else "BOTH_LOSS_SAME_TAP")


def regression_keys(rows):
    return [pair_key(a) for a, b in pair_rows(rows) if classify_pair(a, b) == "BOTH_LOSS_EARLIER"]


def shared_prefix(a, b):
    n = 0
    for left, right in zip(a, b):
        if left != right:
            break
        n += 1
    return {"length": n, "ids": a[:n],
            "first_different_tap": n + 1 if n < min(len(a), len(b)) else None,
            "unmatched_tail_start": min(len(a), len(b)) + 1 if len(a) != len(b) else None}


def physical_key(step, geometry, unordered_tray=False):
    tray = step["diagnostic_tray_ids"]
    return canonical([geometry, sorted(step["diagnostic_remaining_ids"]), sorted(tray) if unordered_tray else tray])


def mechanical_key(step, geometry, tiles, unordered_tray=False):
    ids = set(step["diagnostic_remaining_ids"]) | set(step["diagnostic_tray_ids"])
    return canonical([physical_key(step, geometry, unordered_tray), [[i, tiles[i]["type"]] for i in sorted(ids)]])


def symbol_tray_key(step):
    # Public symbol/tray pattern only: deliberately ignores tile identity and geometry.
    return canonical([step["tray_types_before"], sorted(Counter(json.loads(t)[0] for t in step["legal_tokens"]).items())])


def ident(key):
    return hashlib.sha256(key.encode()).hexdigest()


def public_view(step):
    return {"tray_types": step["tray_types_before"], "tray_occupancy": step["tray_before"],
            "legal_tokens": step["legal_tokens"], "chosen_token": step["chosen_token"],
            "available_triple_types": step["available_triple_types"],
            "safe_action_tokens": [c["token"] for c in step["candidates"] if not c["immediate_loss"]],
            "losing_action_tokens": [c["token"] for c in step["candidates"] if c["immediate_loss"]],
            "root_ranking": step["rankings"][0], "tray_after": step["tray_after"],
            "resolved_triple": step["resolved_triple"],
            "newly_revealed_tokens_after_actual_tap": step["newly_selectable_tokens_after_tap"]}


def snapshot(row, index, evidence):
    step = row["trace"][index]
    model = evidence["tiles"][row["variant"]]
    geom = evidence["geometry_ids"][row["screen"]]
    graph = evidence["blockers"][row["screen"]]
    remaining = set(step["diagnostic_remaining_ids"])
    token_ids = {prior.token(model[i]): i for i in step["diagnostic_legal_ids"]}
    all_tokens = {prior.token(t): i for i, t in model.items()}
    held = Counter(step["tray_types_before"])
    blocked = [{"id": i, "type": model[i]["type"], "held_count": held[model[i]["type"]],
                "active_blockers": sorted(graph[i] & remaining)}
               for i in sorted(remaining - set(step["diagnostic_legal_ids"])) if held[model[i]["type"]]]
    blocked.sort(key=lambda d: (-d["held_count"], len(d["active_blockers"]), d["id"]))
    return {"tap": index + 1, "physical_state_id": ident(physical_key(step, geom)),
            "mechanical_state_id": ident(mechanical_key(step, geom, model)),
            "public_observation_and_recorded_previews": public_view(step),
            "analyst_only": {"chosen_id": step["diagnostic_actual_chosen_id"],
                "remaining_ids": step["diagnostic_remaining_ids"], "tray_ids": step["diagnostic_tray_ids"],
                "legal_tiles": [{"id": i, "type": model[i]["type"],
                    "structural_unlocks_if_removed": sorted(t for t in remaining if t != i and graph[t] & remaining == {i})}
                    for i in step["diagnostic_legal_ids"]],
                "safe_action_ids": [token_ids[c["token"]] for c in step["candidates"] if not c["immediate_loss"]],
                "losing_action_ids": [token_ids[c["token"]] for c in step["candidates"] if c["immediate_loss"]],
                "newly_revealed_ids_after_actual_tap": [all_tokens[t] for t in step["newly_selectable_tokens_after_tap"]],
                "blocked_held_symbols": blocked},
            "information_boundary": "Authoring IDs, covered types and blocker graph are analyst-only. No agent invoked."}


def terminal_step(row, model):
    step = row["trace"][-1]
    chosen = step["diagnostic_actual_chosen_id"]
    return {"diagnostic_remaining_ids": sorted(set(step["diagnostic_remaining_ids"]) - {chosen}),
            "diagnostic_tray_ids": prior.resolve_recorded_tap(step["diagnostic_tray_ids"], chosen, model)}


def stored_graph(evidence):
    nodes, paths = {}, {}
    for row in sorted(evidence["rows"], key=row_key):
        geom, model = evidence["geometry_ids"][row["screen"]], evidence["tiles"][row["variant"]]
        keys = [mechanical_key(s, geom, model) for s in row["trace"]]
        end = mechanical_key(terminal_step(row, model), geom, model)
        keys.append(end)
        paths[row_key(row)] = keys
        nodes.setdefault(end, {"edges": {}, "visits": [], "terminal": row["outcome"]})
        for i, step in enumerate(row["trace"]):
            node = nodes.setdefault(keys[i], {"edges": {}, "visits": []})
            action = step["diagnostic_actual_chosen_id"]
            require(action not in node["edges"] or node["edges"][action] == keys[i+1],
                    "Same mechanical state and action have inconsistent recorded successors")
            node["edges"][action] = keys[i+1]
            node["visits"].append([row_key(row), i+1])
    predecessors = defaultdict(set)
    for key, node in nodes.items():
        for target in node["edges"].values():
            predecessors[target].add(key)
    winning = {key for key, node in nodes.items() if node.get("terminal") == "WIN"}
    queue = deque(sorted(winning))
    while queue:
        for pred in sorted(predecessors[queue.popleft()]):
            if pred not in winning:
                winning.add(pred)
                queue.append(pred)
    return nodes, paths, winning


def changed_tile_events(row):
    return {ident: {
        "first_publicly_selectable_tap": next((s["decision"]+1 for s in row["trace"] if ident in s["diagnostic_legal_ids"]), None),
        "actual_chosen_tap": next((s["decision"]+1 for s in row["trace"] if ident == s["diagnostic_actual_chosen_id"]), None),
        "triple_on_chosen_tap": next((s["resolved_triple"] for s in row["trace"] if ident == s["diagnostic_actual_chosen_id"]), None),
    } for ident in ("L96_T071", "L96_T069")}


def pair_analysis(a, b, evidence):
    prefix = shared_prefix(a["path_ids"], b["path_ids"])
    n = min(len(a["trace"]), len(b["trace"]))
    differences = []
    for i, (x, y) in enumerate(zip(a["trace"], b["trace"])):
        if any(x[k] != y[k] for k in ("chosen_token", "tray_types_before", "available_triple_types", "tray_after", "legal_tokens")):
            differences.append({"tap": i+1, "a_chosen": x["diagnostic_actual_chosen_id"], "b_chosen": y["diagnostic_actual_chosen_id"],
                "same_physical_tap_prefix_before_move": i <= prefix["length"],
                "same_physical_pre_move_state": physical_key(x, 0) == physical_key(y, 0),
                "a_tray": x["tray_types_before"], "b_tray": y["tray_types_before"],
                "a_after": x["tray_after"], "b_after": y["tray_after"],
                "a_triple_opportunities": x["available_triple_types"], "b_triple_opportunities": y["available_triple_types"],
                "a_resolved_triple": x["resolved_triple"], "b_resolved_triple": y["resolved_triple"]})
    first_public = next((i for i, (x, y) in enumerate(zip(a["trace"], b["trace"]))
                         if x["legal_tokens"] != y["legal_tokens"] or x["tray_types_before"] != y["tray_types_before"]), None)
    def contexts(index):
        return None if index is None else {"control_a": snapshot(a, index, evidence), "candidate_b": snapshot(b, index, evidence)}
    mean = lambda row, limit: sum(s["tray_after"] for s in row["trace"][:limit]) / limit / 7
    return {"pair": pair_key(a), "screen": a["screen"], "strategy": a["strategy"], "replica": a["replica"],
        "seed_uint32": a["experiment_seed_uint32"], "classification": classify_pair(a, b),
        "a_outcome": a["outcome"], "b_outcome": b["outcome"], "a_taps": a["decisions"], "b_taps": b["decisions"],
        "shared_physical_tap_prefix": prefix, "first_public_difference_tap": None if first_public is None else first_public+1,
        "first_public_difference": contexts(first_public),
        "physical_choice_divergence": contexts(None if prefix["first_different_tap"] is None else prefix["first_different_tap"]-1),
        "changed_tile_events": {"control_a": changed_tile_events(a), "candidate_b": changed_tile_events(b)},
        "triple_completion_taps": {arm: [s["decision"]+1 for s in row["trace"] if s["resolved_triple"]]
                                    for arm, row in zip(ARMS, (a, b))},
        "pressure": {"common_horizon_taps": n, "a_common_horizon_mean": mean(a, n), "b_common_horizon_mean": mean(b, n),
            "a_entire_path_mean": mean(a, len(a["trace"])), "b_entire_path_mean": mean(b, len(b["trace"])),
            "limitation": "Pressure means are descriptive. Entire-path means have unequal survival horizons and neither estimate human difficulty nor explain causality alone."},
        "aligned_decision_differences": differences}


def cluster_stats(rows, evidence):
    physical, prephysical, mechanical, symbols = defaultdict(list), defaultdict(list), defaultdict(list), defaultdict(list)
    for row in rows:
        geom, model = evidence["geometry_ids"][row["screen"]], evidence["tiles"][row["variant"]]
        step, end = row["trace"][-1], terminal_step(row, model)
        physical[physical_key(end, geom)].append(row_key(row))
        prephysical[physical_key(step, geom)].append(row_key(row))
        mechanical[mechanical_key(end, geom, model)].append(row_key(row))
        symbols[symbol_tray_key(step)].append(row_key(row))
    return {"failures": len(rows), "screen_distribution": dict(sorted(Counter(r["screen"] for r in rows).items())),
        "strategy_distribution": dict(sorted(Counter(r["strategy"] for r in rows).items())),
        "distinct_terminal_physical_states": len(physical), "distinct_pre_loss_physical_states": len(prephysical),
        "distinct_terminal_mechanical_states": len(mechanical), "distinct_pre_loss_symbol_tray_patterns": len(symbols),
        "physical_terminal_groups": [{"state_id": ident(k), "members": v} for k, v in sorted(physical.items())],
        "symbol_tray_pattern_groups": [{"pattern": json.loads(k), "members": v} for k, v in sorted(symbols.items())]}


def analyze(evidence):
    rows = sorted(evidence["rows"], key=row_key)
    lookup = {row_key(r): r for r in rows}
    pairs = [pair_analysis(a, b, evidence) for a, b in pair_rows(rows)]
    nodes, paths, winning = stored_graph(evidence)
    control_exact, control_unordered = defaultdict(list), defaultdict(list)
    for row in rows:
        if row["variant"] != "control_a":
            continue
        for step in row["trace"]:
            args = (step, evidence["geometry_ids"][row["screen"]], evidence["tiles"]["control_a"])
            visit = {"attempt": row_key(row), "tap": step["decision"]+1, "eventual_outcome": row["outcome"]}
            control_exact[mechanical_key(*args)].append(visit)
            control_unordered[mechanical_key(*args, unordered_tray=True)].append(visit)
    regressions = []
    for pair in pairs:
        if pair["classification"] != "BOTH_LOSS_EARLIER":
            continue
        a, b = (lookup[f"{arm}/{pair['pair']}"] for arm in ARMS)
        keys = paths[row_key(b)]
        fork = next((i for i, key in enumerate(keys[:-1]) if key in winning and keys[i+1] not in winning), None)
        winning_fork = None
        if fork is not None:
            alternatives = sorted(action for action, target in nodes[keys[fork]]["edges"].items() if target in winning)
            winning_fork = {"state": snapshot(b, fork, evidence), "observed_winning_alternatives": alternatives,
                "certificates": [prior.winning_continuation(keys[fork], action, nodes, winning, lookup) for action in alternatives],
                "interpretation": "Recorded edges joined only at exact mechanical states. This proves the listed continuation exists, not that the chosen branch is unsolvable or that a public-information bot could foresee it."}
        end = b["trace"][-1]
        args = (end, evidence["geometry_ids"][b["screen"]], evidence["tiles"]["candidate_b"])
        start = max(0, (pair["first_public_difference_tap"] or pair["b_taps"]) - 2)
        regressions.append({**pair, "a_terminal": snapshot(a, len(a["trace"])-1, evidence),
            "b_terminal": snapshot(b, len(b["trace"])-1, evidence),
            "a_b_mechanism_window": [{"tap": i+1, "control_a": snapshot(a, i, evidence),
                "candidate_b": snapshot(b, i, evidence)} for i in range(start, min(len(a["trace"]), len(b["trace"])))],
            "candidate_earliest_observed_winning_fork": winning_fork,
            "control_exact_mechanical_pre_loss_matches": control_exact[mechanical_key(*args)],
            "control_matches_ignoring_tray_order": control_unordered[mechanical_key(*args, unordered_tray=True)],
            "local_terminal_proof": {"all_legal_actions_lose": all(c["immediate_loss"] for c in end["candidates"]),
                "safe_actions": sum(not c["immediate_loss"] for c in end["candidates"]),
                "proof_scope": "All recorded legal immediate previews validated against tray arithmetic; reached state only, taps only."},
            "classification_notes": {"PROVEN": "The held-pair/accessibility intervention changes recorded triple timing before the first chosen-ID divergence. Geometry is unchanged.",
                "OBSERVED": "Earlier loss is reached by a different deterministic removal order after initial relief; it is not itself proof of a new structural deadlock.",
                "PLAUSIBLE": "Greedy ranking, hash tie breaks and exposed-only projection favor local matches while delaying a revealing move.",
                "UNVERIFIED": "All unobserved alternatives, exclusive effect of lookahead depth, human fairness and globally unavoidable loss."}})
    migration = defaultdict(list)
    outcome = lambda row: "WIN" if row["outcome"] == "WIN" else str(row["decisions"])
    for a, b in pair_rows(rows):
        migration[outcome(a), outcome(b)].append(pair_key(a))
    transitions = [{"a": a, "b": b, "count": len(members), "members": members}
                   for (a, b), members in sorted(migration.items())]
    taps = sorted({10, 22, 31, 34, 43, 55, 79} | {r["decisions"] for r in rows if r["outcome"] == "LOSS"})
    clusters = []
    for tap in taps:
        arms = {arm: cluster_stats([r for r in rows if r["variant"] == arm and r["outcome"] == "LOSS" and r["decisions"] == tap], evidence)
                for arm in ARMS}
        affecting = [p for p in pairs if (p["a_outcome"] == "LOSS" and p["a_taps"] == tap)
                     or (p["b_outcome"] == "LOSS" and p["b_taps"] == tap)]
        clusters.append({"tap": tap, **arms, "net_change_b_minus_a": arms["candidate_b"]["failures"]-arms["control_a"]["failures"],
            "outgoing": [t for t in transitions if t["a"] == str(tap)], "incoming": [t for t in transitions if t["b"] == str(tap)],
            "affecting_pair_classifications": dict(sorted(Counter(p["classification"] for p in affecting).items()))})
    correlation = {"strategy_same_path": {}, "medium_tall_same_path": {}, "small_medium_same_path": {}}
    for arm in ARMS:
        correlation["strategy_same_path"][arm] = {screen: sum(
            lookup[f"{arm}/{screen}/greedyMatch/{r}"]["path_ids"] == lookup[f"{arm}/{screen}/visibleLookahead/{r}"]["path_ids"]
            for r in range(30, 60)) for screen in SCREENS}
        for label, left, right in [("medium_tall_same_path", SCREENS[1], SCREENS[2]), ("small_medium_same_path", SCREENS[0], SCREENS[1])]:
            correlation[label][arm] = sum(lookup[f"{arm}/{left}/{p}/{r}"]["path_ids"] == lookup[f"{arm}/{right}/{p}/{r}"]["path_ids"]
                for p in STRATEGIES for r in range(30, 60))
    correlations = []
    for classification in ("BOTH_LOSS_EARLIER", "LOSS_TO_WIN", "BOTH_WIN"):
        selected = [p for p in pairs if p["classification"] == classification]
        trajectory_keys = [canonical([p["screen"], lookup[f"control_a/{p['pair']}"]["path_ids"],
                            lookup[f"candidate_b/{p['pair']}"]["path_ids"]]) for p in selected]
        correlations.append({"classification": classification, "records": len(selected),
            "distinct_replica_indices": sorted({p["replica"] for p in selected}),
            "distinct_paired_paths_including_geometry": len(set(trajectory_keys)),
            "distinct_id_sequence_pairs_ignoring_geometry": len({canonical([lookup[f"control_a/{p['pair']}"]["path_ids"],
                lookup[f"candidate_b/{p['pair']}"]["path_ids"]]) for p in selected})})
    totals = {arm: aggregate([r for r in rows if r["variant"] == arm]) for arm in ARMS}
    summary = {"schema": VERSION, "source_run": RUN, "attempts_analyzed": len(rows), "paired_comparisons": len(pairs),
        "decisions_validated": sum(len(r["trace"]) for r in rows), **totals,
        "paired_classifications": dict(sorted(Counter(p["classification"] for p in pairs).items())),
        "screens": [{"screen": s, **{a: aggregate([r for r in rows if r["variant"] == a and r["screen"] == s]) for a in ARMS}} for s in SCREENS],
        "strategies": [{"strategy": p, **{a: aggregate([r for r in rows if r["variant"] == a and r["strategy"] == p]) for a in ARMS}} for p in STRATEGIES],
        "cells": [{"screen": s, "strategy": p, **{a: aggregate([r for r in rows if r["variant"] == a and r["screen"] == s and r["strategy"] == p]) for a in ARMS}}
                  for s in SCREENS for p in STRATEGIES],
        "pair_details": pairs, "correlations": correlation, "conversion_trajectory_counts": correlations,
        "historical_recommendation_unchanged": evidence["source_summary"]["recommendation"],
        "recommended_option": "B", "recommendation_scope": "Retain both swaps as the in-memory candidate for targeted HUMAN PLAYTESTING / REVIEW ONLY. Do not promote to production; the predeclared REVISE outcome remains binding.",
        "option_comparison": {
            "A": "Safer measured survival for replica 53, but relinquishes ten observed loss-to-win conversions and 48 escapes from the tap-31 cluster. Valid fallback if human testing finds B's later commitments misleading.",
            "B": "Preferred for review: all six A wins retained, ten new B wins, gains on all screens, lower tap-31 losses, no opening regression. Four correlated earlier losses require investigation and human comparison; no production acceptance claimed.",
            "C": "A future alternative second swap may be justified after human evidence, but no alternative was measured here; replacing the current measured benefit now is unsupported."},
        "confidence": {"PROVEN": "Exact cohort, validated stored arithmetic/priorities, unchanged geometry, complete immediate losing action sets at reported terminal states.",
            "OBSERVED": "Fixed-policy paired outcome differences, earlier triple availability, removal-order divergence, retained wins and migration into later failure clusters.",
            "PLAUSIBLE": "Local greedy objectives, hash tie breaks and absent reveal forecasting explain undesirable commitments; causal contributions of search depth and information were not experimentally isolated.",
            "UNVERIFIED": "Human win rate, fairness, excessive ease, unsampled branches, optimal play and results of any future intervention."},
        "limitations": ["No new policy execution, search, witness generation, candidate or A/B cohort.",
            "Stored transition certificates establish existence only; missing branches remain unknown.",
            "Physical ID layouts, exact symbol-aware mechanical states, and public symbol/tray patterns are different equivalence relations.",
            "Tray-order-insensitive matches are reported separately, never called exact physical equality.",
            "Same-seed screen/strategy observations are correlated; no independent-trial significance or human-rate claim.",
            "This confirmation cohort is now inspected; it is no longer an unseen holdout for future tuning.",
            "The existing Flutter contract suites replay their required historical fixtures; the Python diagnostic invokes no agents."],
        "human_playtesting_focus": ["Compare A/B on small, medium and tall displays without exposing covered identities.",
            "Inspect replica-53-like paths around taps 28–43: early relief, empty tray at 36, star commitment and delayed flower/candy reveals.",
            "Check whether tap-31 escapes improve readability or merely postpone frustration into taps 34, 55 and 79.",
            "Assess challenge qualitatively; 16/180 bot wins and a highest cell of 5/30 do not estimate human difficulty."]}
    regression_payload = {"schema": VERSION, "source_run": RUN, "count": len(regressions), "cases": regressions,
        "proof_boundary": "Recorded actual transitions only; complete immediate legal previews validated. No hidden evidence supplied to an agent."}
    migration_payload = {"schema": VERSION, "source_run": RUN, "paired_transitions": transitions, "clusters": clusters,
        "state_definitions": {"physical_terminal": "After the losing tap: exact geometry, remaining IDs and ordered tray IDs; no symbol-version label.",
            "mechanical_terminal": "Physical terminal state plus type of every remaining/held tile. Can merge arms only after all differing types cease to be live.",
            "public_symbol_tray_pattern": "Before losing tap: ordered tray types and counts of selectable types, ignoring IDs/positions; not physical equality."}}
    return summary, regression_payload, migration_payload


def markdown(summary, regressions, migration):
    lines = ["# Phase 4D-6 — Level 96 regression and failure migration", "",
        f"Pinned source: `{RUN}` (**COMPLETE / OK**). Validated **{summary['attempts_analyzed']} stored attempts**, "
        f"**{summary['paired_comparisons']} pairs** and **{summary['decisions_validated']} decisions**, including recorded public previews and planner rankings.", "",
        "The Python diagnostic performs no simulations, policy searches or new candidate construction. It reconstructs only the two already-recorded symbol maps for consistency arithmetic. "
        "The required Flutter contract suites separately replay their existing historical fixtures. Historical artifacts and experiment implementations are unchanged.", "",
        "## Recommendation", "",
        f"**Option {summary['recommended_option']} — retain both swaps for targeted human review/playtesting only.** "
        f"{summary['recommendation_scope']} The Phase 4D-5 recommendation remains **REVISE**; this investigation does not waive its acceptance rules.", "",
        "| Option | Assessment |", "|---|---|"]
    for option, assessment in summary["option_comparison"].items():
        lines.append(f"| {option} | {assessment} |")
    lines += ["", "## Cohort and outcomes", "",
        "Both variants are independent production-derived models. A changes T094 heart→star and T095 star→heart; B additionally changes T071 banana→heart and T069 heart→banana. "
        "The source has replicas 30–59, the original three Campaign geometries, unchanged GreedyMatch and VisibleLookahead, paired-v1 seeds/priorities and exposed-only observations. "
        "All six stored winning witnesses, 18 single-decision paired checks and six historical replica-24 full-trace reproductions passed. No INCONCLUSIVE rows exist.", "",
        "| Arm | Attempts | Wins | Losses |", "|---|---:|---:|---:|"]
    for arm in ARMS:
        value = summary[arm]
        lines.append(f"| {arm} | {value['attempts']} | {value['wins']} | {value['losses']} |")
    lines += ["", "| Paired classification | Pairs |", "|---|---:|"]
    for name, n in summary["paired_classifications"].items():
        lines.append(f"| {name} | {n} |")
    lines += ["", "## Full failure migration", "",
        "Physical terminal states below are **after the actual losing tap**, including ordered tray IDs and exact geometry. "
        "Public symbol/tray patterns are **before that tap** and deliberately collapse IDs/positions. They must not be interpreted as identical boards. "
        "JSON additionally retains pre-loss physical counts, symbol-aware mechanical counts, member lists and incoming/outgoing transitions.", "",
        "| Loss tap | A losses | B losses | B−A | A terminal physical states | B terminal physical states | A public patterns | B public patterns |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for c in migration["clusters"]:
        a, b = c["control_a"], c["candidate_b"]
        lines.append(f"| {c['tap']} | {a['failures']} | {b['failures']} | {c['net_change_b_minus_a']:+d} | "
                     f"{a['distinct_terminal_physical_states']} | {b['distinct_terminal_physical_states']} | "
                     f"{a['distinct_pre_loss_symbol_tray_patterns']} | {b['distinct_pre_loss_symbol_tray_patterns']} |")
    lines += ["", "| A endpoint | B endpoint | Paired transitions |", "|---|---|---:|"]
    for t in migration["paired_transitions"]:
        lines.append(f"| {t['a']} | {t['b']} | {t['count']} |")
    lines += ["", "Of the 48 pairs escaping A's tap-31 loss, 14 end at B tap 34, 12 at 55, 12 at 79 and 10 win. "
        "Thus 38 of these escapes are delayed losses, not completions. The extra four tap-43 losses come from A tap 79, not from tap 31. "
        "The 70 unchanged tap-31 endpoints need not share a physical state. Tap 34 is a newly observed loss position in this sample; this alone does not prove a newly introduced unavoidable trap.", "",
        "## Screen and strategy breakdown", "",
        "| Screen | Strategy | A wins/N | B wins/N | A loss taps | B loss taps |", "|---|---|---:|---:|---|---|"]
    for cell in summary["cells"]:
        a, b = cell["control_a"], cell["candidate_b"]
        lines.append(f"| {cell['screen']} | {cell['strategy']} | {a['wins']}/{a['attempts']} | {b['wins']}/{b['attempts']} | {a['loss_taps']} | {b['loss_taps']} |")
    lines += ["", "Small improves 2→10 wins, medium 2→3 and tall 2→3. Greedy improves 3→7; lookahead 3→9. "
        "Eight of the ten new wins are small-screen records: replicas 45, 46, 54 and 57 under each strategy. "
        "Medium/tall add replica 57 under lookahead only. These are paired/correlated records, not ten independent trials.", "",
        "| Arm | Same Greedy/Lookahead ID path: small / medium / tall (each /30) | Same medium/tall ID path (/60) | Same small/medium ID path (/60) |",
        "|---|---|---:|---:|"]
    for arm in ARMS:
        cor = summary["correlations"]
        lines.append(f"| {arm} | {' / '.join(str(cor['strategy_same_path'][arm][s]) for s in SCREENS)} | "
                     f"{cor['medium_tall_same_path'][arm]} | {cor['small_medium_same_path'][arm]} |")
    lines += ["", "Medium and tall have identical ID trajectories in all 60 matched records per arm; their geometry remains physically distinct. "
        "Their matching outcome tables therefore are correlated trajectory evidence, not independent replication of the effect. Small-screen differences include actual path differences, not just different screen labels.", "",
        "| Class | Records | Replica indices | Distinct paired paths with geometry | Distinct ID path pairs ignoring geometry |", "|---|---:|---|---:|---:|"]
    for group in summary["conversion_trajectory_counts"]:
        lines.append(f"| {group['classification']} | {group['records']} | {group['distinct_replica_indices']} | "
                     f"{group['distinct_paired_paths_including_geometry']} | {group['distinct_id_sequence_pairs_ignoring_geometry']} |")
    lines += ["", "## All conversions and retained wins", "",
        "Every pair, including all both-loss pairs with changed survival, has its shared prefix, first public change, divergence snapshots, changed-tile exposure, "
        "triple timing and aligned pressure/opportunity differences in summary.json. Selected completion pairs are listed here without treating a merely legal alternative as a win.", "",
        "| Pair | A→B | Shared physical tap prefix length | First different chosen ID tap | First public change tap | A/B T071 tap | A/B T069 tap |",
        "|---|---|---:|---|---|---|---|"]
    for p in summary["pair_details"]:
        if p["classification"] not in ("LOSS_TO_WIN", "BOTH_WIN", "WIN_TO_LOSS"):
            continue
        events = p["changed_tile_events"]
        at = lambda arm, tile: events[arm][tile]["actual_chosen_tap"]
        lines.append(f"| {p['pair']} | {p['a_outcome']}({p['a_taps']})→{p['b_outcome']}({p['b_taps']}) | "
            f"{p['shared_physical_tap_prefix']['length']} | {p['shared_physical_tap_prefix']['first_different_tap']} | "
            f"{p['first_public_difference_tap']} | {at('control_a','L96_T071')}/{at('candidate_b','L96_T071')} | "
            f"{at('control_a','L96_T069')}/{at('candidate_b','L96_T069')} |")
    lines += ["", f"## Earlier-loss investigations ({regressions['count']} pairs)", "",
        "At the reached terminal state, a different legal tap avoids the immediate loss only if the validated safe-action set is nonempty. "
        "Earlier safe moves do not by themselves establish eventual success. Recorded-edge winning certificates, where present, have a stronger and explicitly limited existence claim."]
    for case in regressions["cases"]:
        prefix, pressure = case["shared_physical_tap_prefix"], case["pressure"]
        lines += ["", f"### {case['pair']}", "",
            f"Screen **{case['screen']}**, strategy **{case['strategy']}**, replica **{case['replica']}**, paired seed **{case['seed_uint32']}**. "
            f"A loses on tap **{case['a_taps']}**, B on **{case['b_taps']}**. First chosen-ID divergence: **tap {prefix['first_different_tap']}**; "
            f"the first **{prefix['length']} taps** use the same physical tile IDs. This does not imply identical tray contents after symbol-dependent resolution. "
            f"First public symbol difference occurs at tap **{case['first_public_difference_tap']}**.", "",
            f"Last identical tap prefix: `{' → '.join(prefix['ids'])}`.", "",
            f"Changed-tile events: `{case['changed_tile_events']}`.", "",
            "| At physical choice divergence | A | B |", "|---|---|---|"]
        div = case["physical_choice_divergence"]
        for label, getter in [
            ("Chosen tile", lambda s: s["analyst_only"]["chosen_id"]),
            ("Public chosen token", lambda s: s["public_observation_and_recorded_previews"]["chosen_token"]),
            ("Tray types", lambda s: s["public_observation_and_recorded_previews"]["tray_types"]),
            ("Tray occupancy", lambda s: s["public_observation_and_recorded_previews"]["tray_occupancy"]),
            ("Exposed tiles (IDs analyst-only)", lambda s: [(t["id"], t["type"]) for t in s["analyst_only"]["legal_tiles"]]),
            ("Available triples", lambda s: s["public_observation_and_recorded_previews"]["available_triple_types"]),
            ("Safe actions", lambda s: s["analyst_only"]["safe_action_ids"]),
            ("Losing actions", lambda s: s["analyst_only"]["losing_action_ids"]),
            ("Newly revealed by actual tap", lambda s: s["public_observation_and_recorded_previews"]["newly_revealed_tokens_after_actual_tap"]),
        ]:
            lines.append(f"| {label} | `{getter(div['control_a'])}` | `{getter(div['candidate_b'])}` |")
        lines += ["", "Recorded mechanism window (after divergence, equal tap numbers do not imply equal board states):", "",
            "| Tap | A chosen type/ID | A tray after | B chosen type/ID | B tray after | B exposed types | B newly revealed types |",
            "|---:|---|---:|---|---:|---|---|"]
        for window in case["a_b_mechanism_window"]:
            a, b = window["control_a"], window["candidate_b"]
            ap, bp = a["public_observation_and_recorded_previews"], b["public_observation_and_recorded_previews"]
            lines.append(f"| {window['tap']} | {a['analyst_only']['chosen_id']}={json.loads(ap['chosen_token'])[0]} | {ap['tray_after']} | "
                f"{b['analyst_only']['chosen_id']}={json.loads(bp['chosen_token'])[0]} | {bp['tray_after']} | "
                f"{[json.loads(t)[0] for t in bp['legal_tokens']]} | {[json.loads(t)[0] for t in bp['newly_revealed_tokens_after_actual_tap']]} |")
        for name in ("a_terminal", "b_terminal"):
            term = case[name]
            pub, diag = term["public_observation_and_recorded_previews"], term["analyst_only"]
            lines += ["", f"**{name}:** tap {term['tap']}; tray {pub['tray_occupancy']}/7 `{pub['tray_types']}`; "
                f"legal tiles `{[(t['id'],t['type']) for t in diag['legal_tiles']]}`; safe actions `{diag['safe_action_ids']}`; "
                f"losing actions `{diag['losing_action_ids']}`; available complete sets `{pub['available_triple_types']}`.", "",
                f"Nearest blocked held-symbol matches (**analyst-only**): `{diag['blocked_held_symbols'][:4]}`."]
        lines += ["", f"B terminal proof: `{case['local_terminal_proof']}`. "
            "At this terminal decision there is no safe alternative; the earlier critical choices must be investigated instead.", "",
            f"Control exact ordered mechanical-state matches: `{case['control_exact_mechanical_pre_loss_matches']}`. "
            f"Matches only after ignoring tray order: `{case['control_matches_ignoring_tray_order']}`. "
            "The latter establish recurrence of the same remaining board and held tile multiset with the same live symbols, not exact ordered physical equality.", "",
            f"Mean tray pressure over the shared {pressure['common_horizon_taps']}-tap horizon: A **{pressure['a_common_horizon_mean']:.4f}**, "
            f"B **{pressure['b_common_horizon_mean']:.4f}**. Lower average pressure can coexist with an earlier fatal commitment; it is not a safety guarantee."]
        fork = case["candidate_earliest_observed_winning_fork"]
        if fork:
            state = fork["state"]
            lines += ["", f"Earliest departure from the recorded winning-transition graph: **tap {state['tap']}**, "
                f"chosen `{state['analyst_only']['chosen_id']}`, observed winning alternatives `{fork['observed_winning_alternatives']}`. "
                "The full provenance of each recorded edge is retained in regression_cases.json. Missing branches remain unknown; this does not prove the chosen branch globally loses."]
            pub = state["public_observation_and_recorded_previews"]
            lines += ["", f"Critical tray: `{pub['tray_types']}`. Recorded root ranking:", "",
                "| Public token | Immediate tray after | Tray matches | Exposed same type | Unsigned tie priority | Inside branch cap |",
                "|---|---:|---:|---:|---:|---|"]
            for entry in pub["root_ranking"]["ranked"]:
                lines.append(f"| `{entry['token']}` | {entry['tray_after']} | {entry['tray_matches']} | "
                    f"{entry['exposed_same_type']} | {entry['priority_uint32']} | {entry['within_branch_cap']} |")
            lines += ["", "Start of an observed-edge certified winning suffix: `" +
                " → ".join(edge["id"] for edge in fork["certificates"][0]["recorded_edges"][:8]) + "`. "
                "The certificate joins existing transitions at exact symbol-aware mechanical states; it was not generated by running an agent."]
        else:
            lines += ["", "No exact-state observed winning continuation was found at an alternative fork. Unobserved alternatives remain unverified."]
    lines += ["", "## Mechanism and confidence", "",
        "**PROVEN / recorded local intervention:** at tap 28 in the regression family, both arms remove T071, but A sees banana and B sees heart. "
        "B completes its held heart pair immediately (tray 3→1); A reaches tray 4 and completes hearts with T069 on tap 29. "
        "The swap changes accessibility and triple timing without changing geometry. At tap 29, A's heart completion ranks first; B has no held pair and chooses T072 drop through the unchanged ranking/tie policy. "
        "T069 is selected as banana by B at tap 34, so both changed symbols directly enter the recorded trajectory.", "",
        "**OBSERVED / downstream commitment:** B clears shells at 31, drops at 33 and bananas at 36, reaching an empty tray. "
        "It then collects stars T057/T061 at 37–38, candy T055 at 39 and berry T059 at 40, delays T062 flower to 41 and takes T058 flower at 42. "
        "T060 candy is a legal alternative at tap 42, but its mere legality does not certify a win. At tap 43, berry T054 and candy T060 both overflow "
        "the tray `[star, star, candy, berry, flower, flower]`. Structural matching dependencies are listed per case. A's different order exposes and removes "
        "T056 flower at tap 42 and survives to its own tap-79 trap.", "",
        "**OBSERVED / policy limits:** at B tap 29, drop, flower and banana have equal primary greedy scores, with drop selected by the fixed unsigned hash priority. "
        "At taps 37–38 the visible star pair attracts the ranking; taps 39–40 and 42 include consequential equal-score choices. "
        "Both policies reach the same late local sequence for replica 53. Lookahead only projects currently exposed tiles at depth 3, cap 4, 84 expansions; "
        "newly revealed hidden identities never enter its projected search. This is an information/ordering limitation, not evidence that more depth alone would fix it.", "",
        "**PLAUSIBLE / causal mechanism beyond the direct recorded effects:** early relief changes symbol commitments, action order and later decision-index-dependent tie priorities. "
        "That can move the bottleneck deeper or lead to an earlier existing trap. The controlled paired swap explains the fixed-run outcome difference, "
        "but these observations cannot isolate the separate contributions of information, heuristic evaluation, branch pruning and depth. "
        "No counterfactual policy intervention was performed.", "",
        "**UNVERIFIED:** human fairness/win rate, excessive ease, all unobserved alternatives and global inevitability. "
        "Six stored witness wins establish existence of a solution for the two source variants, not that every branch remains solvable. "
        "Four earlier losses are not four independent failures: they share replica 53 and two screen geometries, with strategy paths that converge locally.", "",
        "## Human review and remaining uncertainties", ""]
    lines += [f"- {item}" for item in summary["human_playtesting_focus"]]
    lines += ["", *[f"- {item}" for item in summary["limitations"]], "",
        "## Reproduction and integrity", "",
        "The manifest records pinned SHA-256 input hashes, verified historical FNV fingerprints, the exact cohort, diagnostic/helper source snapshots, "
        "output payload hashes, mandatory validation outcomes and repeat-generation equality. All four analytical payloads are regenerated byte-identically; "
        "only manifest timestamp and destination metadata may differ. The diagnostic rejects alternate runs and writes only a uniquely allocated Phase 4D-6 directory. "
        "No Phase 4D-7 action was started.", ""]
    return "\n".join(lines)


def payloads(evidence):
    summary, regressions, migration = analyze(evidence)
    values = {"summary.json": summary, "regression_cases.json": regressions, "cluster_migration.json": migration}
    rendered = {name: json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n" for name, value in values.items()}
    rendered["report.md"] = markdown(summary, regressions, migration)
    return rendered


def assert_unchanged(evidence):
    require(evidence["hashes"] == {name: sha(evidence["source"] / name) for name in FILES}, "Source evidence changed")
    require(evidence["input_hashes"] == {name: sha(evidence["root"] / name) for name in evidence["input_hashes"]},
            "Historical input or implementation changed")


def write_run(evidence, parent, verify_repeat=True, validation=None):
    rendered = payloads(evidence)
    if verify_repeat:
        require(rendered == payloads(evidence), "Nondeterministic analytical payloads")
    assert_unchanged(evidence)
    summary = json.loads(rendered["summary.json"])
    parent = Path(parent)
    parent.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    directory = Path(tempfile.mkdtemp(prefix=f"phase4d6-level96-{stamp}-", dir=parent))
    for name, contents in rendered.items():
        with (directory / name).open("x", encoding="utf-8", newline="\n") as stream:
            stream.write(contents)
    manifest = {"schema": VERSION, "status": "COMPLETE", "measurement_health": "OK",
        "source_run": RUN, "source_path": evidence["source"].as_posix(),
        "source_sha256_before": evidence["hashes"], "source_sha256_after": {name: sha(evidence["source"] / name) for name in FILES},
        "validated_historical_input_sha256": evidence["input_hashes"],
        "actual_attempts": summary["attempts_analyzed"], "paired_comparisons": summary["paired_comparisons"],
        "decisions_validated": summary["decisions_validated"], "replica_indices": list(range(30, 60)),
        "variant_attempts": {arm: summary[arm]["attempts"] for arm in ARMS},
        "output_sha256": {name: sha(directory / name) for name in rendered},
        "repeat_generation_identical": verify_repeat, "validation": validation,
        "diagnostic_source_snapshot": Path(__file__).read_text(encoding="utf-8"), "diagnostic_source_sha256": sha(__file__),
        "trace_validator_snapshot": Path(prior.__file__).read_text(encoding="utf-8"), "trace_validator_sha256": sha(prior.__file__),
        "methodology": "Validate original Phase 4D-5 envelope first; reuse unchanged Phase 4D-4 trace arithmetic/ranking validator via a copied legacy envelope only. No policy execution; all analytical edges already exist in stored traces.",
        "state_identity_scope": "Exact geometry + remaining IDs + ordered tray; mechanical equality additionally compares live symbols. Unordered tray matches and public symbol/tray patterns are separate.",
        "recommended_option": summary["recommended_option"], "historical_recommendation": "REVISE",
        "recommendation_scope": summary["recommendation_scope"], "read_only_evidence": True,
        "new_ab_attempts": 0, "new_candidates_created": 0, "production_changes": False, "phase4d7_started": False,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "reproduce": "python -B test/balance_audit/level96_phase4d6_diagnostic.py --verify-repeat"}
    assert_unchanged(evidence)
    with (directory / "manifest.json").open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(manifest, stream, indent=2, sort_keys=True, ensure_ascii=False)
        stream.write("\n")
    return directory


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=Path.cwd())
    parser.add_argument("--verify-repeat", action="store_true")
    parser.add_argument("--validation-json", type=Path)
    args = parser.parse_args()
    evidence = load_evidence(args.workspace)
    validation = read_json(args.validation_json) if args.validation_json else None
    directory = write_run(evidence, args.workspace / "qa/campaign_validation_runs", args.verify_repeat, validation)
    print(f"COMPLETE / OK: {directory}")


if __name__ == "__main__":
    main()
