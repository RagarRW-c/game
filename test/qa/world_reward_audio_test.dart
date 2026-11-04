import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triple_tile_adventure/core/audio_service.dart';
import 'package:triple_tile_adventure/presentation/widgets/world_reward_audio.dart';

class _Audio implements GameAudioService {
  final owners = <Object>[];
  final ends = <Object?>[];
  int plays = 0;
  @override
  void beginAchievementFeedback(Object owner) => owners.add(owner);
  @override
  void cancelAchievementFeedback({Object? owner}) => ends.add(owner);
  @override
  Future<void> playWorldUnlocked() async => plays++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final enabled in [false, true]) {
    for (final interruption in ['close', 'cover', 'background', 'dispose']) {
      testWidgets('boss reward enabled=$enabled ends once on $interruption',
          (tester) async {
        final audio = _Audio();
        bool? currentAtPlayback;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
          return TextButton(
              onPressed: () => unawaited(showDialog<void>(
                  context: context,
                  builder: (dialogContext) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (dialogContext.mounted) {
                        currentAtPlayback =
                            ModalRoute.of(dialogContext)!.isCurrent;
                      }
                    });
                    return WorldRewardAudio(
                        audio: audio,
                        enabled: enabled,
                        child: AlertDialog(
                            content: const Text('Boss complete'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Close'))
                            ]));
                  })),
              child: const Text('Open'));
        })));
        await tester.tap(find.text('Open'));
        expect(audio.plays, 0, reason: 'No cue before the result is rendered.');
        await tester.pumpAndSettle();
        expect(currentAtPlayback, isTrue);
        expect(audio.plays, enabled ? 1 : 0);
        expect(audio.owners, hasLength(enabled ? 1 : 0));
        expect(audio.ends, isEmpty);
        tester.element(find.byType(WorldRewardAudio)).markNeedsBuild();
        await tester.pump();
        expect(audio.plays, enabled ? 1 : 0);

        if (interruption == 'close') {
          await tester.tap(find.text('Close'));
        } else if (interruption == 'cover') {
          final navigator =
              Navigator.of(tester.element(find.byType(WorldRewardAudio)));
          unawaited(navigator.push<void>(MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Away')))));
          await tester.pumpAndSettle();
          expect(audio.ends, orderedEquals(audio.owners));
          navigator.pop();
          await tester.pumpAndSettle();
          expect(audio.plays, enabled ? 1 : 0,
              reason: 'Returning must not replay.');
          await tester.tap(find.text('Close'));
        } else if (interruption == 'background') {
          try {
            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.paused);
            expect(audio.ends, orderedEquals(audio.owners));
          } finally {
            tester.binding
                .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          }
          await tester.pump();
          expect(audio.plays, enabled ? 1 : 0);
          await tester.tap(find.text('Close'));
        } else {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        await tester.pumpAndSettle();
        expect(audio.ends, orderedEquals(audio.owners));
        expect(audio.plays, enabled ? 1 : 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
