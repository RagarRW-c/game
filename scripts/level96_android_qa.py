"""Repeatable, fail-closed Level 96 host + physical Android QA orchestration."""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid
import xml.etree.ElementTree as ET

PRODUCTION = 'com.ragarrwc.game'
DEV = PRODUCTION + '.dev'
HOST_TEST_STEPS = {'phase4d7_tests', 'historical_contracts', 'ordinary_tests',
                   'python_phase4', 'python_phase6', 'python_phase7a', 'phase4d7a_driver_tests'}
SCENARIOS = ['startup_and_opt_in', 'select_original', 'select_a', 'select_b',
    'covered_and_selectable_touch', 'restart', 'variant_switching',
    'win_original', 'win_a', 'win_b', 'loss_original',
    'android_clipboard_export', 'persistence_and_assistance_isolation']


def safe_app_id(value):
    return bool(re.fullmatch(r'com\.ragarrwc\.game\.dev\.l96qa[a-z0-9]{12,48}', value))


def require_safe_install(value, installed):
    if not safe_app_id(value) or value in installed:
        raise ValueError('Unsafe or already-installed test application ID: ' + value)


def findings(text):
    return sorted(line.strip() for line in text.splitlines()
                  if re.match(r'^\s*(info|warning|error) - ', line))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def dependency_versions(text):
    result = {}
    for match in re.finditer(r'^  (\w+):\n(.*?)(?=^  \w+:|\Z)', text, re.M | re.S):
        version = re.search(r'^    version: "([^"]+)"', match[2], re.M)
        if version: result[match[1]] = version[1]
    return result


def configure_android_copy(copy, gradle, app_id):
    require_safe_install(app_id, [])
    path = copy / 'android/app/build.gradle'
    path.write_text(gradle.replace("applicationIdSuffix '.dev'", f"applicationIdSuffix '{app_id[len(PRODUCTION):]}'")
        .replace("'Tile Adventure DEV'", "'Level 96 QA'"), encoding='utf-8')
    # Flutter's debug VM service needs a loopback server socket. This project
    # has no debug manifest; grant INTERNET only in the disposable QA build.
    manifest = copy / 'android/app/src/debug/AndroidManifest.xml'
    manifest.parent.mkdir(parents=True, exist_ok=True)
    tree = ET.parse(manifest) if manifest.exists() else ET.ElementTree(ET.Element('manifest'))
    name = '{http://schemas.android.com/apk/res/android}name'
    ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
    if not any(node.get(name) == 'android.permission.INTERNET' for node in tree.getroot().findall('uses-permission')):
        ET.SubElement(tree.getroot(), 'uses-permission', {name: 'android.permission.INTERNET'})
    tree.write(manifest, encoding='utf-8', xml_declaration=True)


def test_counts(text):
    matches = re.findall(r'\+(\d+)(?: ~(\d+))?(?: -(\d+))?: (All tests passed!|Some tests failed\.)', text)
    if matches:
        passed, skipped, failed, _ = matches[-1]
        return {'PASS': int(passed), 'FAIL': int(failed or 0), 'NOT RUN': int(skipped or 0)}
    match = re.search(r'Ran (\d+) tests? in ', text)
    if match and re.search(r'^OK\s*$', text, re.M):
        return {'PASS': int(match[1]), 'FAIL': 0, 'NOT RUN': 0}
    return None


class Run:
    def __init__(self, root, device):
        self.root = root
        self.id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S') + '-' + uuid.uuid4().hex[:12]
        self.output = root / 'qa/level96_android_qa_runs' / self.id
        self.output.mkdir(parents=True, exist_ok=False)
        self.copy = root / '.dart_tool/level96_android_qa' / self.id
        self.steps = []
        self.scenarios = {name: {'status': 'NOT RUN', 'reason': 'Android execution not completed'} for name in SCENARIOS}
        self.device = device
        self.app_id = DEV + '.l96qa' + self.id.replace('-', '').lower()
        self.data = {'schema': 'level96-android-qa/v1', 'run_id': self.id,
            'created_utc': datetime.now(timezone.utc).isoformat(), 'status': 'RUNNING',
            'device': device, 'test_application_id': self.app_id,
            'production_application_id': PRODUCTION, 'existing_dev_application_id': DEV,
            'steps': self.steps, 'android_scenarios': self.scenarios,
            'new_ab_attempts': 0, 'committed_or_pushed': False}
        self.save()

    def save(self):
        self.data['step_counts'] = dict(Counter(s['status'] for s in self.steps))
        self.data['android_scenario_counts'] = {v: sum(s['status'] == v for s in self.scenarios.values()) for v in ['PASS', 'FAIL', 'NOT RUN']}
        self.data['host_test_counts'] = {v: sum(s.get('test_counts', {}).get(v, 0)
            for s in self.steps if s['name'] in HOST_TEST_STEPS) for v in ['PASS', 'FAIL', 'NOT RUN']}
        (self.output / 'summary.json').write_text(json.dumps(self.data, indent=2) + '\n', encoding='utf-8')
        lines = ['# Level 96 Android QA', '', f"Status: {self.data['status']}",
            f'Test package: `{self.app_id}`', '', '## Checks', '', '| Check | Status | Details |', '|---|---|---|']
        for s in self.steps:
            details = s.get('reason', s.get('log', '')).replace('|', '/').replace('\n', ' ')
            lines.append(f"| {s['name']} | {s['status']} | {details} |")
        lines += ['', '## Android scenarios', '', '| Scenario | Status |', '|---|---|']
        lines += [f"| {name} | {s['status']} |" for name, s in self.scenarios.items()]
        lines += ['', 'Host tests: ' + json.dumps(self.data['host_test_counts']),
            'Android scenarios: ' + json.dumps(self.data['android_scenario_counts']), '',
            'Taps use the real Flutter UI on the phone, not direct engine moves. '
            'They do not certify physical finger targeting or human judgment.',
            'Debug frame timings do not establish release smoothness. Fairness, enjoyment, '
            'visual quality, perceived animation and human difficulty still require human review.',
            'Raw errors are preserved in per-step logs and android_response.json when available.',
            'Existing installed application data is never cleared, restored, read or overwritten.']
        (self.output / 'report.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')

    def note(self, name, status, reason, **extra):
        self.steps.append({'name': name, 'status': status, 'reason': reason, **extra})
        self.save()

    def command(self, name, args, cwd=None, timeout=1200, accept=None, env=None, expected_tests=None):
        path = self.output / (name + '.log')
        print(f'[{self.id}] {name}', flush=True)
        start = time.monotonic()
        with path.open('xb') as stream:
            try:
                process = subprocess.Popen([str(x) for x in args], cwd=cwd or self.root,
                    stdout=stream, stderr=subprocess.STDOUT, env=env)
                try:
                    code = process.wait(timeout=timeout)
                except subprocess.TimeoutExpired:
                    # Do not kill unrelated Flutter/ADB processes.
                    if os.name == 'nt':
                        subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], stdout=stream, stderr=subprocess.STDOUT)
                    else:
                        process.kill()
                    process.wait()
                    stream.write(b'\nQA timeout exceeded; direct child terminated.\n')
                    code = 124
            except OSError as error:
                stream.write(str(error).encode('utf-8'))
                code = 127
        text = path.read_text(encoding='utf-8', errors='replace')
        ok = accept(code, text) if accept else code == 0
        counts = test_counts(text) if name in HOST_TEST_STEPS else None
        if expected_tests is not None:
            ok = ok and counts is not None and counts['PASS'] == expected_tests and counts['FAIL'] == 0 and counts['NOT RUN'] == 0
        step = {'name': name, 'status': 'PASS' if ok else 'FAIL',
            'command': [str(x) for x in args], 'cwd': str(cwd or self.root),
            'exit_code': code, 'duration_seconds': round(time.monotonic() - start, 3), 'log': path.name}
        if counts: step['test_counts'] = counts
        if expected_tests is not None: step['expected_tests'] = expected_tests
        self.steps.append(step)
        self.save()
        print(f"  {step['status']} ({step['duration_seconds']}s) {path.name}", flush=True)
        return ok, text


def copy_project(run):
    run.copy.mkdir(parents=True, exist_ok=False)
    ignored = shutil.ignore_patterns('.gradle', '.dart_tool', 'build', '*.jks', '*.keystore',
                                     'key.properties', 'signing.properties', '__pycache__')
    for folder in ['lib', 'assets', 'android', 'test/qa', 'test/goldens']:
        shutil.copytree(run.root / folder, run.copy / folder, ignore=ignored)
    for file in ['pubspec.yaml', 'pubspec.lock', '.flutter-plugins-dependencies']:
        shutil.copy2(run.root / file, run.copy / file)
    (run.copy / '.dart_tool').mkdir()
    for name in ['package_config.json', 'package_graph.json']:
        shutil.copy2(run.root / '.dart_tool' / name, run.copy / '.dart_tool' / name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', default='RZCTA0TPGDD')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    if not re.fullmatch(r'[A-Za-z0-9_.:-]+', args.device): raise ValueError('Invalid device ID')
    if not (root / 'pubspec.yaml').is_file() or not (root / 'lib/main_level96_playtest.dart').is_file():
        raise ValueError('Expected Flutter playtest workspace not found')
    run = Run(root, args.device)
    print('REPORT_DIRECTORY=' + str(run.output), flush=True)
    flutter = shutil.which('flutter') or 'C:/flutter/bin/flutter.bat'
    local = (root / 'android/local.properties').read_text()
    sdk = Path(next(x.split('=', 1)[1] for x in local.splitlines() if x.startswith('sdk.dir=')).replace('\\\\', '\\'))
    adb = sdk / 'platform-tools' / ('adb.exe' if os.name == 'nt' else 'adb')
    def adbc(*parts): return [adb, '-s', args.device, *parts]
    baseline = json.loads((root / 'test/balance_audit/phase4d7_validation.json').read_text())['analyzer']['unchanged_baseline_findings']
    protected = [p for folder in ['lib', 'assets/levels', 'qa/campaign_validation_runs'] for p in (root / folder).rglob('*') if p.is_file()]
    protected += [root / 'pubspec.yaml', root / 'pubspec.lock', root / 'android/app/build.gradle']
    protected += list((root / 'integration_test').glob('*.dart'))
    protected += [root / 'scripts/level96_android_qa.py', root / 'scripts/run_level96_android_qa.sh']
    before = {str(p.relative_to(root)): sha(p) for p in protected}
    try:
        _, devices = run.command('device_inventory', [adb, 'devices', '-l'])
        connected = any(re.match(re.escape(args.device) + r'\s+device\b', line) for line in devices.splitlines())
        if not connected:
            run.note('android_availability', 'NOT RUN', 'Requested device disconnected, unauthorized or unavailable; host checks continue')
        else:
            run.note('android_availability', 'PASS', 'Requested device is connected and authorized')
        gradle = (root / 'android/app/build.gradle').read_text()
        if "applicationId 'com.ragarrwc.game'" not in gradle or "applicationIdSuffix '.dev'" not in gradle:
            raise ValueError('Unrecognized application ID configuration; failing closed')
        require_safe_install(run.app_id, [])
        run.note('source_package_isolation', 'PASS', 'Production and DEV are distinct; each QA run uses an additional unique suffix')
        run.command('tooling_dependencies', [flutter, 'pub', 'get', '--offline'], cwd=root / 'integration_test')
        new = ['contract', 'session', 'widget']
        run.command('phase4d7_tests', [flutter, 'test', '--no-pub',
            *[f'test/balance_audit/level96_phase4d7_{n}_test.dart' for n in new], '--concurrency=1', '--reporter=expanded'], expected_tests=27)
        run.command('phase4d7a_driver_tests', [flutter, 'test', '--no-pub', 'test/balance_audit/level96_phase4d7a_driver_test.dart', '--concurrency=1', '--reporter=expanded'], expected_tests=3)
        run.command('historical_contracts', [flutter, 'test', '--no-pub',
            *['test/balance_audit/' + n for n in ['level96_phase4d5_contract_test.dart', 'level96_shadow_contract_test.dart',
              'campaign_paired_contract_test.dart', 'campaign_validation_contract_test.dart']], '--concurrency=1', '--reporter=expanded'], expected_tests=54)
        for phase, file in [('4', 'test_level96_post_opening.py'), ('6', 'test_level96_phase4d6_diagnostic.py'), ('7a', 'test_level96_android_qa.py')]:
            run.command('python_phase' + phase, [sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'test/balance_audit', '-p', file, '-v'], expected_tests={'4':11, '6':14, '7a':11}[phase])
        copy_project(run)
        run.command('ordinary_tests', [flutter, 'test', '--no-pub', 'test/qa', 'test/goldens', '--concurrency=1', '--reporter=expanded'], cwd=run.copy)
        run.command('analyzer', [flutter, 'analyze', '--no-pub'], accept=lambda code, text: code in [0, 1] and findings(text) == sorted(baseline))
        run.command('diff_check', ['git', 'diff', '--check'])
        if any(s['status'] == 'FAIL' for s in run.steps):
            run.note('android_execution', 'NOT RUN', 'Critical host check failed; see original errors in logs')
            return 1
        if not connected:
            run.note('android_execution', 'NOT RUN', 'No authorized target Android device')
            return 2
        _, packages = run.command('installed_packages_before', adbc('shell', 'pm', 'list', 'packages', PRODUCTION))
        installed = {line.removeprefix('package:').strip() for line in packages.splitlines() if line.startswith('package:')}
        require_safe_install(run.app_id, installed)
        existing_paths = {}
        for label, package in [('production', PRODUCTION), ('dev', DEV)]:
            _, text = run.command('package_' + label + '_before', adbc('shell', 'pm', 'path', package))
            existing_paths[package] = text
        # Mutate only the disposable Android build, never workspace Gradle or locks.
        configure_android_copy(run.copy, gradle, run.app_id)
        for file in (root / 'integration_test').glob('*.dart'):
            (run.copy / 'integration_test').mkdir(exist_ok=True)
            shutil.copy2(file, run.copy / 'integration_test' / file.name)
        pub = run.copy / 'pubspec.yaml'
        pub.write_text(pub.read_text().replace('dev_dependencies:', 'dev_dependencies:\n  integration_test:\n    sdk: flutter'), encoding='utf-8')
        ok, _ = run.command('android_dependencies', [flutter, 'pub', 'get', '--offline'], cwd=run.copy)
        if not ok: return 1
        original_versions = dependency_versions((root / 'pubspec.lock').read_text())
        android_versions = dependency_versions((run.copy / 'pubspec.lock').read_text())
        if any(android_versions.get(k) != v for k, v in original_versions.items()):
            raise ValueError('Existing dependency versions changed in Android test build')
        run.note('android_dependency_integrity', 'PASS', 'All existing locked dependency versions retained; only test SDK dependencies added')
        flags = ['--flavor', 'dev', '--dart-define=FLAVOR=dev', '--dart-define=LEVEL96_PLAYTEST=true', '--dart-define=LEVEL96_QA_INSTALL=true']
        ok, _ = run.command('android_build', [flutter, 'build', 'apk', '--debug', '--no-pub', *flags,
            '-t', 'integration_test/level96_playtest_e2e_test.dart'], cwd=run.copy, timeout=1800)
        if not ok: return 1
        apk = run.copy / 'build/app/outputs/flutter-apk/app-dev-debug.apk'
        aapt = sorted((sdk / 'build-tools').glob('*/aapt.exe'))[-1]
        ok, badging = run.command('apk_identity', [aapt, 'dump', 'badging', apk])
        identity = re.search(r"^package: name='([^']+)'", badging, re.M)
        if not ok or not identity or identity[1] != run.app_id:
            raise ValueError('Built APK ID does not match safe dedicated test ID; installation prohibited')
        if "uses-permission: name='android.permission.INTERNET'" not in badging:
            raise ValueError('QA APK lacks loopback VM-service permission; driver cannot connect')
        ok, manifest = run.command('apk_manifest', [aapt, 'dump', 'xmltree', apk, 'AndroidManifest.xml'])
        if not ok or 'sharedUserId' in manifest:
            raise ValueError('QA APK must not share an Android application UID')
        run.data['apk_sha256'] = sha(apk)
        run.note('apk_safety_gate', 'PASS', 'Verified unique APK application ID before any install')
        # Recheck immediately before Flutter drive installs the verified binary.
        ok, check = run.command('test_package_absent', adbc('shell', 'pm', 'list', 'packages', run.app_id))
        if not ok or any(x == 'package:' + run.app_id for x in check.splitlines()):
            raise ValueError('Test installation ID unexpectedly present; refusing to replace data')
        run.command('device_geometry', adbc('shell', 'wm', 'size'))
        run.command('device_density', adbc('shell', 'wm', 'density'))
        run.command('device_android_version', adbc('shell', 'getprop', 'ro.build.version.release'))
        environment = os.environ.copy()
        environment['LEVEL96_QA_RESPONSE'] = str(run.output / 'android_response.json')
        ok, _ = run.command('android_integration', [flutter, 'drive', '--no-pub', '--debug', *flags,
            '-d', args.device, '--driver=integration_test/driver.dart',
            '--target=integration_test/level96_playtest_e2e_test.dart', '--keep-app-running', '--use-application-binary=' + str(apk)],
            cwd=run.copy, timeout=1500, env=environment)
        _, pid_text = run.command('test_process_id', adbc('shell', 'pidof', run.app_id))
        if re.fullmatch(r'\d+', pid_text.strip()):
            run.command('android_logcat', adbc('logcat', '-d', '--pid=' + pid_text.strip()), timeout=30)
        else:
            run.note('android_logcat', 'NOT RUN', 'Test process unavailable; Flutter driver log retains launch/test errors')
        # Only the package created for this run is stopped; nothing is cleared.
        run.command('stop_test_application', adbc('shell', 'am', 'force-stop', run.app_id))
        response = run.output / 'android_response.json'
        if response.exists():
            payload = json.loads(response.read_text())
            if set(payload.get('scenarios', {})) != set(SCENARIOS): raise ValueError('Missing Android scenarios')
            run.scenarios.update(payload['scenarios'])
            run.data['frame_timings'] = payload.get('frame_timings')
        elif ok:
            raise ValueError('Driver reported success without Android scenario evidence')
        for label, package in [('production', PRODUCTION), ('dev', DEV)]:
            _, after = run.command('package_' + label + '_after', adbc('shell', 'pm', 'path', package))
            if after != existing_paths[package]: raise ValueError('Existing installed package path changed: ' + package)
        run.note('existing_installations_preserved', 'PASS', 'Production and existing DEV APK paths unchanged; no commands cleared or accessed their private storage')
        return 0 if ok and all(s['status'] == 'PASS' for s in run.scenarios.values()) else 1
    except Exception as error:
        import traceback
        (run.output / 'orchestration_error.log').write_text(traceback.format_exc(), encoding='utf-8')
        run.note('orchestration', 'FAIL', str(error), log='orchestration_error.log')
        return 1
    finally:
        drift = [p for p, digest in before.items() if not (root / p).is_file() or sha(root / p) != digest]
        run.note('protected_input_integrity', 'FAIL' if drift else 'PASS',
                 'Changed: ' + ', '.join(drift) if drift else f'{len(before)} protected input files unchanged')
        run.data['protected_before_sha256'] = before
        run.data['status'] = 'FAIL' if any(s['status'] == 'FAIL' for s in run.steps) or any(s['status'] == 'FAIL' for s in run.scenarios.values()) else 'COMPLETE' if all(s['status'] == 'PASS' for s in run.scenarios.values()) else 'INCOMPLETE'
        run.save()
        print('FINAL_REPORT=' + str(run.output / 'report.md'), flush=True)
        if drift:
            raise RuntimeError('Protected input integrity failed; see generated report')


if __name__ == '__main__':
    sys.exit(main())
