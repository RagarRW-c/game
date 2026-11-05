"""Phase 5A host regressions and isolated Android ON/OFF profile validation.

Run from Git Bash: PYTHONUTF8=1 python -B scripts/run_phase5a_qa.py
Reuses the tested Phase 4D-7A process, copy and package-safety helpers.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import sys
import subprocess
import traceback
import uuid

import level96_android_qa as qa

HOSTS = {'phase5a_contracts', 'affected_regressions', 'phase4d7_off',
         'phase4d7_on', 'historical_contracts', 'ordinary_tests'}
qa.HOST_TEST_STEPS.update(HOSTS)


def normalized_findings(text):
    return Counter(re.sub(r':\d+:\d+(?= - )', '', line) for line in qa.findings(text))


def reuse_host_evidence(run, directory):
    directory = Path(directory).resolve()
    allowed = (run.root / 'qa/phase5a_runs').resolve()
    if directory.parent != allowed:
        raise ValueError('Host evidence must be a Phase 5A run directory')
    old = json.loads((directory / 'summary.json').read_text(encoding='utf-8'))
    if old['run_id'] != directory.name:
        raise ValueError('Host evidence identity mismatch')
    if not any(s['name'] == 'input_integrity' and s['status'] == 'PASS' for s in old['steps']):
        raise ValueError('Prior run did not verify input integrity')
    for path, digest in old['source_sha256'].items():
        # These two device-only files are freshly built/executed below and are
        # not dependencies of any reused host tests. Runtime and host tests must match.
        if Path(path).as_posix() in {'integration_test/phase5a_campaign_test.dart', 'integration_test/phase5a_driver.dart'}:
            continue
        if not (run.root / path).is_file() or qa.sha(run.root / path) != digest:
            raise ValueError('Source changed since host validation: ' + path)
    old_copy = run.root / '.dart_tool/phase5a_qa' / directory.name
    checked = 0
    for folder in ['test/qa', 'test/goldens']:
        original = {str(p.relative_to(run.root)): qa.sha(p) for p in (run.root / folder).rglob('*') if p.is_file()}
        saved = {str(p.relative_to(old_copy)): qa.sha(p) for p in (old_copy / folder).rglob('*') if p.is_file()}
        if original != saved:
            raise ValueError('Ordinary test sources changed since host validation: ' + folder)
        checked += len(original)
    # These explicitly invoked contract files are tracked and unchanged in this
    # workspace. New reports can additionally verify all test hashes directly.
    subprocess.run(['git', 'diff', '--exit-code', '--', 'test/balance_audit'], cwd=run.root, check=True, stdout=subprocess.DEVNULL)
    for path, digest in old.get('test_source_sha256', {}).items():
        if not (run.root / path).is_file() or qa.sha(run.root / path) != digest:
            raise ValueError('Contract source changed since host validation: ' + path)
    expected = {'phase5a_contracts':35, 'affected_regressions':211,
                'phase4d7_off':27, 'phase4d7_on':27, 'historical_contracts':54,
                'ordinary_tests':1628}
    for name, count in expected.items():
        step = next((x for x in old['steps'] if x['name'] == name), None)
        if not step or step['status'] != 'PASS' or step.get('test_counts') != {'PASS':count, 'FAIL':0, 'NOT RUN':0}:
            raise ValueError('Missing complete host results: ' + name)
        run.steps.append({**step, 'log': str(directory / step['log']),
            'reused_from': str(directory), 'reason': 'Verified unchanged source/test evidence: ' + str(directory / step['log'])})
    run.note('host_evidence_integrity', 'PASS', f'Runtime hashes and {checked} ordinary test files match prior passing checks; Campaign contracts unchanged; device-only drivers freshly validated')
    run.data['host_evidence'] = str(directory)


class PhaseRun(qa.Run):
    def __init__(self, root, device):
        self.root = root
        self.device = device
        self.id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S') + '-' + uuid.uuid4().hex[:8]
        self.output = root / 'qa/phase5a_runs' / self.id
        self.output.mkdir(parents=True, exist_ok=False)
        self.copy = root / '.dart_tool/phase5a_qa' / self.id
        self.steps = []
        self.android = {variant: {'status': 'NOT RUN'} for variant in ['off', 'on']}
        self.data = {'schema': 'phase5a-qa/v1', 'run_id': self.id, 'status': 'RUNNING',
                     'device': device, 'steps': self.steps, 'android': self.android,
                     'new_balance_attempts': 0}
        self.save()

    def save(self):
        self.data['step_counts'] = dict(Counter(s['status'] for s in self.steps))
        self.data['host_test_counts'] = {v: sum(s.get('test_counts', {}).get(v, 0)
            for s in self.steps if s['name'] in HOSTS) for v in ['PASS', 'FAIL', 'NOT RUN']}
        (self.output / 'summary.json').write_text(json.dumps(self.data, indent=2) + '\n', encoding='utf-8')
        lines = ['# Phase 5A validation', '', 'Status: ' + self.data['status'], '',
                 '| Check | Status | Evidence |', '|---|---|---|']
        lines += [f"| {s['name']} | {s['status']} | {s.get('reason', s.get('log', '')).replace('|', '/')} |" for s in self.steps]
        lines += ['', 'Host tests: ' + json.dumps(self.data['host_test_counts']), '',
                  '## Physical Android', '', '| Flag | Status | Package |', '|---|---|---|']
        lines += [f"| {name} | {a['status']} | {a.get('app_id', '')} |" for name, a in self.android.items()]
        lines += ['', 'Profile frame samples exclude screenshot conversion. They do not certify sustained 60 FPS,',
                  'perceived smoothness, speaker quality or audio timbre. Original reference audio was not extracted.',
                  'Raw commands, errors, snapshots and frame samples are preserved in this directory.',
                  'Production and existing DEV saves are never read or cleared. No balance cohorts, commits or pushes.']
        (self.output / 'report.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', default='RZCTA0TPGDD')
    parser.add_argument('--host-evidence', help='Reuse complete host checks only after unchanged source/test verification')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_.:-]+', args.device):
        raise ValueError('Invalid device ID')
    root = Path(__file__).resolve().parents[1]
    run = PhaseRun(root, args.device)
    print('REPORT_DIRECTORY=' + str(run.output), flush=True)
    flutter = shutil.which('flutter') or 'C:/flutter/bin/flutter.bat'
    local = (root / 'android/local.properties').read_text()
    sdk = Path(next(x.split('=', 1)[1] for x in local.splitlines() if x.startswith('sdk.dir=')).replace('\\\\', '\\'))
    adb = sdk / 'platform-tools/adb.exe'
    def adbc(*parts): return [adb, '-s', args.device, *parts]
    protected = [p for d in ['lib', 'assets/levels', 'qa/campaign_validation_runs'] for p in (root / d).rglob('*') if p.is_file()]
    protected += [root / p for p in ['pubspec.yaml', 'pubspec.lock', 'android/app/build.gradle',
                  'qa/balance_campaign.json', 'qa/balance_endless.json']]
    protected += list((root / 'integration_test').glob('*.dart'))
    protected += list((root / 'assets/audio').glob('campaign_*_v2.wav'))
    before = {str(p.relative_to(root)): qa.sha(p) for p in protected}
    run.data['source_sha256'] = before
    run.data['test_source_sha256'] = {str(p.relative_to(root)):qa.sha(p) for p in (root / 'test').rglob('*.dart')}
    try:
        _, inventory = run.command('device_inventory', [adb, 'devices', '-l'])
        connected = any(re.match(re.escape(args.device) + r'\s+device\b', line) for line in inventory.splitlines())
        run.note('authorized_device', 'PASS' if connected else 'NOT RUN', 'Requested authorized device found' if connected else 'Android unavailable; host checks continue')
        # Nested tooling package leaves the historical production lockfile intact.
        run.command('tooling_dependencies', [flutter, 'pub', 'get', '--offline'], cwd=root / 'integration_test')
        tail = ['--concurrency=1', '--reporter=expanded']
        if args.host_evidence:
            reuse_host_evidence(run, args.host_evidence)
        else:
            run.command('phase5a_contracts', [flutter, 'test', '--no-pub', 'test/qa/phase5a_game_feel_test.dart', 'test/qa/phase5a_audio_test.dart', 'test/qa/phase5a_reverse_test.dart', *tail], expected_tests=35)
            run.command('affected_regressions', [flutter, 'test', '--no-pub', *[f'test/qa/{n}_test.dart' for n in ['tile_motion', 'tile_feedback', 'tile_audio_service']], *tail], expected_tests=211)
            contracts = [f'test/balance_audit/level96_phase4d7_{n}_test.dart' for n in ['contract', 'session', 'widget']]
            for flag in ['off', 'on']:
                run.command('phase4d7_' + flag, [flutter, 'test', '--no-pub', '--dart-define=GAME_FEEL_V2=' + str(flag == 'on').lower(), *contracts, *tail], expected_tests=27)
            run.command('historical_contracts', [flutter, 'test', '--no-pub', *['test/balance_audit/' + n for n in [
                'level96_phase4d5_contract_test.dart', 'level96_shadow_contract_test.dart', 'campaign_paired_contract_test.dart', 'campaign_validation_contract_test.dart']], *tail], expected_tests=54)
        qa.copy_project(run)
        if not args.host_evidence:
            run.command('ordinary_tests', [flutter, 'test', '--no-pub', 'test/qa', 'test/goldens', *tail], cwd=run.copy, expected_tests=1628)
        baseline = json.loads((root / 'qa/phase5a_analyzer_baseline.json').read_text())['findings']
        baseline = normalized_findings('\n'.join(baseline))
        _, analysis = run.command('analyzer', [flutter, 'analyze', '--no-pub'],
            accept=lambda code, text: code in [0, 1] and not (normalized_findings(text) - baseline))
        run.data['analyzer'] = {'baseline_findings': sum(baseline.values()),
            'current_findings': len(qa.findings(analysis)),
            'new_findings': list((normalized_findings(analysis) - baseline).elements()),
            'comparison': 'Message, path and lint identity; line numbers ignored after source insertions'}
        run.command('diff_check', ['git', 'diff', '--check'])
        if any(s['status'] == 'FAIL' for s in run.steps) or not connected:
            return 1 if connected else 2
        gradle = (root / 'android/app/build.gradle').read_text()
        if "applicationId 'com.ragarrwc.game'" not in gradle or "applicationIdSuffix '.dev'" not in gradle:
            raise ValueError('Unrecognized application ID configuration')
        existing = {}
        for label, package in [('production', qa.PRODUCTION), ('dev', qa.DEV)]:
            _, existing[package] = run.command(label + '_before', adbc('shell', 'pm', 'path', package))
        run.command('android_version', adbc('shell', 'getprop', 'ro.build.version.release'))
        target = run.copy / 'integration_test'
        target.mkdir()
        for file in (root / 'integration_test').glob('*.dart'):
            shutil.copy2(file, target / file.name)
        pub = run.copy / 'pubspec.yaml'
        pub.write_text(pub.read_text().replace('dev_dependencies:', 'dev_dependencies:\n  integration_test:\n    sdk: flutter'), encoding='utf-8')
        ok, _ = run.command('android_dependencies', [flutter, 'pub', 'get', '--offline'], cwd=run.copy)
        if not ok: return 1
        versions = qa.dependency_versions((root / 'pubspec.lock').read_text())
        android_versions = qa.dependency_versions((run.copy / 'pubspec.lock').read_text())
        if any(android_versions.get(k) != v for k, v in versions.items()):
            raise ValueError('Existing dependency version changed')
        aapt = sorted((sdk / 'build-tools').glob('*/aapt.exe'))[-1]
        for flag in ['off', 'on']:
            app_id = qa.DEV + '.l96qap5a' + run.id.replace('-', '').lower() + flag
            run.android[flag]['app_id'] = app_id
            qa.configure_android_copy(run.copy, gradle, app_id)
            flags = ['--flavor', 'dev', '--dart-define=FLAVOR=dev', '--dart-define=LEVEL96_QA_INSTALL=true', '--dart-define=GAME_FEEL_V2=' + str(flag == 'on').lower()]
            ok, _ = run.command('build_' + flag, [flutter, 'build', 'apk', '--profile', '--no-pub', *flags, '-t', 'integration_test/phase5a_campaign_test.dart'], cwd=run.copy, timeout=1800)
            if not ok: return 1
            apk = run.copy / 'build/app/outputs/flutter-apk/app-dev-profile.apk'
            ok, badging = run.command('apk_identity_' + flag, [aapt, 'dump', 'badging', apk])
            identity = re.search(r"^package: name='([^']+)'", badging, re.M)
            if not ok or not identity or identity[1] != app_id:
                raise ValueError('APK identity mismatch; install prohibited')
            ok, manifest = run.command('apk_manifest_' + flag, [aapt, 'dump', 'xmltree', apk, 'AndroidManifest.xml'])
            if not ok or 'sharedUserId' in manifest or "uses-permission: name='android.permission.INTERNET'" not in badging:
                raise ValueError('Unsafe UID or missing profile VM-service permission')
            ok, installed = run.command('package_absent_' + flag, adbc('shell', 'pm', 'list', 'packages', app_id))
            if not ok: return 1
            qa.require_safe_install(app_id, [x.removeprefix('package:').strip() for x in installed.splitlines()])
            directory = run.output / flag
            directory.mkdir()
            run.android[flag]['apk_sha256'] = qa.sha(apk)
            env = os.environ.copy()
            env['PHASE5A_RESPONSE'] = str(directory / 'android_response.json')
            try:
                ok, _ = run.command('android_' + flag, [flutter, 'drive', '--no-pub', '--profile', *flags,
                    '-d', args.device, '--driver=integration_test/phase5a_driver.dart', '--target=integration_test/phase5a_campaign_test.dart',
                    '--keep-app-running', '--use-application-binary=' + str(apk)], cwd=run.copy, timeout=600, env=env)
                _, pid = run.command('pid_' + flag, adbc('shell', 'pidof', app_id))
                if re.fullmatch(r'\d+', pid.strip()):
                    run.command('logcat_' + flag, adbc('logcat', '-d', '--pid=' + pid.strip()), timeout=30)
                response = directory / 'android_response.json'
                if response.exists():
                    payload = json.loads(response.read_text())
                    run.android[flag]['response'] = str(response)
                    run.android[flag]['checks'] = payload.get('checks', {})
                    run.android[flag]['frame_timings'] = payload.get('frame_timings')
                    required = {'fresh_isolated_storage_and_native_audio', 'entry_muted_False', 'entry_muted_True',
                                'selection_and_triple_muted_False', 'selection_and_triple_muted_True', 'screenshots_after_performance_sampling'}
                    # Dart string interpolation uses lowercase boolean names.
                    required = {x.replace('_False', '_false').replace('_True', '_true') for x in required}
                    ok = ok and set(payload.get('checks', {})) == required and all(v == 'PASS' for v in payload['checks'].values())
                else:
                    ok = False
                run.android[flag]['status'] = 'PASS' if ok else 'FAIL'
                run.save()
            finally:
                run.command('stop_' + flag, adbc('shell', 'am', 'force-stop', app_id))
            if not ok: return 1
        for label, package in [('production', qa.PRODUCTION), ('dev', qa.DEV)]:
            _, after = run.command(label + '_after', adbc('shell', 'pm', 'path', package))
            if after != existing[package]: raise ValueError('Existing package path changed')
        run.note('existing_installations_preserved', 'PASS', 'Production and existing DEV APK paths unchanged; private storage untouched')
        return 0
    except Exception as error:
        (run.output / 'orchestration_error.log').write_text(traceback.format_exc(), encoding='utf-8')
        run.note('orchestration', 'FAIL', str(error))
        return 1
    finally:
        changed = [p for p, digest in before.items() if not (root / p).is_file() or qa.sha(root / p) != digest]
        run.note('input_integrity', 'FAIL' if changed else 'PASS', 'Changed: ' + ', '.join(changed) if changed else f'{len(before)} inputs unchanged during validation')
        failed = any(s['status'] == 'FAIL' for s in run.steps) or any(a['status'] == 'FAIL' for a in run.android.values())
        run.data['status'] = 'FAIL' if failed else 'COMPLETE' if all(a['status'] == 'PASS' for a in run.android.values()) else 'INCOMPLETE'
        run.save()
        print('FINAL_REPORT=' + str(run.output / 'report.md'), flush=True)
        if changed: raise RuntimeError('Input integrity changed during run')


if __name__ == '__main__':
    sys.exit(main())
