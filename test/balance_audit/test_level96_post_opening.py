"""Contracts over stored evidence only: no engine, policy or new A/B cohort."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import level96_post_opening as diagnostic


class PostOpeningContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(__file__).resolve().parents[2]
        cls.source = diagnostic.select_source(cls.root / "qa/campaign_validation_runs")
        cls.evidence = diagnostic.load_evidence(cls.source, cls.root)
        cls.original_model = diagnostic.canonical(cls.evidence["tiles"])
        cls.summary, cls.clusters = diagnostic.analyze(cls.evidence)

    @classmethod
    def tearDownClass(cls):
        assert cls.evidence["hashes"] == {f: diagnostic.sha_file(cls.source / f) for f in diagnostic.FILES}
        assert cls.evidence["asset_sha256"] == diagnostic.sha_file(cls.root / diagnostic.ASSET)
        assert cls.original_model == diagnostic.canonical(cls.evidence["tiles"])

    def test_latest_complete_ok_selection_and_no_corrupt_fallback(self):
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary)
            for name, status, health, stamp in [
                ("old", "COMPLETE", "OK", "2026-11-05T08:00:00Z"),
                ("new", "COMPLETE", "OK", "2026-11-05T09:00:00Z"),
                ("failed", "FAILED", "REVIEW_REQUIRED", "2026-11-05T10:00:00Z"),
                ("partial", "PARTIAL", "OK", "2026-11-05T11:00:00Z"),
            ]:
                directory = parent / name
                directory.mkdir()
                (directory / "manifest.json").write_text(json.dumps({"schema": diagnostic.SHADOW,
                    "status": status, "measurement_health": health, "finished_utc": stamp}), encoding="utf-8")
            chosen = diagnostic.select_source(parent)
            self.assertEqual(chosen.name, "new")
            with self.assertRaisesRegex(diagnostic.IntegrityError, "Missing required"):
                diagnostic.load_evidence(chosen, self.root)

    def test_input_integrity_all_source_hashes_and_pinned_original_asset(self):
        self.assertEqual(self.evidence["hashes"], {f: diagnostic.sha_file(self.source / f) for f in diagnostic.FILES})
        self.assertEqual(f"{diagnostic.fnv((self.root / diagnostic.ASSET).read_bytes()):08x}", "2b2b8578")
        self.assertEqual(self.evidence["manifest"]["solvability_gate"]["passed"], True)
        self.assertEqual(len(self.evidence["manifest"]["control_reproduction"]), 60)

    def test_cohort_accounting_rejects_duplicate_missing_or_mislabeled_attempts(self):
        rows = self.evidence["rows"]
        diagnostic.validate_accounting(rows)
        for broken in [rows[:-1], [rows[0], *rows[:-1]], [{**rows[0], "replica": 30}, *rows[1:]],
                       [{**rows[0], "cohort": "holdout_10_29"}, *rows[1:]]]:
            with self.assertRaises(diagnostic.IntegrityError):
                diagnostic.validate_accounting(broken)
        self.assertEqual(len(self.summary["strata"]), 24)
        for row in self.summary["strata"]:
            self.assertEqual(row["attempts"], 10 if row["cohort"] == "overlap_0_9" else 20)
            self.assertEqual(row["wins"] + row["losses"], row["attempts"])

    def test_recorded_trace_checks_detect_priority_inventory_and_ranking_corruption(self):
        row = self.evidence["rows"][0]
        tiles = self.evidence["tiles"][row["variant"]]
        blockers = self.evidence["blockers"][row["screen"]]
        for mutation in ("priority", "tray", "ranking", "reveal"):
            altered = copy.deepcopy(row)
            step = altered["trace"][0]
            if mutation == "priority":
                step["candidates"][0]["priority_uint32"] ^= 1
            elif mutation == "tray":
                step["diagnostic_tray_ids"] = ["L96_T000"]
            elif mutation == "ranking":
                step["rankings"][0]["ranked"][0]["tray_matches"] = 99
            else:
                step["newly_selectable_tokens_after_tap"] = ["invented hidden reveal"]
            with self.assertRaises(diagnostic.IntegrityError, msg=mutation):
                diagnostic.validate_trace(altered, tiles, blockers)

    def test_failure_cluster_regression_and_complete_member_accounting(self):
        expected = {10: (36, 10), 22: (10, 7), 31: (86, 35), 43: (4, 2),
                    55: (6, 4), 79: (28, 12), 82: (2, 2)}
        actual = {g["loss_tap"]: (g["attempts"], g["unique_terminal_physical_states"]) for g in self.clusters["clusters"]}
        self.assertEqual(actual, expected)
        members = [m for g in self.clusters["clusters"] for m in g["members"]]
        self.assertEqual(len(members), 172)
        self.assertEqual(len(set(members)), 172)
        self.assertEqual(self.summary["candidate"]["wins"], 8)
        self.assertEqual(self.summary["control"]["losses"], 180)
        self.assertEqual(self.summary["decisions_validated"], 8176)

    def test_exact_physical_state_separates_tray_order_symbols_and_geometry(self):
        key = diagnostic.physical_key("candidate", "small", ["a", "b"], ["c", "d"])
        self.assertEqual(key, diagnostic.physical_key("candidate", "small", ["b", "a"], ["c", "d"]))
        for other in [diagnostic.physical_key("candidate", "small", ["a", "b"], ["d", "c"]),
                      diagnostic.physical_key("candidate", "tall", ["a", "b"], ["c", "d"]),
                      diagnostic.physical_key("control", "small", ["a", "b"], ["c", "d"]),
                      diagnostic.physical_key("candidate", "small", ["a"], ["c", "d"])]:
            self.assertNotEqual(key, other)
        # The same loss tap actually covers multiple different exact states.
        for cluster in self.clusters["clusters"]:
            self.assertGreater(cluster["unique_terminal_physical_states"], 1)
            self.assertEqual(sum(len(g["attempts"]) for g in cluster["state_groups"]), cluster["attempts"])

    def test_local_loss_certificates_do_not_claim_earlier_unobserved_branches(self):
        rows = {diagnostic.attempt_id(r): r for r in self.evidence["rows"]}
        for failure in self.clusters["failed_attempt_details"]:
            terminal = rows[failure["attempt"]]["trace"][-1]
            self.assertTrue(all(c["immediate_loss"] for c in terminal["candidates"]))
            self.assertEqual(failure["terminal"]["immediate_safe_moves"], 0)
            proof = failure["earliest_certified_forced_loss"]
            self.assertEqual(proof["tap"], failure["loss_tap"])
            self.assertEqual({a["id"] for a in proof["certificate"]["actions"]}, set(terminal["diagnostic_legal_ids"]))
            self.assertLess(failure["earliest_observed_winning_fork"]["tap"], failure["loss_tap"])

    def test_winning_continuations_only_join_identical_recorded_physical_states(self):
        rows = {diagnostic.attempt_id(r): r for r in self.evidence["rows"]}
        values = sorted({diagnostic.canonical(g) for g in self.evidence["geometries"].values()})
        geometry_keys = {s: values.index(diagnostic.canonical(g)) for s, g in self.evidence["geometries"].items()}
        for failure in self.clusters["failed_attempt_details"]:
            fork = failure["earliest_observed_winning_fork"]
            for cert in fork["winning_continuation_certificates"]:
                previous = fork["state_id"]
                for edge in cert["recorded_edges"]:
                    row = rows[edge["source_attempt"]]
                    step = row["trace"][edge["source_tap"] - 1]
                    geometry = geometry_keys[row["screen"]]
                    actual = diagnostic.physical_key(row["variant"], geometry,
                        step["diagnostic_remaining_ids"], step["diagnostic_tray_ids"])
                    self.assertEqual(diagnostic.state_id(actual), previous)
                    self.assertEqual(edge["from_state"], previous)
                    self.assertEqual(step["diagnostic_actual_chosen_id"], edge["id"])
                    previous = edge["to_state"]
                self.assertEqual(previous, diagnostic.state_id(diagnostic.physical_key("candidate", geometry, [], [])))
        self.assertEqual(self.summary["failures_with_observed_winning_fork"], 172)

    def test_proposals_are_frozen_state_hypotheses_and_do_not_change_model(self):
        proposal = self.summary["recommended_next_experiment"]
        self.assertEqual(proposal["swap"], ["L96_T071", "L96_T069"])
        self.assertEqual(proposal["current_types"], ["banana", "heart"])
        self.assertEqual(proposal["frozen_terminal_attempts_with_immediate_relief"], 34)
        self.assertFalse(proposal["touches_existing_opening_swap"])
        self.assertEqual(proposal["status"], "HYPOTHESIS_ONLY_NOT_APPLIED_NOT_REPLAYED")
        self.assertEqual(diagnostic.canonical(self.evidence["tiles"]), self.original_model)

    def test_report_generation_is_deterministic_even_if_attempt_enumeration_changes(self):
        first = diagnostic.payloads(self.evidence)
        reordered = {**self.evidence, "rows": list(reversed(self.evidence["rows"]))}
        self.assertEqual(first, diagnostic.payloads(reordered))
        self.assertEqual(set(first), {"summary.json", "failure_clusters.json", "report.md"})
        self.assertIn("8176", first["report.md"])
        self.assertIn("No new A/B cohort", first["report.md"])

    def test_output_is_new_unique_and_historical_evidence_is_not_modified(self):
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary)
            historical = parent / "old" / "manifest.json"
            historical.parent.mkdir()
            historical.write_text("historical sentinel", encoding="utf-8")
            first = diagnostic.write_run(self.evidence, parent)
            second = diagnostic.write_run(self.evidence, parent)
            self.assertNotEqual(first, second)
            self.assertEqual(historical.read_text(encoding="utf-8"), "historical sentinel")
            self.assertEqual({p.name for p in first.iterdir()}, {"report.md", "summary.json", "manifest.json", "failure_clusters.json"})
            for name in ("report.md", "summary.json", "failure_clusters.json"):
                self.assertEqual(diagnostic.sha_file(first / name), diagnostic.sha_file(second / name))
            manifest = json.loads((first / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(manifest["source_sha256_before"], manifest["source_sha256_after"])
            self.assertEqual(manifest["new_ab_attempts"], 0)
            self.assertFalse(manifest["additional_symbol_swaps_applied"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
