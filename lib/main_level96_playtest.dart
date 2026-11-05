import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'level96_playtest/app.dart';
import 'level96_playtest/session.dart';

Future<void> main() async {
  requirePlaytestOptIn(); // Deliberately before binding, asset or plugin access.
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final levels = await PlaytestLevels.load();
  runApp(Level96PlaytestApp(levels: levels));
}
