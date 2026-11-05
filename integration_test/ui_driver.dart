import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';

/// Real pointer interaction shared by host regressions and Android tests.
class Level96UiDriver {
  Level96UiDriver(this.tester);

  final WidgetTester tester;

  Future<void> visible(Finder finder, String description) async {
    for (var frame = 0; frame < 1250 && finder.evaluate().isEmpty; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(finder, findsWidgets, reason: 'Timed out waiting for $description');
  }

  Future<void> settle() => tester.pumpAndSettle(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20));

  Future<void> tap(Finder finder) async {
    await visible(finder, finder.toString());
    await tester.ensureVisible(finder);
    // Scroll layout must complete before computing the pointer position.
    await settle();
    expect(finder.hitTestable(), findsOneWidget,
        reason: 'Requested control must be hit-testable after scrolling');
    await tester.tap(finder);
    await settle();
  }

  Future<void> selectVariant(String name) async {
    final finder = find.byKey(ValueKey(name));
    // Session history makes this ListView lazy. Materialize earlier options
    // using bounded real drags before ensureVisible can locate their render box.
    await tester.scrollUntilVisible(finder, -200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
        duration: const Duration(milliseconds: 16));
    await tap(finder);
    expect(tester.widget<ListTile>(finder).selected, true,
        reason: 'Variant selection must be visible before Start');
  }

  Future<void> tapDisabledBooster(String label) async {
    final finder = find
        .byWidgetPredicate((w) => w is GameBoosterButton && w.label == label);
    expect(finder, findsOneWidget);
    expect(tester.widget<GameBoosterButton>(finder).onPressed, isNull);
    await tester.ensureVisible(finder);
    await settle();
    final box = tester.renderObject<RenderBox>(finder);
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final screen =
        Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    expect(screen.contains(center), true,
        reason: 'Disabled booster must be rendered within the screen');
    // Disabled InkWell intentionally has no hit-test target. Send a real
    // pointer at its rendered center and assert unchanged state at the caller.
    await tester.tapAt(center);
    await settle();
  }
}
