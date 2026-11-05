import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
    timeout: const Duration(minutes: 7),
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final path = Platform.environment['PHASE5A_RESPONSE'];
      if (path == null || File(path).existsSync()) {
        throw StateError('A new explicit Phase 5A response path is required');
      }
      final screenshots = data?['screenshots'] as List? ?? [];
      for (final screenshot in screenshots) {
        final name = screenshot['screenshotName'] as String;
        if (!RegExp(r'^[a-z]+$').hasMatch(name)) {
          throw StateError('Invalid screenshot name');
        }
        final image = File('${File(path).parent.path}/$name.png');
        if (image.existsSync()) {
          throw StateError('Refusing to overwrite screenshot');
        }
        await image
            .writeAsBytes((screenshot.remove('bytes') as List).cast<int>());
        screenshot['path'] = image.path;
      }
      await File(path).writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(data)}\n');
    });
