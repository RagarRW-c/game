import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      timeout: const Duration(minutes: 20),
      writeResponseOnFailure: true,
      responseDataCallback: (data) async {
        final destination = Platform.environment['LEVEL96_QA_RESPONSE'];
        if (destination == null || File(destination).existsSync()) {
          throw StateError('A new, explicit response destination is required.');
        }
        await File(destination).writeAsString(
            '${const JsonEncoder.withIndent('  ').convert(data)}\n');
      },
    );
