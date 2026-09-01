import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/storage_service.dart';

class NetCareApp extends StatefulWidget {
  const NetCareApp({super.key});

  @override
  State<NetCareApp> createState() => _NetCareAppState();
}

class _NetCareAppState extends State<NetCareApp> {
  final StorageService _storage = StorageService();
  bool _isBangla = true;
  bool _darkMode = true;

  @override
  void initState() {
    super.initState();
    _restorePreferences();
  }

  Future<void> _restorePreferences() async {
    final preferences = await _storage.loadPreferences();
    if (!mounted) return;
    setState(() {
      _isBangla = preferences.isBangla;
      _darkMode = preferences.darkMode;
    });
  }

  Future<void> _setLanguage(bool value) async {
    setState(() => _isBangla = value);
    await _storage.savePreferences(isBangla: value, darkMode: _darkMode);
  }

  Future<void> _setDarkMode(bool value) async {
    setState(() => _darkMode = value);
    await _storage.savePreferences(isBangla: _isBangla, darkMode: value);
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF31D6C4);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RAR NetCare',
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F6F8),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF0D1B2A),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF07111F),
      ),
      home: HomeShell(
        storage: _storage,
        isBangla: _isBangla,
        darkMode: _darkMode,
        onLanguageChanged: _setLanguage,
        onDarkModeChanged: _setDarkMode,
      ),
    );
  }
}
