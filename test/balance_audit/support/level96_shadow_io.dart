// IO boundary: read fixed historical evidence; write only a freshly allocated run.
import 'dart:convert';
import 'dart:io';

import '../../qa/support/geometry.dart';
import 'campaign_paired.dart';
import 'campaign_validation.dart';
import 'level96_shadow.dart';

const shadow96PairedRun =
    'qa/campaign_validation_runs/paired-20261105T085938901757Z-32484-15d06b81';
const shadow96WitnessRun =
    'qa/campaign_validation_runs/20261104T215452428949Z-25028';
const shadow96ReferenceFiles = [
  '$shadow96PairedRun/manifest.json',
  '$shadow96PairedRun/paired_attempts.jsonl',
  '$shadow96WitnessRun/manifest.json',
  '$shadow96WitnessRun/baseline.jsonl',
];
const shadow96BehaviorInputs = [
  'pubspec.yaml',
  'pubspec.lock',
  shadow96Asset,
  'lib/domain/game_engine.dart',
  'lib/domain/game_result.dart',
  'lib/domain/level.dart',
  'lib/domain/tile.dart',
  'test/qa/support/geometry.dart',
  'test/qa/support/solver.dart',
  'test/balance_audit/support/balance_metrics.dart',
  'test/balance_audit/support/campaign_validation.dart',
  'test/balance_audit/support/campaign_paired.dart',
];
const shadow96ToolInputs = [
  'test/balance_audit/support/level96_shadow.dart',
  'test/balance_audit/support/level96_shadow_io.dart',
  'test/balance_audit/support/level96_shadow_report.dart',
  'test/balance_audit/level96_shadow_run_test.dart',
  'test/balance_audit/level96_shadow_contract_test.dart',
  'test/balance_audit/LEVEL96_SHADOW_EXPERIMENT.md',
];

// Historical JSONL can be hundreds of MB. Hash incrementally rather than
// allocating the entire historical run while candidate traces are in memory.
String shadowFileFingerprint(File file) {
  final handle = file.openSync();
  var hash = 0x811c9dc5;
  try {
    while (true) {
      final bytes = handle.readSync(64 * 1024);
      if (bytes.isEmpty) break;
      for (final byte in bytes) {
        hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
      }
    }
  } finally {
    handle.closeSync();
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

CampaignJson shadowFingerprints(Iterable<String> paths) => {
      for (final path in paths)
        path: File(path).existsSync()
            ? shadowFileFingerprint(File(path))
            : 'MISSING',
    };
String shadowReferenceKey(String screen, String policy, int replica) =>
    '$screen|$policy|$replica';

class Shadow96Reference {
  Shadow96Reference(this.pairedManifest, this.witnessManifest, this.rows,
      this.witnesses, this.inputChecks);
  final CampaignJson pairedManifest, witnessManifest;
  final Map<String, CampaignJson> rows;
  final Map<String, List<String>> witnesses;
  final List<CampaignJson> inputChecks;
  CampaignJson toJson() => {
        'paired_run': shadow96PairedRun,
        'witness_run': shadow96WitnessRun,
        'paired_version': pairedManifest['experiment_version'],
        'paired_git_head': pairedManifest['git_head'],
        'paired_dart_version': pairedManifest['dart_version'],
        'paired_flutter_version': pairedManifest['flutter_version'],
        'input_checks': inputChecks,
        'control_overlap_rows': rows.values.toList(),
        'stored_witnesses': witnesses,
      };
}

/// Required, fixed reference: no discovery of a newer/different run or fallback.
Future<Shadow96Reference> loadShadow96Reference() async {
  final manifest = Map<String, Object?>.from(
      jsonDecode(File(shadow96ReferenceFiles[0]).readAsStringSync()) as Map);
  final baselineManifest = Map<String, Object?>.from(
      jsonDecode(File(shadow96ReferenceFiles[2]).readAsStringSync()) as Map);
  if (manifest['status'] != 'COMPLETE' ||
      manifest['measurement_health'] != 'OK' ||
      manifest['actual_attempts'] != 990 ||
      manifest['experiment_version'] != pairedVersion ||
      baselineManifest['status'] != 'COMPLETE') {
    throw StateError(
        'Historical reference is not the completed healthy paired-v1 / witness run');
  }
  final checks = <CampaignJson>[];
  final current = shadowFingerprints(shadow96BehaviorInputs);
  final before = manifest['fingerprints_before'] as Map;
  final after = manifest['fingerprints_after'] as Map;
  for (final path in shadow96BehaviorInputs) {
    final passed = current[path] != 'MISSING' &&
        current[path] == before[path] &&
        current[path] == after[path];
    checks.add({
      'path': path,
      'current': current[path],
      'historical_before': before[path],
      'historical_after': after[path],
      'passed': passed
    });
  }
  if (current[shadow96Asset] != shadow96AssetFingerprint ||
      checks.any((c) => c['passed'] != true)) {
    throw StateError(
        'Paired-v1 input drift: ${checks.where((c) => c['passed'] != true).toList()}');
  }
  final baselineBefore = baselineManifest['fingerprints_before'] as Map;
  final baselineAfter = baselineManifest['fingerprints_after'] as Map;
  if (baselineBefore[shadow96Asset] != current[shadow96Asset] ||
      baselineAfter[shadow96Asset] != current[shadow96Asset]) {
    throw StateError(
        'Stored witness does not refer to the unchanged original level 96 asset');
  }
  final rows = <String, CampaignJson>{};
  await for (final line in File(shadow96ReferenceFiles[1])
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    if (line.trim().isEmpty) continue;
    final row = Map<String, Object?>.from(jsonDecode(line) as Map);
    if (row['level'] != 96 ||
        !shadow96Policies.any((p) => p.name == row['strategy'])) continue;
    if (row['experiment_version'] != pairedVersion ||
        row['omniscient'] != false ||
        row['replica'] is! int ||
        (row['replica'] as int) < 0 ||
        (row['replica'] as int) > 9 ||
        !qaScreens.any((s) => s.name == row['screen']) ||
        row['trace'] is! List ||
        !['WIN', 'LOSS'].contains(row['outcome']))
      throw StateError('Invalid historical level 96 paired row');
    final key = shadowReferenceKey(row['screen'] as String,
        row['strategy'] as String, row['replica'] as int);
    if (rows.containsKey(key))
      throw StateError('Duplicate historical row $key');
    rows[key] = row;
  }
  if (rows.length != 60)
    throw StateError(
        'Expected exactly 60 historical overlap rows; found ${rows.length}');
  final witnesses = <String, List<String>>{};
  await for (final line in File(shadow96ReferenceFiles[3])
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    if (line.trim().isEmpty) continue;
    final row = jsonDecode(line) as Map;
    if (row['level'] != 96) continue;
    final screen = row['screen'] as String;
    if (!qaScreens.any((s) => s.name == screen) ||
        witnesses.containsKey(screen) ||
        row['witness_status'] != 'REPLAYED' ||
        row['witness']['full_clearance'] != true) {
      throw StateError('Invalid/duplicate historical level 96 witness $screen');
    }
    witnesses[screen] = (row['witness']['path_ids'] as List).cast<String>();
  }
  if (witnesses.length != 3)
    throw StateError('All three stored historical witnesses are required');
  return Shadow96Reference(manifest, baselineManifest, rows, witnesses, checks);
}

class ShadowRunOutput {
  ShadowRunOutput._(this.directory) {
    File('${directory.path}/attempts.jsonl').writeAsStringSync('');
  }
  final Directory directory;
  static ShadowRunOutput create({Directory? parent}) {
    final root = parent ?? Directory('qa/campaign_validation_runs');
    root.createSync(recursive: true);
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9TZ]'), '');
    return ShadowRunOutput._(root.createTempSync('shadow96-$stamp-$pid-'));
  }

  String get runId =>
      directory.uri.pathSegments.where((p) => p.isNotEmpty).last;
  void writeJson(String name, CampaignJson value) {
    if (!['manifest.json', 'summary.json'].contains(name))
      throw ArgumentError('Unsupported run artifact');
    File('${directory.path}/$name').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(value)}\n',
        flush: true);
  }

  void appendAttempt(CampaignJson row) =>
      File('${directory.path}/attempts.jsonl').writeAsStringSync(
          '${jsonEncode(row)}\n',
          mode: FileMode.append,
          flush: true);
  void writeReport(String report) => File('${directory.path}/report.md')
      .writeAsStringSync(report, flush: true);
}

String shadowGit(List<String> arguments) {
  try {
    final result = Process.runSync('git', arguments);
    return result.exitCode == 0 ? '${result.stdout}'.trim() : 'UNAVAILABLE';
  } on ProcessException {
    return 'UNAVAILABLE';
  }
}

Object shadowFlutterVersion() {
  var directory = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final file = File('${directory.path}/bin/cache/flutter.version.json');
    if (file.existsSync()) return jsonDecode(file.readAsStringSync()) as Object;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  return 'UNAVAILABLE; record installed SDK provenance separately';
}
