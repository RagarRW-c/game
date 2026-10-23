/// Order and equal odds match the existing nine wheel segments.
enum DailyWheelReward {
  coins30,
  coins50,
  coins75,
  coins100,
  coins150,
  coins200,
  hint,
  shuffle,
  undo;

  int? get coins => switch (this) {
        coins30 => 30,
        coins50 => 50,
        coins75 => 75,
        coins100 => 100,
        coins150 => 150,
        coins200 => 200,
        _ => null,
      };
}

class DailyWheelClaim {
  const DailyWheelClaim({
    required this.reward,
    required this.coinsBefore,
    required this.coinsAfter,
  });

  final DailyWheelReward reward;
  final int coinsBefore;
  final int coinsAfter;
}
