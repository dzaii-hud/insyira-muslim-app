import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Cek sesi tersimpan sambil menampilkan splash minimal 1,5 detik,
  /// supaya user yang sudah pernah login langsung masuk Home (tidak perlu
  /// login ulang setiap membuka aplikasi).
  Future<void> _bootstrap() async {
    final minimumSplash = Future<void>.delayed(
      const Duration(milliseconds: 1500),
    );

    final sudahLogin = await _authService.isLoggedIn();
    final sesiMasihValid = sudahLogin
        ? await _authService.verifySession()
        : false;

    await minimumSplash;

    if (!mounted) return;

    // Tujuan awal ditentukan di sini (bukan di router) karena butuh
    // membaca sesi tersimpan lalu memverifikasinya ke server.
    // `go` menimpa alamat `/`, jadi tombol Back tidak balik ke splash.
    context.go(sesiMasihValid ? AppRoutes.home : AppRoutes.login);
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
          Image.asset('assets/images/splash_bg.webp', fit: BoxFit.cover),

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
