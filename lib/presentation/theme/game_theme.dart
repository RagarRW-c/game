import 'package:flutter/material.dart';

class GameColors {
  const GameColors._();

  static const primaryBlue = Color(0xFF2D7CFF);
  static const primaryBlueLight = Color(0xFF66D4FF);
  static const primaryBlueDark = Color(0xFF173A70);
  static const secondaryPurple = Color(0xFF7B61FF);
  static const accentGold = Color(0xFFFFC33D);
  static const accentGoldDark = Color(0xFFFF9800);
  static const successGreen = Color(0xFF43C844);
  static const warningOrange = Color(0xFFFF8F2A);
  static const dangerRed = Color(0xFFFF3F6E);

  static const ink = Color(0xFF14205A);
  static const mutedInk = Color(0xFF596177);
  static const panel = Color(0xFFFFFBEE);
  static const panelBlue = Color(0xFFEAF8FF);
  static const borderBlue = Color(0xFFD7EAFF);
  static const boardTint = Color(0xFF78D8FF);
  static const boardShadow = Color(0xFF102064);
  static const boardInnerShadow = Color(0xFF17225B);
  static const trayTop = Color(0xFF24357A);
  static const trayBottom = Color(0xFF101A4B);
  static const traySlotTop = Color(0xFF16224F);
  static const traySlotBottom = Color(0xFF27336A);
  static const tileFallback = Color(0xFF90CAF9);
  static const tileBlocked = Color(0xFF8290A9);
  static const tileBlockedOverlay = Color(0xFF52617E);
  static const tileHighlight = Color(0xFFFFF4A8);
  static const tileHighlightGlow = Color(0xFFFFCF33);
  static const disabledTop = Color(0xFF82899E);
  static const disabledBottom = Color(0xFF5A6174);
  static const dialogOverlay = Color(0xFF061145);
}

class GameRadius {
  const GameRadius._();

  static const small = 12.0;
  static const medium = 18.0;
  static const large = 24.0;
  static const extraLarge = 32.0;

  static BorderRadius get smallRadius => BorderRadius.circular(small);
  static BorderRadius get mediumRadius => BorderRadius.circular(medium);
  static BorderRadius get largeRadius => BorderRadius.circular(large);
  static BorderRadius get extraLargeRadius => BorderRadius.circular(extraLarge);
}

class GameSpacing {
  const GameSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class GameDurations {
  const GameDurations._();

  static const quick = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 300);
}

class GameShadows {
  const GameShadows._();

  static List<BoxShadow> light([Color color = Colors.black]) => [
        BoxShadow(
          color: color.withValues(alpha: 0.14),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];

  static List<BoxShadow> medium([Color color = Colors.black]) => [
        BoxShadow(
          color: color.withValues(alpha: 0.22),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ];

  static List<BoxShadow> heavy([Color color = Colors.black]) => [
        BoxShadow(
          color: color.withValues(alpha: 0.32),
          blurRadius: 28,
          offset: const Offset(0, 16),
        ),
      ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.42),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}

class GameGradients {
  const GameGradients._();

  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1129A8),
      Color(0xFF3356D8),
      Color(0xFF6E6CE8),
      Color(0xFFFFB66E),
    ],
    stops: [0, 0.42, 0.76, 1],
  );

  static const primaryButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [GameColors.primaryBlueLight, GameColors.primaryBlue],
  );

  static const successButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF7BEA49), GameColors.successGreen],
  );

  static const goldButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [GameColors.accentGold, GameColors.accentGoldDark],
  );

  static const dialogHeader = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [GameColors.primaryBlueLight, GameColors.primaryBlue],
  );

  static const badge = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE577), GameColors.accentGoldDark],
  );

  static const darkBadge = LinearGradient(
    colors: [Color(0xFF101D63), Color(0xFF223481)],
  );

  static const panel = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.white, GameColors.panelBlue],
  );

  static const tray = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [GameColors.trayTop, GameColors.trayBottom],
  );

  static const traySlot = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [GameColors.traySlotTop, GameColors.traySlotBottom],
  );

  static const board = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x7AFFFFFF), Color(0x4778D8FF)],
  );

  static const dangerButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF7F7F), GameColors.dangerRed],
  );

  static const disabled = LinearGradient(
    colors: [GameColors.disabledTop, GameColors.disabledBottom],
  );
}

class GameTextStyles {
  const GameTextStyles._();

  static const h1 = TextStyle(
    color: Colors.white,
    fontSize: 40,
    height: 0.95,
    fontWeight: FontWeight.w900,
    shadows: [Shadow(color: Color(0x66061145), blurRadius: 10)],
  );

  static const h2 = TextStyle(
    color: GameColors.ink,
    fontSize: 30,
    fontWeight: FontWeight.w900,
  );

  static const title = TextStyle(
    color: Colors.white,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    shadows: [
      Shadow(
        color: Color(0x66061145),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
  );

  static const body = TextStyle(
    color: GameColors.mutedInk,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const caption = TextStyle(
    color: GameColors.mutedInk,
    fontSize: 12,
    fontWeight: FontWeight.w800,
  );

  static const button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w900,
  );
}

class GameTheme {
  const GameTheme._();

  static ThemeData theme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: GameColors.primaryBlue,
        primary: GameColors.primaryBlue,
        secondary: GameColors.secondaryPurple,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: GameColors.primaryBlueDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GameTextStyles.title,
      ),
    );
  }
}
