import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/about_screen.dart';
import '../screens/detail_surah_screen.dart';
import '../config.dart';
import '../screens/fawaidh_baca_screen.dart';
import '../screens/fawaidh_screen.dart';
import '../screens/fawaidh_saya_screen.dart';
import '../screens/google_callback_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/tonton_screen.dart';
import '../services/sira_observer.dart';

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

  /// Halaman khusus akun yang terdaftar sebagai ustadz, untuk mengisi dan
  /// mengelola fawaidh miliknya sendiri.
  static const String fawaidhSaya = '/fawaidh-saya';

  /// Alamat halaman baca satu fawaidh.
  ///
  /// Data fawaidhnya boleh dititipkan lewat `extra` saat berpindah halaman,
  /// supaya halaman baca langsung tampil tanpa menunggu jaringan. Kalau
  /// alamatnya dibuka langsung (mis. dari tautan di web), halaman mengambil
  /// datanya sendiri dari server.
  static String bacaFawaidh(Object? id) => '/fawaidh/$id';

  /// Tautan yang bisa dibagikan untuk sebuah video atau siaran langsung.
  ///
  /// Mengarah ke versi **WEB** aplikasi ini (`/#/tonton/<id>`), bukan ke
  /// YouTube dan bukan ke aplikasi. Penerima tautan bisa langsung menonton di
  /// halaman Insyira tanpa memasang apa pun.
  static String tautanTonton(String videoId) =>
      '${AppConfig.webBaseUrl}/#/tonton/$videoId';
  static const String settings = '/settings';
  static const String about = '/tentang';

  /// Halaman pendarat setelah login Google lewat pengalihan browser (web).
  ///
  /// Backend mengalihkan ke sini lengkap dengan `?token=...`, jadi alamatnya
  /// berbentuk `/#/auth/callback?token=...`.
  static const String googleCallback = '/auth/callback';

  static const String surah = '/surah';

  /// Halaman pemutar kajian DI DALAM aplikasi (video biasa & siaran
  /// langsung). Dipakai lewat [tontonVideo].
  static const String tonton = '/tonton';

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

  /// Alamat halaman pemutar kajian.
  ///
  /// Contoh: `/tonton/dQw4w9WgXcQ?judul=...&kanal=...&live=1`.
  ///
  /// [judul] dan [kanal] hanya dipakai untuk tampilan, jadi keduanya boleh
  /// dikosongkan — halaman tetap jalan karena yang wajib hanya ID videonya.
  /// Nilai kosong otomatis tidak ikut ditulis supaya alamatnya tetap rapi.
  static String tontonVideo({
    required String videoId,
    String? judul,
    String? kanal,
    bool siaranLangsung = false,
  }) {
    return Uri(
      path: '$tonton/$videoId',
      queryParameters: <String, String>{
        if (judul != null && judul.trim().isNotEmpty) 'judul': judul,
        if (kanal != null && kanal.trim().isNotEmpty) 'kanal': kanal,
        if (siaranLangsung) 'live': '1',
      },
    ).toString();
  }
}

/// Jumlah surah di Al-Quran — dipakai untuk memvalidasi nomor dari URL.
const int _jumlahSurah = 114;

/// Bentuk ID video YouTube yang dianggap sah.
///
/// ID video normalnya 11 karakter dari huruf, angka, `-`, dan `_`. Batasnya
/// sengaja dilonggarkan (6–20) supaya ID istimewa tidak ikut ditolak, tetapi
/// tetap cukup ketat untuk menolak alamat yang jelas bukan ID video — mis.
/// `/tonton/abcd` atau tulisan berisi spasi.
final RegExp _polaIdVideo = RegExp(r'^[A-Za-z0-9_-]{6,20}$');

/// Kunci navigator global.
///
/// Dipakai oleh kode yang berada di LUAR pohon widget — terutama ketika user
/// menekan sebuah notifikasi — supaya bisa memerintahkan pindah halaman.
/// Tanpa ini, notifikasi tidak punya cara membuka halaman tertentu.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Router utama aplikasi.
///
/// Catatan: aplikasi ini bisa dipakai tanpa login (Mode Tamu), jadi
/// tidak ada route yang dikunci. Halaman awal tetap ditentukan oleh
/// [SplashScreen] lewat [AuthService].
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  navigatorKey: appNavigatorKey,

  // Sira perlu tahu kapan ada lembar bawah / dialog di atas halaman, supaya
  // bisa menyembunyikan diri selama itu.
  observers: <NavigatorObserver>[SiraObserver()],

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
      builder: (BuildContext context, GoRouterState state) => HomeScreen(
        // Tab awal boleh ditentukan dari URL, mis. `/#/home?tab=3`.
        // Nilai yang tidak sah ditangani di dalam HomeScreen.
        initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
      ),
    ),
    GoRoute(
      path: AppRoutes.fawaidh,
      name: 'fawaidh',
      builder: (BuildContext context, GoRouterState state) =>
          const FawaidhScreen(),
    ),
    GoRoute(
      // Halaman baca satu fawaidh. Angkanya divalidasi dulu: kalau bukan
      // angka, pembaca dikembalikan ke daftar daripada melihat halaman kosong.
      path: '/fawaidh/:id',
      name: 'fawaidh-baca',
      redirect: (BuildContext context, GoRouterState state) {
        final int? id = int.tryParse(state.pathParameters['id'] ?? '');

        return id == null ? AppRoutes.fawaidh : null;
      },
      builder: (BuildContext context, GoRouterState state) {
        final int id = int.parse(state.pathParameters['id']!);
        final Object? awal = state.extra;

        return FawaidhBacaScreen(
          // Kunci per-id: tanpa ini, membuka tulisan lain dari halaman baca
          // bisa tetap menampilkan tulisan yang lama.
          key: ValueKey<String>('fawaidh-baca-$id'),
          id: id,
          awal: awal is Map<String, dynamic> ? awal : null,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.fawaidhSaya,
      name: 'fawaidh-saya',
      builder: (BuildContext context, GoRouterState state) =>
          const FawaidhSayaScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (BuildContext context, GoRouterState state) =>
          const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.about,
      name: 'tentang',
      builder: (BuildContext context, GoRouterState state) =>
          const AboutScreen(),
    ),

    // Pendarat login Google lewat pengalihan browser (khusus web). Tidak ada
    // sidebar/AppBar — halaman ini langsung mengalihkan ke Home.
    GoRoute(
      path: AppRoutes.googleCallback,
      name: 'google-callback',
      builder: (BuildContext context, GoRouterState state) =>
          GoogleCallbackScreen(
            token: state.uri.queryParameters['token'],
            galat: state.uri.queryParameters['error'],
          ),
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

    // Alamat `/tonton` tanpa ID video tidak punya arti — kembalikan ke Home.
    GoRoute(
      path: AppRoutes.tonton,
      redirect: (BuildContext context, GoRouterState state) => AppRoutes.home,
    ),

    GoRoute(
      path: '${AppRoutes.tonton}/:videoId',
      name: 'tonton',
      builder: (BuildContext context, GoRouterState state) {
        // ID dari URL bisa saja tidak masuk akal (mis. `/tonton/abc` atau
        // alamat yang diketik asal-asalan), jadi wajib divalidasi dulu.
        final String id = (state.pathParameters['videoId'] ?? '').trim();

        if (!_polaIdVideo.hasMatch(id)) {
          return const _RouteFallbackScreen(
            judul: 'Video tidak ditemukan',
            pesan: 'Tautan video yang kamu buka tidak dikenali.',
          );
        }

        return TontonScreen(
          // Kunci ini PENTING. Tanpa kunci yang berubah saat ID videonya
          // berganti, Flutter akan memakai ulang halaman yang sedang tampil —
          // dan pemutarnya tetap menampilkan video LAMA walaupun alamatnya
          // sudah menunjuk video lain.
          key: ValueKey<String>('tonton-$id'),
          videoId: id,
          judul: state.uri.queryParameters['judul'] ?? '',
          kanal: state.uri.queryParameters['kanal'] ?? '',
          siaranLangsung: state.uri.queryParameters['live'] == '1',
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
