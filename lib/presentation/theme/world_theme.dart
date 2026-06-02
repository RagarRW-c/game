import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import 'game_theme.dart';

class WorldVisualTheme {
  const WorldVisualTheme({
    required this.tileTheme,
    required this.background,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.boardGradient,
    required this.trayGradient,
    required this.boosterAccents,
    required this.decorationIcons,
  });

  final TileVisualTheme tileTheme;
  final LinearGradient background;
  final Color primaryAccent;
  final Color secondaryAccent;
  final LinearGradient boardGradient;
  final LinearGradient trayGradient;
  final List<Color> boosterAccents;
  final List<IconData> decorationIcons;
}

class WorldThemes {
  const WorldThemes._();

  static const garden = WorldVisualTheme(
    tileTheme: TileVisualTheme.garden,
    background: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1F9D65), Color(0xFF70DFA8), Color(0xFFFFD98A)],
      stops: [0, 0.62, 1],
    ),
    primaryAccent: Color(0xFF43C844),
    secondaryAccent: Color(0xFFB7F36A),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xCCF3FFE8), Color(0x9966DFA5)],
    ),
    trayGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1D7C50), Color(0xFF0F4A35)],
    ),
    boosterAccents: [Color(0xFFFFC857), Color(0xFF72D661), Color(0xFF35C99B)],
    decorationIcons: [
      Icons.local_florist_rounded,
      Icons.energy_savings_leaf_rounded,
      Icons.grass_rounded,
    ],
  );

  static const ocean = WorldVisualTheme(
    tileTheme: TileVisualTheme.ocean,
    background: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0B4AA2), Color(0xFF16B7D9), Color(0xFFBFF8FF)],
      stops: [0, 0.64, 1],
    ),
    primaryAccent: Color(0xFF1BC7E8),
    secondaryAccent: Color(0xFF7CEBFF),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xCCF0FDFF), Color(0x9952D6F5)],
    ),
    trayGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0E6EA8), Color(0xFF083B74)],
    ),
    boosterAccents: [Color(0xFF7CEBFF), Color(0xFF2D7CFF), Color(0xFF00B4D8)],
    decorationIcons: [
      Icons.waves_rounded,
      Icons.bubble_chart_rounded,
      Icons.trip_origin_rounded,
    ],
  );

  static const candy = WorldVisualTheme(
    tileTheme: TileVisualTheme.candy,
    background: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFF6FAE), Color(0xFFFFB45C), Color(0xFFFFF0B8)],
      stops: [0, 0.58, 1],
    ),
    primaryAccent: Color(0xFFFF72B6),
    secondaryAccent: Color(0xFFFF9F43),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF7FC), Color(0xBBFFD166)],
    ),
    trayGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFD43D8D), Color(0xFF8D2F72)],
    ),
    boosterAccents: [Color(0xFFFFC857), Color(0xFFFF72B6), Color(0xFFFF8F2A)],
    decorationIcons: [
      Icons.circle_rounded,
      Icons.cookie_rounded,
      Icons.donut_large_rounded,
    ],
  );

  static const space = WorldVisualTheme(
    tileTheme: TileVisualTheme.space,
    background: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF090E3F), Color(0xFF392285), Color(0xFF7B61FF)],
      stops: [0, 0.62, 1],
    ),
    primaryAccent: Color(0xFF8F7CFF),
    secondaryAccent: Color(0xFFFFC857),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xAAFFFFFF), Color(0x667B61FF)],
    ),
    trayGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF22235E), Color(0xFF0A0D33)],
    ),
    boosterAccents: [Color(0xFFFFC857), Color(0xFFB388FF), Color(0xFF66D4FF)],
    decorationIcons: [
      Icons.star_rounded,
      Icons.public_rounded,
      Icons.auto_awesome_rounded,
    ],
  );

  static WorldVisualTheme forTileTheme(TileVisualTheme theme) {
    switch (theme) {
      case TileVisualTheme.garden:
        return garden;
      case TileVisualTheme.ocean:
        return ocean;
      case TileVisualTheme.candy:
        return candy;
      case TileVisualTheme.space:
        return space;
    }
  }

  static WorldVisualTheme forLevel(int level) {
    return forTileTheme(tileVisualThemeForLevel(level));
  }

  static const fallbackBoardGradient = GameGradients.board;
  static const fallbackTrayGradient = GameGradients.tray;
}
