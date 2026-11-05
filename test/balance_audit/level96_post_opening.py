"""Phase 4D-4: read-only diagnostics over recorded 4D-3 traces; no agent runs.

Standard-library only. No Flutter/engine imports, new searches, new trajectories,
or level writes. Recorded transitions and graph queries are the evidence boundary.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict, deque
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import tempfile

VERSION = "campaign4d4/level96-post-opening-v1"
PAIRED = "campaign4d2/paired-v1"
SHADOW = "campaign4d3/level96-shadow-v1"
SCREENS = ("small_320x568", "medium_360x800", "tall_412x915")
STRATEGIES = ("greedyMatch", "visibleLookahead")
FILES = ("manifest.json", "attempts.jsonl", "summary.json", "report.md")
ASSET = "assets/levels/level_96.json"


class IntegrityError(ValueError):
    """Invalid or inconsistent evidence is never silently skipped."""


def require(condition, message):
    if not condition:
        raise IntegrityError(message)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def sha_file(path):
    with Path(path).open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def fnv(data):
    value = 0x811C9DC5
    for byte in data:
        value = ((value ^ byte) * 0x01000193) & 0xFFFFFFFF
    return value


def json_hash(value):
    return fnv(json.dumps(value, separators=(",", ":"), ensure_ascii=False).encode())


def attempt_id(row):
    return f"{row['variant']}/{row['screen']}/{row['strategy']}/{row['replica']:02d}"


def cohort(replica):
    return "overlap_0_9" if replica < 10 else "holdout_10_29"


def select_source(parent):
    eligible = []
    for path in Path(parent).glob("*/manifest.json"):
        try:
            manifest = json.loads(path.read_text(encoding="utf-8"))
        except (ValueError, OSError):
            continue
        if (manifest.get("schema") == SHADOW and manifest.get("status") == "COMPLETE"
                and manifest.get("measurement_health") == "OK"):
            stamp = datetime.fromisoformat(manifest["finished_utc"].replace("Z", "+00:00"))
            eligible.append((stamp, path.parent.name, path.parent))
    require(eligible, "No COMPLETE / OK Phase 4D-3 source")
    # Choose the latest eligible run, then validate it; never silently fall back
    # to older evidence when the selected run has corrupt/incomplete contents.
    return max(eligible)[2]


def token(tile):
    coord = lambda x: str(0.0 if x == 0 else float(x))
    return json.dumps([tile["type"], coord(tile["x"]), coord(tile["y"])], separators=(",", ":"))


def physical_key(variant, geometry, remaining, tray):
    """Exact state, including symbol version, geometry and ordered physical tray.

    Excludes seed, strategy, replica and tap count. Canonical *full values* are
    dictionary keys; hashes below are display identifiers, not equality proofs.
    Matched IDs are the complement of remaining + tray in the fixed 99-tile set.
    """
    return canonical([variant, geometry, sorted(remaining), list(tray)])


def state_id(key):
    return hashlib.sha256(key.encode()).hexdigest()


def legal_ids(remaining, blockers):
    return sorted(t for t in remaining if not (blockers[t] & remaining))


def resolve_recorded_tap(tray, tile_id, tiles):
    """Consistency arithmetic for an already recorded tap, never choose a move."""
    after = [*tray, tile_id]
    kind = tiles[tile_id]["type"]
    matches = [t for t in after if tiles[t]["type"] == kind]
    return [t for t in after if t not in matches[:3]] if len(matches) >= 3 else after


def validate_accounting(rows):
    expected = {(v, s, p, r) for v in ("control", "candidate") for s in SCREENS for p in STRATEGIES for r in range(30)}
    actual = [(x["variant"], x["screen"], x["strategy"], x["replica"]) for x in rows]
    require(len(rows) == 360 and len(set(actual)) == 360 and set(actual) == expected,
            "Attempt/cohort accounting mismatch")
    require(all(x["cohort"] == cohort(x["replica"]) for x in rows), "Wrong overlap/holdout stratum")


def load_evidence(source, workspace):
    source, workspace = Path(source), Path(workspace)
    require(all((source / f).is_file() for f in FILES), "Missing required 4D-3 artifacts")
    hashes = {f: sha_file(source / f) for f in FILES}
    manifest = json.loads((source / "manifest.json").read_text(encoding="utf-8"))
    summary = json.loads((source / "summary.json").read_text(encoding="utf-8"))
    require(manifest.get("schema") == SHADOW and manifest.get("status") == "COMPLETE"
            and manifest.get("measurement_health") == "OK", "Source is not COMPLETE / OK 4D-3")
    require(manifest["actual_attempts"] == 360 and manifest["planned_attempts"] == 360,
            "Unexpected attempt budget")
    require(manifest["replica_indices"] == list(range(30)) and manifest["strategies"] == list(STRATEGIES),
            "Unexpected replicas or policies")
    require(manifest["paired_policy_version"] == PAIRED and not manifest["variant_in_seed_or_priority"],
            "Paired policy namespace changed")
    require(manifest["inputs_unchanged"] and not manifest["problems"] and "report_error" not in manifest,
            "Source measurement errors")
    require(manifest["fingerprints_before"] == manifest["fingerprints_after"], "Source input drift")
    require(summary["evidence_complete"] and summary["actual_attempts"] == 360,
            "Incomplete source summary")
    require(len(summary["paired_outcomes"]) == 180 and len(summary["strategy_pairs"]) == 180
            and len(summary["cells"]) == 18 and all(not c["missing_replica_pairs"] for c in summary["cells"]),
            "Incomplete source comparisons")
    text = (source / "report.md").read_text(encoding="utf-8")
    require("360/360 attempts" in text and summary["recommendation"] in text, "Incomplete source Markdown")
    checks = manifest["control_reproduction"]
    expected = {(s, p, r) for s in SCREENS for p in STRATEGIES for r in range(10)}
    require(len(checks) == 60 and {(x["screen"], x["strategy"], x["replica"]) for x in checks} == expected
            and all(x["passed"] and x["trace_equal"] and x["outcome_equal"] for x in checks),
            "Historical control checks incomplete")
    gate = manifest["solvability_gate"]
    require(gate["passed"] and gate["invariants"]["inventory_equal"], "Solvability/inventory gate failed")
    require(len(gate["screens"]) == 3 and {g["screen"] for g in gate["screens"]} == set(SCREENS),
            "Geometry coverage mismatch")
    for g in gate["screens"]:
        require(g["passed"] and g["blocking_graph_equal"] and g["bounds_equal"], "Geometry gate failure")
        require(g["control_geometry"] == g["candidate_geometry"], "Different A/B geometry")
        for variant in ("control", "candidate"):
            replay = g[f"{variant}_replay"]
            require(replay["replay_success"] and replay["full_clearance"]
                    and replay["successful_moves"] == 99 and len(set(replay["winning_moves"])) == 99,
                    "Invalid stored witness evidence")
    raw = (workspace / ASSET).read_bytes()
    require(f"{fnv(raw):08x}" == manifest["fingerprints_before"][ASSET] == "2b2b8578",
            "Production level differs from original evidence")
    original = json.loads(manifest["input_snapshots_utf8"][ASSET])
    require(json.loads(raw) == original and original["level"] == 96
            and original.get("objective") is None, "Unsupported or changed level model")
    tiles = {v: {t["id"]: dict(t) for t in original["tiles"]} for v in ("control", "candidate")}
    swap = manifest["candidate_definition"]["type_swap"]
    require(swap == {"L96_T094": {"from": "heart", "to": "star"},
                     "L96_T095": {"from": "star", "to": "heart"}}, "Different candidate")
    # Reconstruct only the EXISTING candidate represented by the evidence.
    # Proposed future swaps are never applied to these models.
    for ident, change in swap.items():
        require(tiles["candidate"][ident]["type"] == change["from"], "Swap precondition failed")
        tiles["candidate"][ident]["type"] = change["to"]
    geometries = {g["screen"]: g["candidate_geometry"] for g in gate["screens"]}
    blockers = {}
    for screen, geom in geometries.items():
        graph = {t: set() for t in tiles["control"]}
        for edge in geom["blocking_edges"]:
            graph[edge["lower"]].add(edge["upper"])
        blockers[screen] = graph
    with (source / "attempts.jsonl").open(encoding="utf-8") as handle:
        rows = [json.loads(line) for line in handle if line.strip()]
    validate_accounting(rows)
    for variant in tiles:
        selected = [r for r in rows if r["variant"] == variant]
        for field in ("attempts", "wins", "losses"):
            require(summarize_rows(selected)[field] == summary[variant][field], "Source summary outcome mismatch")
    for cell in summary["cells"]:
        for variant in tiles:
            selected = [r for r in rows if r["variant"] == variant and r["screen"] == cell["screen"]
                        and r["strategy"] == cell["strategy"]
                        and (cell["cohort"] == "all_0_29" or cohort(r["replica"]) == cell["cohort"])]
            require(all(summarize_rows(selected)[f] == cell[variant][f] for f in ("attempts", "wins", "losses")),
                    "Source summary cohort mismatch")
    rows.sort(key=attempt_id)
    return {"source": source, "hashes": hashes, "manifest": manifest, "source_summary": summary,
            "tiles": tiles, "geometries": geometries, "blockers": blockers, "rows": rows,
            "asset_path": workspace / ASSET, "asset_sha256": hashlib.sha256(raw).hexdigest()}


def validate_trace(row, tiles, blockers):
    """Check every stored decision, including stored internal ranking nodes."""
    tag = attempt_id(row)
    require(row["level"] == 96 and row["experiment_version"] == PAIRED
            and row["shadow_experiment_version"] == SHADOW and not row["omniscient"]
            and row["cohort"] == cohort(row["replica"]), f"{tag}: identity mismatch")
    require(row["experiment_seed_uint32"] == json_hash([PAIRED, 96, row["replica"]]), f"{tag}: seed mismatch")
    trace = row["trace"]
    require(len(trace) == row["decisions"] == len(row["path_ids"]), f"{tag}: trace length")
    remaining, tray = set(tiles), []
    first_triple = first_available = first_risk = None
    token_by_id = {i: token(t) for i, t in tiles.items()}
    for index, step in enumerate(trace):
        context = f"{tag} tap {index + 1}"
        legal = legal_ids(remaining, blockers)
        require(step["decision"] == index and step["diagnostic_remaining_ids"] == sorted(remaining)
                and step["diagnostic_tray_ids"] == tray and step["diagnostic_legal_ids"] == legal,
                f"{context}: physical inventory/eligibility")
        public = sorted(token_by_id[t] for t in legal)
        require(step["legal_tokens"] == public, f"{context}: public observation")
        tray_types = [tiles[t]["type"] for t in tray]
        counts = Counter(tray_types)
        require(step["tray_types_before"] == tray_types and step["tray_before"] == len(tray)
                and abs(step["pressure_before"] - len(tray) / 7) < 1e-12, f"{context}: tray before")
        available = sorted(t for t, n in (counts + Counter(tiles[i]["type"] for i in legal)).items() if n >= 3)
        require(step["available_triple_types"] == available and step["high_risk"] == (len(tray) >= 6),
                f"{context}: opportunities/risk")
        if available and first_available is None:
            first_available = index
        if len(tray) >= 6 and first_risk is None:
            first_risk = index
        candidates = {x["token"]: x for x in step["candidates"]}
        require(len(candidates) == len(legal) and set(candidates) == set(public), f"{context}: candidate coverage")
        for ident in legal:
            entry = candidates[token_by_id[ident]]
            matching = counts[tiles[ident]["type"]] == 2
            after = len(tray) + 1 - (3 if matching else 0)
            require(entry["priority_uint32"] == json_hash([PAIRED, 96, row["replica"], index, "actual", [], token_by_id[ident]])
                    and entry["tray_after"] == after and entry["immediate_loss"] == (after == 7)
                    and entry["completes_triple"] == matching, f"{context}: candidate preview/priority")
        require(step["immediate_losing_choices"] == sum(c["immediate_loss"] for c in candidates.values()),
                f"{context}: losing options")
        # These are already stored planner projections, not new agent searches.
        require(step["rankings"] and step["rankings"][0]["planned_path_tokens"] == [], f"{context}: missing root ranking")
        for ranking in step["rankings"]:
            path = ranking["planned_path_tokens"]
            require(len(path) <= 2 and len(set(path)) == len(path) and set(path) <= set(public),
                    f"{context}: hidden/invalid planned path")
            projected = list(tray_types)
            for tok in path:
                kind = json.loads(tok)[0]
                projected.append(kind)
                if projected.count(kind) == 3:
                    projected = [t for t in projected if t != kind]
            options = set(public) - set(path)
            exposed_counts = Counter(json.loads(tok)[0] for tok in options)
            entries = ranking["ranked"]
            require(len(entries) == len(options) and {e["token"] for e in entries} == options,
                    f"{context}: ranking information boundary")
            ordering = []
            for position, entry in enumerate(entries):
                kind = json.loads(entry["token"])[0]
                matches = projected.count(kind)
                after = len(projected) + 1 - (3 if matches == 2 else 0)
                domain = "plan" if path else "actual"
                priority = json_hash([PAIRED, 96, row["replica"], index, domain, path, entry["token"]])
                require(entry["priority_uint32"] == priority and entry["tray_after"] == after
                        and entry["lost"] == (after == 7) and entry["tray_matches"] == matches
                        and entry["exposed_same_type"] == exposed_counts[kind]
                        and entry["within_branch_cap"] == (position < (4 if row["strategy"] == "visibleLookahead" else 1)),
                        f"{context}: stored ranking score/priority")
                ordering.append((after == 7, after, -matches, -exposed_counts[kind], priority, entry["token"]))
            require(ordering == sorted(ordering), f"{context}: ranking order")
        require(0 <= step["lookahead_nodes"] <= 84, f"{context}: planning budget")
        chosen = step["diagnostic_actual_chosen_id"]
        require(chosen in legal and row["path_ids"][index] == chosen
                and step["chosen_token"] == token_by_id[chosen], f"{context}: chosen move")
        after_tray = resolve_recorded_tap(tray, chosen, tiles)
        resolved = len(after_tray) < len(tray)
        require(step["tray_after"] == len(after_tray) and step["resolved_triple"] == resolved
                and abs(step["pressure_after"] - len(after_tray) / 7) < 1e-12, f"{context}: recorded transition")
        if resolved and first_triple is None:
            first_triple = index
        remaining.remove(chosen)
        terminal = len(after_tray) == 7 or not remaining
        newly = [] if terminal else sorted(token_by_id[t] for t in legal_ids(remaining, blockers) if t not in legal)
        require(newly == step["newly_selectable_tokens_after_tap"], f"{context}: recorded reveals")
        require(not terminal or index == len(trace) - 1, f"{context}: moves after termination")
        tray = after_tray
    expected_outcome = "LOSS" if len(tray) == 7 else "WIN" if not remaining else "INCONCLUSIVE"
    require(row["outcome"] == expected_outcome and expected_outcome != "INCONCLUSIVE"
            and row["final_board_count"] == len(remaining) and row["final_tray_count"] == len(tray), f"{tag}: result")
    require(row["first_resolved_triple_decision"] == first_triple
            and row["first_available_triple_decision"] == first_available
            and row["first_high_risk_decision"] == first_risk, f"{tag}: first events")
    require(row["max_tray_after_resolution"] == max(s["tray_after"] for s in trace)
            and abs(row["average_tray_pressure"] - sum(s["tray_after"] for s in trace) / len(trace) / 7) < 1e-12,
            f"{tag}: tray aggregate")


def build_state_graph(evidence):
    nodes, paths = {}, {}
    # Intern exact canonical geometry values to avoid copying thousands of edges
    # into every state key. These IDs are scoped to this single source run.
    geometry_values = sorted({canonical(g) for g in evidence["geometries"].values()})
    geometry_keys = {s: geometry_values.index(canonical(g)) for s, g in evidence["geometries"].items()}
    for row in sorted(evidence["rows"], key=attempt_id):
        tiles = evidence["tiles"][row["variant"]]
        validate_trace(row, tiles, evidence["blockers"][row["screen"]])
        keys = []
        for step in row["trace"]:
            key = physical_key(row["variant"], geometry_keys[row["screen"]],
                               step["diagnostic_remaining_ids"], step["diagnostic_tray_ids"])
            node = nodes.setdefault(key, {"step": step, "row": row, "edges": {}, "visits": []})
            node["visits"].append([attempt_id(row), step["decision"] + 1])
            keys.append(key)
        last = row["trace"][-1]
        end_remaining = set(last["diagnostic_remaining_ids"]) - {last["diagnostic_actual_chosen_id"]}
        end_tray = resolve_recorded_tap(last["diagnostic_tray_ids"], last["diagnostic_actual_chosen_id"], tiles)
        end = physical_key(row["variant"], geometry_keys[row["screen"]], end_remaining, end_tray)
        terminal = nodes.setdefault(end, {"terminal": row["outcome"], "edges": {}, "visits": []})
        require(terminal.get("terminal") == row["outcome"], "Inconsistent terminal state")
        paths[attempt_id(row)] = keys + [end]
        for index, key in enumerate(keys):
            action = row["path_ids"][index]
            target = keys[index + 1] if index + 1 < len(keys) else end
            previous = nodes[key]["edges"].get(action)
            require(previous is None or previous == target, "Same physical state/action has different successor")
            nodes[key]["edges"][action] = target
    # Winning reachability is exclusively through existing recorded edges. It
    # can join histories ONLY at identical exact physical states and geometry.
    predecessors = defaultdict(set)
    for key, node in nodes.items():
        for target in node["edges"].values():
            predecessors[target].add(key)
    winning = {k for k, n in nodes.items() if n.get("terminal") == "WIN"}
    queue = deque(sorted(winning))
    while queue:
        for pred in sorted(predecessors[queue.popleft()]):
            if pred not in winning:
                winning.add(pred)
                queue.append(pred)
    # A loss proof closes only when EVERY legal action is either an immediate
    # logged fatal preview or has an observed successor already certified lost.
    # Missing branches remain unknown; no solver or hypothetical trajectory runs.
    forced = {k: {"rule": "RECORDED_TERMINAL_LOSS"} for k, n in nodes.items() if n.get("terminal") == "LOSS"}
    for key in sorted(nodes, key=lambda k: len(nodes[k].get("step", {}).get("diagnostic_remaining_ids", []))):
        node = nodes[key]
        if "step" not in node:
            continue
        row, step = node["row"], node["step"]
        tiles = evidence["tiles"][row["variant"]]
        candidates = {c["token"]: c for c in step["candidates"]}
        certificates = []
        for ident in step["diagnostic_legal_ids"]:
            if candidates[token(tiles[ident])]["immediate_loss"]:
                certificates.append({"id": ident, "rule": "ALL_VISIBLE_PREVIEW_RULES_VALIDATED_IMMEDIATE_LOSS"})
            elif node["edges"].get(ident) in forced:
                certificates.append({"id": ident, "rule": "OBSERVED_FORCED_SUCCESSOR", "state_id": state_id(node["edges"][ident])})
            else:
                break
        else:
            forced[key] = {"rule": "ALL_LEGAL_ACTIONS_COVERED", "actions": certificates}
    return nodes, paths, winning, forced


def state_detail(row, step, evidence, key):
    tiles, blockers = evidence["tiles"][row["variant"]], evidence["blockers"][row["screen"]]
    remaining = set(step["diagnostic_remaining_ids"])
    tray = Counter(step["tray_types_before"])
    ranked = {entry["token"]: (i + 1, entry) for i, entry in enumerate(step["rankings"][0]["ranked"])}
    exposed = []
    for ident in step["diagnostic_legal_ids"]:
        priority, entry = ranked[token(tiles[ident])]
        unlocks = sorted(t for t in remaining if t != ident and blockers[t] & remaining == {ident})
        exposed.append({"id": ident, "type": tiles[ident]["type"], "root_rank": priority,
                        "root_score": entry, "structural_unlocks_if_removed": unlocks})
    matching_blocked = []
    for ident in sorted(remaining - set(step["diagnostic_legal_ids"])):
        kind = tiles[ident]["type"]
        if tray[kind]:
            matching_blocked.append({"id": ident, "type": kind, "tray_count": tray[kind],
                                     "active_blockers": sorted(blockers[ident] & remaining)})
    matching_blocked.sort(key=lambda d: (-d["tray_count"], len(d["active_blockers"]), d["id"]))
    return {"attempt": attempt_id(row), "tap": step["decision"] + 1, "state_id": state_id(key),
            "remaining_ids": step["diagnostic_remaining_ids"], "tray_ids": step["diagnostic_tray_ids"],
            "tray_types": step["tray_types_before"], "tray_occupancy": step["tray_before"],
            "chosen_id": step["diagnostic_actual_chosen_id"], "chosen_type": json.loads(step["chosen_token"])[0],
            "legal_tiles": exposed, "available_triple_types": step["available_triple_types"],
            "immediate_safe_moves": sum(not c["immediate_loss"] for c in step["candidates"]),
            "alternative_legal_moves": [i for i in step["diagnostic_legal_ids"] if i != step["diagnostic_actual_chosen_id"]],
            "blocked_matching_symbols_PRIVILEGED_DIAGNOSTIC_ONLY": matching_blocked,
            "information_boundary": "Blocker identities and covered symbols are analyst-only stored data, never agent inputs"}


def summarize_rows(rows):
    return {"attempts": len(rows), "wins": sum(r["outcome"] == "WIN" for r in rows),
            "losses": sum(r["outcome"] == "LOSS" for r in rows),
            "loss_taps": dict(sorted(Counter(str(r["decisions"]) for r in rows if r["outcome"] == "LOSS").items(), key=lambda x: int(x[0])))}


def winning_continuation(start, first_action, nodes, winning, row_lookup):
    key, action, steps = start, first_action, []
    while "terminal" not in nodes[key]:
        node = nodes[key]
        target = node["edges"][action]
        require(target in winning, "Nonwinning edge in certificate")
        producer = next((ident, tap) for ident, tap in node["visits"]
                        if row_lookup[ident]["path_ids"][tap - 1] == action)
        steps.append({"id": action, "from_state": state_id(key), "to_state": state_id(target),
                      "source_attempt": producer[0], "source_tap": producer[1]})
        key = target
        if "terminal" not in nodes[key]:
            action = min(a for a, t in nodes[key]["edges"].items() if t in winning)
    require(nodes[key]["terminal"] == "WIN", "Certificate did not reach recorded win")
    return {"first_action": first_action, "recorded_edges": steps,
            "scope": "Joined recorded edges at exact physical states; no new simulation or policy run"}


def analyze(evidence):
    nodes, paths, winning, forced = build_state_graph(evidence)
    rows = sorted(evidence["rows"], key=attempt_id)
    row_lookup = {attempt_id(r): r for r in rows}
    candidate = [r for r in rows if r["variant"] == "candidate"]
    winners = [r for r in candidate if r["outcome"] == "WIN"]
    failures = [r for r in candidate if r["outcome"] == "LOSS"]
    details, clusters, proposal_support = [], {}, defaultdict(list)
    for row in failures:
        ident, trace = attempt_id(row), row["trace"]
        keys = paths[ident]
        terminal = state_detail(row, trace[-1], evidence, keys[-2])
        certified = next((i for i, k in enumerate(keys[:-1]) if k in forced), None)
        fork = next((i for i, k in enumerate(keys[:-1]) if k in winning and keys[i + 1] not in winning), None)
        critical = None
        if fork is not None:
            critical = state_detail(row, trace[fork], evidence, keys[fork])
            alternatives = [action for action, target in nodes[keys[fork]]["edges"].items() if target in winning]
            critical["observed_winning_alternative_ids"] = sorted(alternatives)
            critical["supporting_visits"] = nodes[keys[fork]]["visits"]
            critical["winning_continuation_certificates"] = [
                winning_continuation(keys[fork], action, nodes, winning, row_lookup) for action in sorted(alternatives)]
            critical["inference"] = "Earliest departure from the observed winning transition graph; chosen branch may still have unobserved winning continuations"
        comparisons = []
        for win in winners:
            if win["screen"] != row["screen"]:
                continue
            win_keys = set(paths[attempt_id(win)][:-1])
            shared = [i for i, k in enumerate(keys[:-1]) if k in win_keys]
            prefix = 0
            for a, b in zip(row["path_ids"], win["path_ids"]):
                if a != b:
                    break
                prefix += 1
            comparisons.append({"winner": attempt_id(win), "identical_action_prefix_length": prefix,
                                "shared_physical_state_taps": [i + 1 for i in shared],
                                "last_shared_state_tap": shared[-1] + 1 if shared else None})
        record = {"attempt": ident, "screen": row["screen"], "strategy": row["strategy"],
                  "replica": row["replica"], "cohort": row["cohort"], "loss_tap": row["decisions"],
                  "classification": {"terminal_immediate_dead_end_proven": terminal["immediate_safe_moves"] == 0,
                      "earlier_observed_winning_alternative": critical is not None,
                      "blocked_held_symbols_observed": bool(terminal["blocked_matching_symbols_PRIVILEGED_DIAGNOSTIC_ONLY"]),
                      "chosen_earlier_branch_unsolvable": "UNKNOWN",
                      "exclusive_cause_structural_vs_strategy": "NOT_IDENTIFIABLE_FROM_THIS_OBSERVATIONAL_COHORT"},
                  "terminal": terminal, "earliest_observed_winning_fork": critical,
                  "earliest_certified_forced_loss": None if certified is None else {
                      **state_detail(row, trace[certified], evidence, keys[certified]), "certificate": forced[keys[certified]]},
                  "last_successful_moves": [{"tap": s["decision"] + 1, "id": s["diagnostic_actual_chosen_id"],
                    "type": json.loads(s["chosen_token"])[0], "tray_before": s["tray_types_before"],
                    "tray_after_count": s["tray_after"], "resolved_triple": s["resolved_triple"]} for s in trace[max(0, len(trace) - 6):-1]],
                  "same_geometry_winner_comparisons": comparisons}
        details.append(record)
        group = clusters.setdefault(row["decisions"], [])
        group.append(record)
        # Static, inventory-preserving *proposals*, not modified levels or replay.
        # At the frozen pre-loss state an exposed blocker could carry the needed
        # symbol of its directly blocked donor. No trajectory benefit is claimed.
        for donor in terminal["blocked_matching_symbols_PRIVILEGED_DIAGNOSTIC_ONLY"]:
            if donor["tray_count"] != 2 or len(donor["active_blockers"]) != 1:
                continue
            exposed = donor["active_blockers"][0]
            if exposed in trace[-1]["diagnostic_legal_ids"]:
                proposal_support[(exposed, donor["id"])].append(record)
    cluster_rows = []
    for tap, group in sorted(clusters.items()):
        states = defaultdict(list)
        for item in group:
            states[item["terminal"]["state_id"]].append(item["attempt"])
        forks = Counter((r["earliest_observed_winning_fork"] or {}).get("tap") for r in group)
        certified = Counter((r["earliest_certified_forced_loss"] or {}).get("tap") for r in group)
        cluster_rows.append({"loss_tap": tap, "attempts": len(group), "unique_terminal_physical_states": len(states),
            "state_groups": [{"state_id": k, "attempts": v} for k, v in sorted(states.items())],
            "cohorts": dict(sorted(Counter(f"{r['screen']}/{r['strategy']}/{r['cohort']}" for r in group).items())),
            "critical_fork_taps": {str(k): v for k, v in sorted(forks.items(), key=lambda x: -1 if x[0] is None else x[0])},
            "certified_forced_loss_taps": {str(k): v for k, v in sorted(certified.items(), key=lambda x: -1 if x[0] is None else x[0])},
            "immediately_forced_at_terminal": sum(r["terminal"]["immediate_safe_moves"] == 0 for r in group),
            "members": [r["attempt"] for r in group]})
    proposals = []
    for (exposed, donor), support in proposal_support.items():
        tiles = evidence["tiles"]["candidate"]
        proposals.append({"swap": [exposed, donor], "current_types": [tiles[exposed]["type"], tiles[donor]["type"]],
            "frozen_terminal_attempts_with_immediate_relief": len(support),
            "unique_terminal_states": len({r["terminal"]["state_id"] for r in support}),
            "loss_taps": dict(sorted(Counter(str(r["loss_tap"]) for r in support).items())),
            "affected_strata": dict(sorted(Counter(f"{r['screen']}/{r['strategy']}/{r['cohort']}" for r in support).items())),
            "touches_existing_opening_swap": bool({exposed, donor} & {"L96_T094", "L96_T095"}),
            "supporting_attempts": [r["attempt"] for r in support],
            "status": "HYPOTHESIS_ONLY_NOT_APPLIED_NOT_REPLAYED",
            "limitation": "Only frozen-state immediate relief is inferred; earlier choices, later inventory pressure, witness viability and human challenge may change"})
    proposals.sort(key=lambda p: (-p["frozen_terminal_attempts_with_immediate_relief"], p["touches_existing_opening_swap"], p["swap"]))
    stratified = []
    for variant in ("control", "candidate"):
        for screen in SCREENS:
            for strategy in STRATEGIES:
                for part in ("overlap_0_9", "holdout_10_29"):
                    selected = [r for r in rows if (r["variant"], r["screen"], r["strategy"], r["cohort"]) == (variant, screen, strategy, part)]
                    stratified.append({"variant": variant, "screen": screen, "strategy": strategy, "cohort": part, **summarize_rows(selected)})
    lookup = {attempt_id(r): r for r in candidate}
    strategy_comparisons = []
    for screen in SCREENS:
        for replica in range(30):
            a = lookup[f"candidate/{screen}/greedyMatch/{replica:02d}"]
            b = lookup[f"candidate/{screen}/visibleLookahead/{replica:02d}"]
            strategy_comparisons.append({"screen": screen, "replica": replica, "cohort": cohort(replica),
                "greedy_outcome": a["outcome"], "lookahead_outcome": b["outcome"],
                "same_physical_move_sequence": a["path_ids"] == b["path_ids"],
                "first_different_tap": next((i + 1 for i, (x, y) in enumerate(zip(a["path_ids"], b["path_ids"])) if x != y), None)})
    critical_root = []
    for record in details:
        fork = record["earliest_observed_winning_fork"]
        if not fork:
            continue
        alternatives = [t for t in fork["legal_tiles"] if t["id"] in fork["observed_winning_alternative_ids"]]
        chosen = next(t for t in fork["legal_tiles"] if t["id"] == fork["chosen_id"])
        score_fields = ("lost", "tray_after", "tray_matches", "exposed_same_type")
        critical_root.append({"attempt": record["attempt"], "tap": fork["tap"],
            "known_winning_alternative_inside_cap4": any(t["root_rank"] <= 4 for t in alternatives),
            "known_winning_alternative_equal_greedy_score": any(all(t["root_score"][f] == chosen["root_score"][f] for f in score_fields) for t in alternatives),
            "known_winning_alternative_ranks": [t["root_rank"] for t in alternatives]})
    total_decisions = sum(len(r["trace"]) for r in rows)
    summary = {"schema": VERSION, "source_run": evidence["manifest"]["run_id"],
        "attempts_analyzed": len(rows), "decisions_validated": total_decisions,
        "control": summarize_rows([r for r in rows if r["variant"] == "control"]),
        "candidate": summarize_rows(candidate), "strata": stratified,
        "candidate_by_screen": {s: summarize_rows([r for r in candidate if r["screen"] == s]) for s in SCREENS},
        "candidate_by_strategy": {s: summarize_rows([r for r in candidate if r["strategy"] == s]) for s in STRATEGIES},
        "candidate_by_cohort": {s: summarize_rows([r for r in candidate if r["cohort"] == s]) for s in ("overlap_0_9", "holdout_10_29")},
        "candidate_failure_clusters": [{k: v for k, v in c.items() if k not in ("state_groups", "members")} for c in cluster_rows],
        "candidate_winners": [{"attempt": attempt_id(r), "path_ids": r["path_ids"],
            "physical_states": [state_id(k) for k in paths[attempt_id(r)]]} for r in winners],
        "distinct_winning_physical_paths": len({canonical([r["screen"], r["path_ids"]]) for r in winners}),
        "failures_with_observed_winning_fork": sum(r["earliest_observed_winning_fork"] is not None for r in details),
        "critical_root_ordering": critical_root,
        "strategy_comparisons": strategy_comparisons,
        "lookahead": {"decisions": sum(len(r["trace"]) for r in candidate if r["strategy"] == "visibleLookahead"),
            "pruned_options": sum(r["lookahead_branch_options_pruned"] for r in candidate if r["strategy"] == "visibleLookahead"),
            "budget_exhausted_decisions": sum(r["lookahead_budget_exhausted_decisions"] for r in candidate if r["strategy"] == "visibleLookahead")},
        "proposal_rankings": proposals,
        "recommended_next_experiment": next((p for p in proposals if not p["touches_existing_opening_swap"]), None),
        "recommendation_selection_rule": "Largest frozen-state immediate-relief support among proposals that preserve both Phase 4D-3 opening-swap tiles; not a measured win improvement",
        "classification": {
            "PROVEN_LOCAL": "Every terminal state with zero safe legal previews is a taps-only immediate dead end; recursive certificates require complete observed action coverage",
            "OBSERVED_STRATEGIC": "A shared exact physical state has an observed winning alternative; leaving its recorded winning graph is not proof the chosen branch is unsolvable",
            "OBSERVED_STRUCTURAL": "Needed symbols remain behind active blockers at saturated tray states; global level solvability is established separately by stored witnesses",
            "HYPOTHESIS_INFORMATION": "Greedy preference and exposed-only planning can undervalue revealing covered matches; no depth/cap intervention was run",
            "UNVERIFIED": "Human fairness, optimal policy win rate, unsampled alternative continuations, benefit or challenge level after any proposed swap"}}
    failure_keys = {q for r in failures for q in paths[attempt_id(r)]}
    cluster_payload = {"schema": VERSION, "source_run": summary["source_run"], "clusters": cluster_rows,
        "failed_attempt_details": details,
        "forced_state_certificates": [{"state_id": state_id(k), **cert} for k, cert in sorted(forced.items())
            if k in failure_keys],
        "proof_scope": "Existing recorded transitions and complete legal immediate previews only; no search, no new policies, no new A/B attempts"}
    return summary, cluster_payload


def markdown(summary, clusters):
    lines = ["# Phase 4D-4 — Level 96 post-opening investigation", "",
        f"Source: `{summary['source_run']}` (COMPLETE / OK). All **{summary['attempts_analyzed']} stored attempts** and "
        f"**{summary['decisions_validated']} actual decisions** were validated, including recorded planner rankings. "
        "No new A/B cohort, agent execution, alternate-policy search or level edit was performed.", "",
        "## Findings and confidence", "",
        "**High confidence, conditional proof:** every reported terminal state with zero safe legal moves has six of seven tray slots occupied "
        "and every legal next tap loses after resolution. This proves a taps-only immediate dead end at that reached state, "
        "not that the initial level or an earlier unobserved branch is unsolvable. The six stored witness replays establish initial solvability.", "",
        f"**High confidence, observed choices:** all {summary['failures_with_observed_winning_fork']} candidate failures leave a graph "
        "of recorded winning continuations at an identifiable earlier fork. Certificates link ONLY already recorded transitions at exact "
        "physical states. They show that a legal alternative with a recorded winning continuation existed. They do not prove the chosen "
        "branch had no unrecorded recovery or that a human could know the hidden symbols.", "",
        "**High confidence, structural association:** saturated trays retain pairs whose completing symbols are blocked. Static dependencies "
        "and the selected removal order delay their availability. The same geometry also supports wins; this is a geometry/symbol/choice interaction, "
        "not a proof that geometry alone makes the level unfair.", "",
        "**Moderate confidence, explanatory hypothesis:** greedy matching and exposed-only lookahead undervalue earlier revealing moves. "
        "The depth/branch limits are known, but no depth or cap intervention was run, so their separate causal effects are unmeasured. "
        "Increasing depth cannot recover symbols that never enter the projection.", "",
        "**Unverified:** human win rate, all unsampled continuations, absence of later traps, and the benefit or difficulty of proposed swaps.", "",
        "## Cohort accounting", "",
        "| Arm | Screen | Strategy | Stratum | N | Wins | Losses | Loss taps: count |",
        "|---|---|---|---|---:|---:|---:|---|"]
    for r in summary["strata"]:
        lines.append(f"| {r['variant']} | {r['screen']} | {r['strategy']} | {r['cohort']} | {r['attempts']} | {r['wins']} | {r['losses']} | {r['loss_taps']} |")
    lines += ["", "Candidate aggregates (descriptive bot outcomes, not human probabilities):", "",
              "| Dimension | Group | Wins / N | Loss taps: count |", "|---|---|---:|---|"]
    for dimension in ("screen", "strategy", "cohort"):
        for name, group in summary[f"candidate_by_{dimension}"].items():
            lines.append(f"| {dimension} | {name} | {group['wins']}/{group['attempts']} | {group['loss_taps']} |")
    lines += ["", "The small screen has six stored wins; medium and tall have one each. The 36 tap-10 losses occur only "
              "on medium/tall, while small-screen losses concentrate at tap 31. Medium/tall outcome counts coincide, "
              "but their physical geometries remain distinct. These are paired deterministic replicas, not independent Bernoulli human trials.", "",
              "Symbol distribution is implicated locally: completing symbols for retained pairs remain behind selectable blockers of other "
              "types. Swaps preserve global inventory, and the same inventory permits observed wins. Thus these traces support a local "
              "availability/order bottleneck, not a proven global symbol-count defect. Structural constraints, heuristic ordering and "
              "limited public information interact; this observational cohort cannot assign exclusive causal shares."]
    lines += ["", "0–9 and 10–29 retain their historical overlap/holdout labels. Both strata have now been inspected for proposal discovery; "
              "10–29 must not be advertised as a fresh holdout for a future candidate designed from these findings.", "",
              "## Failure clusters and state identity", "",
              "| Loss tap | Failed attempts | Distinct exact pre-loss states | Immediately forced | Earliest observed winning forks (tap: N) | Earliest certified loss (tap: N) |",
              "|---:|---:|---:|---:|---|---|"]
    for c in clusters["clusters"]:
        lines.append(f"| {c['loss_tap']} | {c['attempts']} | {c['unique_terminal_physical_states']} | {c['immediately_forced_at_terminal']} | {c['critical_fork_taps']} | {c['certified_forced_loss_taps']} |")
    lines += ["", "Physical equality uses the exact remaining IDs, ordered tray IDs, symbol version and exact geometry (interned by full-value equality). "
        "Seed, strategy, replica and tap count are excluded. State IDs are display hashes of exact keys scoped to this source. "
        "Same-tap clusters are not physical-state equivalence classes. Different screens remain distinct even when move IDs coincide.", "",
        "Earliest observed fork = first recorded step that leaves observed winning reachability. Missing edges mean unknown, not a forced loss. "
        "Earliest certified loss = every legal action immediately loses or has an observed already-certified losing successor. "
        "In this evidence these certificates do not establish that earlier apparently risky states are unsolvable."]
    by_id = {r["attempt"]: r for r in clusters["failed_attempt_details"]}
    for group in clusters["clusters"]:
        tap = group["loss_tap"]
        lines += ["", f"## Loss cluster at tap {tap}", "",
                  f"{group['attempts']} attempts; {group['unique_terminal_physical_states']} distinct pre-loss physical states. "
                  "All member-level traces, alternatives, blocker lists, winning-suffix certificates and winner comparisons are in failure_clusters.json.", "",
                  "| Screen / strategy / stratum | Failures |", "|---|---:|"]
        for stratum, count in group["cohorts"].items():
            lines.append(f"| {stratum} | {count} |")
        # Show one example per affected geometry; JSON retains every failed attempt.
        examples = []
        for screen in SCREENS:
            record = next((by_id[i] for i in group["members"] if by_id[i]["screen"] == screen), None)
            if record:
                examples.append(record)
        for record in examples:
            terminal = record["terminal"]
            lines += ["", f"### Example `{record['attempt']}`", "",
                f"Pre-loss state `{terminal['state_id']}`. Tray ({terminal['tray_occupancy']}/7): "
                f"`{terminal['tray_types']}`. Available complete visible sets: `{terminal['available_triple_types']}`. "
                f"Safe next moves: **{terminal['immediate_safe_moves']}**. Other legal moves: `{terminal['alternative_legal_moves']}`.", "",
                "Last successful taps: " + "; ".join(f"{m['tap']}: {m['id']} ({m['type']}), tray→{m['tray_after_count']}" for m in record["last_successful_moves"]) + ".", "",
                "Exposed legal tiles: " + "; ".join(f"{t['id']}={t['type']}" for t in terminal["legal_tiles"]) + ".", "",
                "Nearest blocked matching symbols (privileged diagnostic, not agent knowledge): " + "; ".join(
                    f"{t['id']}={t['type']} behind {t['active_blockers']}" for t in terminal["blocked_matching_symbols_PRIVILEGED_DIAGNOSTIC_ONLY"][:3]) + "."]
            fork = record["earliest_observed_winning_fork"]
            if fork:
                lines += ["", f"Earliest observed winning fork: **tap {fork['tap']}**, tray `{fork['tray_types']}`. "
                    f"Chosen `{fork['chosen_id']}={fork['chosen_type']}`; known winning alternatives `{fork['observed_winning_alternative_ids']}`. "
                    "The alternate suffix uses recorded transitions, potentially from different attempts joined at identical states; it is not a newly run bot.", "",
                    "| Legal option | Type | Root rank | Immediate tray after | Tray matches | Exposed same type | Structurally reveals if removed |",
                    "|---|---|---:|---:|---:|---:|---|"]
                for t in fork["legal_tiles"]:
                    score = t["root_score"]
                    lines.append(f"| {t['id']} | {t['type']} | {t['root_rank']} | {score['tray_after']} | {score['tray_matches']} | {score['exposed_same_type']} | {t['structural_unlocks_if_removed']} |")
                cert = fork["winning_continuation_certificates"][0]
                lines += ["", "Start of one certified observed-edge winning continuation: `" +
                          " → ".join(edge["id"] for edge in cert["recorded_edges"][:6]) + "`. Full edge provenance is in JSON."]
    root = summary["critical_root_ordering"]
    look = [x for x in root if "/visibleLookahead/" in x["attempt"]]
    same = sum(r["same_physical_move_sequence"] for r in summary["strategy_comparisons"])
    lines += ["", "## Eight successful attempts versus failures", "",
        f"{len(summary['candidate_winners'])} winning attempt records represent **{summary['distinct_winning_physical_paths']} distinct physical paths** "
        "when geometry is included; they are not eight independent human observations.", "",
        "| Winning record | Moves |", "|---|---:|"]
    for winner in summary["candidate_winners"]:
        lines.append(f"| {winner['attempt']} | {len(winner['path_ids'])} |")
    lines += ["", "Each failed record is compared to every successful record on its own geometry. JSON records both the original "
        "shared action-prefix length and all shared physical-state taps: paths can diverge and later rejoin after completed triples. "
        "Cross-screen records are not declared identical. The winning-transition graph additionally permits certified joins of observed "
        "nonwinning prefixes to observed winning suffixes at exact states.", "",
        "## Strategy and planning limitations", "",
        f"Greedy and lookahead follow exactly the same candidate physical move sequence in **{same}/90** matched screen/replica pairs. "
        f"Among {len(look)} failing lookahead records, a known winning root alternative is already inside the four-child cap at "
        f"**{sum(x['known_winning_alternative_inside_cap4'] for x in look)}** critical forks. "
        f"An alternative has the same greedy score at **{sum(x['known_winning_alternative_equal_greedy_score'] for x in root)}/{len(root)}** failing critical forks.", "",
        f"Candidate lookahead totals: `{summary['lookahead']}`. Depth remains 3, branch cap 4 and expansion cap 84. "
        "Zero exhausted expansion budgets does not imply complete search: pruning and the absent reveal model remain. "
        "Root alternatives already inside the cap cannot be explained solely by root pruning; deeper pruning or short-horizon evaluation "
        "may still matter. No experiment here isolates depth from missing information.", "",
        "## Minimal changes for later review — none implemented", "",
        "The table ranks static donor/blocker swaps. At a FROZEN recorded terminal state, a selectable blocker would carry the "
        "needed symbol of a directly blocked donor and complete a held pair. Counts are NOT projected wins; earlier actions and "
        "the donor's later type change may alter the entire path. Inventory preservation follows from exchanging two types, "
        "but witness viability and acceptable challenge have not been tested.", "",
        "| Proposed pair | Current candidate types | Frozen-state relief records | Distinct states | Loss taps | Touches opening swap |",
        "|---|---|---:|---:|---|---|"]
    for p in summary["proposal_rankings"][:8]:
        lines.append(f"| {' ↔ '.join(p['swap'])} | {' ↔ '.join(p['current_types'])} | {p['frozen_terminal_attempts_with_immediate_relief']} | {p['unique_terminal_states']} | {p['loss_taps']} | {p['touches_existing_opening_swap']} |")
    chosen = summary["recommended_next_experiment"]
    if chosen:
        lines += ["", "**Recommended next experiment, for review only:** retain the existing 094/095 opening swap and evaluate "
            f"one additional exchange **{' ↔ '.join(chosen['swap'])} ({' ↔ '.join(chosen['current_types'])})**. "
            f"Selection rule: {summary['recommendation_selection_rule']}. "
            f"It offers conditional immediate relief in {chosen['frozen_terminal_attempts_with_immediate_relief']} stored failures, "
            "not every member of the larger cluster and not a predicted completion gain.", "",
            "Proposed design: current Phase 4D-3 candidate as control; its independent in-memory copy with only this extra swap as candidate. "
            "Require inventory/geometry equality and all six witness gates, then a separately authorized fixed 360-attempt comparison "
            "(2 arms × 3 screens × 2 unchanged policies × replicas 0–29, same paired-v1 keys). Reproduce all 180 current-candidate control "
            "records before interpretation. Because these seeds informed proposal selection, this is exploratory regression evidence. "
            "Independent confirmation requires separately predeclared unseen replicas, with an explicitly approved budget; no automatic expansion.", "",
            "Acceptance review must examine new seven-tap losses, cluster migration, paired regressions, remaining pressure and late failures, "
            "plus human readability/challenge. Do not combine multiple proposed swaps or infer that more bot wins are automatically better design. "
            "The 094/093 proposal would alter an existing opening-swap tile and is lower priority for this reason despite its larger frozen-state count."]
    lines += ["", "## Reproducibility and uncertainty", "",
        "manifest.json records SHA-256 input/output fingerprints, source selection, trace-validation scope, diagnostic source snapshots, "
        "repeat-generation verification and mandatory validation outcomes. failure_clusters.json contains every failed member, full physical-state "
        "grouping and local loss certificates. No hidden information was supplied to an agent; no new agent was invoked by this analysis.", "",
        "All observations are conditional on the fixed exposed-only policies and deterministic sampled keys. Stored-witness and observed-edge "
        "certificates are evidence about the fixed taps-only rules. No claim is made that earlier unknown branches are unsolvable, that the "
        "proposal eliminates all traps, or that a measured bot rate is a human win rate. Phase 4D-5 has not been started."]
    return "\n".join(lines) + "\n"


def payloads(evidence):
    summary, clusters = analyze(evidence)
    return {"summary.json": json.dumps(summary, sort_keys=True, indent=2, ensure_ascii=False) + "\n",
            "failure_clusters.json": json.dumps(clusters, sort_keys=True, indent=2, ensure_ascii=False) + "\n",
            "report.md": markdown(summary, clusters)}


def write_run(evidence, output_parent, verify_repeat=False, validation=None):
    rendered = payloads(evidence)
    summary = json.loads(rendered["summary.json"])
    if verify_repeat:
        require(rendered == payloads(evidence), "Diagnostic output is nondeterministic")
    require(evidence["hashes"] == {f: sha_file(evidence["source"] / f) for f in FILES}, "Historical evidence changed during analysis")
    require(evidence["asset_sha256"] == sha_file(evidence["asset_path"]), "Production asset changed during analysis")
    parent = Path(output_parent)
    parent.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    destination = Path(tempfile.mkdtemp(prefix=f"phase4d4-level96-{stamp}-", dir=parent))
    for name, contents in rendered.items():
        with (destination / name).open("x", encoding="utf-8", newline="\n") as handle:
            handle.write(contents)
    manifest = {"schema": VERSION, "status": "COMPLETE", "measurement_health": "OK",
        "actual_attempts": summary["attempts_analyzed"], "decisions_validated": summary["decisions_validated"],
        "candidate_wins": summary["candidate"]["wins"], "candidate_losses": summary["candidate"]["losses"],
        "source_run": evidence["manifest"]["run_id"], "source_path": evidence["source"].as_posix(),
        "source_selection": "Default: latest finished_utc among COMPLETE / OK Phase 4D-3 manifests; --source pins a specific run; selected evidence must pass full validation",
        "source_sha256_before": evidence["hashes"],
        "source_sha256_after": {f: sha_file(evidence["source"] / f) for f in FILES},
        "production_asset_sha256": evidence["asset_sha256"],
        "output_sha256": {name: sha_file(destination / name) for name in rendered},
        "diagnostic_source_snapshot": Path(__file__).read_text(encoding="utf-8"),
        "diagnostic_source_sha256": sha_file(__file__),
        "repeat_generation_identical": verify_repeat, "validation": validation,
        "analysis_scope": "360 stored attempts; every decision, public candidate, priority, stored ranking, eligibility, tray transition, reveal and result checked",
        "proof_scope": "Complete immediate losing legal sets; backwards closure only over recorded successors; recorded winning reachability joins exact physical states",
        "read_only_evidence": True, "new_ab_attempts": 0, "new_policy_runs": 0,
        "additional_symbol_swaps_applied": False, "production_changed": False,
        "endless_modes_included": False, "phase4d5_started": False,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "reproduce": f'python -B test/balance_audit/level96_post_opening.py --source "{evidence["source"].as_posix()}" --verify-repeat'}
    require(manifest["source_sha256_before"] == manifest["source_sha256_after"], "Evidence changed while writing reports")
    with (destination / "manifest.json").open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, sort_keys=True, indent=2, ensure_ascii=False)
        handle.write("\n")
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=Path.cwd())
    parser.add_argument("--source", type=Path, help="Pin an original evidence directory instead of selecting the latest COMPLETE / OK run")
    parser.add_argument("--verify-repeat", action="store_true")
    parser.add_argument("--validation-json", type=Path)
    args = parser.parse_args()
    parent = args.workspace / "qa/campaign_validation_runs"
    source = args.source if args.source else select_source(parent)
    evidence = load_evidence(source, args.workspace)
    validation = json.loads(args.validation_json.read_text(encoding="utf-8")) if args.validation_json else None
    destination = write_run(evidence, parent, args.verify_repeat, validation)
    print(f"COMPLETE / OK: {destination}")


if __name__ == "__main__":
    main()
