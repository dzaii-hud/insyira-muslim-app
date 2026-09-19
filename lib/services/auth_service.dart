import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Error dari proses autentikasi yang pesannya sudah ramah untuk user.
class AuthException implements Exception {
  AuthException(this.message, {this.fieldErrors = const {}});

  final String message;

  /// Error per field dari validasi Laravel, contoh: {'email': 'Email salah.'}
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}

/// Semua urusan autentikasi + penyimpanan sesi.
///
/// Token disimpan di SharedPreferences (di web otomatis memakai localStorage),
/// jadi user tidak perlu login ulang setiap membuka aplikasi.
class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  static const Duration _timeout = Duration(seconds: 20);

  // =====================================================================
  // LOGIN
  // =====================================================================

  /// Login pakai email + password.
  Future<Map<String, dynamic>> loginWithEmail(
    String email,
    String password,
  ) async {
    final data = await _post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    await _saveSession(data);
    return data;
  }

  /// Daftar akun baru pakai email + password.
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final data = await _post('/auth/register', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
    await _saveSession(data);
    return data;
  }

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final data = await _post('/auth/google', {'id_token': idToken});
    await _saveSession(data);
    return data;
  }

  Future<Map<String, dynamic>> loginWithApple(
    String identityToken, {
    String? fullName,
  }) async {
    final data = await _post('/auth/apple', {
      'identity_token': identityToken,
      if (fullName != null && fullName.trim().isNotEmpty)
        'name': fullName.trim(),
    });
    await _saveSession(data);
    return data;
  }

  // =====================================================================
  // SESI
  // =====================================================================

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.trim().isEmpty) return null;
    return token;
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr == null) return null;
    try {
      return json.decode(userStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async => (await getToken()) != null;

  /// Header siap pakai untuk request ke endpoint yang butuh login.
  Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Cek apakah token yang tersimpan masih berlaku.
  ///
  /// - `true`  : token valid (user tetap login)
  /// - `false` : token ditolak server (401) -> sesi lokal dibersihkan
  ///
  /// Kalau gagal karena gangguan jaringan, dianggap `true` supaya user tidak
  /// dipaksa login ulang hanya karena internetnya sedang mati.
  Future<bool> verifySession() async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/auth/user'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        // Perbarui data user yang tersimpan.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, response.body);
        return true;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await _clearSession();
        return false;
      }

      // 5xx / lainnya -> anggap masih login.
      return true;
    } on TimeoutException {
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Logout: hapus token di server (kalau bisa) lalu bersihkan sesi lokal.
  Future<void> logout() async {
    final token = await getToken();

    if (token != null) {
      try {
        await http
            .post(
              Uri.parse('${AppConfig.apiBaseUrl}/auth/logout'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(_timeout);
      } catch (_) {
        // Tidak masalah kalau server tidak terjangkau; sesi lokal tetap dibersihkan.
      }
    }

    await _clearSession();
  }

  // =====================================================================
  // INTERNAL
  // =====================================================================

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final token = data['token'];
    if (token == null) {
      throw AuthException('Server tidak mengirim token login.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token.toString());
    await prefs.setString(_userKey, json.encode(data['user'] ?? {}));
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    http.Response response;

    try {
      response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}$path'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: json.encode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw AuthException(
        'Server tidak merespons. Cek koneksi internetmu lalu coba lagi.',
      );
    } catch (e) {
      debugPrint('Gagal menghubungi server: $e');
      throw AuthException(
        'Tidak bisa terhubung ke server. Cek koneksi internetmu lalu coba lagi.',
      );
    }

    Map<String, dynamic> jsonBody = {};
    if (response.body.isNotEmpty) {
      try {
        jsonBody = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        jsonBody = {};
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonBody;
    }

    if (response.statusCode == 422) {
      // Validasi Laravel: { message, errors: { field: [pesan] } }
      final errors = <String, String>{};
      final rawErrors = jsonBody['errors'];
      if (rawErrors is Map) {
        rawErrors.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            errors[key.toString()] = value.first.toString();
          } else if (value != null) {
            errors[key.toString()] = value.toString();
          }
        });
      }

      throw AuthException(
        errors.values.isNotEmpty
            ? errors.values.first
            : (jsonBody['message']?.toString() ??
                  'Data yang dimasukkan belum benar.'),
        fieldErrors: errors,
      );
    }

    throw AuthException(
      jsonBody['message']?.toString() ??
          'Terjadi kesalahan di server (${response.statusCode}).',
    );
  }
}
