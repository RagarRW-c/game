"""Host contracts for safe installation gates and honest result accounting."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('android_qa', Path(__file__).resolve().parents[2] / 'scripts/level96_android_qa.py')
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)


class AndroidQaContracts(unittest.TestCase):
    def test_production_dev_and_arbitrary_ids_fail_closed(self):
        for value in [qa.PRODUCTION, qa.DEV, 'com.other.app', qa.DEV + '.l96qaX; rm', qa.DEV + '.l96qa1']:
            with self.assertRaises(ValueError): qa.require_safe_install(value, [])

    def test_unique_uninstalled_test_id_accepted(self):
        qa.require_safe_install(qa.DEV + '.l96qa20261105abcdef123456', [qa.PRODUCTION, qa.DEV])

    def test_existing_test_installation_never_overwritten(self):
        value = qa.DEV + '.l96qa20261105abcdef123456'
        with self.assertRaises(ValueError): qa.require_safe_install(value, [value])

    def test_pass_fail_and_skipped_are_distinct(self):
        self.assertEqual(qa.test_counts('00:10 +10 ~2 -1: Some tests failed.'), {'PASS': 10, 'FAIL': 1, 'NOT RUN': 2})
        self.assertEqual(qa.test_counts('00:10 +27: All tests passed!'), {'PASS': 27, 'FAIL': 0, 'NOT RUN': 0})

    def test_no_success_count_inferred_from_incomplete_log(self):
        self.assertIsNone(qa.test_counts('loading test.dart\nDisconnected'))

    def test_python_count_requires_ok(self):
        self.assertIsNone(qa.test_counts('Ran 14 tests in 80s\nFAILED'))
        self.assertEqual(qa.test_counts('Ran 14 tests in 80s\nOK\n')['PASS'], 14)

    def test_analyzer_comparison_preserves_new_infos(self):
        baseline = ' info - old - old.dart:1:1 - lint\n81 issues found'
        changed = baseline + '\n error - new - new.dart:1:1 - error'
        self.assertNotEqual(qa.findings(baseline), qa.findings(changed))

    def test_unique_output_and_initial_not_run_states(self):
        with tempfile.TemporaryDirectory() as temp:
            a = qa.Run(Path(temp), 'test-device')
            b = qa.Run(Path(temp), 'test-device')
            self.assertNotEqual(a.output, b.output)
            self.assertNotEqual(a.app_id, b.app_id)
            self.assertTrue(qa.safe_app_id(a.app_id))
            self.assertEqual(a.data['android_scenario_counts'], {'PASS': 0, 'FAIL': 0, 'NOT RUN': 13})

    def test_lock_comparison_extracts_versions(self):
        lock = 'packages:\n  flutter:\n    source: sdk\n    version: "0.0.0"\n  foo:\n    version: "1.2.3"\nsdks:\n  dart: ">=3.0.0"\n'
        self.assertEqual(qa.dependency_versions(lock), {'flutter': '0.0.0', 'foo': '1.2.3'})

    def test_debug_permission_and_unique_suffix_only_in_copy(self):
        with tempfile.TemporaryDirectory() as temp:
            copy = Path(temp)
            (copy / 'android/app').mkdir(parents=True)
            original = "applicationId 'com.ragarrwc.game'\napplicationIdSuffix '.dev'\n"
            app_id = qa.DEV + '.l96qa20261105abcdef123456'
            qa.configure_android_copy(copy, original, app_id)
            text = (copy / 'android/app/build.gradle').read_text()
            self.assertIn(app_id[len(qa.PRODUCTION):], text)
            manifest = copy / 'android/app/src/debug/AndroidManifest.xml'
            qa.configure_android_copy(copy, original, app_id)
            tree = qa.ET.parse(manifest)
            self.assertEqual(len(tree.getroot().findall('uses-permission')), 1)
            self.assertIn('android.permission.INTERNET', manifest.read_text())
            self.assertFalse((copy / 'android/app/src/main/AndroidManifest.xml').exists())

    def test_android_and_logcat_messages_cannot_inflate_host_counts(self):
        with tempfile.TemporaryDirectory() as temp:
            run = qa.Run(Path(temp), 'test-device')
            for name in ['phase4d7_tests', 'android_integration', 'android_logcat']:
                run.steps.append({'name': name, 'status': 'PASS',
                    'test_counts': {'PASS': 27, 'FAIL': 0, 'NOT RUN': 0}})
            run.save()
            self.assertEqual(run.data['host_test_counts'], {'PASS': 27, 'FAIL': 0, 'NOT RUN': 0})


if __name__ == '__main__':
    unittest.main()
