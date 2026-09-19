import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

// Global key untuk akses state dari mana saja
final GlobalKey<_InsyiraAppState> appKey = GlobalKey<_InsyiraAppState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('is_dark_mode') ?? true;

  runApp(InsyiraApp(key: appKey, isDarkMode: isDarkMode));
}

class InsyiraApp extends StatefulWidget {
  final bool isDarkMode;

  const InsyiraApp({super.key, required this.isDarkMode});

  @override
  State<InsyiraApp> createState() => _InsyiraAppState();
}

class _InsyiraAppState extends State<InsyiraApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  // Method untuk update theme - public
  void updateTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    // MaterialApp.router + go_router: alamat di browser ikut berubah,
    // tombol Back/Forward berfungsi wajar, dan halaman bisa di-refresh
    // tanpa kembali ke splash.
    return MaterialApp.router(
      title: 'Insyira Muslim App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
