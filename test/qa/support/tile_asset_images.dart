import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wait for actual asset decoding, which pumpAndSettle alone cannot guarantee.
/// No virtual animation time is advanced; failures identify the missing asset.
Future<void> loadVisibleTileImages(WidgetTester tester) async {
  final images = find.byType(Image).evaluate().where((element) {
    final provider = (element.widget as Image).image;
    return provider is AssetImage &&
        provider.assetName.startsWith('assets/tiles/approved/');
  }).toList();
  if (images.isEmpty) return;
  await tester.runAsync(() async {
    for (final element in images) {
      final provider = (element.widget as Image).image as AssetImage;
      final stream = provider.resolve(createLocalImageConfiguration(element));
      final ready = Completer<void>();
      final listener = ImageStreamListener((image, synchronous) {
        // The listener receives its own reference-counted handle.
        image.dispose();
        if (!ready.isCompleted) ready.complete();
      }, onError: (Object error, StackTrace? stack) {
        if (!ready.isCompleted) ready.completeError(error, stack);
      });
      stream.addListener(listener);
      try {
        await ready.future.timeout(const Duration(seconds: 5), onTimeout: () {
          throw StateError('Tile image did not decode: ${provider.assetName}');
        });
      } finally {
        stream.removeListener(listener);
      }
    }
  });
  await tester.pump();
  expect(tester.takeException(), isNull);
}
