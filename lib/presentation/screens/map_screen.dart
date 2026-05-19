import 'package:flutter/material.dart';

import '../../data/level_repository.dart';
import '../../main.dart';
import 'game_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  static const route = '/map';

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<int> _highestFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _highestFuture =
        AppScope.of(context).progressRepository.highestUnlockedLevel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adventure Map')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF1B8), Color(0xFFFFC3A0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<int>(
          future: _highestFuture,
          builder: (context, snapshot) {
            final highest = snapshot.data ?? 1;
            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: LevelRepository.levelCount,
              itemBuilder: (context, index) {
                final level = index + 1;
                final unlocked = level <= highest;
                return InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: unlocked
                      ? () async {
                          await Navigator.pushNamed(
                            context,
                            GameScreen.route,
                            arguments: level,
                          );
                          if (mounted) {
                            setState(() {
                              _highestFuture = AppScope.of(context)
                                  .progressRepository
                                  .highestUnlockedLevel();
                            });
                          }
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: unlocked ? Colors.white : Colors.white60,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepOrange.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(unlocked ? '⭐' : '🔒',
                            style: const TextStyle(fontSize: 42)),
                        const SizedBox(height: 8),
                        Text(
                          'Level $level',
                          style: const TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w900),
                        ),
                        Text(level < highest
                            ? 'Cleared'
                            : unlocked
                                ? 'Ready'
                                : 'Locked'),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
