import 'package:flutter/material.dart';

import '../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const route = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _music = true;
  bool _sfx = true;
  final _codeController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final music = await scope.progressRepository.musicEnabled();
    final sfx = await scope.progressRepository.sfxEnabled();
    final code = await scope.progressRepository.finalCode();
    if (!mounted) return;
    setState(() {
      _music = music;
      _sfx = sfx;
      _codeController.text = code;
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            title: const Text('Background music'),
            value: _music,
            onChanged: (value) async {
              setState(() => _music = value);
              await scope.progressRepository.setMusicEnabled(value);
              await scope.audioService.setMusicEnabled(value);
            },
          ),
          SwitchListTile(
            title: const Text('Sound effects'),
            value: _sfx,
            onChanged: (value) async {
              setState(() => _sfx = value);
              scope.audioService.sfxEnabled = value;
              await scope.progressRepository.setSfxEnabled(value);
            },
          ),
          const Divider(),
          TextField(
            controller: _codeController,
            maxLength: 4,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Final 4-digit reward code',
              helperText: 'Also configurable at build time with --dart-define=FINAL_CODE=1234.',
            ),
          ),
          FilledButton(
            onPressed: () async {
              await scope.progressRepository.setFinalCode(_codeController.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code saved')),
                );
              }
            },
            child: const Text('Save Code'),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await scope.progressRepository.reset();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Progress reset')),
                );
              }
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset progress'),
          ),
        ],
      ),
    );
  }
}
