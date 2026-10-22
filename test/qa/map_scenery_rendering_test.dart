import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/presentation/models/adventure_progress.dart';
import 'package:triple_tile_adventure/presentation/screens/world_selection_screen.dart';
import 'package:triple_tile_adventure/presentation/theme/game_theme.dart';
import 'package:triple_tile_adventure/presentation/widgets/adventure_level_node.dart';
import 'package:triple_tile_adventure/presentation/widgets/adventure_map_path.dart';
import 'package:triple_tile_adventure/presentation/widgets/adventure_world_scenery.dart';

// Characterization for experiment 3. Production scenery is already isolated.
// Picture identity proves retained paint recording, not GPU caching or FPS.
class _Scene {
  final scroll = ScrollController();
  final nodeKeys = List.generate(10, (_) => GlobalKey());
  int worldIndex = 0;
  int highest = 1;
  Map<int, int> stars = {};
  double scale = 1;
  bool reducedMotion = false;
  final taps = <int>[];

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        theme: GameTheme.theme(),
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reducedMotion,
          ),
          child: Scaffold(
            body: CustomScrollView(
              controller: scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: AdventureMapPath(
                    startLevel: gameWorlds[worldIndex].startLevel,
                    theme: gameWorlds[worldIndex].visualTheme,
                    progress: AdventureProgress(
                      highestUnlockedLevel: highest,
                      starsByLevel: stars,
                    ),
                    nodeKeys: nodeKeys,
                    onLevelTap: taps.add,
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
}

Finder get _scenery => find.byKey(const ValueKey('map_scenery'));

RenderRepaintBoundary _boundary(WidgetTester tester) =>
    tester.renderObject<RenderRepaintBoundary>(find.descendant(
      of: _scenery,
      matching: find.byType(RepaintBoundary),
    ));

CustomPaint _sceneryPaint(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.descendant(
      of: _scenery,
      matching: find.byType(CustomPaint),
    ));

CustomPaint _routePaint(WidgetTester tester) {
  final scenery = _sceneryPaint(tester);
  final regions = tester.widgetList<RepaintBoundary>(find.descendant(
    of: find.byType(AdventureMapPath),
    matching: find.byWidgetPredicate(
        (widget) => widget is RepaintBoundary && widget.child is CustomPaint),
  ));
  return regions
      .map((region) => region.child as CustomPaint)
      .singleWhere((paint) => !identical(paint, scenery));
}

Object _picture(RenderRepaintBoundary boundary) {
  final pictures = <PictureLayer>[];
  void visit(Layer layer) {
    if (layer is PictureLayer) pictures.add(layer);
    if (layer is ContainerLayer) {
      for (var child = layer.firstChild;
          child != null;
          child = child.nextSibling) {
        visit(child);
      }
    }
  }

  expect(boundary.debugNeedsPaint, isFalse);
  expect(boundary.debugLayer, isNotNull);
  visit(boundary.debugLayer!);
  expect(pictures, hasLength(1),
      reason:
          'Scenery is one continuous, independently retained paint region.');
  expect(pictures.single.picture, isNotNull);
  return pictures.single.picture!;
}

List<Invocation> _calls(CustomPainter painter, Size size, Symbol method) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, size);
  return canvas.invocations
      .map((record) => record.invocation)
      .where((call) => call.memberName == method)
      .toList();
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (var worldIndex = 0; worldIndex < gameWorlds.length; worldIndex++) {
    final world = gameWorlds[worldIndex];
    testWidgets('${world.name}: scenery survives pulse, scroll and progress',
        (tester) async {
      _viewport(tester, const Size(360, 800));
      final scene = _Scene()
        ..worldIndex = worldIndex
        ..highest = world.startLevel;
      addTearDown(scene.scroll.dispose);
      await scene.pump(tester);
      await tester.pump(const Duration(milliseconds: 16));
      final boundary = _boundary(tester);
      final picture = _picture(boundary);
      final painter = _sceneryPaint(tester).painter!;
      final routePainter = _routePaint(tester).painter!;
      expect(tester.widget<AdventureWorldScenery>(_scenery).theme,
          same(world.visualTheme));

      // Sample the live 1,200 ms current-node pulse before settling.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_picture(boundary), same(picture));
      await tester.pumpAndSettle();
      for (final offset in [360.25, 720.5, 1080.75, 0.0]) {
        scene.scroll.jumpTo(offset);
        await tester.pump();
        expect(_boundary(tester), same(boundary));
        expect(_picture(boundary), same(picture),
            reason: 'Scrolling must not re-record static scenery.');
      }

      await scene.pump(tester); // An ordinary parent rebuild.
      expect(_sceneryPaint(tester).painter!.shouldRepaint(painter), isFalse);
      expect(_picture(boundary), same(picture));
      scene.highest = world.startLevel + 5;
      scene.stars = {world.startLevel: 3};
      await scene.pump(tester);
      await tester.pumpAndSettle();
      expect(_picture(boundary), same(picture));
      expect(_routePaint(tester).painter!.shouldRepaint(routePainter), isTrue);
      final first = tester.widget<AdventureLevelNode>(
          find.byKey(ValueKey('level_${world.startLevel}')));
      expect(first.completed, isTrue);
      expect(first.stars, 3);
      await tester.tap(find.byKey(ValueKey('level_${world.startLevel}')));
      await tester.pumpAndSettle();
      expect(scene.taps, [world.startLevel]);
      expect(_picture(boundary), same(picture));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '${world.name}: one global gradient and clip for the full scene',
        (tester) async {
      final scene = _Scene()
        ..worldIndex = worldIndex
        ..reducedMotion = true;
      addTearDown(scene.scroll.dispose);
      await scene.pump(tester);
      final painter = _sceneryPaint(tester).painter!;
      final size = _boundary(tester).size;
      final clips = _calls(painter, size, #clipRect);
      expect(clips, hasLength(1));
      expect(clips.single.positionalArguments.first, Offset.zero & size);
      final backgrounds = _calls(painter, size, #drawRect);
      expect(backgrounds, hasLength(1));
      expect(backgrounds.single.positionalArguments.first, Offset.zero & size);
      expect((backgrounds.single.positionalArguments[1] as Paint).shader,
          isNotNull);
      expect(_calls(painter, size, #saveLayer), isEmpty);
      final motifs = _calls(painter, size, #translate);
      expect(motifs, hasLength((size.height / 160).ceil()));
      for (var index = 0; index < motifs.length; index++) {
        expect(motifs[index].positionalArguments, [
          size.width * (index.isEven ? .07 : .93),
          80.0 + index * 160,
        ]);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final viewport in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      for (final reduced in [false, true]) {
        testWidgets('$viewport / $scale / reduced=$reduced: route alignment',
            (tester) async {
          _viewport(tester, viewport);
          final scene = _Scene()
            ..scale = scale
            ..reducedMotion = reduced;
          addTearDown(scene.scroll.dispose);
          await scene.pump(tester);
          await tester.pumpAndSettle();
          final geometry =
              AdventureMapGeometry(viewport.width, TextScaler.linear(scale));
          final path = tester.getRect(find.byType(AdventureMapPath));
          expect(_boundary(tester).size, Size(viewport.width, geometry.height));
          final strokes = _calls(_routePaint(tester).painter!,
              Size(viewport.width, geometry.height), #drawPath);
          expect(strokes, hasLength(27));
          for (var index = 0; index < 10; index++) {
            final node =
                tester.getRect(find.byKey(ValueKey('level_${index + 1}')));
            final center = geometry.center(index);
            expect(node.center.dx - path.left, closeTo(center.dx, .001));
            expect(node.top - path.top, closeTo(center.dy - 46, .001));
            expect(node.width, closeTo(geometry.nodeWidth, .001));
            if (index < 9) {
              // The middle stroke has the unshifted curve used by the route.
              final curve =
                  strokes[index * 3 + 1].positionalArguments[0] as Path;
              final metric = curve.computeMetrics().single;
              final start = metric.getTangentForOffset(0)!.position;
              final end = metric.getTangentForOffset(metric.length)!.position;
              expect((start - center).distance, lessThan(.01));
              expect(
                  (end - geometry.center(index + 1)).distance, lessThan(.01));
            }
          }
          final picture = _picture(_boundary(tester));
          await tester.drag(
              find.byType(CustomScrollView), const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(scene.scroll.offset, greaterThan(0));
          expect(_picture(_boundary(tester)), same(picture));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('theme and size invalidate scenery; changing inputs keeps scroll',
      (tester) async {
    _viewport(tester, const Size(360, 800));
    final scene = _Scene()..reducedMotion = true;
    addTearDown(scene.scroll.dispose);
    await scene.pump(tester);
    scene.scroll.jumpTo(240.5);
    await tester.pump();
    final boundary = _boundary(tester);
    var picture = _picture(boundary);
    var painter = _sceneryPaint(tester).painter!;
    scene.worldIndex = 1;
    await scene.pump(tester);
    expect(_boundary(tester), same(boundary));
    expect(_sceneryPaint(tester).painter!.shouldRepaint(painter), isTrue);
    expect(_picture(boundary), isNot(same(picture)));
    expect(scene.scroll.offset, 240.5);
    picture = _picture(boundary);
    painter = _sceneryPaint(tester).painter!;
    scene.scale = 2;
    await scene.pump(tester);
    // Size changes repaint independently of CustomPainter.shouldRepaint.
    expect(_sceneryPaint(tester).painter!.shouldRepaint(painter), isFalse);
    expect(boundary.size.height, 2780);
    expect(_picture(boundary), isNot(same(picture)));
    expect(scene.scroll.offset, 240.5);
    picture = _picture(boundary);
    tester.view.physicalSize = const Size(412, 915);
    await tester.pump();
    expect(boundary.size.width, 412);
    expect(_picture(boundary), isNot(same(picture)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposal during a node pulse leaves no scenery animation work',
      (tester) async {
    final scene = _Scene();
    addTearDown(scene.scroll.dispose);
    await scene.pump(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AdventureWorldScenery), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('panorama mode invalidates the shared scenery painter',
      (tester) async {
    Future<void> mount(bool panorama) => tester.pumpWidget(MaterialApp(
          home: Center(
            child: SizedBox(
              width: 320,
              height: 160,
              child: AdventureWorldScenery(
                key: const ValueKey('map_scenery'),
                theme: gameWorlds.first.visualTheme,
                panorama: panorama,
              ),
            ),
          ),
        ));
    await mount(false);
    final painter = _sceneryPaint(tester).painter!;
    final boundary = _boundary(tester);
    final picture = _picture(boundary);
    await mount(true);
    expect(_boundary(tester), same(boundary));
    expect(_sceneryPaint(tester).painter!.shouldRepaint(painter), isTrue);
    expect(_picture(boundary), isNot(same(picture)));
    expect(tester.takeException(), isNull);
  });
}
