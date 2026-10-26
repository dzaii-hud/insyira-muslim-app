import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../services/auth_service.dart';

/// Halaman pendarat setelah login Google lewat **pengalihan browser** (web).
///
/// Alurnya:
/// 1. Di halaman Masuk, tombol Google membuka `<alamat-api>/auth/google`.
/// 2. Backend mengalihkan browser ke halaman Google.
/// 3. Setelah user memilih akun, backend membuat token lalu mengalihkan
///    browser kembali ke aplikasi di `/#/auth/callback?token=...`
///    (lihat `finishBrowserLogin()` di `Api\AuthController`).
/// 4. Halaman ini menyimpan token itu, mengambil data user, lalu ke Home.
///
/// Kalau gagal, backend datang dengan `?error=oauth_failed`
/// (lihat `oauthFailed()` di controller yang sama).
///
/// ⚠️ Halaman ini sengaja TANPA sidebar/AppBar — umurnya hanya sekejap.
class GoogleCallbackScreen extends StatefulWidget {
  const GoogleCallbackScreen({super.key, this.token, this.galat});

  /// Token dari backend. Null kalau login gagal.
  final String? token;

  /// Kode galat dari backend, mis. `oauth_failed`.
  final String? galat;

  @override
  State<GoogleCallbackScreen> createState() => _GoogleCallbackScreenState();
}

class _GoogleCallbackScreenState extends State<GoogleCallbackScreen> {
  /// Pesan galat yang ditampilkan. Null selama masih memproses.
  String? _pesan;

  @override
  void initState() {
    super.initState();
    // Dipanggil setelah frame pertama supaya aman memakai `context.go`.
    WidgetsBinding.instance.addPostFrameCallback((_) => _proses());
  }

  Future<void> _proses() async {
    if (widget.galat != null && widget.galat!.isNotEmpty) {
      setState(
        () => _pesan =
            'Login dengan Google gagal di server. Coba lagi ya, atau masuk '
            'memakai email & kata sandi.',
      );
      return;
    }

    final String token = (widget.token ?? '').trim();
    if (token.isEmpty) {
      setState(
        () => _pesan =
            'Server tidak mengirim token login. Coba masuk lagi dari halaman '
            'Masuk.',
      );
      return;
    }

    try {
      await AuthService().simpanSesiDariToken(token);
      if (!mounted) return;
      // `go` menimpa halaman ini, jadi token tidak ikut tertinggal di
      // alamat browser dan tombol Back tidak kembali ke sini.
      context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesan = 'Gagal menyimpan sesi login: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_pesan == null) ...<Widget>[
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF00695C),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Menyelesaikan masuk dengan Google…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF191C1D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...<Widget>[
                  const Icon(
                    Icons.error_outline,
                    size: 44,
                    color: Color(0xFFB3261E),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _pesan!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF191C1D),
                    ),
                  ),
                  const SizedBox(height: 26),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.login),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Kembali ke halaman Masuk'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
