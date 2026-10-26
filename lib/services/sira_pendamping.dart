import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keadaan maskot pendamping "Sira".
///
/// Kelas ini hanya menyimpan "Sira sedang menemani di mana" dan "mau
/// ditampilkan atau tidak". Tampilannya ada di `SiraLayer`.
///
/// Dipisah begini supaya halaman mana pun bisa melapor tanpa perlu tahu
/// bagaimana Sira digambar — dan supaya keadaan ini bisa diuji tanpa
/// membangun pohon widget.
class SiraPendamping {
  SiraPendamping._();

  static final SiraPendamping instance = SiraPendamping._();

  /// Kunci pilihan pengguna di Pengaturan.
  static const String kunciAktif = 'sira_aktif';

  /// Apakah Sira boleh tampil.
  ///
  /// Bawaannya AKTIF. Alasannya: maskot adalah bagian dari aplikasi, jadi
  /// pengguna baru berhak melihatnya lebih dulu. Kalau tidak suka, satu
  /// sakelar di Pengaturan mematikannya permanen.
  final ValueNotifier<bool> aktif = ValueNotifier<bool>(true);

  /// Ada lembar bawah atau dialog di atas halaman.
  ///
  /// Sira harus menghilang selama itu — maskot yang mengapung di atas lembar
  /// rincian kajian terbaca sebagai kesalahan tampilan, bukan sebagai teman.
  final ValueNotifier<bool> adaLapisanDiAtas = ValueNotifier<bool>(false);

  /// Alamat halaman yang sedang terbuka, mis. `/home`.
  final ValueNotifier<String> rute = ValueNotifier<String>('');

  /// Tab Home yang sedang dibuka (0..4).
  ///
  /// Tidak bisa dibaca dari URL karena tab Home berpindah tanpa mengubah
  /// alamat. Karena itu Home yang melaporkannya sendiri.
  final ValueNotifier<int> tabHome = ValueNotifier<int>(0);

  Future<void> muat() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    aktif.value = prefs.getBool(kunciAktif) ?? true;
  }

  Future<void> setAktif(bool value) async {
    aktif.value = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kunciAktif, value);
  }

  /// Dipanggil Home setiap kali tabnya berpindah.
  void laporkanTabHome(int index) => tabHome.value = index;
}
