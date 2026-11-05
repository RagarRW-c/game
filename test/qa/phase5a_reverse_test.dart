import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_surfaces.dart';

import 'phase5a_game_feel_test.dart';

void main() {
  testWidgets(
      'Phase 5A mid-flight Undo preserves the painted path and canonical state',
      (tester) async {
    await mountFeel(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    await pointer(tester, 'f0');
    final controller = effects(tester);
    final forward = controller.flights.single;
    await tester.pump(const Duration(milliseconds: 100));
    final snapshot = controller.captureUndo(
        tray(tester).trayTiles.whereType<Tile>().toList(),
        maxLayer: 0)['f0']!;
    final painted = forward.rectAt(snapshot.reverseFrom);
    expect(snapshot.rectAt(0), painted,
        reason:
            'Undo must retain the active flight curve, including its V2 pickup/arrival');
    await tester.tap(find
        .byWidgetPredicate((w) => w is GameBoosterButton && w.label == 'Undo'));
    for (var i = 0; i < 30 && !controller.flights.any((f) => f.reversed); i++) {
      await tester.pump();
    }
    final reverse = controller.flights.single;
    expect(reverse.reversed, true);
    expect(reverse.rectAt(0), painted);
    await tester
        .pump(); // Paint the committed Undo state after its async transaction.
    expect(boardTile(), findsNWidgets(9));
    expect(tray(tester).trayTiles.whereType<Tile>(), isEmpty);
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    expect(controller.flights, isEmpty);
    expect(controller.hidesBoard('f0'), false);
    expect(tester.takeException(), isNull);
  });
}
