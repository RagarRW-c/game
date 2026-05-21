import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/audio_service.dart';
import 'data/level_repository.dart';
import 'data/progress_repository.dart';
import 'presentation/screens/game_screen.dart';
import 'presentation/screens/lucky_wheel_screen.dart';
import 'presentation/screens/main_menu_screen.dart';
import 'presentation/screens/map_screen.dart';
import 'presentation/screens/settings_screen.dart';
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
          LuckyWheelScreen.route: (_) => const LuckyWheelScreen(),
          MapScreen.route: (_) => const MapScreen(),
          SettingsScreen.route: (_) => const SettingsScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == GameScreen.route) {
            return MaterialPageRoute<void>(
              builder: (_) => GameScreen(level: settings.arguments! as int),
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
