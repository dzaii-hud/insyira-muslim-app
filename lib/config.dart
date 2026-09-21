import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;

/// Konfigurasi global aplikasi Insyira.
///
/// Ada **dua cara** menentukan alamat API, dan keduanya tetap didukung.
///
/// ### 1. Saat build (`--dart-define`) — dipakai untuk aplikasi Android/iOS
///
/// ```bash
/// flutter build apk --release --dart-define=API_BASE_URL=https://api.insyira.id/api
/// ```
///
/// Cocok untuk aplikasi HP karena nilainya ikut terpaket di dalam aplikasi:
/// mau tidak mau tetap butuh build baru untuk menggantinya.
///
/// ### 2. Saat dijalankan (`config.json`) — khusus versi web
///
/// Berkas `config.json` diletakkan di sebelah `index.html`. Isinya dibaca
/// setiap kali halaman dibuka, jadi alamat backend bisa diganti **tanpa build
/// ulang** — cukup edit satu berkas di server.
///
/// ```json
/// {
///   "apiBaseUrl": "https://insyira-api.up.railway.app/api",
///   "googleWebClientId": "xxxxx.apps.googleusercontent.com"
/// }
/// ```
///
/// Kalau `config.json` tidak ada atau isinya kosong, aplikasi otomatis
/// kembali memakai nilai `--dart-define` (dan nilai bawaan untuk development).
///
/// Urutan prioritas: `config.json` → `--dart-define` → bawaan dev.
class AppConfig {
  AppConfig._();

  // =====================================================================
  // NILAI DARI --dart-define
  // =====================================================================

  /// Nilai dari `--dart-define=API_BASE_URL=...`.
  /// Kosong kalau tidak diisi saat build/run.
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Nilai default untuk development di jaringan lokal.
  ///
  /// Dipakai hanya kalau tidak ada `config.json` dan tidak ada
  /// `--dart-define`. IP ini hanya bisa diakses dari Wi-Fi yang sama.
  static const String _defaultBaseUrl = 'http://192.168.18.4:8000/api';

  /// Client ID Google tipe **Web application** dari `--dart-define`.
  static const String _envGoogleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  // =====================================================================
  // NILAI DARI config.json (runtime)
  // =====================================================================

  /// Nama berkas konfigurasi yang diletakkan di sebelah `index.html`.
  static const String configFileName = 'config.json';

  /// Alamat API hasil pembacaan `config.json`. Null kalau belum/tidak ada.
  static String? _runtimeBaseUrl;

  /// Client ID Google web hasil pembacaan `config.json`.
  static String? _runtimeGoogleWebClientId;

  /// Penanda supaya [load] tidak melakukan pekerjaan dua kali.
  static bool _sudahDimuat = false;

  /// Membaca [configFileName] dari server.
  ///
  /// Dipanggil sekali di `main()` **sebelum** `runApp`, supaya permintaan API
  /// pertama sudah memakai alamat yang benar.
  ///
  /// Fungsi ini sengaja tidak pernah melempar error: kalau berkasnya tidak ada
  /// (misalnya aplikasi HP, atau web yang belum dikonfigurasi), aplikasi tetap
  /// jalan memakai nilai `--dart-define`/bawaan. Lebih baik aplikasi terbuka
  /// dengan alamat default daripada gagal start sama sekali.
  static Future<void> load() async {
    if (_sudahDimuat) return;
    _sudahDimuat = true;

    // Hanya versi web yang punya berkas statis di sebelah halaman.
    if (!kIsWeb) return;

    try {
      // `Uri.base.origin` = skema + host + port, TANPA path/query/fragment.
      // Ini penting: kalau memakai Uri.base begitu saja, halaman
      // `/surah/2?ayat=255` akan membuat alamat berkasnya ikut jadi
      // `/surah/config.json` dan gagal.
      final Uri alamat = Uri.parse('${Uri.base.origin}/$configFileName');

      final http.Response respons = await http
          .get(alamat)
          .timeout(const Duration(seconds: 5));

      if (respons.statusCode != 200) {
        debugPrint(
          'AppConfig: $configFileName tidak ditemukan '
          '(HTTP ${respons.statusCode}). Memakai nilai bawaan.',
        );
        return;
      }

      // ⚠️ Buang BOM (\uFEFF) di awal berkas kalau ada.
      //
      // Alat di Windows — misalnya `Set-Content -Encoding utf8` pada
      // PowerShell 5.1 — sering menyisipkan karakter ini. `jsonDecode`
      // menolaknya dengan "Unexpected character", dan karena kegagalannya
      // ditangkap blok catch di bawah, aplikasi hanya akan diam-diam memakai
      // alamat API bawaan. Gejalanya: web terbuka normal tapi seluruh data
      // kosong dan login gagal, tanpa pesan error apa pun.
      final String teks = respons.body.replaceFirst('\uFEFF', '');

      final Object? isi = jsonDecode(teks);

      if (isi is! Map) {
        debugPrint('AppConfig: isi $configFileName bukan objek JSON.');
        return;
      }

      _runtimeBaseUrl = _teksBersih(isi['apiBaseUrl']);
      _runtimeGoogleWebClientId = _teksBersih(isi['googleWebClientId']);

      debugPrint(
        'AppConfig: $configFileName terbaca '
        '(apiBaseUrl=${_runtimeBaseUrl ?? '-'}).',
      );
    } catch (e) {
      // Termasuk: berkas tidak ada, JSON rusak, atau koneksi lambat.
      debugPrint('AppConfig: gagal membaca $configFileName ($e).');
    }
  }

  /// Ambil nilai teks dari JSON. Mengembalikan null kalau bukan teks atau
  /// isinya kosong, supaya pengecekan di pemanggil jadi sederhana.
  static String? _teksBersih(Object? nilai) {
    if (nilai is! String) return null;

    final String teks = nilai.trim();

    return teks.isEmpty ? null : teks;
  }

  /// Buang garis miring di akhir supaya tidak jadi `//kajian` saat digabung.
  static String _tanpaGarisMiringAkhir(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  // =====================================================================
  // NILAI YANG DIPAKAI APLIKASI
  // =====================================================================

  /// Base URL API yang dipakai seluruh aplikasi.
  ///
  /// Contoh hasil: `https://insyira-api.up.railway.app/api`.
  ///
  /// Catatan: untuk **emulator Android** host komputer dipetakan ke
  /// `10.0.2.2`, sedangkan HP fisik memakai IP komputer di jaringan yang sama.
  static String get apiBaseUrl {
    final String? runtime = _runtimeBaseUrl;
    if (runtime != null) return _tanpaGarisMiringAkhir(runtime);

    final String dariBuild = _envBaseUrl.trim();
    if (dariBuild.isNotEmpty) return _tanpaGarisMiringAkhir(dariBuild);

    return _tanpaGarisMiringAkhir(_defaultBaseUrl);
  }

  /// Apakah aplikasi masih memakai alamat bawaan (development).
  ///
  /// Berguna untuk menampilkan peringatan "alamat API belum diatur" di web.
  static bool get usingDefaultBaseUrl =>
      _runtimeBaseUrl == null && _envBaseUrl.trim().isEmpty;

  // =====================================================================
  // GOOGLE SIGN-IN
  // =====================================================================

  /// Client ID Google tipe **Web application**.
  ///
  /// Di web, `google_sign_in` butuh nilai ini (bukan `serverClientId`).
  /// Isinya bisa datang dari `config.json` atau dari:
  /// ```bash
  /// flutter build web --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
  /// ```
  ///
  /// Nilai ini HARUS juga terdaftar di backend pada `GOOGLE_ALLOWED_AUDIENCES`.
  static String get googleWebClientId =>
      _runtimeGoogleWebClientId ?? _envGoogleWebClientId.trim();

  /// Client ID Google untuk Android/iOS (audience id_token dari HP).
  /// Sudah dipakai backend untuk memvalidasi token.
  static const String googleServerClientId =
      '38106971142-9r3vugu4javqak2dnvc0vu3nek2ocmvr.apps.googleusercontent.com';

  /// Apakah Google Sign-In web sudah dikonfigurasi.
  static bool get hasGoogleWebClientId => googleWebClientId.trim().isNotEmpty;
}
