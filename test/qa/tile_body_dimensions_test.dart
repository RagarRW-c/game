import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/tile_catalog.dart';
import 'package:triple_tile_adventure/presentation/widgets/tile_face.dart';

/// Measure the actual solid body, excluding the translucent exterior shadow.
/// One output pixel allows AA differences between raster art and vector edges;
/// a stretched full-height tray body would miss by tens of pixels.
Future<Rect> _solidBounds(void Function(Canvas) paint, Size size) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final picture = recorder.endRecording();
  try {
    final image =
        await picture.toImage(size.width.toInt(), size.height.toInt());
    try {
      final bytes = (await image.toByteData())!;
      var left = image.width, top = image.height, right = -1, bottom = -1;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (bytes.getUint8((y * image.width + x) * 4 + 3) < 250) continue;
          if (x < left) left = x;
          if (y < top) top = y;
          if (x > right) right = x;
          if (y > bottom) bottom = y;
        }
      }
      expect(right, greaterThan(left));
      expect(bottom, greaterThan(top));
      return Rect.fromLTRB(left.toDouble(), top.toDouble(),
          (right + 1).toDouble(), (bottom + 1).toDouble());
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

void _sameBounds(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 1));
  expect(actual.top, closeTo(expected.top, 1));
  expect(actual.right, closeTo(expected.right, 1));
  expect(actual.bottom, closeTo(expected.bottom, 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in [
    const Size(24, 60),
    const Size(32, 60),
    const Size(48, 48),
    const Size(72, 72)
  ]) {
    test('$size: every PNG and painted body has the same solid dimensions',
        () async {
      final active = await _solidBounds(
          (canvas) => const TileFacePainter(
                  blocked: false,
                  highlighted: false,
                  pressed: false,
                  depth: 1,
                  trayBlend: 0)
              .paint(canvas, size),
          size);
      for (final blocked in [false, true]) {
        for (final trayBlend in [0.0, 1.0]) {
          final painted = await _solidBounds(
              (canvas) => TileFacePainter(
                      blocked: blocked,
                      highlighted: false,
                      pressed: false,
                      depth: 1,
                      trayBlend: trayBlend)
                  .paint(canvas, size),
              size);
          expect(painted, active,
              reason:
                  'Coverage and tray styling cannot change body dimensions.');
        }
      }
      for (final art
          in tileCatalog.values.where((art) => art.assetPath != null)) {
        final data = await rootBundle.load(art.assetPath!);
        final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        try {
          final frame = await codec.getNextFrame();
          try {
            final png = await _solidBounds(
                (canvas) => canvas.drawImageRect(
                    frame.image,
                    const Rect.fromLTWH(0, 0, 320, 320),
                    TileFace.artworkRect(size),
                    Paint()..filterQuality = FilterQuality.medium),
                size);
            _sameBounds(png, active);
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      }
      expect(active.width, lessThanOrEqualTo(size.shortestSide));
      expect(active.height, lessThanOrEqualTo(size.shortestSide));
      expect((active.center.dy - size.height / 2).abs(), lessThan(1));
    });
  }
}
