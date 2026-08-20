import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const InsyiraApp());
}

class InsyiraApp extends StatelessWidget {
  const InsyiraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Insyira Muslim App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF022C22),
          surface: const Color(0xFF022C22),
        ),
        scaffoldBackgroundColor: const Color(
          0xFF022C22,
        ), // Deep Forest dari HTML

        // ... (biarkan sisanya sama)
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
