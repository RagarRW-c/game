import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Rect resultGlobalRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return Rect.fromPoints(box.localToGlobal(Offset.zero),
      box.localToGlobal(Offset(box.size.width, box.size.height)));
}

void expectResultInside(Rect outer, Rect inner, String reason) {
  final bounds = outer.inflate(0.01);
  expect(bounds.contains(inner.topLeft) && bounds.contains(inner.bottomRight),
      isTrue,
      reason: reason);
}

/// Check painted geometry, including the FittedBox transform, not just whether
/// an offscreen widget exists. Art must stay complete while text scrolls.
void expectAchievementArtworkVisible(WidgetTester tester) {
  final art = find.byKey(const ValueKey('achievement_trophy'));
  final artBounds = resultGlobalRect(tester, art);
  final panel =
      resultGlobalRect(tester, find.byKey(const ValueKey('achievement_panel')));
  final close = find.byKey(const ValueKey('achievement_close'));
  final scroll = resultGlobalRect(
      tester, find.byKey(const ValueKey('achievement_scroll')));
  expect(artBounds.width, greaterThanOrEqualTo(100),
      reason: 'The illustration must remain substantial, not be hidden.');
  expect(artBounds.height, closeTo(artBounds.width, 0.01));
  expectResultInside(
      panel, artBounds, 'The entire trophy must fit in the panel');
  expect(artBounds.overlaps(resultGlobalRect(tester, close)), isFalse);
  expect(artBounds.bottom, lessThanOrEqualTo(scroll.top + 0.01),
      reason: 'Scrolling content must not clip or cover the trophy.');
  final medal =
      resultGlobalRect(tester, find.byKey(const ValueKey('achievement_medal')));
  expectResultInside(
      artBounds, medal, 'The complete medal rim must be visible');
  final icon = resultGlobalRect(
      tester,
      find.descendant(
          of: art, matching: find.byIcon(Icons.emoji_events_rounded)));
  expectResultInside(medal, icon, 'The trophy glyph must fit inside its medal');
  expect(close.hitTestable(), findsOneWidget);
}

void expectResultTextVisible(
    WidgetTester tester, String key, String scrollKey) {
  final text = find.byKey(ValueKey(key));
  expect(text, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)));
  expect(paragraph.didExceedMaxLines, isFalse,
      reason: '$key must not truncate');
  expectResultInside(
      resultGlobalRect(tester, find.byKey(ValueKey(scrollKey))),
      resultGlobalRect(tester, text),
      '$key must be entirely visible inside the scroll viewport');
}

void expectVictoryContentSeparated(WidgetTester tester) {
  final scroll =
      resultGlobalRect(tester, find.byKey(const ValueKey('victory_scroll')));
  final next = find.byKey(const ValueKey('victory_next'));
  expect(resultGlobalRect(tester, next).top - scroll.bottom,
      greaterThanOrEqualTo(19.99),
      reason:
          'Leave visible separation between scroll clipping and button shadows');
  expect(next.hitTestable(), findsOneWidget);
}

void expectVictoryDescriptionVisible(WidgetTester tester) {
  expectResultTextVisible(tester, 'victory_description', 'victory_scroll');
  final description = resultGlobalRect(
      tester, find.byKey(const ValueKey('victory_description')));
  for (final action in ['victory_next', 'victory_replay', 'victory_map']) {
    expect(
        description
            .overlaps(resultGlobalRect(tester, find.byKey(ValueKey(action)))),
        isFalse,
        reason: 'The completion description must not overlap $action');
  }
  expectVictoryContentSeparated(tester);
}
