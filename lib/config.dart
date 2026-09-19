/// Konfigurasi global aplikasi Insyira.
///
/// Base URL API TIDAK lagi hardcode di tengah kode. Cara mengubahnya:
///
/// ```bash
/// # Development (default)
/// flutter run
///
/// # HP fisik / web dev: pakai IP komputer
/// flutter run --dart-define=API_BASE_URL=http://192.168.18.4:8000/api
///
/// # Emulator Android: 10.0.2.2 = localhost komputer
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
///
/// # Produksi (WAJIB https supaya web tidak kena mixed-content)
/// flutter build web --release --dart-define=API_BASE_URL=https://api.insyira.id/api
/// flutter build apk --release --dart-define=API_BASE_URL=https://api.insyira.id/api
/// ```
class AppConfig {
  AppConfig._();

  /// Nilai dari `--dart-define=API_BASE_URL=...`.
  /// Kosong kalau tidak diisi saat build/run.
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Nilai default untuk development di jaringan lokal.
  static const String _defaultBaseUrl = 'http://192.168.18.4:8000/api';

  /// Base URL API yang dipakai seluruh aplikasi.
  ///
  /// Catatan: untuk **emulator Android** host komputer dipetakan ke
  /// `10.0.2.2`, sedangkan HP fisik memakai IP komputer di jaringan yang sama.
  static String get apiBaseUrl {
    final override = _envBaseUrl.trim();
    return override.isEmpty ? _defaultBaseUrl : override;
  }

  /// Apakah aplikasi masih memakai konfigurasi default (belum di-override).
  static bool get usingDefaultBaseUrl => _envBaseUrl.trim().isEmpty;

  // =====================================================================
  // GOOGLE SIGN-IN
  // =====================================================================

  /// Client ID Google tipe **Web application**.
  ///
  /// Di web, `google_sign_in` butuh nilai ini (bukan `serverClientId`).
  /// Isi lewat:
  /// ```bash
  /// flutter build web --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
  /// ```
  ///
  /// Nilai ini HARUS juga terdaftar di backend pada `GOOGLE_ALLOWED_AUDIENCES`.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Client ID Google untuk Android/iOS (audience id_token dari HP).
  /// Sudah dipakai backend untuk memvalidasi token.
  static const String googleServerClientId =
      '38106971142-9r3vugu4javqak2dnvc0vu3nek2ocmvr.apps.googleusercontent.com';

  /// Apakah Google Sign-In web sudah dikonfigurasi.
  static bool get hasGoogleWebClientId => googleWebClientId.trim().isNotEmpty;
}
