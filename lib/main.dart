import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/audio_service.dart';
import 'data/level_repository.dart';
import 'data/progress_repository.dart';
import 'presentation/screens/achievements_screen.dart';
import 'presentation/screens/booster_shop_screen.dart';
import 'presentation/screens/collection_book_screen.dart';
import 'presentation/screens/daily_challenges_screen.dart';
import 'presentation/screens/final_code_screen.dart';
import 'presentation/screens/game_screen.dart';
import 'presentation/screens/lucky_wheel_screen.dart';
import 'presentation/screens/main_menu_screen.dart';
import 'presentation/screens/map_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/statistics_screen.dart';
import 'presentation/screens/world_selection_screen.dart';
import 'presentation/theme/game_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(TripleTileApp());
}

class TripleTileApp extends StatefulWidget {
  TripleTileApp({super.key});

  final progressRepository = ProgressRepository();
  final levelRepository = LevelRepository();
  final audioService = GameAudioService();

  @override
  State<TripleTileApp> createState() => _TripleTileAppState();
}

class _TripleTileAppState extends State<TripleTileApp> {
  @override
  void initState() {
    super.initState();
    _loadAudioPrefs();
  }

  Future<void> _loadAudioPrefs() async {
    widget.audioService.musicEnabled =
        await widget.progressRepository.musicEnabled();
    widget.audioService.sfxEnabled =
        await widget.progressRepository.sfxEnabled();
    await widget.audioService.startMusic();
  }

  @override
  void dispose() {
    widget.audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      progressRepository: widget.progressRepository,
      levelRepository: widget.levelRepository,
      audioService: widget.audioService,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Triple Tile Adventure',
        theme: GameTheme.theme(),
        locale: const Locale('en'),
        supportedLocales: const [Locale('en')],
        routes: {
          MainMenuScreen.route: (_) => const MainMenuScreen(),
          AchievementsScreen.route: (_) => const AchievementsScreen(),
          BoosterShopScreen.route: (_) => const BoosterShopScreen(),
          CollectionBookScreen.route: (_) => const CollectionBookScreen(),
          DailyChallengesScreen.route: (_) => const DailyChallengesScreen(),
          FinalCodeScreen.route: (_) => const FinalCodeScreen(),
          LuckyWheelScreen.route: (_) => const LuckyWheelScreen(),
          WorldSelectionScreen.route: (_) => const WorldSelectionScreen(),
          SettingsScreen.route: (_) => const SettingsScreen(),
          StatisticsScreen.route: (_) => const StatisticsScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == GameScreen.route) {
            return MaterialPageRoute<void>(
              builder: (_) => GameScreen(level: settings.arguments! as int),
            );
          }
          if (settings.name == MapScreen.route) {
            return MaterialPageRoute<void>(
              builder: (_) =>
                  MapScreen(world: settings.arguments! as GameWorld),
            );
          }
          return null;
        },
      ),
    );
  }
}

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.progressRepository,
    required this.levelRepository,
    required this.audioService,
    required super.child,
  });

  final ProgressRepository progressRepository;
  final LevelRepository levelRepository;
  final GameAudioService audioService;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
