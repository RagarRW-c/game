import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/domain/tile.dart';
import 'package:triple_tile_adventure/presentation/widgets/game_tile.dart';

void main() {
  testWidgets('enabled tile sends taps; disabled covered tile does not',
      (tester) async {
    var taps = 0;
    Future<void> show({required bool covered}) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
            width: 60,
            height: 60,
            child: GameTileWidget(
              tile: const Tile(id: 'a', type: 'apple', x: 0, y: 0, layer: 0),
              enabled: !covered,
              blocked: covered,
              highlighted: false,
              onTap: () => taps++,
            ),
          ))),
        ));
    await show(covered: false);
    await tester.tap(find.byType(GameTileWidget));
    await tester.pumpAndSettle();
    expect(taps, 1);
    await show(covered: true);
    await tester.tap(find.byType(GameTileWidget));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
