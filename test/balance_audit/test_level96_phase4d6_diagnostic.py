"""Read-only Phase 4D-6 contracts over pinned historical evidence."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import level96_phase4d6_diagnostic as diagnostic


class Phase4D6Contracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(__file__).resolve().parents[2]
        cls.evidence = diagnostic.load_evidence(cls.root)
        cls.models_before = diagnostic.canonical(cls.evidence["tiles"])
        cls.summary, cls.regressions, cls.migration = diagnostic.analyze(cls.evidence)

    @classmethod
    def tearDownClass(cls):
        diagnostic.assert_unchanged(cls.evidence)
        assert diagnostic.canonical(cls.evidence["tiles"]) == cls.models_before

    def test_missing_malformed_and_substituted_input_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / diagnostic.RUN
            path.mkdir()
            with self.assertRaisesRegex(diagnostic.IntegrityError, "Missing required"):
                diagnostic.load_evidence(self.root, path)
            for name in diagnostic.FILES:
                (path / name).write_text("{}", encoding="utf-8")
            (path / "manifest.json").write_text("broken JSON", encoding="utf-8")
            with self.assertRaisesRegex(diagnostic.IntegrityError, "malformed JSON"):
                diagnostic.load_evidence(self.root, path)
            with self.assertRaisesRegex(diagnostic.IntegrityError, "alternate run"):
                diagnostic.load_evidence(self.root, Path(temp))
            wrong = {**self.evidence["manifest"], "run_id": "another-complete-run"}
            (path / "manifest.json").write_text(json.dumps(wrong), encoding="utf-8")
            with self.assertRaisesRegex(diagnostic.IntegrityError, "identity"):
                diagnostic.load_evidence(self.root, path)

    def test_manifest_identity_definitions_gates_and_seed_policy_are_strict(self):
        manifest = self.evidence["manifest"]
        for field, value in [("schema", "wrong"), ("measurement_health", "PENDING"),
            ("status", "PARTIAL"), ("actual_attempts", 359), ("replica_indices", list(range(30))),
            ("type_changes_from_production", {}), ("paired_seed_policy", "changed"),
            ("variant_in_seed_or_priority", True), ("inputs_unchanged", False)]:
            with self.subTest(field=field), self.assertRaises(diagnostic.IntegrityError):
                diagnostic.validate_manifest({**manifest, field: value})
        for section in ("witness_and_invariants", "deterministic_paired"):
            changed = copy.deepcopy(manifest)
            changed["correctness_gate"][section]["passed"] = False
            with self.assertRaises(diagnostic.IntegrityError):
                diagnostic.validate_manifest(changed)
        changed = copy.deepcopy(manifest)
        changed["historical_control_reproduction"][0]["different_fields"] = ["trace"]
        with self.assertRaises(diagnostic.IntegrityError):
            diagnostic.validate_manifest(changed)
        changed = copy.deepcopy(manifest)
        changed["screens"][0]["board"][0] += 1
        with self.assertRaises(diagnostic.IntegrityError):
            diagnostic.validate_manifest(changed)

    def test_duplicate_missing_wrong_range_and_attribution_are_rejected(self):
        rows = self.evidence["rows"]
        for altered in [rows[:-1], [rows[0], *rows[:-1]], [*rows, rows[0]]]:
            with self.assertRaises(diagnostic.IntegrityError):
                diagnostic.validate_accounting(altered)
        for key, value in [("replica", 29), ("replica", 60), ("screen", "other"),
            ("strategy", "randomLegal"), ("variant", "candidate"), ("cohort", "holdout_10_29"),
            ("outcome", "INCONCLUSIVE"), ("experiment_seed_uint32", 0), ("omniscient", True)]:
            with self.subTest(key=key, value=value), self.assertRaises(diagnostic.IntegrityError):
                diagnostic.validate_accounting([{**rows[0], key: value}, *rows[1:]])

    def test_trace_corruption_and_inconsistent_source_summary_are_rejected(self):
        row = self.evidence["rows"][0]
        for field, value in [("priority_uint32", 0), ("immediate_loss", True)]:
            altered = copy.deepcopy(row)
            altered["trace"][0]["candidates"][0][field] = value
            with self.assertRaises(diagnostic.IntegrityError):
                diagnostic.validate_trace(altered, self.evidence["tiles"][row["variant"]], self.evidence["blockers"][row["screen"]])
        summary = copy.deepcopy(self.evidence["source_summary"])
        summary["candidate_b"]["loss_taps"]["31"] += 1
        with self.assertRaises(diagnostic.IntegrityError):
            diagnostic.validate_summary(summary, self.evidence["manifest"], self.evidence["rows"])

    def test_exact_four_earlier_loss_cases_and_seeds(self):
        cases = self.regressions["cases"]
        expected = {f"{s}/{p}/53" for s in diagnostic.SCREENS[1:] for p in diagnostic.STRATEGIES}
        self.assertEqual({c["pair"] for c in cases}, expected)
        self.assertEqual(set(diagnostic.regression_keys(self.evidence["rows"])), expected)
        for case in cases:
            self.assertEqual((case["a_taps"], case["b_taps"], case["seed_uint32"]), (79, 43, 3710518896))
            self.assertEqual(case["shared_physical_tap_prefix"]["length"], 28)
            self.assertEqual(case["shared_physical_tap_prefix"]["first_different_tap"], 29)
            self.assertEqual(case["first_public_difference_tap"], 28)
            self.assertTrue(case["local_terminal_proof"]["all_legal_actions_lose"])
            self.assertEqual(case["local_terminal_proof"]["safe_actions"], 0)
            self.assertEqual(case["candidate_earliest_observed_winning_fork"]["state"]["tap"], 39)
            self.assertEqual(case["candidate_earliest_observed_winning_fork"]["observed_winning_alternatives"], ["L96_T062"])
            self.assertEqual(case["changed_tile_events"]["candidate_b"]["L96_T069"]["actual_chosen_tap"], 34)

    def test_paired_outcomes_and_every_migration_cell(self):
        expected = {("10", "10"): 16, ("22", "22"): 18, ("31", "31"): 70,
            ("31", "34"): 14, ("31", "55"): 12, ("31", "79"): 12, ("31", "WIN"): 10,
            ("43", "43"): 4, ("55", "55"): 4, ("79", "43"): 4, ("79", "79"): 10, ("WIN", "WIN"): 6}
        actual = {(t["a"], t["b"]): t["count"] for t in self.migration["paired_transitions"]}
        self.assertEqual(actual, expected)
        self.assertEqual(sum(actual.values()), 180)
        self.assertEqual(self.summary["paired_classifications"], {"BOTH_LOSS_EARLIER": 4,
            "BOTH_LOSS_LONGER": 38, "BOTH_LOSS_SAME_TAP": 122, "BOTH_WIN": 6, "LOSS_TO_WIN": 10})
        self.assertEqual(self.summary["decisions_validated"], 14054)
        for arm, wins in [("control_a", 6), ("candidate_b", 16)]:
            self.assertEqual(self.summary[arm]["wins"], wins)
            self.assertEqual(self.summary[arm]["attempts"], 180)

    def test_histogram_reconstruction_and_cluster_member_accounting(self):
        expected_a = {10: 16, 22: 18, 31: 118, 34: 0, 43: 4, 55: 4, 79: 14}
        expected_b = {10: 16, 22: 18, 31: 70, 34: 14, 43: 8, 55: 16, 79: 22}
        for cluster in self.migration["clusters"]:
            tap = cluster["tap"]
            for arm, expected in [("control_a", expected_a), ("candidate_b", expected_b)]:
                stats = cluster[arm]
                self.assertEqual(stats["failures"], expected[tap])
                self.assertEqual(sum(stats["screen_distribution"].values()), expected[tap])
                self.assertEqual(sum(stats["strategy_distribution"].values()), expected[tap])
                self.assertEqual(sum(len(g["members"]) for g in stats["physical_terminal_groups"]), expected[tap])
            self.assertEqual(cluster["net_change_b_minus_a"], expected_b[tap]-expected_a[tap])

    def test_physical_symbolic_and_order_insensitive_states_remain_separate(self):
        step = {"diagnostic_remaining_ids": ["a", "b"], "diagnostic_tray_ids": ["c", "d"]}
        permuted = {"diagnostic_remaining_ids": ["b", "a"], "diagnostic_tray_ids": ["d", "c"]}
        model = {i: {"type": "heart"} for i in "abcd"}
        self.assertNotEqual(diagnostic.physical_key(step, 0), diagnostic.physical_key(permuted, 0))
        self.assertEqual(diagnostic.physical_key(step, 0, True), diagnostic.physical_key(permuted, 0, True))
        self.assertNotEqual(diagnostic.physical_key(step, 0), diagnostic.physical_key(step, 1))
        changed = {**model, "a": {"type": "star"}}
        self.assertNotEqual(diagnostic.mechanical_key(step, 0, model), diagnostic.mechanical_key(step, 0, changed))
        for case in self.regressions["cases"]:
            self.assertEqual(case["control_exact_mechanical_pre_loss_matches"], [])
            self.assertEqual(len(case["control_matches_ignoring_tray_order"]), 2)
            self.assertTrue(all(x["attempt"].endswith('/42') for x in case["control_matches_ignoring_tray_order"]))
        cluster = next(c for c in self.migration["clusters"] if c["tap"] == 31)
        self.assertEqual(cluster["control_a"]["distinct_terminal_physical_states"], 53)
        self.assertEqual(cluster["control_a"]["distinct_pre_loss_physical_states"], 51)
        self.assertEqual(cluster["candidate_b"]["distinct_terminal_physical_states"], 28)
        self.assertEqual(cluster["candidate_b"]["distinct_pre_loss_symbol_tray_patterns"], 5)

    def test_shared_prefix_detection_does_not_invent_tail_divergence(self):
        self.assertEqual(diagnostic.shared_prefix(["a", "b"], ["a", "c"]),
            {"length": 1, "ids": ["a"], "first_different_tap": 2, "unmatched_tail_start": None})
        self.assertEqual(diagnostic.shared_prefix(["a"], ["a", "b"])["first_different_tap"], None)
        self.assertEqual(diagnostic.shared_prefix([], ["a"])["unmatched_tail_start"], 1)
        self.assertEqual(diagnostic.shared_prefix(["a"], ["a"])["length"], 1)

    def test_public_and_privileged_information_are_not_mixed(self):
        row = self.evidence["rows"][0]
        step = row["trace"][0]
        altered = {**step, "diagnostic_secret": "HIDDEN_SENTINEL", "diagnostic_remaining_ids": ["HIDDEN_SENTINEL"]}
        public = diagnostic.public_view(altered)
        self.assertEqual(public, diagnostic.public_view(step))
        self.assertNotIn("HIDDEN_SENTINEL", diagnostic.canonical(public))
        self.assertNotIn("diagnostic", diagnostic.canonical(public))
        state = diagnostic.snapshot(row, 0, self.evidence)
        self.assertIn("analyst_only", state)
        self.assertNotIn("remaining_ids", state["public_observation_and_recorded_previews"])

    def test_observed_winning_certificates_have_exact_edge_provenance(self):
        rows = {diagnostic.row_key(r): r for r in self.evidence["rows"]}
        for case in self.regressions["cases"]:
            fork = case["candidate_earliest_observed_winning_fork"]
            for certificate in fork["certificates"]:
                previous = fork["state"]["mechanical_state_id"]
                for edge in certificate["recorded_edges"]:
                    row = rows[edge["source_attempt"]]
                    step = row["trace"][edge["source_tap"]-1]
                    args = (self.evidence["geometry_ids"][row["screen"]], self.evidence["tiles"][row["variant"]])
                    self.assertEqual(diagnostic.ident(diagnostic.mechanical_key(step, *args)), previous)
                    self.assertEqual(edge["from_state"], previous)
                    self.assertEqual(step["diagnostic_actual_chosen_id"], edge["id"])
                    after = row["trace"][edge["source_tap"]] if edge["source_tap"] < len(row["trace"]) else diagnostic.terminal_step(row, args[1])
                    self.assertEqual(diagnostic.ident(diagnostic.mechanical_key(after, *args)), edge["to_state"])
                    previous = edge["to_state"]
                self.assertEqual(row["outcome"], "WIN")
                self.assertEqual(edge["source_tap"], 99)

    def test_no_regression_and_synthetic_regression_classification(self):
        identity = {"screen": "synthetic", "strategy": "synthetic", "replica": 30}
        a = {**identity, "variant": "control_a", "outcome": "LOSS", "decisions": 20}
        b = {**identity, "variant": "candidate_b", "outcome": "LOSS", "decisions": 10}
        self.assertEqual(diagnostic.regression_keys([]), [])
        self.assertEqual(diagnostic.regression_keys([a, b]), ["synthetic/synthetic/30"])
        for outcome, taps, expected in [("LOSS", 20, "BOTH_LOSS_SAME_TAP"),
            ("LOSS", 21, "BOTH_LOSS_LONGER"), ("WIN", 99, "LOSS_TO_WIN")]:
            variant = {**b, "outcome": outcome, "decisions": taps}
            self.assertEqual(diagnostic.classify_pair(a, variant), expected)
            self.assertEqual(diagnostic.regression_keys([a, variant]), [])
        self.assertEqual(diagnostic.classify_pair({**a, "outcome": "WIN"}, b), "WIN_TO_LOSS")
        self.assertEqual(diagnostic.classify_pair({**a, "outcome": "WIN"}, {**b, "outcome": "WIN"}), "BOTH_WIN")

    def test_reports_repeat_byte_identically_after_reordering_input_rows(self):
        first = diagnostic.payloads(self.evidence)
        second = diagnostic.payloads({**self.evidence, "rows": list(reversed(self.evidence["rows"]))})
        self.assertEqual(first, second)
        self.assertEqual(set(first), {"summary.json", "regression_cases.json", "cluster_migration.json", "report.md"})
        for name in first:
            if name.endswith('.json'):
                self.assertEqual(json.loads(first[name])["schema"], diagnostic.VERSION)
        self.assertIn("14054", first["report.md"])
        self.assertIn("Option B", first["report.md"])
        self.assertIn("REVISE", first["report.md"])

    def test_unique_outputs_and_protection_of_historical_files(self):
        with tempfile.TemporaryDirectory() as temp:
            parent = Path(temp)
            sentinel = parent/'historical.json'
            sentinel.write_text('unchanged', encoding='utf-8')
            first = diagnostic.write_run(self.evidence, parent, verify_repeat=False)
            second = diagnostic.write_run(self.evidence, parent, verify_repeat=False)
            self.assertNotEqual(first, second)
            self.assertEqual(sentinel.read_text(), 'unchanged')
            self.assertEqual({p.name for p in first.iterdir()}, {'manifest.json', 'summary.json', 'report.md', 'regression_cases.json', 'cluster_migration.json'})
            manifest = diagnostic.read_json(first/'manifest.json')
            self.assertEqual(manifest['source_sha256_before'], manifest['source_sha256_after'])
            self.assertEqual(manifest['new_ab_attempts'], 0)
            self.assertFalse(manifest['production_changes'])
            for name, expected in manifest['output_sha256'].items():
                self.assertEqual(diagnostic.sha(first/name), expected)
                self.assertEqual(diagnostic.sha(second/name), expected)
            diagnostic.assert_unchanged(self.evidence)


if __name__ == '__main__':
    unittest.main(verbosity=2)
