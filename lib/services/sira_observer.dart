import 'package:flutter/widgets.dart';

import 'sira_pendamping.dart';

/// Mengikuti perpindahan halaman dan lapisan yang dibuka di atasnya.
///
/// Dua tugasnya:
///
/// 1. **Melaporkan halaman yang sedang terbuka.** Memakai [NavigatorObserver],
///    bukan pendengar router: hanya observer ini yang benar-benar terpicu saat
///    halaman dibuka lewat `push`/`go` dan saat ditutup kembali. Sebelumnya
///    lapisan Sira membaca alamat dari router dan tidak ikut berubah saat
///    halaman surah dibuka — akibatnya maskot tetap tampil di halaman baca.
///
/// 2. **Menghitung lapisan di atas halaman** (lembar bawah/dialog), supaya Sira
///    bisa menyembunyikan diri selama itu.
///
/// [PopupRoute] adalah induk dari `ModalBottomSheetRoute` dan `DialogRoute`,
/// jadi keduanya tertangkap tanpa perlu menyebut jenisnya satu per satu.
class SiraObserver extends NavigatorObserver {
  /// Jumlah lapisan yang sedang terbuka. Dipakai sebagai penghitung, bukan
  /// nilai benar/salah, karena lembar di atas lembar bisa terjadi.
  int _jumlahLapisan = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      _ubah(1);
      return;
    }
    _laporkan(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      _ubah(-1);
      return;
    }

    // Kembali ke halaman sebelumnya — halaman itulah yang kini terlihat.
    if (previousRoute != null) _laporkan(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _ubah(-1);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is PopupRoute && newRoute is! PopupRoute) _ubah(-1);
    if (newRoute is PopupRoute && oldRoute is! PopupRoute) _ubah(1);
    if (newRoute != null && newRoute is! PopupRoute) _laporkan(newRoute);
  }

  void _laporkan(Route<dynamic> route) {
    final String nama = route.settings.name ?? '';
    // Route tanpa nama tidak boleh menghapus halaman yang sudah dilaporkan —
    // lebih baik Sira tetap menganggap halaman sebelumnya masih terbuka
    // daripada ia menghilang tanpa alasan.
    if (nama.isEmpty) return;
    SiraPendamping.instance.laporkanHalaman(nama);
  }

  void _ubah(int selisih) {
    _jumlahLapisan = (_jumlahLapisan + selisih).clamp(0, 99);
    SiraPendamping.instance.adaLapisanDiAtas.value = _jumlahLapisan > 0;
  }
}
