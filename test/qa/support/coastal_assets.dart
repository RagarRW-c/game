import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Decode the coastal backdrop and premium result artwork separately from
/// virtual animation time, including density-aware nine-slice image providers.
Future<void> loadCoastalImages(WidgetTester tester) async {
  String? assetName(ImageProvider provider) => switch (provider) {
        AssetImage(:final assetName) => assetName,
        ExactAssetImage(:final assetName) => assetName,
        _ => null,
      };
  final images = find.byType(Image).evaluate().where((element) {
    final provider = (element.widget as Image).image;
    final name = assetName(provider);
    return name != null &&
        (name.startsWith('assets/ui/coastal/') ||
            name.startsWith('assets/ui/victory_premium/'));
  }).toList();
  if (images.isEmpty) return;
  await tester.runAsync(() async {
    final providers = {
      for (final element in images) (element.widget as Image).image,
      const AssetImage('assets/ui/coastal/victory_banner.png'),
    };
    for (final provider in providers) {
      final ready = Completer<void>();
      final stream =
          provider.resolve(createLocalImageConfiguration(images.first));
      final listener = ImageStreamListener((image, synchronous) {
        image.dispose();
        if (!ready.isCompleted) ready.complete();
      }, onError: (Object error, StackTrace? stack) {
        if (!ready.isCompleted) ready.completeError(error, stack);
      });
      stream.addListener(listener);
      try {
        await ready.future.timeout(const Duration(seconds: 5), onTimeout: () {
          throw StateError(
              'Illustrated UI image did not decode: ${assetName(provider)}');
        });
      } finally {
        stream.removeListener(listener);
      }
    }
  });
  await tester.pump();
  expect(tester.takeException(), isNull);
}
