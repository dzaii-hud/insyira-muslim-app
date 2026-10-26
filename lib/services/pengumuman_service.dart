import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Pengumuman singkat dari server.
///
/// Ditulis pengurus lewat panel admin, jadi isinya bisa berubah kapan saja
/// tanpa perlu merilis versi baru aplikasi.
class Pengumuman {
  const Pengumuman({required this.id, required this.judul, required this.isi});

  final int id;
  final String judul;
  final String isi;

  /// Mengubah jawaban server menjadi [Pengumuman].
  ///
  /// Mengembalikan null kalau bentuknya tidak sesuai. Server memang boleh
  /// mengirim `data: null` (artinya tidak ada pengumuman), dan itu bukan
  /// kesalahan — jadi tidak perlu melempar apa pun.
  static Pengumuman? dariJson(dynamic data) {
    if (data is! Map) return null;

    final dynamic id = data['id'];
    final String judul = (data['judul'] ?? '').toString().trim();
    final String isi = (data['isi'] ?? '').toString().trim();

    if (id is! int || judul.isEmpty || isi.isEmpty) return null;

    return Pengumuman(id: id, judul: judul, isi: isi);
  }
}

/// Mengambil pengumuman yang sedang tayang.
///
/// Semua kegagalan di sini sengaja ditelan diam-diam: pengumuman hanya
/// pelengkap, dan beranda tidak boleh rusak atau menampilkan galat hanya
/// karena pesan tambahan ini gagal dimuat.
class PengumumanService {
  static const String _kunciDibaca = 'pengumuman_dibaca_id';

  static Future<Pengumuman?> ambil() async {
    try {
      final http.Response jawaban = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/pengumuman'),
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(AppConfig.requestTimeout);

      if (jawaban.statusCode != 200) return null;

      final dynamic badan = json.decode(jawaban.body);
      if (badan is! Map) return null;

      return Pengumuman.dariJson(badan['data']);
    } catch (e) {
      debugPrint('Gagal mengambil pengumuman: $e');
      return null;
    }
  }

  /// Apakah pengumuman ini belum pernah ditampilkan sebagai dialog.
  ///
  /// Yang disimpan adalah **id**, bukan sekadar "sudah pernah baca". Jadi
  /// begitu pengurus menulis pengumuman baru, dialognya muncul lagi — tanpa
  /// perlu menyuruh pengguna menghapus data aplikasi.
  static Future<bool> perluDiberitahu(int id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    return prefs.getInt(_kunciDibaca) != id;
  }

  static Future<void> tandaiSudahDibaca(int id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kunciDibaca, id);
  }
}
