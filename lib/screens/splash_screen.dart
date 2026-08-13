import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'login_screen.dart'; // Pastikan path import ini sesuai

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Timer 3 detik sebelum otomatis pindah ke Halaman Login
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF003527,
      ), // Warna Deep Emerald untuk jaga-jaga
      body: Stack(
        fit: StackFit.expand,
        children: [
          // LAYER 1: Gambar Background Utuh
          Image.asset('assets/images/splash_bg.png', fit: BoxFit.cover),

          // LAYER 2: Animasi Loading Titik-Titik di Bawah
          const Positioned(
            bottom: 80, // Jarak animasi dari ujung bawah layar
            left: 0,
            right: 0,
            child: Center(
              child: SpinKitThreeBounce(
                color: Color(0xFFD4AF37), // Warna Gold senada dengan lampion
                size: 30.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
