import 'package:flutter/widgets.dart';

import 'sira_pendamping.dart';

/// Mengikuti lembar bawah & dialog yang dibuka di atas halaman.
///
/// Sira perlu tahu kapan ada lapisan di atas halaman supaya bisa menyembunyikan
/// diri. Tanpa ini, maskot mengapung di atas lembar rincian kajian atau di atas
/// papan tombol — terlihat seperti kesalahan render.
///
/// [PopupRoute] adalah induk dari `ModalBottomSheetRoute` dan `DialogRoute`,
/// jadi keduanya tertangkap tanpa perlu menyebut jenisnya satu per satu.
class SiraObserver extends NavigatorObserver {
  /// Jumlah lapisan yang sedang terbuka. Dipakai sebagai penghitung, bukan
  /// nilai benar/salah, karena lembar di atas lembar bisa terjadi.
  int _jumlahLapisan = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _ubah(1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _ubah(-1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _ubah(-1);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is PopupRoute && newRoute is! PopupRoute) _ubah(-1);
    if (newRoute is PopupRoute && oldRoute is! PopupRoute) _ubah(1);
  }

  void _ubah(int selisih) {
    _jumlahLapisan = (_jumlahLapisan + selisih).clamp(0, 99);
    SiraPendamping.instance.adaLapisanDiAtas.value = _jumlahLapisan > 0;
  }
}
