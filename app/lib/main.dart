import 'dart:async';

import 'package:flutter/material.dart';

import 'data/json_note_store.dart';
import 'data/note_store.dart';
import 'models/app_settings.dart';
import 'screens/home_screen.dart';
import 'services/settings_store.dart';
import 'theme/offload_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore().load();
  final noteStore = await JsonNoteStore.open();
  runApp(OffloadApp(initialSettings: settings, noteStore: noteStore));
}

class OffloadApp extends StatefulWidget {
  const OffloadApp({
    super.key,
    required this.noteStore,
    this.initialSettings = const AppSettings(),
  });

  final NoteStore noteStore;
  final AppSettings initialSettings;

  @override
  State<OffloadApp> createState() => _OffloadAppState();
}

class _OffloadAppState extends State<OffloadApp> {
  final SettingsStore _settingsStore = SettingsStore();
  late AppSettings _settings = widget.initialSettings;
  Timer? _saveTimer;

  void _updateSettings(AppSettings settings) {
    setState(() {
      _settings = settings;
    });
    // Ползунок шлёт много событий: пишем на диск с небольшой задержкой.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_settingsStore.save(settings));
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offload',
      debugShowCheckedModeBanner: false,
      theme: buildOffloadTheme(
        dark: _settings.isDark,
        cornerRadius: _settings.cornerRadius,
        deepBlack: _settings.deepBlack,
      ),
      home: HomeScreen(
        settings: _settings,
        onSettingsChanged: _updateSettings,
        noteStore: widget.noteStore,
      ),
    );
  }
}
