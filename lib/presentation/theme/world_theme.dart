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

  String get worldName {
    final name = tileTheme.name;
    return '${name[0].toUpperCase()}${name.substring(1)} World';
  }

  LinearGradient get hudGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(primaryAccent, const Color(0xFF102337), 0.72)!,
          Color.lerp(primaryAccent, const Color(0xFF102337), 0.90)!,
        ],
      );

  LinearGradient get actionGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(primaryAccent, Colors.white, 0.12)!,
          Color.lerp(primaryAccent, const Color(0xFF102337), 0.40)!,
        ],
      );
}

class WorldThemes {
  const WorldThemes._();

  static const garden = WorldVisualTheme(
    tileTheme: TileVisualTheme.garden,
    background: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF075C46), Color(0xFF35BA78), Color(0xFFC7ECA0)],
      stops: [0, 0.62, 1],
    ),
    primaryAccent: Color(0xFF43C844),
    secondaryAccent: Color(0xFFB7F36A),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF5FFEC), Color(0xFFBBE5BD)],
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
      colors: [Color(0xFF073B67), Color(0xFF087FAD), Color(0xFF78D9DD)],
      stops: [0, 0.64, 1],
    ),
    primaryAccent: Color(0xFF1BC7E8),
    secondaryAccent: Color(0xFF7CEBFF),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF0FDFF), Color(0xFFB1DEEB)],
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
      colors: [Color(0xFF642860), Color(0xFFD55490), Color(0xFFFFC3A0)],
      stops: [0, 0.58, 1],
    ),
    primaryAccent: Color(0xFFFF72B6),
    secondaryAccent: Color(0xFFFF9F43),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF7FC), Color(0xFFF2C8DD)],
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
      colors: [Color(0xFF080D2B), Color(0xFF27205D), Color(0xFF62519B)],
      stops: [0, 0.62, 1],
    ),
    primaryAccent: Color(0xFF8F7CFF),
    secondaryAccent: Color(0xFFFFC857),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEEECFF), Color(0xFFB9B4DC)],
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

  static const desert = WorldVisualTheme(
    tileTheme: TileVisualTheme.desert,
    background: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF6B342B), Color(0xFFBF7549), Color(0xFFF1D294)],
      stops: [0, 0.6, 1],
    ),
    primaryAccent: Color(0xFFE9A852),
    secondaryAccent: Color(0xFF58A55C),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF0D6), Color(0xFFE7C299)],
    ),
    trayGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF9A4F2B), Color(0xFF5C2D1B)],
    ),
    boosterAccents: [Color(0xFFFFC857), Color(0xFFE76F51), Color(0xFF52B788)],
    decorationIcons: [
      Icons.local_florist_rounded,
      Icons.wb_sunny_rounded,
      Icons.change_history_rounded,
    ],
  );

  static const ice = WorldVisualTheme(
    tileTheme: TileVisualTheme.ice,
    background: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF144C83), Color(0xFF62BAD7), Color(0xFFD4F0F5)],
      stops: [0, 0.62, 1],
    ),
    primaryAccent: Color(0xFF48CAE4),
    secondaryAccent: Color(0xFFBDE0FE),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF0FDFF), Color(0xFFC1DDEB)],
    ),
    trayGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0E6EA8), Color(0xFF17345E)],
    ),
    boosterAccents: [Color(0xFFBDE0FE), Color(0xFF48CAE4), Color(0xFF7D8CFF)],
    decorationIcons: [
      Icons.ac_unit_rounded,
      Icons.terrain_rounded,
      Icons.auto_awesome_rounded,
    ],
  );

  static const jungle = WorldVisualTheme(
    tileTheme: TileVisualTheme.jungle,
    background: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF082F2B), Color(0xFF1E6C4E), Color(0xFF8BC89B)],
      stops: [0, 0.6, 1],
    ),
    primaryAccent: Color(0xFF52B788),
    secondaryAccent: Color(0xFFFFD166),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF0FADE), Color(0xFFA7CEAE)],
    ),
    trayGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1B6B46), Color(0xFF0B2F24)],
    ),
    boosterAccents: [Color(0xFFFFD166), Color(0xFF06D6A0), Color(0xFF2F9E44)],
    decorationIcons: [
      Icons.forest_rounded,
      Icons.energy_savings_leaf_rounded,
      Icons.park_rounded,
    ],
  );

  static const volcano = WorldVisualTheme(
    tileTheme: TileVisualTheme.volcano,
    background: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF21121E), Color(0xFF7C252D), Color(0xFFEE8D52)],
      stops: [0, 0.58, 1],
    ),
    primaryAccent: Color(0xFFFF5C33),
    secondaryAccent: Color(0xFFFFC857),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF0E4), Color(0xFFE7BAA2)],
    ),
    trayGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF6E1F1A), Color(0xFF220909)],
    ),
    boosterAccents: [Color(0xFFFFC857), Color(0xFFFF5C33), Color(0xFFB42318)],
    decorationIcons: [
      Icons.local_fire_department_rounded,
      Icons.terrain_rounded,
      Icons.flare_rounded,
    ],
  );

  static const dream = WorldVisualTheme(
    tileTheme: TileVisualTheme.dream,
    background: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF373064), Color(0xFF9F79BA), Color(0xFFF0C7D9)],
      stops: [0, 0.6, 1],
    ),
    primaryAccent: Color(0xFFB388FF),
    secondaryAccent: Color(0xFFFFAFCC),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF7FC), Color(0xFFD6CAE8)],
    ),
    trayGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF6D5DD3), Color(0xFF35266F)],
    ),
    boosterAccents: [Color(0xFFFFAFCC), Color(0xFFB388FF), Color(0xFFBDE0FE)],
    decorationIcons: [
      Icons.cloud_rounded,
      Icons.dark_mode_rounded,
      Icons.auto_awesome_rounded,
    ],
  );

  static const crystal = WorldVisualTheme(
    tileTheme: TileVisualTheme.crystal,
    background: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF132A53), Color(0xFF247F91), Color(0xFFB4DFDB)],
      stops: [0, 0.6, 1],
    ),
    primaryAccent: Color(0xFF4ECDC4),
    secondaryAccent: Color(0xFFFFD166),
    boardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF0FFFD), Color(0xFFB4DBDB)],
    ),
    trayGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF24577A), Color(0xFF102238)],
    ),
    boosterAccents: [Color(0xFFFFD166), Color(0xFF4ECDC4), Color(0xFFB388FF)],
    decorationIcons: [
      Icons.diamond_rounded,
      Icons.auto_awesome_rounded,
      Icons.workspace_premium_rounded,
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
      case TileVisualTheme.desert:
        return desert;
      case TileVisualTheme.ice:
        return ice;
      case TileVisualTheme.jungle:
        return jungle;
      case TileVisualTheme.volcano:
        return volcano;
      case TileVisualTheme.dream:
        return dream;
      case TileVisualTheme.crystal:
        return crystal;
    }
  }

  static WorldVisualTheme forLevel(int level) {
    return forTileTheme(tileVisualThemeForLevel(level));
  }

  static const fallbackBoardGradient = GameGradients.board;
  static const fallbackTrayGradient = GameGradients.tray;
}
