import 'package:flutter/material.dart';
import 'screens/splash_screen.dart'; // <-- 1. INI TAMBAHAN IMPORT-NYA

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
          seedColor: const Color(0xFF1B4332),
        ), // Tema hijau gelap
        useMaterial3: true,
      ),
      home: const SplashScreen(), // <-- 2. INI KITA UBAH JADI SPLASH SCREEN
    );
  }
}
