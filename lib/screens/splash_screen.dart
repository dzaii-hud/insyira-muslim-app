import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../services/auth_service.dart';
import '../widgets/responsive_content.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  /// Berkas poster splash.
  static const String _berkasPoster = 'assets/images/splash_bg.webp';

  /// Warna dasar halaman.
  static const Color _hijauTua = Color(0xFF03422F);

  /// Warna emas senada lampion di poster.
  static const Color _emas = Color(0xFFD4AF37);

  /// Tinggi poster saat layar lebar.
  ///
  /// Poster aslinya 768x1376 (potret). Kalau tingginya dibiarkan setinggi
  /// layar, lebarnya ikut membengkak dan poster memenuhi monitor sehingga
  /// terlihat berlebihan — inilah yang membuat splash terasa "segede
  /// gaban" di laptop. Tinggi dibatasi, lebarnya mengikuti rasio poster.
  static const double _tinggiPosterLayarLebar = 620;

  /// Gradasi latar yang menyambung dengan pinggiran poster.
  ///
  /// Warnanya diambil (sampling) langsung dari tepi berkas
  /// `assets/images/splash_bg.webp` pada beberapa ketinggian, jadi
  /// warnanya sama persis dengan pinggir poster. Hasilnya poster seperti
  /// menyatu dengan halaman, bukan gambar yang ditempel di tengah.
  static const LinearGradient _latarSenada = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFF084C32),
      Color(0xFF084E33),
      Color(0xFF054C36),
      Color(0xFF074A35),
      Color(0xFF03422F),
      Color(0xFF033829),
      Color(0xFF023125),
      Color(0xFF073022),
      Color(0xFF062F21),
    ],
    stops: <double>[0.0, 0.15, 0.25, 0.35, 0.5, 0.65, 0.75, 0.85, 1.0],
  );

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
    // LayoutBuilder dipakai supaya tata letak ikut menyesuaikan lebar
    // jendela — di browser ukurannya bisa berubah kapan saja.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints batas) {
        final bool layarLebar = batas.maxWidth >= kBreakpointDesktop;

        // Sisakan ruang di bawah untuk animasi memuat.
        final double tinggiPoster = math.min(
          _tinggiPosterLayarLebar,
          math.max(240.0, batas.maxHeight - 170),
        );

        return Scaffold(
          backgroundColor: _hijauTua,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // LAYER 1: Latar bergradasi, senada dengan tepi poster.
              const DecoratedBox(
                decoration: BoxDecoration(gradient: _latarSenada),
              ),

              // LAYER 2: Poster.
              if (layarLebar)
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: tinggiPoster),
                    child: Image.asset(_berkasPoster, fit: BoxFit.contain),
                  ),
                )
              else
                // Di HP poster tetap memenuhi layar seperti semula.
                Image.asset(_berkasPoster, fit: BoxFit.cover),

              // LAYER 3: Animasi loading titik-titik.
              Positioned(
                bottom: layarLebar ? 44 : 80,
                left: 0,
                right: 0,
                child: const Center(
                  child: SpinKitThreeBounce(color: _emas, size: 30.0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
