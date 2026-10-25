import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EasyRentApp());
}

class EasyRentApp extends StatefulWidget {
  const EasyRentApp({super.key});
  @override
  State<EasyRentApp> createState() => _EasyRentAppState();
}

class _EasyRentAppState extends State<EasyRentApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final settings = await StorageService.loadSettings();
    final dark = settings['dark'] == true;
    if (mounted) {
      setState(() => _themeMode = dark ? ThemeMode.dark : ThemeMode.light);
    }
  }

  void updateTheme(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'EasyRent Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2563EB),
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF2563EB),
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: _themeMode,
        home: PropertyHome(onThemeChanged: updateTheme),
      );
}
