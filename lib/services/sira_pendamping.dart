import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  /// Posisi gelembung Sira, disimpan sebagai pecahan lebar/tinggi layar (0..1).
  ///
  /// Pecahan, bukan piksel: kalau layar diputar atau ukuran HP berbeda,
  /// posisinya tetap masuk akal tanpa perlu disimpan ulang.
  static const String kunciPosisiX = 'sira_posisi_x';
  static const String kunciPosisiY = 'sira_posisi_y';

  /// Apakah halaman perkenalan Sira sudah pernah dilihat.
  static const String kunciPengenalanSelesai = 'sira_pengenalan_selesai';

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

  /// Nama halaman yang sedang terbuka, mis. `home` atau `settings`.
  ///
  /// Memakai nama route (bukan alamat URL) karena itulah yang tersedia di
  /// [NavigatorObserver] — satu-satunya sumber yang benar-benar terpicu saat
  /// halaman dibuka atau ditutup, termasuk lewat `push`.
  final ValueNotifier<String> namaHalaman = ValueNotifier<String>('');

  /// Tab Home yang sedang dibuka (0..4).
  ///
  /// Tidak bisa dibaca dari URL karena tab Home berpindah tanpa mengubah
  /// alamat. Karena itu Home yang melaporkannya sendiri.
  final ValueNotifier<int> tabHome = ValueNotifier<int>(0);

  /// Posisi gelembung Sira sebagai pecahan layar, atau `null` kalau pengguna
  /// belum pernah menggesernya (pakai posisi bawaan).
  final ValueNotifier<Offset?> posisi = ValueNotifier<Offset?>(null);

  /// Apakah halaman perkenalan Sira sudah pernah tampil.
  final ValueNotifier<bool> pengenalanSelesai = ValueNotifier<bool>(false);

  Future<void> muat() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    aktif.value = prefs.getBool(kunciAktif) ?? true;
    pengenalanSelesai.value = prefs.getBool(kunciPengenalanSelesai) ?? false;

    final double? x = prefs.getDouble(kunciPosisiX);
    final double? y = prefs.getDouble(kunciPosisiY);
    if (x != null && y != null) posisi.value = Offset(x, y);
  }

  Future<void> setAktif(bool value) async {
    aktif.value = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kunciAktif, value);
  }

  /// Menyimpan posisi hasil geseran pengguna.
  Future<void> simpanPosisi(Offset pecahan) async {
    posisi.value = pecahan;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kunciPosisiX, pecahan.dx);
    await prefs.setDouble(kunciPosisiY, pecahan.dy);
  }

  /// Mengembalikan Sira ke pojok kanan bawah.
  Future<void> resetPosisi() async {
    posisi.value = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(kunciPosisiX);
    await prefs.remove(kunciPosisiY);
  }

  /// Menandai perkenalan sudah dilihat, supaya tidak muncul lagi.
  Future<void> tandaiPengenalanSelesai() async {
    pengenalanSelesai.value = true;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kunciPengenalanSelesai, true);
  }

  /// Dipanggil Home setiap kali tabnya berpindah.
  void laporkanTabHome(int index) => tabHome.value = index;

  /// Dipanggil [SiraObserver] saat halaman berganti.
  void laporkanHalaman(String nama) {
    if (namaHalaman.value == nama) return;
    _amanDariBuild(() {
      // Dicek ulang: halaman bisa sudah berganti lagi sebelum frame ini usai.
      if (namaHalaman.value != nama) namaHalaman.value = nama;
    });
  }

  /// Dipanggil [SiraObserver] saat lapisan di atas halaman dibuka atau ditutup.
  void laporkanLapisan(bool ada) {
    if (adaLapisanDiAtas.value == ada) return;
    _amanDariBuild(() => adaLapisanDiAtas.value = ada);
  }

  /// Menjalankan [ubah] tanpa memicunya di tengah fase build.
  ///
  /// [NavigatorObserver] (`didPush`/`didPop`) bisa terpanggil saat Navigator
  /// sedang membangun widgetnya. Mengubah [ValueNotifier] pada saat itu membuat
  /// `AnimatedBuilder` yang mendengarkannya memanggil `setState` di fase build,
  /// dan Flutter melempar "setState() or markNeedsBuild() called during build".
  /// Menundanya ke akhir frame membuat urutan build tetap bersih.
  void _amanDariBuild(VoidCallback ubah) {
    final SchedulerPhase fase = SchedulerBinding.instance.schedulerPhase;
    if (fase == SchedulerPhase.persistentCallbacks ||
        fase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => ubah());
      return;
    }
    ubah();
  }
}
