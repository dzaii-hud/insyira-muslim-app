import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/detail_surah_screen.dart';
import '../screens/fawaidh_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';

/// Daftar alamat (URL) halaman aplikasi.
///
/// Semua alamat dipusatkan di sini supaya tidak ada string URL yang
/// ditulis manual di dalam layar. Kalau suatu saat alamatnya berubah,
/// cukup ubah di satu tempat ini.
///
/// Manfaat di web:
/// * alamat di address bar ikut berubah saat pindah halaman,
/// * tombol Back / Forward browser berfungsi wajar,
/// * halaman bisa di-refresh tanpa kembali ke splash,
/// * tautan bisa dibagikan, mis. `/surah/2?ayat=255&mode=mushaf`.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String fawaidh = '/fawaidh';
  static const String settings = '/settings';
  static const String surah = '/surah';

  /// Alamat halaman detail surah.
  ///
  /// Contoh: `/surah/2`, `/surah/2?ayat=255`, atau
  /// `/surah/2?mode=mushaf&page=42`.
  ///
  /// Parameter yang bernilai `null` otomatis tidak ikut ditulis, jadi
  /// alamatnya tetap rapi.
  static String surahDetail({
    required int nomorSurah,
    int? ayat,
    String? mode,
    int? mushafPage,
  }) {
    return Uri(
      path: '$surah/$nomorSurah',
      queryParameters: <String, String>{
        if (ayat != null) 'ayat': '$ayat',
        if (mode != null && mode.isNotEmpty) 'mode': mode,
        if (mushafPage != null) 'page': '$mushafPage',
      },
    ).toString();
  }
}

/// Jumlah surah di Al-Quran — dipakai untuk memvalidasi nomor dari URL.
const int _jumlahSurah = 114;

/// Router utama aplikasi.
///
/// Catatan: aplikasi ini bisa dipakai tanpa login (Mode Tamu), jadi
/// tidak ada route yang dikunci. Halaman awal tetap ditentukan oleh
/// [SplashScreen] lewat [AuthService].
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,

  // Mencetak log navigasi saat mode debug saja — berguna untuk melacak
  // masalah back/forward di web.
  debugLogDiagnostics: kDebugMode,

  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      builder: (BuildContext context, GoRouterState state) =>
          const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (BuildContext context, GoRouterState state) =>
          const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      name: 'register',
      builder: (BuildContext context, GoRouterState state) =>
          const RegisterScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.fawaidh,
      name: 'fawaidh',
      builder: (BuildContext context, GoRouterState state) =>
          const FawaidhScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (BuildContext context, GoRouterState state) =>
          const SettingsScreen(),
    ),

    // Alamat `/surah` tanpa nomor tidak punya arti — kembalikan ke Home
    // daripada menampilkan halaman "tidak ditemukan".
    GoRoute(
      path: AppRoutes.surah,
      redirect: (BuildContext context, GoRouterState state) => AppRoutes.home,
    ),

    GoRoute(
      path: '${AppRoutes.surah}/:nomor',
      name: 'surah-detail',
      builder: (BuildContext context, GoRouterState state) {
        // Nomor dari URL bisa saja tidak masuk akal (mis. `/surah/999`
        // atau `/surah/abc`), jadi wajib divalidasi dulu.
        final int? nomor = int.tryParse(state.pathParameters['nomor'] ?? '');

        if (nomor == null || nomor < 1 || nomor > _jumlahSurah) {
          return const _RouteFallbackScreen(
            judul: 'Surah tidak ditemukan',
            pesan: 'Al-Quran hanya memiliki 114 surah.',
          );
        }

        return DetailSurahScreen(
          nomorSurah: nomor,
          initialAyat: _angkaDariQuery(state, 'ayat'),
          initialMode: state.uri.queryParameters['mode'],
          initialMushafPage: _angkaDariQuery(state, 'page'),
        );
      },
    ),
  ],

  // Halaman cadangan kalau alamat yang dibuka tidak dikenal.
  errorBuilder: (BuildContext context, GoRouterState state) =>
      const _RouteFallbackScreen(
        judul: 'Halaman tidak ditemukan',
        pesan: 'Alamat yang kamu buka tidak ada di aplikasi ini.',
      ),
);

/// Kembali satu langkah kalau memang ada halaman sebelumnya.
///
/// Dipakai oleh tombol back di AppBar. Kalau halaman dibuka langsung dari
/// URL (mis. user menempel `/surah/2` di address bar), tidak ada halaman
/// yang bisa di-pop — jadi kita arahkan ke Home supaya tombolnya tidak
/// terasa mati.
void popOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.home);
  }
}

/// Membaca angka dari query string URL dengan aman.
///
/// Mengembalikan `null` kalau parameternya tidak ada atau bukan angka,
/// supaya nilai sampah di URL tidak membuat aplikasi error.
int? _angkaDariQuery(GoRouterState state, String key) {
  final String? mentah = state.uri.queryParameters[key];
  if (mentah == null || mentah.isEmpty) return null;
  return int.tryParse(mentah);
}

/// Halaman sederhana untuk alamat yang salah / tidak dikenal.
///
/// Dipakai dua keadaan: nomor surah di luar 1–114, dan alamat yang
/// memang tidak terdaftar di [appRouter].
class _RouteFallbackScreen extends StatelessWidget {
  const _RouteFallbackScreen({required this.judul, required this.pesan});

  final String judul;
  final String pesan;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.explore_off_outlined,
                size: 56,
                color: tema.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                judul,
                textAlign: TextAlign.center,
                style: tema.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                pesan,
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Icons.home_filled),
                label: const Text('Kembali ke Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
