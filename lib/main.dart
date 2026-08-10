import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // Import file home_screen.dart
import 'screens/login_screen.dart';

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
      home:
          const LoginScreen(), // Mengarah ke class yang ada di login_screen.dart
    );
  }
}
