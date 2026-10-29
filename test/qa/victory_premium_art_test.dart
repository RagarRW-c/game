import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/presentation/screens/win_screen.dart';
import 'package:triple_tile_adventure/presentation/widgets/victory_premium.dart';

import 'support/coastal_assets.dart';

class _DecodedArt {
  const _DecodedArt(this.width, this.height, this.pixels);
  final int width;
  final int height;
  final Uint8List pixels;
  int alpha(int x, int y) => pixels[(y * width + x) * 4 + 3];
}

Future<_DecodedArt> _decode(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  try {
    final frame = await codec.getNextFrame();
    try {
      final rgba =
          (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      return _DecodedArt(
          frame.image.width,
          frame.image.height,
          Uint8List.fromList(
              rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes)));
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void main() {
  testWidgets('all approved derivatives are bundled, bounded and transparent',
      (tester) async {
    const sizes = {
      VictoryPremiumAssets.banner: Size(1240, 317),
      VictoryPremiumAssets.star: Size(256, 241),
      VictoryPremiumAssets.unearnedStar: Size(256, 241),
      VictoryPremiumAssets.rewards: Size(1200, 625),
      VictoryPremiumAssets.primary: Size(1024, 276),
      VictoryPremiumAssets.secondary: Size(1024, 276),
      VictoryPremiumAssets.coins: Size(256, 248),
      VictoryPremiumAssets.xp: Size(256, 261),
      VictoryPremiumAssets.frame: Size(450, 800),
    };
    final decoded = await tester.runAsync(() async => {
          for (final name in sizes.keys) name: await _decode(name),
        });
    expect(decoded, isNotNull);
    if (decoded == null) fail('Production artwork decoding did not complete');
    for (final entry in sizes.entries) {
      final art = decoded[entry.key]!;
      expect(Size(art.width.toDouble(), art.height.toDouble()), entry.value,
          reason:
              '${entry.key} geometry must match its slice/opening coordinates');
      var transparent = 0;
      var opaque = 0;
      for (var index = 3; index < art.pixels.length; index += 4) {
        if (art.pixels[index] == 0) transparent++;
        if (art.pixels[index] == 255) opaque++;
      }
      expect(transparent, greaterThan(100),
          reason: '${entry.key} must not have an opaque matte');
      expect(opaque, greaterThan(100),
          reason: '${entry.key} must not be washed out');
    }
    final frame = decoded[VictoryPremiumAssets.frame]!;
    // This is the entire live-video rectangle used by the production frame,
    // not a convenient center sample that could miss opaque flowers or borders.
    final opening = Rect.fromLTWH(
        frame.width / 9,
        frame.height / 9,
        frame.width * PremiumVictoryVideoFrame.openingFraction,
        frame.height * PremiumVictoryVideoFrame.openingFraction);
    var coveredPixels = 0;
    for (var y = opening.top.ceil(); y < opening.bottom.floor(); y++) {
      for (var x = opening.left.ceil(); x < opening.right.floor(); x++) {
        if (frame.alpha(x, y) != 0) coveredPixels++;
      }
    }
    expect(coveredPixels, 0, reason: 'No frame pixel may obscure the live cat');
    final gold = decoded[VictoryPremiumAssets.star]!;
    final empty = decoded[VictoryPremiumAssets.unearnedStar]!;
    var alphaDifferences = 0;
    for (var index = 3; index < gold.pixels.length; index += 4) {
      if (empty.pixels[index] != gold.pixels[index]) alphaDifferences++;
    }
    expect(alphaDifferences, 0,
        reason: 'Every earned/unearned edge pixel must align');
    final center = ((gold.height ~/ 2) * gold.width + gold.width ~/ 2) * 4;
    expect(gold.pixels[center], greaterThan(gold.pixels[center + 2] + 80));
    expect(empty.pixels[center + 2], greaterThan(empty.pixels[center]));
  });

  for (final earned in [1, 2, 3]) {
    testWidgets(
        'illustrated result shows exactly $earned earned stars and one named banner',
        (tester) async {
      final handle = tester.ensureSemantics();
      // WidgetTester's end-of-test handle check precedes package:test teardown.
      // Release our handle before this callback returns, including on failure.
      try {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Center(
          child: SizedBox(
              width: 296,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                VictoryStars(stars: earned, illustrated: true),
                const PremiumVictoryBanner(),
              ])),
        ))));
        final reveal = tester.widget<TweenAnimationBuilder<double>>(
            find.descendant(
                of: find.byType(VictoryStars),
                matching: find.byType(TweenAnimationBuilder<double>)));
        expect(reveal.duration, const Duration(milliseconds: 1100));
        await tester.pump(const Duration(milliseconds: 1100));
        await loadCoastalImages(tester);
        final stars = tester
            .widgetList<PremiumVictoryStar>(find.byType(PremiumVictoryStar))
            .toList();
        expect(stars, hasLength(3));
        expect(stars.where((star) => star.earned), hasLength(earned));
        expect(stars.where((star) => !star.earned), hasLength(3 - earned));
        for (var index = 0; index < stars.length; index++) {
          final image = tester.widget<Image>(find.descendant(
              of: find.byKey(ValueKey('victory_star_${index + 1}')),
              matching: find.byType(Image)));
          expect(
              (image.image as AssetImage).assetName,
              index < earned
                  ? VictoryPremiumAssets.star
                  : VictoryPremiumAssets.unearnedStar);
        }
        expect(find.bySemanticsLabel('$earned of 3 stars'), findsOneWidget);
        expect(tester.getSemantics(find.byType(PremiumVictoryBanner)),
            matchesSemantics(label: 'Level Complete!', isHeader: true));
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });
  }

  testWidgets('premium rewards use live amounts and omit an absent chest',
      (tester) async {
    Future<void> show(String? chest) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
        width: 296,
        child: PremiumVictoryRewards(
            coins: 37, xp: 415, compact: true, chest: chest),
      )))));
      await loadCoastalImages(tester);
    }

    await show('Silver Chest');
    expect(find.text('+37'), findsOneWidget);
    expect(find.text('+415'), findsOneWidget);
    expect(find.text('Silver Chest'), findsOneWidget);
    expect(find.text('Rewards'), findsNothing,
        reason: 'The artwork already includes this heading');
    final images = tester.widgetList<Image>(find.descendant(
        of: find.byType(PremiumVictoryRewards), matching: find.byType(Image)));
    expect(
        images.where((image) =>
            image.image is AssetImage &&
            (image.image as AssetImage).assetName ==
                VictoryPremiumAssets.coins),
        hasLength(1));
    expect(
        images.where((image) =>
            image.image is AssetImage &&
            (image.image as AssetImage).assetName == VictoryPremiumAssets.xp),
        hasLength(1));
    await show(null);
    expect(find.byKey(const ValueKey('victory_chest')), findsNothing);
    expect(find.text('+37'), findsOneWidget);
    expect(find.text('+415'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final symbol in VictoryActionSymbol.values) {
    testWidgets(
        '$symbol shell preserves slice geometry, press feedback and disabled semantics',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        var taps = 0;
        final label = switch (symbol) {
          VictoryActionSymbol.play => 'Next Level',
          VictoryActionSymbol.replay => 'Replay',
          VictoryActionSymbol.map => 'Back to Map',
        };
        Future<void> show(bool enabled) async {
          await tester.pumpWidget(MaterialApp(
              home: Scaffold(
                  body: Center(
                      child: SizedBox(
            width: 144,
            child: PremiumVictoryButton(
                label: label,
                symbol: symbol,
                primary: symbol == VictoryActionSymbol.play,
                onPressed: enabled ? () => taps++ : null),
          )))));
          await loadCoastalImages(tester);
        }

        await show(true);
        final button = find.byType(PremiumVictoryButton);
        final art = tester.widget<Image>(
            find.descendant(of: button, matching: find.byType(Image)));
        expect(
            (art.image as ExactAssetImage).assetName,
            symbol == VictoryActionSymbol.play
                ? VictoryPremiumAssets.primary
                : VictoryPremiumAssets.secondary);
        final bounds = tester.getSize(button);
        final density = (art.image as ExactAssetImage).scale;
        expect(bounds.height,
            greaterThanOrEqualTo(symbol == VictoryActionSymbol.play ? 76 : 64));
        expect(density, closeTo(276 / bounds.height, 1e-9));
        expect(art.fit, BoxFit.fill);
        final slice = art.centerSlice!;
        expect(slice.left * density, closeTo(192, 1e-9));
        expect(slice.right * density, closeTo(832, 1e-9));
        expect(slice.top, 0);
        expect(slice.bottom * density, closeTo(276, 1e-9),
            reason: 'The full-height end caps must scale uniformly');
        expect(384 / density, lessThan(bounds.width),
            reason: 'Both fixed end caps fit without cropping or squeezing');
        expect(
            tester.getSize(
                find.descendant(of: button, matching: find.byType(Image))),
            bounds);
        final labelText = tester.widget<Text>(find.text(label));
        expect(labelText.style!.fontSize,
            symbol == VictoryActionSymbol.play ? 20 : 17);
        final icon = find.descendant(
            of: button,
            matching: find.byKey(const ValueKey('victory_action_symbol')));
        expect(tester.getSize(icon),
            Size.square(symbol == VictoryActionSymbol.play ? 28 : 24));
        expect(button.hitTestable(), findsOneWidget);
        expect(
            tester.getSemantics(button),
            matchesSemantics(
                label: label,
                isButton: true,
                hasEnabledState: true,
                isEnabled: true,
                hasTapAction: true));
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 150));
        expect(
            tester
                .widget<AnimatedScale>(find.descendant(
                    of: button, matching: find.byType(AnimatedScale)))
                .scale,
            .98);
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 120));
        expect(taps, 1);
        expect(
            tester
                .widget<AnimatedScale>(find.descendant(
                    of: button, matching: find.byType(AnimatedScale)))
                .scale,
            1);
        await show(false);
        expect(
            tester.getSemantics(button),
            matchesSemantics(
                label: label,
                isButton: true,
                hasEnabledState: true,
                isEnabled: false,
                hasTapAction: false));
        await tester.tap(button);
        await tester.pump();
        expect(taps, 1);
        expect(
            tester
                .widget<Opacity>(
                    find.descendant(of: button, matching: find.byType(Opacity)))
                .opacity,
            lessThan(1));
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });
  }
}
