import 'dart:convert';
import 'dart:io';

import 'package:triple_tile_adventure/domain/level.dart';

import '../../qa/support/geometry.dart';
import 'campaign_paired.dart';
import 'campaign_validation.dart';
import 'level96_shadow.dart';
import 'level96_shadow_io.dart';

const phase5SourceRun =
    'qa/campaign_validation_runs/shadow96-20261105T102737023052Z-30288-562eae3b';
const phase5DiagnosticRun =
    'qa/campaign_validation_runs/phase4d4-level96-20261105T105649681167Z-iw07bmfe';
// Pin the reviewed evidence. Never silently pick a newer run or altered report.
const phase5ReferenceFingerprints = {
  '$phase5SourceRun/attempts.jsonl': '43d1befb',
  '$phase5SourceRun/manifest.json': '2da5beaa',
  '$phase5SourceRun/report.md': '28f131db',
  '$phase5SourceRun/summary.json': '5b1f2519',
  '$phase5DiagnosticRun/failure_clusters.json': '1925873b',
  '$phase5DiagnosticRun/manifest.json': 'c2ed6471',
  '$phase5DiagnosticRun/report.md': 'b1c97edb',
  '$phase5DiagnosticRun/summary.json': '51e0f982',
};
const phase5ToolInputs = [
  'test/balance_audit/support/level96_phase4d5.dart',
  'test/balance_audit/support/level96_phase4d5_io.dart',
  'test/balance_audit/support/level96_phase4d5_report.dart',
  'test/balance_audit/level96_phase4d5_contract_test.dart',
  'test/balance_audit/level96_phase4d5_run_test.dart',
  'test/balance_audit/LEVEL96_PHASE4D5.md',
];
List<String> phase5InputPaths() => {
      ...shadow96BehaviorInputs,
      ...shadow96ToolInputs,
      ...shadow96ReferenceFiles,
      ...phase5ReferenceFingerprints.keys,
      ...phase5ToolInputs,
    }.toList()
      ..sort();

void phase5RequireReferenceHashes(CampaignJson current) {
  for (final e in phase5ReferenceFingerprints.entries) {
    if (current[e.key] != e.value) {
      throw StateError('Historical evidence changed: ${e.key}');
    }
  }
}

bool phase5InputsUnchanged(CampaignJson before, CampaignJson after) =>
    before.isNotEmpty &&
    !before.values.contains('MISSING') &&
    !after.values.contains('MISSING') &&
    shadowCanonical(before) == shadowCanonical(after);

class Phase5Reference {
  Phase5Reference(this.sourceManifest, this.diagnosticManifest, this.historical,
      this.candidateRows);
  final CampaignJson sourceManifest, diagnosticManifest;
  final Shadow96Reference historical;
  final Map<String, CampaignJson> candidateRows;
  Map<String, List<String>> get witnesses => historical.witnesses;
  CampaignJson toJson() => {
        'phase4d3_source': phase5SourceRun,
        'phase4d4_source': phase5DiagnosticRun,
        'pinned_fingerprints': phase5ReferenceFingerprints,
        'phase4d3_status': sourceManifest['status'],
        'phase4d3_health': sourceManifest['measurement_health'],
        'phase4d4_status': diagnosticManifest['status'],
        'phase4d4_health': diagnosticManifest['measurement_health'],
        'historical_candidate_rows_validated': candidateRows.length,
        'historical_behavior_input_checks': historical.inputChecks,
        'witness_source': shadow96WitnessRun,
        'historical_reproduction_replicas': [24],
        'historical_reproductions_planned': 6,
        'historical_reproductions_counted_in_new_cohort': false,
      };
}

Future<Phase5Reference> loadPhase5Reference() async {
  phase5RequireReferenceHashes(
      shadowFingerprints(phase5ReferenceFingerprints.keys));
  CampaignJson read(String path) => Map<String, Object?>.from(
      jsonDecode(File(path).readAsStringSync()) as Map);
  final source = read('$phase5SourceRun/manifest.json');
  final diagnostic = read('$phase5DiagnosticRun/manifest.json');
  final findings = read('$phase5DiagnosticRun/summary.json');
  if (source['schema'] != shadow96Version ||
      source['status'] != 'COMPLETE' ||
      source['measurement_health'] != 'OK' ||
      source['actual_attempts'] != 360 ||
      source['inputs_unchanged'] != true ||
      diagnostic['schema'] != 'campaign4d4/level96-post-opening-v1' ||
      diagnostic['status'] != 'COMPLETE' ||
      diagnostic['measurement_health'] != 'OK' ||
      diagnostic['source_run'] != source['run_id'] ||
      shadowCanonical(
              (findings['recommended_next_experiment'] as Map)['swap']) !=
          shadowCanonical(['L96_T071', 'L96_T069'])) {
    throw StateError('Reviewed Phase 4D-3 / 4D-4 provenance is invalid');
  }
  final historical = await loadShadow96Reference();
  final behavior = shadowFingerprints(shadow96BehaviorInputs);
  for (final e in behavior.entries) {
    if ((source['fingerprints_before'] as Map)[e.key] != e.value ||
        (source['fingerprints_after'] as Map)[e.key] != e.value) {
      throw StateError('Behavior drift since Phase 4D-3: ${e.key}');
    }
  }
  final seen = <String>{}, candidates = <String, CampaignJson>{};
  await for (final line in File('$phase5SourceRun/attempts.jsonl')
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    if (line.trim().isEmpty) continue;
    final r = Map<String, Object?>.from(jsonDecode(line) as Map);
    if (r['level'] != 96 ||
        r['experiment_version'] != pairedVersion ||
        r['shadow_experiment_version'] != shadow96Version ||
        r['omniscient'] != false ||
        !shadow96Variants.contains(r['variant']) ||
        !qaScreens.any((s) => s.name == r['screen']) ||
        !shadow96Policies.any((p) => p.name == r['strategy']) ||
        r['replica'] is! int ||
        (r['replica'] as int) < 0 ||
        (r['replica'] as int) > 29 ||
        !['WIN', 'LOSS'].contains(r['outcome']) ||
        (r['trace'] as List).length != r['decisions']) {
      throw StateError('Invalid historical shadow row');
    }
    final key = shadowReferenceKey(
        r['screen'] as String, r['strategy'] as String, r['replica'] as int);
    if (!seen.add('${r['variant']}|$key')) {
      throw StateError('Duplicate historical row');
    }
    if (r['variant'] == 'candidate') candidates[key] = r;
  }
  if (seen.length != 360 || candidates.length != 180) {
    throw StateError('Incomplete source cohort');
  }
  return Phase5Reference(source, diagnostic, historical, candidates);
}

/// Six old replica-24 regressions, not new 30-59 measurements or added A/B rows.
List<CampaignJson> phase5ReproduceHistoricalControl(
        LevelDefinition a, Phase5Reference ref) =>
    [
      for (final s in qaScreens)
        for (final p in shadow96Policies)
          (() {
            final historical = Map<String, Object?>.of(
                ref.candidateRows[shadowReferenceKey(s.name, p.name, 24)]!)
              ..remove('shadow_experiment_version')
              ..remove('variant')
              ..remove('cohort');
            final actual = simulatePairedCampaign(
                a, CampaignGraph(a.tiles, s.geometry()), p, s.name, 24);
            final keys = {...actual.keys, ...historical.keys}.toList()..sort();
            final different = [
              for (final k in keys)
                if (shadowCanonical(actual[k]) !=
                        shadowCanonical(historical[k]) ||
                    actual.containsKey(k) != historical.containsKey(k))
                  k
            ];
            return <String, Object?>{
              'screen': s.name,
              'strategy': p.name,
              'replica': 24,
              'passed': different.isEmpty,
              'different_fields': different,
              'comparison': 'FULL_PAIRED_V1_ROW_INCLUDING_COMPLETE_TRACE',
              'counted_in_experiment': false
            };
          })(),
    ];

bool phase5ReproductionPassed(List<CampaignJson> checks) {
  final expected = {
    for (final s in qaScreens)
      for (final p in shadow96Policies) shadowReferenceKey(s.name, p.name, 24)
  };
  final actual = checks
      .map((r) => '${r['screen']}|${r['strategy']}|${r['replica']}')
      .toSet();
  return checks.length == 6 &&
      actual.length == 6 &&
      actual.containsAll(expected) &&
      checks.every((r) => r['passed'] == true);
}

/// Constructor is private: writes are possible only inside a fresh temp run.
class Phase5Output {
  Phase5Output._(this.directory) {
    File('${directory.path}/attempts.jsonl').writeAsStringSync('', flush: true);
  }
  final Directory directory;
  static Phase5Output create({Directory? parent}) {
    final root = parent ?? Directory('qa/campaign_validation_runs');
    root.createSync(recursive: true);
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9TZ]'), '');
    return Phase5Output._(root.createTempSync('phase4d5-level96-$stamp-$pid-'));
  }

  String get runId =>
      directory.uri.pathSegments.where((x) => x.isNotEmpty).last;
  void writeJson(String name, CampaignJson data) {
    if (!['manifest.json', 'summary.json'].contains(name)) {
      throw ArgumentError('Unsupported artifact');
    }
    File('${directory.path}/$name').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(data)}\n',
        flush: true);
  }

  void append(CampaignJson row) => File('${directory.path}/attempts.jsonl')
      .writeAsStringSync('${jsonEncode(row)}\n',
          mode: FileMode.append, flush: true);
  void report(String text) =>
      File('${directory.path}/report.md').writeAsStringSync(text, flush: true);
}
