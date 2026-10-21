/// Bounded, deterministic difficulty rhythm. It has no persistence or economy
/// state: the caller still owns round advancement, themes and random seeds.
enum EndlessRoundKind { standard, recovery, challenge }

enum EndlessLayout { terraces, weave, cross }

class EndlessDifficulty {
  const EndlessDifficulty._({
    required this.stage,
    required this.kind,
    required this.layout,
    required this.minTiles,
    required this.maxTiles,
    required this.minLayers,
    required this.maxLayers,
    required this.typeCount,
    required this.topTiles,
    required this.offset,
  });

  /// Only used after round 13; earlier seeded recipes stay unchanged.
  factory EndlessDifficulty.forRound(int round) {
    if (round < 14) throw ArgumentError.value(round, 'round', 'Must be >= 14');
    final stage = round < 25
        ? 0
        : round < 50
            ? 1
            : round < 75
                ? 2
                : 3;
    final kind = round % 10 == 1
        ? EndlessRoundKind.recovery
        : round % 5 == 0
            ? EndlessRoundKind.challenge
            : EndlessRoundKind.standard;
    final recovery = kind == EndlessRoundKind.recovery;
    final challenge = kind == EndlessRoundKind.challenge;
    final maxTiles =
        recovery ? [54, 60, 66, 66][stage] : [60, 66, 72, 72][stage];
    final maxLayers = recovery
        ? [4, 4, 5, 5][stage]
        : stage < 2
            ? 5
            : 6;
    return EndlessDifficulty._(
      stage: stage,
      kind: kind,
      // Rotates independently of the screen's existing three-round theme cycle.
      layout: EndlessLayout.values[(round ~/ 5 + round % 5) % 3],
      minTiles: challenge ? maxTiles : maxTiles - 6,
      maxTiles: maxTiles,
      minLayers: recovery || challenge ? maxLayers : [5, 5, 5, 6][stage],
      maxLayers: maxLayers,
      typeCount: recovery
          ? [8, 9, 10, 11][stage]
          : [9, 10, 11, 12][stage] + (challenge ? 2 : 0),
      topTiles: recovery
          ? 12
          : challenge
              ? 6
              : [10, 9, 8, 8][stage],
      offset: recovery ? 0.016 : [0.018, 0.022, 0.026, 0.028][stage],
    );
  }

  final int stage;
  final EndlessRoundKind kind;
  final EndlessLayout layout;
  final int minTiles, maxTiles, minLayers, maxLayers, typeCount, topTiles;
  final double offset;

  /// A whole batch clears before the next begins. Complexity grows through
  /// the proportion of four-type batches, never through a larger tray peak.
  int batchWidth(int batch) {
    if (kind == EndlessRoundKind.recovery) return 3;
    if (kind == EndlessRoundKind.challenge) return 4;
    return switch (stage) {
      0 => batch % 3 == 2 ? 4 : 3,
      1 => batch.isOdd ? 4 : 3,
      2 => batch % 4 == 0 ? 3 : 4,
      _ => 4,
    };
  }
}
